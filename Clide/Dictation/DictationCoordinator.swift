import AppKit
import KeyboardShortcuts

/// Orchestrates the sacred path: global shortcut → record → transcribe → insert.
/// Owns the pieces that make it up so each of them can stay small and focused.
@MainActor
final class DictationCoordinator {
    private let audioCapture = AudioCaptureService()
    private let transcriptionEngine: TranscriptionEngine
    private let pillWindow = DictationPillWindow()

    private var state: PillState = .idle {
        didSet { pillWindow.update(state: state) }
    }
    private var isListening = false
    private var hideTask: Task<Void, Never>?
    private var escapeMonitor: Any?

    init(transcriptionEngine: TranscriptionEngine = WhisperKitTranscriptionEngine()) {
        self.transcriptionEngine = transcriptionEngine
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
            try audioCapture.startRecording()
            isListening = true
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

        guard !samples.isEmpty else {
            state = .idle
            return
        }

        state = .transcribing
        Task { await transcribeAndInsert(samples: samples) }
    }

    private func cancelListening() {
        guard isListening else { return }
        stopEscapeMonitor()
        isListening = false
        _ = audioCapture.stopRecording()
        state = .idle
    }

    // MARK: - Transcribe / insert

    private func transcribeAndInsert(samples: [Float]) async {
        do {
            let text = try await transcriptionEngine.transcribe(samples: samples)
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
