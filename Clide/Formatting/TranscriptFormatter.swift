import Foundation

/// Turns a raw transcript into tidier prose without changing what was said.
///
/// Separate from transcription on purpose (clide.md §22): a formatter failing,
/// being unavailable, or being slow must never stop dictation from working.
protocol TranscriptFormatter: Sendable {
    /// Whether this formatter can run right now on this Mac.
    var isAvailable: Bool { get }
    /// Why it can't, in plain language, when `isAvailable` is false.
    var unavailableReason: String? { get }
    var displayName: String { get }

    func format(_ transcript: String) async throws -> String
}

enum FormattingError: Error, LocalizedError {
    case unavailable(String)
    case failed(String)
    case producedNothing

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .failed(let detail): return "Formatting didn't work: \(detail)"
        case .producedNothing: return "The formatter returned nothing."
        }
    }
}
