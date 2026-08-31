import AVFoundation
import Speech

/// Transcription through macOS's own speech recognizer.
///
/// `SFSpeechRecognizer` predates the deployment target, so no availability
/// gating is needed for the API itself — but whether a *usable* recognizer and
/// on-device model exist depends on the user's Mac and language settings, so
/// everything here degrades to a clear error rather than assuming.
///
/// On-device recognition is requested when the recognizer supports it, so
/// Clide's local-first promise holds. If it doesn't, Apple's recognizer would
/// use its servers — so Clide refuses instead of quietly sending audio away.
actor AppleSpeechTranscriptionEngine: TranscriptionEngine {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func prepare() async throws {
        _ = try await authorizedRecognizer()
    }

    func transcribe(samples: [Float]) async throws -> String {
        let recognizer = try await authorizedRecognizer()

        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.modelUnavailable(
                "Your Mac doesn't have an offline speech model for \(locale.identifier). "
                    + "Add it in System Settings → Keyboard → Dictation, or choose another model in Clide."
            )
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        guard let buffer = Self.makeBuffer(from: samples) else {
            throw TranscriptionError.modelUnavailable("Couldn't prepare the audio for Apple Speech.")
        }
        request.append(buffer)
        request.endAudio()

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }

                if let error {
                    hasResumed = true
                    continuation.resume(
                        throwing: TranscriptionError.modelUnavailable(
                            "Apple Speech couldn't transcribe that: \(error.localizedDescription)"
                        )
                    )
                    return
                }

                guard let result, result.isFinal else { return }
                hasResumed = true

                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    continuation.resume(throwing: TranscriptionError.emptyResult)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
    }

    // MARK: - Setup

    private func authorizedRecognizer() async throws -> SFSpeechRecognizer {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw TranscriptionError.modelUnavailable(
                "macOS doesn't offer speech recognition for \(locale.identifier)."
            )
        }
        guard recognizer.isAvailable else {
            throw TranscriptionError.modelUnavailable("Apple Speech isn't available on this Mac right now.")
        }
        guard await Self.requestAuthorization() else {
            throw TranscriptionError.modelUnavailable(
                "Clide needs Speech Recognition access. Turn it on in System Settings → Privacy & Security → Speech Recognition."
            )
        }
        return recognizer
    }

    private static func requestAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }

    private static func makeBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: AudioCaptureService.whisperSampleRate,
                  channels: 1,
                  interleaved: false
              ),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData
        else { return nil }

        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel[0].update(from: base, count: samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }
}
