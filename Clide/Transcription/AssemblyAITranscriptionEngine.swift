import Foundation

/// BYOK transcription via AssemblyAI.
///
/// Unlike Groq and Deepgram, AssemblyAI is a three-step batch API: upload the
/// bytes, create a transcript job from the returned URL, then poll until it
/// finishes. That makes it the slowest option for dictation, which the model
/// catalog's speed score reflects.
struct AssemblyAITranscriptionEngine: TranscriptionEngine {
    private static let uploadURL = URL(string: "https://api.assemblyai.com/v2/upload")!
    private static let transcriptURL = URL(string: "https://api.assemblyai.com/v2/transcript")!

    /// Dictation clips are short; if it hasn't finished by now something is wrong.
    private static let pollTimeout: TimeInterval = 120
    private static let pollInterval: Duration = .milliseconds(750)

    let modelName: String

    init(modelName: String = "best") {
        self.modelName = modelName
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let key = CloudProvider.assemblyAI.apiKey, !key.isEmpty else {
            throw CloudProviderError.missingKey(.assemblyAI)
        }

        let audioURL = try await upload(WAVEncoder.encode(samples: samples), key: key)
        let jobID = try await createTranscript(audioURL: audioURL, key: key)
        return try await pollForResult(id: jobID, key: key)
    }

    // MARK: - Steps

    private func upload(_ wavData: Data, key: String) async throws -> String {
        var request = URLRequest(url: Self.uploadURL)
        request.httpMethod = "POST"
        applyAuth(to: &request, key: key)
        // Must be sent as raw bytes; AssemblyAI accepts the upload either way
        // but fails later in transcoding if the body isn't the audio itself.
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = wavData
        request.timeoutInterval = 120

        let data = try await CloudRequest.perform(request, provider: .assemblyAI)
        return try CloudRequest.decode(UploadResponse.self, from: data, provider: .assemblyAI).uploadURL
    }

    private func createTranscript(audioURL: String, key: String) async throws -> String {
        var request = URLRequest(url: Self.transcriptURL)
        request.httpMethod = "POST"
        applyAuth(to: &request, key: key)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["audio_url": audioURL, "speech_model": modelName]
        )
        request.timeoutInterval = 30

        let data = try await CloudRequest.perform(request, provider: .assemblyAI)
        return try CloudRequest.decode(TranscriptResponse.self, from: data, provider: .assemblyAI).id
    }

    private func pollForResult(id: String, key: String) async throws -> String {
        let deadline = Date().addingTimeInterval(Self.pollTimeout)
        let url = Self.transcriptURL.appendingPathComponent(id)

        while Date() < deadline {
            try Task.checkCancellation()

            var request = URLRequest(url: url)
            applyAuth(to: &request, key: key)
            request.timeoutInterval = 30

            let data = try await CloudRequest.perform(request, provider: .assemblyAI)
            let result = try CloudRequest.decode(TranscriptResponse.self, from: data, provider: .assemblyAI)

            switch result.status {
            case "completed":
                let text = (result.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { throw TranscriptionError.emptyResult }
                return text
            case "error":
                throw CloudProviderError.providerError(.assemblyAI, result.error ?? "transcription failed")
            default:
                try await Task.sleep(for: Self.pollInterval)
            }
        }

        throw CloudProviderError.timedOut(.assemblyAI)
    }

    private func applyAuth(to request: inout URLRequest, key: String) {
        let header = CloudProvider.assemblyAI.authorizationHeader(for: key)
        request.setValue(header.value, forHTTPHeaderField: header.field)
    }
}

private struct UploadResponse: Decodable {
    let uploadURL: String

    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
    }
}

private struct TranscriptResponse: Decodable {
    let id: String
    let status: String
    let text: String?
    let error: String?
}
