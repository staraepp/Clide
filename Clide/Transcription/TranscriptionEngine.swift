import Foundation

/// Abstraction over a speech-to-text backend so later milestones can add
/// Parakeet, Apple Speech, or cloud engines without reshaping the dictation pipeline.
protocol TranscriptionEngine: Sendable {
    func transcribe(samples: [Float]) async throws -> String
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
