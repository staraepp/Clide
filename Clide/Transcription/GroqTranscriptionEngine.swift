import Foundation

/// BYOK cloud transcription via Groq's OpenAI-compatible Whisper endpoint.
/// Audio goes straight from this device to Groq using the user's own API key —
/// no Clide-owned proxy, per clide.md §10.
struct GroqTranscriptionEngine: TranscriptionEngine {
    private static let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!

    let modelName: String

    init(modelName: String = "whisper-large-v3-turbo") {
        self.modelName = modelName
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let key = CloudProvider.groq.apiKey, !key.isEmpty else {
            throw CloudProviderError.missingKey(.groq)
        }

        let boundary = "Clide-\(UUID().uuidString)"
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        let header = CloudProvider.groq.authorizationHeader(for: key)
        request.setValue(header.value, forHTTPHeaderField: header.field)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            model: modelName,
            wavData: WAVEncoder.encode(samples: samples)
        )
        request.timeoutInterval = 60

        let data = try await CloudRequest.perform(request, provider: .groq)
        let decoded = try CloudRequest.decode(GroqTranscriptionResponse.self, from: data, provider: .groq)

        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.emptyResult }
        return text
    }

    private static func multipartBody(boundary: String, model: String, wavData: Data) -> Data {
        var body = Data()

        func appendField(name: String, value: String) {
            body.append(contentsOf: "--\(boundary)\r\n".utf8)
            body.append(contentsOf: "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8)
            body.append(contentsOf: "\(value)\r\n".utf8)
        }

        appendField(name: "model", value: model)
        appendField(name: "response_format", value: "json")

        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"file\"; filename=\"dictation.wav\"\r\n".utf8)
        body.append(contentsOf: "Content-Type: audio/wav\r\n\r\n".utf8)
        body.append(wavData)
        body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)

        return body
    }
}

private struct GroqTranscriptionResponse: Decodable {
    let text: String
}
