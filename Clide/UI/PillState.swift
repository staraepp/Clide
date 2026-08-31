import Foundation

/// Visual/semantic state of the floating Clide pill during one dictation cycle.
enum PillState: Equatable {
    case idle
    case listening
    case transcribing
    /// Transcript is ready but the user has an optional cleanup step to
    /// decide on (clide.md §23). The pill offers the choice; the raw text
    /// stays available either way.
    case awaitingChoice
    case inserted
    case copiedToClipboard
    case secureFieldBlocked
    case error(String)

    var message: String {
        switch self {
        case .idle: return ""
        case .listening: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .awaitingChoice: return "Ready"
        case .inserted: return "Inserted"
        case .copiedToClipboard: return "Copied to clipboard"
        case .secureFieldBlocked: return "This looks like a secure field"
        case .error(let message): return message
        }
    }

    var symbolName: String {
        switch self {
        case .idle: return "mic"
        case .listening: return "waveform"
        case .transcribing: return "ellipsis"
        case .awaitingChoice: return "text.badge.checkmark"
        case .inserted: return "checkmark"
        case .copiedToClipboard: return "doc.on.clipboard"
        case .secureFieldBlocked: return "lock"
        case .error: return "exclamationmark.triangle"
        }
    }

    /// Whether the pill should remain visible on screen for this state.
    var isVisible: Bool {
        self != .idle
    }

    /// Only states offering actions should accept clicks — otherwise the pill
    /// must stay click-through so it never gets in the user's way.
    var isInteractive: Bool {
        self == .awaitingChoice
    }
}

/// Actions the pill offers while waiting on a cleanup decision.
struct PillChoiceActions {
    let removeFillers: () -> Void
    let insertAsIs: () -> Void
}
