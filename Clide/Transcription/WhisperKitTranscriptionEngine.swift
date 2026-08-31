import Foundation
import WhisperKit

/// Local Whisper transcription via WhisperKit. Loads (and downloads, on first
/// use) its model lazily so app launch stays fast; the model is cached under
/// Clide's own Application Support directory rather than WhisperKit's default.
actor WhisperKitTranscriptionEngine: TranscriptionEngine {
    private let modelName: String
    private var pipe: WhisperKit?

    init(modelName: String = "tiny.en") {
        self.modelName = modelName
    }

    func prepare() async throws {
        _ = try await loadedPipe()
    }

    func transcribe(samples: [Float]) async throws -> String {
        let pipe = try await loadedPipe()
        let results = await pipe.transcribe(audioArrays: [samples])

        guard let segments = results.first ?? nil, !segments.isEmpty else {
            throw TranscriptionError.emptyResult
        }

        let text = segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.emptyResult }
        return text
    }

    private func loadedPipe() async throws -> WhisperKit {
        if let pipe { return pipe }

        do {
            let config = WhisperKitConfig(
                model: modelName,
                downloadBase: ClideStorage.modelsDirectory,
                verbose: true,
                prewarm: true,
                load: true,
                download: true
            )
            let newPipe = try await WhisperKit(config)
            pipe = newPipe
            return newPipe
        } catch {
            throw TranscriptionError.modelUnavailable(
                "Couldn't load the transcription model: \(error.localizedDescription)"
            )
        }
    }
}
