import Foundation

/// A bring-your-own-key transcription service (clide.md §10).
///
/// Clide never proxies any of these — audio goes from this Mac straight to the
/// provider using the user's own key, which lives in the Keychain.
enum CloudProvider: String, CaseIterable, Identifiable, Sendable {
    case groq
    case deepgram
    case assemblyAI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .deepgram: return "Deepgram"
        case .assemblyAI: return "AssemblyAI"
        }
    }

    /// Where the user gets a key, for a "Get a key" link in Settings.
    var apiKeyURL: URL? {
        switch self {
        case .groq: return URL(string: "https://console.groq.com/keys")
        case .deepgram: return URL(string: "https://console.deepgram.com/")
        case .assemblyAI: return URL(string: "https://www.assemblyai.com/dashboard/")
        }
    }

    private var keychainAccount: String { "\(rawValue)-api-key" }

    var apiKey: String? {
        KeychainService.value(forAccount: keychainAccount)
    }

    func setAPIKey(_ key: String?) {
        guard let key, !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            KeychainService.removeValue(forAccount: keychainAccount)
            return
        }
        KeychainService.setValue(key.trimmingCharacters(in: .whitespaces), forAccount: keychainAccount)
    }

    var hasAPIKey: Bool {
        apiKey?.isEmpty == false
    }

    /// The header each provider expects. They genuinely differ: Groq uses
    /// OpenAI-style bearer auth, Deepgram uses its own `Token` scheme, and
    /// AssemblyAI takes the bare key.
    func authorizationHeader(for key: String) -> (field: String, value: String) {
        switch self {
        case .groq: return ("Authorization", "Bearer \(key)")
        case .deepgram: return ("Authorization", "Token \(key)")
        case .assemblyAI: return ("Authorization", key)
        }
    }

    /// A cheap authenticated request used to validate a key without spending
    /// transcription quota.
    private var connectionTestURL: URL? {
        switch self {
        case .groq: return URL(string: "https://api.groq.com/openai/v1/models")
        case .deepgram: return URL(string: "https://api.deepgram.com/v1/projects")
        // AssemblyAI has no cheap GET that validates a key, so this one asks
        // for a transcript that cannot exist: a bad key gives 401, a good key
        // gives 404. See CloudProviderTester.
        case .assemblyAI: return URL(string: "https://api.assemblyai.com/v2/transcript/clide-connection-test")
        }
    }

    /// Status codes that mean "the key worked", per provider.
    private var successStatusCodes: Set<Int> {
        switch self {
        case .groq, .deepgram: return Set(200..<300)
        case .assemblyAI: return Set(200..<300).union([404])
        }
    }

    func testConnection() async -> Result<Void, CloudProviderError> {
        guard let key = apiKey, !key.isEmpty else { return .failure(.missingKey(self)) }
        guard let url = connectionTestURL else { return .failure(.unexpected("No test endpoint")) }

        var request = URLRequest(url: url)
        let header = authorizationHeader(for: key)
        request.setValue(header.value, forHTTPHeaderField: header.field)
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.unexpected("No response from \(displayName)"))
            }
            if successStatusCodes.contains(http.statusCode) { return .success(()) }
            if http.statusCode == 401 || http.statusCode == 403 { return .failure(.invalidKey(self)) }
            return .failure(.providerError(self, "HTTP \(http.statusCode)"))
        } catch {
            return .failure(.unreachable(self, error.localizedDescription))
        }
    }
}

enum CloudProviderError: Error, LocalizedError, Equatable {
    case missingKey(CloudProvider)
    case invalidKey(CloudProvider)
    case unreachable(CloudProvider, String)
    case providerError(CloudProvider, String)
    case timedOut(CloudProvider)
    case unexpected(String)

    /// Plain-language messages — a normal user should never need logs to
    /// understand what went wrong or what to do next (clide.md §39).
    var errorDescription: String? {
        switch self {
        case .missingKey(let provider):
            return "Add your \(provider.displayName) API key in Settings to use this model."
        case .invalidKey(let provider):
            return "\(provider.displayName) rejected that API key. Check it in Settings."
        case .unreachable(let provider, let detail):
            return "Couldn't reach \(provider.displayName). \(detail)"
        case .providerError(let provider, let detail):
            return "\(provider.displayName) couldn't transcribe that (\(detail))."
        case .timedOut(let provider):
            return "\(provider.displayName) took too long to respond."
        case .unexpected(let detail):
            return detail
        }
    }
}
