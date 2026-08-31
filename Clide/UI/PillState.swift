import Foundation

/// Visual/semantic state of the floating Clide pill during one dictation cycle.
enum PillState: Equatable {
    case idle
    case listening
    case transcribing
    case inserted
    case copiedToClipboard
    case secureFieldBlocked
    case error(String)

    var message: String {
        switch self {
        case .idle: return ""
        case .listening: return "Listening…"
        case .transcribing: return "Transcribing…"
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
}
