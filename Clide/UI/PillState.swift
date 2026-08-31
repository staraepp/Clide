import Foundation

/// Visual/semantic state of the floating Clide pill during one dictation cycle
/// (clide.md §16).
///
/// The three "text ended up on the clipboard" cases are deliberately separate:
/// they have different causes, different advice, and different diagnostics.
enum PillState: Equatable {
    case idle
    case modelLoading(String)
    case listening
    case transcribing
    case formatting
    /// Transcript is ready but an optional cleanup step needs a decision.
    case awaitingChoice
    case inserted
    /// Direct insertion failed for this particular field, so Clide pasted instead.
    case copiedAfterInsertionFailed
    /// Accessibility isn't granted, so Clide couldn't type or paste at all.
    case copiedNeedsAccessibility
    /// The focused field isn't editable text, so there was nowhere to insert.
    case copiedUnsupportedField
    case secureFieldBlocked
    case microphoneUnavailable(String)
    case error(String)

    var message: String {
        switch self {
        case .idle: return ""
        case .modelLoading(let name): return "Getting \(name) ready…"
        case .listening: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .formatting: return "Tidying up…"
        case .awaitingChoice: return "Ready"
        case .inserted: return "Inserted"
        case .copiedAfterInsertionFailed: return "Couldn't type there — copied instead"
        case .copiedNeedsAccessibility: return "Copied — allow Accessibility to type it for you"
        case .copiedUnsupportedField: return "No text field here — copied instead"
        case .secureFieldBlocked: return "This looks like a secure field"
        case .microphoneUnavailable(let detail): return detail
        case .error(let message): return message
        }
    }

    var symbolName: String {
        switch self {
        case .idle: return "mic"
        case .modelLoading: return "arrow.down.circle"
        case .listening: return "waveform"
        case .transcribing: return "ellipsis"
        case .formatting: return "sparkles"
        case .awaitingChoice: return "text.badge.checkmark"
        case .inserted: return "checkmark"
        case .copiedAfterInsertionFailed, .copiedNeedsAccessibility, .copiedUnsupportedField:
            return "doc.on.clipboard"
        case .secureFieldBlocked: return "lock"
        case .microphoneUnavailable: return "mic.slash"
        case .error: return "exclamationmark.triangle"
        }
    }

    /// Whether the pill should remain visible on screen for this state.
    var isVisible: Bool { self != .idle }

    /// Only states offering actions should accept clicks — otherwise the pill
    /// must stay click-through so it never gets in the user's way.
    var isInteractive: Bool { self == .awaitingChoice }

    /// States that are waiting on work, so the icon can pulse.
    var isBusy: Bool {
        switch self {
        case .modelLoading, .transcribing, .formatting: return true
        default: return false
        }
    }

    /// Something the user may need to act on, versus a routine confirmation.
    var isAdvisory: Bool {
        switch self {
        case .copiedAfterInsertionFailed, .copiedNeedsAccessibility, .copiedUnsupportedField,
             .secureFieldBlocked, .microphoneUnavailable, .error:
            return true
        default:
            return false
        }
    }
}

/// Actions the pill offers while waiting on a cleanup decision. The optional
/// ones are only present when that step actually applies to this transcript.
struct PillChoiceActions {
    let removeFillers: (() -> Void)?
    let format: (() -> Void)?
    let insertAsIs: () -> Void
}
