import Foundation

/// BYOK cloud transcription via Groq's OpenAI-compatible Whisper endpoint.
/// Audio goes straight from this device to Groq using the user's own API key —
/// no Clide-owned proxy, per clide.md §10.
struct GroqTranscriptionEngine: TranscriptionEngine {
    private static let transcriptionURL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!

    let modelName: String

    init(modelName: String = "whisper-large-v3-turbo") {
        self.modelName = modelName
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let apiKey = KeychainService.groqAPIKey(), !apiKey.isEmpty else {
            throw TranscriptionError.modelUnavailable("Add a Groq API key in Settings to use this model.")
        }

        let boundary = "Clide-\(UUID().uuidString)"
        var request = URLRequest(url: Self.transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            model: modelName,
            wavData: WAVEncoder.encode(samples: samples)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranscriptionError.modelUnavailable("Couldn't reach Groq: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw TranscriptionError.modelUnavailable("Groq couldn't transcribe that: \(message)")
        }

        let decoded = try JSONDecoder().decode(GroqTranscriptionResponse.self, from: data)
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

extension GroqTranscriptionEngine {
    /// Lightweight key validation for Settings' "Test Connection" — hits the
    /// (free) models-list endpoint rather than spending transcription quota.
    static func testConnection(apiKey: String) async -> Bool {
        guard !apiKey.isEmpty else { return false }
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse
        else { return false }
        return (200..<300).contains(httpResponse.statusCode)
    }
}
