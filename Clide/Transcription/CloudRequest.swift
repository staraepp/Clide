import Foundation

/// Shared HTTP handling for cloud providers, so each engine only describes
/// what makes it different and error mapping stays consistent.
enum CloudRequest {
    static func perform(_ request: URLRequest, provider: CloudProvider) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CloudProviderError.timedOut(provider)
        } catch {
            throw CloudProviderError.unreachable(provider, error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CloudProviderError.unexpected("No response from \(provider.displayName).")
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw CloudProviderError.invalidKey(provider)
        case 429:
            throw CloudProviderError.providerError(provider, "rate limited — try again shortly")
        default:
            throw CloudProviderError.providerError(provider, "HTTP \(http.statusCode)")
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data, provider: CloudProvider) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw CloudProviderError.providerError(provider, "unexpected response format")
        }
    }
}
