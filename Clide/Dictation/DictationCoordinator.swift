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

    private var state: PillState = .idle {
        didSet { pillWindow.present(state: state) }
    }
    private var isListening = false
    private var listeningStartedAt: Date?
    private var hideTask: Task<Void, Never>?
    private var escapeMonitor: Any?

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
        guard PermissionsManager.accessibilityStatus() == .granted else {
            PermissionsManager.requestAccessibilityAccess()
            present(.error("Grant Accessibility access in System Settings, then try again"), autoHideAfter: 4)
            return
        }

        do {
            try audioCapture.startRecording { [weak self] amplitude in
                Task { @MainActor in self?.pillWindow.updateAmplitude(amplitude) }
            }
            isListening = true
            listeningStartedAt = Date()
            state = .listening
            startEscapeMonitor()
        } catch {
            present(.error(error.localizedDescription), autoHideAfter: 3)
        }
    }

    private func requestMicrophoneThenRetry() async {
        guard await PermissionsManager.requestMicrophoneAccess() else {
            present(.error("Clide needs microphone access to dictate"), autoHideAfter: 3)
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
        do {
            let engine = modelManager.currentEngine()
            let rawTranscript = try await engine.transcribe(samples: samples)

            let pipeline = TranscriptPipeline(
                fillerRemovalMode: formattingPreferences.fillerRemovalMode,
                aiFormattingMode: formattingPreferences.aiFormattingMode
            )
            let text = pipeline.process(rawTranscript).text

            statistics.record(transcript: text, speakingDuration: speakingDuration, model: model)
            handle(TextInsertionService.insert(text))
        } catch {
            present(.error(error.localizedDescription), autoHideAfter: 3)
        }
    }

    private func handle(_ outcome: InsertionOutcome) {
        switch outcome {
        case .insertedDirectly:
            present(.inserted, autoHideAfter: 1.2)
        case .copiedToClipboard:
            present(.copiedToClipboard, autoHideAfter: 2)
        case .secureFieldBlocked:
            present(.secureFieldBlocked, autoHideAfter: 2.5)
        case .failed(let message):
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
