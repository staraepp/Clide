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
    case modelDownloadFailed(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let message): return message
        case .modelDownloadFailed(let name): return "Couldn't finish downloading \(name). Check your connection and try again."
        case .emptyResult: return "Didn't catch that — try again."
        }
    }
}

/// A recovery the user can actually perform, surfaced next to an error rather
/// than leaving them to work it out (clide.md §38, §39).
enum RecoveryAction: Equatable {
    case openAccessibilitySettings
    case openMicrophoneSettings
    case openClideSettings
    case retry

    var title: String {
        switch self {
        case .openAccessibilitySettings: return "Open Accessibility Settings"
        case .openMicrophoneSettings: return "Open Microphone Settings"
        case .openClideSettings: return "Open Clide Settings"
        case .retry: return "Try Again"
        }
    }
}
