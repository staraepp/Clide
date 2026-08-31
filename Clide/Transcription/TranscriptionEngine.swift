import Foundation

/// Abstraction over a speech-to-text backend so later milestones can add
/// Parakeet, Apple Speech, or cloud engines without reshaping the dictation pipeline.
protocol TranscriptionEngine: Sendable {
    func transcribe(samples: [Float]) async throws -> String

    /// Loads (and downloads, if needed) whatever the engine requires, so a
    /// caller can show progress instead of a long silent pause on first use.
    /// Calling it is optional — `transcribe` prepares lazily either way.
    func prepare() async throws
}

extension TranscriptionEngine {
    func prepare() async throws {}
}

enum TranscriptionError: Error, LocalizedError {
    case modelUnavailable(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let message): return message
        case .emptyResult: return "Didn't catch that — try again."
        }
    }
}
