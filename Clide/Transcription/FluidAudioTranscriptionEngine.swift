import FluidAudio
import Foundation

/// Local Parakeet transcription via FluidAudio. Mirrors WhisperKitTranscriptionEngine's
/// lazy-load-on-first-use shape; models are cached under Clide's Application Support
/// directory via `AsrModels.downloadAndLoad(to:)`.
actor FluidAudioTranscriptionEngine: TranscriptionEngine {
    private let modelVersion: AsrModelVersion
    private var manager: AsrManager?
    private var decoderState: TdtDecoderState?

    init(modelVersion: AsrModelVersion = .v2) {
        self.modelVersion = modelVersion
    }

    func prepare() async throws {
        _ = try await loadedManager()
    }

    func transcribe(samples: [Float]) async throws -> String {
        let manager = try await loadedManager()
        var state = try currentDecoderState()

        let result = try await manager.transcribe(samples, decoderState: &state)
        decoderState = state

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.emptyResult }
        return text
    }

    private func currentDecoderState() throws -> TdtDecoderState {
        if let decoderState { return decoderState }
        return try TdtDecoderState()
    }

    private func loadedManager() async throws -> AsrManager {
        if let manager { return manager }

        do {
            let models = try await AsrModels.downloadAndLoad(to: ClideStorage.modelsDirectory, version: modelVersion)
            let newManager = AsrManager(config: .default)
            try await newManager.loadModels(models)
            manager = newManager
            return newManager
        } catch {
            throw TranscriptionError.modelUnavailable(
                "Couldn't load Parakeet: \(error.localizedDescription)"
            )
        }
    }
}
