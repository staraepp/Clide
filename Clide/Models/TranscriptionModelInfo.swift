import Foundation

/// Which transcription runtime backs a model. Kept free of any single
/// runtime's own types so this file doesn't need to import WhisperKit/FluidAudio.
enum TranscriptionRuntime: String, Sendable, Equatable {
    case whisperKit
    case fluidAudio
    case groq
}

/// Metadata for one selectable transcription model/provider, per clide.md §12.
/// `engineIdentifier` is runtime-specific (a WhisperKit model name, a FluidAudio
/// version tag, or a Groq model string) — only `ModelManager` interprets it.
struct TranscriptionModelInfo: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let runtime: TranscriptionRuntime
    let engineIdentifier: String
    let isLocal: Bool
    let requiresAPIKey: Bool
}

enum ModelCatalog {
    static let all: [TranscriptionModelInfo] = [
        TranscriptionModelInfo(
            id: "whisper.tiny.en",
            displayName: "Whisper Tiny (English)",
            runtime: .whisperKit,
            engineIdentifier: "tiny.en",
            isLocal: true,
            requiresAPIKey: false
        ),
        TranscriptionModelInfo(
            id: "fluid.parakeet-tdt-0.6b-v2",
            displayName: "Parakeet TDT 0.6B (English)",
            runtime: .fluidAudio,
            engineIdentifier: "v2",
            isLocal: true,
            requiresAPIKey: false
        ),
        TranscriptionModelInfo(
            id: "groq.whisper-large-v3-turbo",
            displayName: "Groq — Whisper Large v3 Turbo",
            runtime: .groq,
            engineIdentifier: "whisper-large-v3-turbo",
            isLocal: false,
            requiresAPIKey: true
        ),
    ]

    static let defaultModelID = all[0].id
}
