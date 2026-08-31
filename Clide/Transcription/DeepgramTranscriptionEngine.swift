import Foundation

/// BYOK transcription via Deepgram's pre-recorded endpoint.
///
/// Deepgram takes the audio bytes as the raw request body (not multipart),
/// authenticates with its own `Token` scheme, and returns the text at
/// `results.channels[0].alternatives[0].transcript`.
struct DeepgramTranscriptionEngine: TranscriptionEngine {
    private static let endpoint = "https://api.deepgram.com/v1/listen"

    let modelName: String

    init(modelName: String = "nova-3") {
        self.modelName = modelName
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let key = CloudProvider.deepgram.apiKey, !key.isEmpty else {
            throw CloudProviderError.missingKey(.deepgram)
        }

        var components = URLComponents(string: Self.endpoint)
        components?.queryItems = [
            URLQueryItem(name: "model", value: modelName),
            URLQueryItem(name: "smart_format", value: "true"),
        ]
        guard let url = components?.url else {
            throw CloudProviderError.unexpected("Couldn't build the Deepgram request.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let header = CloudProvider.deepgram.authorizationHeader(for: key)
        request.setValue(header.value, forHTTPHeaderField: header.field)
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = WAVEncoder.encode(samples: samples)
        request.timeoutInterval = 60

        let data = try await CloudRequest.perform(request, provider: .deepgram)
        let decoded = try CloudRequest.decode(DeepgramResponse.self, from: data, provider: .deepgram)

        let text = decoded.results.channels.first?.alternatives.first?.transcript
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw TranscriptionError.emptyResult }
        return text
    }
}

private struct DeepgramResponse: Decodable {
    struct Results: Decodable {
        struct Channel: Decodable {
            struct Alternative: Decodable { let transcript: String }
            let alternatives: [Alternative]
        }
        let channels: [Channel]
    }
    let results: Results
}
