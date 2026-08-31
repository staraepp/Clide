import Foundation
import Security

/// Thin wrapper over the Keychain Services API for storing provider API keys.
/// Generic on purpose — one file, one small surface, no per-provider subclassing.
enum KeychainService {
    private static let service = "com.staraepp.Clide"

    static func setValue(_ value: String, forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func value(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func removeValue(forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension KeychainService {
    private static let groqAccount = "groq-api-key"

    static func groqAPIKey() -> String? { value(forAccount: groqAccount) }

    static func setGroqAPIKey(_ key: String?) {
        guard let key, !key.isEmpty else {
            removeValue(forAccount: groqAccount)
            return
        }
        setValue(key, forAccount: groqAccount)
    }
}
