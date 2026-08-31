import Foundation

/// How the shortcut behaves (clide.md §7).
enum DictationActivation: String, CaseIterable, Identifiable, Sendable {
    /// Press once to start, again to stop.
    case toggle
    /// Record only while the shortcut is held down.
    case pushToTalk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggle: return "Press to start and stop"
        case .pushToTalk: return "Hold to talk"
        }
    }
}

@MainActor
final class DictationPreferences: ObservableObject {
    static let shared = DictationPreferences()

    private static let activationKey = "Clide.dictationActivation"

    @Published var activation: DictationActivation {
        didSet { UserDefaults.standard.set(activation.rawValue, forKey: Self.activationKey) }
    }

    private init() {
        activation = UserDefaults.standard.string(forKey: Self.activationKey)
            .flatMap(DictationActivation.init(rawValue:)) ?? .toggle
    }
}
