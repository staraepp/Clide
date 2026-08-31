import Foundation

/// How eagerly an optional transcript transformation should be applied
/// (clide.md §22 and §24).
enum FormattingMode: String, CaseIterable, Identifiable, Sendable {
    case alwaysOff
    case askEachTime
    case alwaysOn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alwaysOff: return "Always Off"
        case .askEachTime: return "Ask Each Time"
        case .alwaysOn: return "Always On"
        }
    }
}

/// User-facing formatting settings, persisted in UserDefaults.
@MainActor
final class FormattingPreferences: ObservableObject {
    static let shared = FormattingPreferences()

    private enum Key {
        static let fillerRemoval = "Clide.fillerRemovalMode"
        static let aiFormatting = "Clide.aiFormattingMode"
    }

    @Published var fillerRemovalMode: FormattingMode {
        didSet { UserDefaults.standard.set(fillerRemovalMode.rawValue, forKey: Key.fillerRemoval) }
    }

    @Published var aiFormattingMode: FormattingMode {
        didSet { UserDefaults.standard.set(aiFormattingMode.rawValue, forKey: Key.aiFormatting) }
    }

    private init() {
        let defaults = UserDefaults.standard
        fillerRemovalMode = defaults.string(forKey: Key.fillerRemoval)
            .flatMap(FormattingMode.init(rawValue:)) ?? .askEachTime
        aiFormattingMode = defaults.string(forKey: Key.aiFormatting)
            .flatMap(FormattingMode.init(rawValue:)) ?? .askEachTime
    }
}
