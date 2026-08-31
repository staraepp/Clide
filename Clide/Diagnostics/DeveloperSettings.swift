import Foundation

/// Developer-data consent and the Debug Mode it unlocks (clide.md §3).
/// Off by default, opt-in only, reversible, and never bundled into any
/// other setting.
@MainActor
final class DeveloperSettings: ObservableObject {
    static let shared = DeveloperSettings()

    private static let consentKey = "Clide.developerDataConsent"

    @Published var hasConsentedToDeveloperData: Bool {
        didSet {
            UserDefaults.standard.set(hasConsentedToDeveloperData, forKey: Self.consentKey)
            clideLog(.info, "privacy", "Developer data sharing \(hasConsentedToDeveloperData ? "enabled" : "disabled")")
        }
    }

    /// Debug Mode rides along with the consent, as the spec describes — but
    /// diagnostics can always be exported manually without consenting.
    var isDebugModeEnabled: Bool { hasConsentedToDeveloperData }

    private init() {
        hasConsentedToDeveloperData = UserDefaults.standard.bool(forKey: Self.consentKey)
    }
}
