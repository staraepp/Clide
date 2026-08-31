import AppKit
import KeyboardShortcuts

/// Orchestrates the sacred path: global shortcut → record → transcribe → insert.
/// Owns the pieces that make it up so each of them can stay small and focused.
@MainActor
final class DictationCoordinator {
    private let audioCapture = AudioCaptureService()
    private let modelManager: ModelManager
    private let formattingPreferences: FormattingPreferences
    private let statistics: DictationStatistics
    private let pillWindow = DictationPillWindow()

    /// When set, finished transcripts go here instead of being inserted into
    /// the focused field — onboarding's practice dictation uses this so it can
    /// show the result rather than typing it into whatever was behind the window.
    var transcriptHandler: ((String, TimeInterval) -> Void)?

    private var state: PillState = .idle {
        didSet { pillWindow.present(state: state, choiceActions: pendingChoiceActions) }
    }
    private var pendingChoiceActions: PillChoiceActions?
    private var isListening = false
    private var listeningStartedAt: Date?
    private var hideTask: Task<Void, Never>?
    private var choiceTimeoutTask: Task<Void, Never>?
    private var escapeMonitor: Any?

    /// How long the pill waits for a cleanup decision before inserting as-is.
    private static let choiceTimeout: TimeInterval = 8

    init(
        modelManager: ModelManager = .shared,
        formattingPreferences: FormattingPreferences = .shared,
        statistics: DictationStatistics = .shared
    ) {
        self.modelManager = modelManager
        self.formattingPreferences = formattingPreferences
        self.statistics = statistics
        KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
            self?.toggleDictation()
        }
    }

    func toggleDictation() {
        isListening ? stopListeningAndProcess() : startListening()
    }

    // MARK: - Start / stop

    private func startListening() {
        hideTask?.cancel()

        guard PermissionsManager.microphoneStatus() == .granted else {
            Task { await requestMicrophoneThenRetry() }
            return
        }
        // Dictation never prompts for Accessibility. It isn't required — Clide
        // transcribes and leaves the text on the clipboard without it — and
        // because ad-hoc signed builds go untrusted on every rebuild, prompting
        // here fires the dialog on every fresh launch. The pill says what's
        // missing; Settings and onboarding are where it's granted.
        do {
            try audioCapture.startRecording { [weak self] amplitude in
                Task { @MainActor in self?.pillWindow.updateAmplitude(amplitude) }
            }
            isListening = true
            listeningStartedAt = Date()
            state = .listening
            startEscapeMonitor()
        } catch {
            clideLog(.error, "audio", "Couldn't start capture: \(error.localizedDescription)")
            present(.microphoneUnavailable(error.localizedDescription), autoHideAfter: 4)
        }
    }

    private func requestMicrophoneThenRetry() async {
        guard await PermissionsManager.requestMicrophoneAccess() else {
            clideLog(.warning, "permissions", "Microphone access denied")
            present(
                .microphoneUnavailable("Clide needs microphone access — turn it on in System Settings"),
                autoHideAfter: 5
            )
            return
        }
        startListening()
    }

    private func stopListeningAndProcess() {
        stopEscapeMonitor()
        isListening = false
        let samples = audioCapture.stopRecording()
        let speakingDuration = listeningStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        listeningStartedAt = nil

        guard !samples.isEmpty else {
            state = .idle
            return
        }

        state = .transcribing
        Task { await transcribeAndInsert(samples: samples, speakingDuration: speakingDuration) }
    }

    private func cancelListening() {
        guard isListening else { return }
        stopEscapeMonitor()
        isListening = false
        listeningStartedAt = nil
        _ = audioCapture.stopRecording()
        state = .idle
    }

    // MARK: - Transcribe / insert

    private func transcribeAndInsert(samples: [Float], speakingDuration: TimeInterval) async {
        let model = modelManager.activeModel
        let startedAt = Date()
        do {
            let engine = modelManager.currentEngine()

            // First use of a local model downloads it, which is slow enough
            // that a silent "Transcribing…" would look stuck.
            if model.isLocal, !modelManager.isInstalled(model) {
                state = .modelLoading(model.displayName)
                try await modelManager.prepare(model)
            }

            state = .transcribing
            let rawTranscript = try await engine.transcribe(samples: samples)

            // Word count, not content — see DiagnosticsLog's contract.
            clideLog(
                .info,
                "transcribe",
                "\(model.id) produced \(TimeSavedCalculator.wordCount(of: rawTranscript)) words "
                    + "in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s "
                    + "from \(String(format: "%.1f", speakingDuration))s of audio"
            )

            state = .formatting
            let pipeline = TranscriptPipeline(
                fillerRemovalMode: formattingPreferences.fillerRemovalMode,
                aiFormattingMode: formattingPreferences.aiFormattingMode
            )
            let output = pipeline.process(rawTranscript)

            statistics.record(transcript: output.text, speakingDuration: speakingDuration, model: model)

            if let transcriptHandler {
                transcriptHandler(output.text, speakingDuration)
                state = .idle
                return
            }

            if output.pendingChoices.contains(.removeFillers) {
                offerFillerChoice(for: output.text)
                return
            }

            handle(TextInsertionService.insert(output.text))
        } catch {
            clideLog(.error, "transcribe", "\(model.id) failed: \(error.localizedDescription)")
            present(.error(error.localizedDescription), autoHideAfter: 5)
        }
    }

    /// Ask-each-time: the pill offers the cleanup rather than a modal, and
    /// falls back to inserting the text as-is if the user doesn't answer —
    /// never leaving a finished transcript stranded.
    private func offerFillerChoice(for text: String) {
        let insert: (String) -> Void = { [weak self] finalText in
            guard let self else { return }
            self.choiceTimeoutTask?.cancel()
            self.choiceTimeoutTask = nil
            self.pendingChoiceActions = nil
            self.handle(TextInsertionService.insert(finalText))
        }

        hideTask?.cancel()
        pendingChoiceActions = PillChoiceActions(
            removeFillers: { insert(FillerWordRemover.removeFillers(from: text)) },
            insertAsIs: { insert(text) }
        )
        state = .awaitingChoice

        choiceTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.choiceTimeout))
            guard !Task.isCancelled, self?.state == .awaitingChoice else { return }
            insert(text)
        }
    }

    private func handle(_ outcome: InsertionOutcome) {
        switch outcome {
        case .insertedDirectly:
            clideLog(.info, "insertion", "Inserted via Accessibility")
            present(.inserted, autoHideAfter: 1.2)
        case .copiedAfterInsertionFailed:
            clideLog(.warning, "insertion", "Field rejected direct insertion; pasted via clipboard")
            present(.copiedAfterInsertionFailed, autoHideAfter: 2.5)
        case .copiedUnsupportedField:
            clideLog(.warning, "insertion", "No editable field focused; pasted via clipboard")
            present(.copiedUnsupportedField, autoHideAfter: 2.5)
        case .copiedNeedsAccessibility:
            clideLog(.warning, "insertion", "Accessibility not granted; copied to clipboard only")
            present(.copiedNeedsAccessibility, autoHideAfter: 4)
        case .secureFieldBlocked:
            clideLog(.info, "insertion", "Secure field detected; nothing inserted")
            present(.secureFieldBlocked, autoHideAfter: 2.5)
        case .failed(let message):
            clideLog(.error, "insertion", "Failed: \(message)")
            present(.error(message), autoHideAfter: 3)
        }
    }

    // MARK: - Escape to cancel

    private func startEscapeMonitor() {
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return } // Escape
            Task { @MainActor in self?.cancelListening() }
        }
    }

    private func stopEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
        escapeMonitor = nil
    }

    // MARK: - Pill presentation

    private func present(_ newState: PillState, autoHideAfter seconds: TimeInterval) {
        state = newState
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            state = .idle
        }
    }
}
