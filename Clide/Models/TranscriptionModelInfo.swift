import Foundation

/// Which transcription runtime backs a model. Kept free of any single
/// runtime's own types so this file doesn't need to import WhisperKit/FluidAudio.
enum TranscriptionRuntime: String, Sendable, Equatable {
    case whisperKit
    case fluidAudio
    case groq

    var displayName: String {
        switch self {
        case .whisperKit: return "WhisperKit"
        case .fluidAudio: return "FluidAudio"
        case .groq: return "Groq"
        }
    }
}

/// Metadata for one selectable transcription model/provider, per clide.md §12.
/// `engineIdentifier` is runtime-specific (a WhisperKit model name, a FluidAudio
/// version tag, or a Groq model string) — only `ModelManager` interprets it.
///
/// `accuracyScore` and `speedScore` are approximate 1–5 characterisations drawn
/// from each model's published benchmarks, not measurements taken on this Mac.
/// The UI must present them as estimates.
struct TranscriptionModelInfo: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let runtime: TranscriptionRuntime
    let engineIdentifier: String
    let isLocal: Bool
    let requiresAPIKey: Bool
    let downloadSizeMB: Int
    let recommendedMemoryGB: Double
    let usesNeuralEngine: Bool
    let accuracyScore: Int
    let speedScore: Int
    let languageSummary: String
    let summary: String
}

enum ModelCatalog {
    static let all: [TranscriptionModelInfo] = [
        TranscriptionModelInfo(
            id: "whisper.tiny.en",
            displayName: "Whisper Tiny",
            runtime: .whisperKit,
            engineIdentifier: "tiny.en",
            isLocal: true,
            requiresAPIKey: false,
            downloadSizeMB: 78,
            recommendedMemoryGB: 4,
            usesNeuralEngine: true,
            accuracyScore: 2,
            speedScore: 5,
            languageSummary: "English",
            summary: "Smallest and fastest. Good for quick notes, less reliable on names and technical terms."
        ),
        TranscriptionModelInfo(
            id: "fluid.parakeet-tdt-0.6b-v2",
            displayName: "Parakeet TDT 0.6B",
            runtime: .fluidAudio,
            engineIdentifier: "v2",
            isLocal: true,
            requiresAPIKey: false,
            downloadSizeMB: 600,
            recommendedMemoryGB: 8,
            usesNeuralEngine: true,
            accuracyScore: 5,
            speedScore: 5,
            languageSummary: "English",
            summary: "Accurate and very fast on Apple Silicon. A good default if you have the disk space."
        ),
        TranscriptionModelInfo(
            id: "groq.whisper-large-v3-turbo",
            displayName: "Whisper Large v3 Turbo",
            runtime: .groq,
            engineIdentifier: "whisper-large-v3-turbo",
            isLocal: false,
            requiresAPIKey: true,
            downloadSizeMB: 0,
            recommendedMemoryGB: 0,
            usesNeuralEngine: false,
            accuracyScore: 5,
            speedScore: 4,
            languageSummary: "Multilingual",
            summary: "Runs on Groq's servers with your own API key. Your audio leaves this Mac."
        ),
    ]

    static let defaultModelID = all[0].id

    static func model(withID id: String) -> TranscriptionModelInfo? {
        all.first { $0.id == id }
    }
}
