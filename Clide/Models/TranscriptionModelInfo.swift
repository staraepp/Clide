import Foundation

/// Which runtime executes a model. Cloud providers carry their identity in the
/// associated value so nothing has to maintain a parallel provider field.
enum TranscriptionRuntime: Sendable, Equatable, Hashable {
    case whisperKit
    case fluidAudio
    case appleSpeech
    case cloud(CloudProvider)

    var isLocal: Bool {
        switch self {
        case .whisperKit, .fluidAudio, .appleSpeech: return true
        case .cloud: return false
        }
    }

    var displayName: String {
        switch self {
        case .whisperKit: return "WhisperKit"
        case .fluidAudio: return "FluidAudio"
        case .appleSpeech: return "Apple Speech"
        case .cloud(let provider): return provider.displayName
        }
    }

    var cloudProvider: CloudProvider? {
        if case .cloud(let provider) = self { return provider }
        return nil
    }

    /// Core ML runtimes can use the Neural Engine; Apple's own recognizer is
    /// managed by macOS and doesn't expose that detail.
    var usesCoreML: Bool {
        switch self {
        case .whisperKit, .fluidAudio: return true
        case .appleSpeech, .cloud: return false
        }
    }
}

/// What a model can do. Kept as data so the UI can adapt to capabilities
/// rather than hardcoding per-model special cases (clide.md §11).
struct ModelCapabilities: Sendable, Equatable {
    var streaming = false
    var batch = true
    var wordTimestamps = false
    var segmentTimestamps = false
    var diarization = false
    var translation = false
    var languageDetection = false
}

/// How a local model gets onto the machine, so the manager can report install
/// state without each runtime's own conventions leaking into the UI.
enum ModelSource: Sendable, Equatable {
    /// Downloaded into Clide's models directory by its runtime.
    ///
    /// `directoryName` is the folder each runtime actually creates, stated
    /// explicitly rather than derived from the engine identifier: deriving it
    /// makes "small" match "small.en", which both misreports install state and
    /// would delete the wrong model's files.
    case download(repository: String, directoryName: String)
    /// Provided and updated by macOS; nothing for Clide to fetch.
    case systemManaged
    /// Runs on the provider's servers.
    case remote
}

/// Everything Clide knows about one selectable transcription option
/// (clide.md §12). Deliberately plain data — no view ever hardcodes this.
///
/// `accuracyScore` and `speedScore` are approximate 1–5 characterisations
/// drawn from each model's published benchmarks, **not** measurements taken on
/// this Mac, and the UI must present them as estimates. `HardwareFit`, by
/// contrast, is computed from this machine's real capabilities.
struct TranscriptionModelInfo: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let runtime: TranscriptionRuntime
    /// Runtime-specific handle: a WhisperKit model name, a FluidAudio version
    /// tag, a provider model string. Only `ModelManager` interprets it.
    let engineIdentifier: String
    let version: String
    let downloadSizeMB: Int
    let recommendedMemoryGB: Double
    let accuracyScore: Int
    let speedScore: Int
    let languageSummary: String
    let isMultilingual: Bool
    let capabilities: ModelCapabilities
    let source: ModelSource
    let summary: String
    var isExperimental = false

    var isLocal: Bool { runtime.isLocal }

    /// The folder this model occupies on disk, when it's a downloadable one.
    var installDirectoryName: String? {
        if case .download(_, let directoryName) = source { return directoryName }
        return nil
    }

    /// Whether a directory on disk belongs to this model.
    ///
    /// Requires an exact name or a `-`/`_` separated extension of it, so
    /// "openai_whisper-small" never claims "openai_whisper-small.en".
    func owns(directoryNamed name: String) -> Bool {
        guard let expected = installDirectoryName?.lowercased() else { return false }
        let candidate = name.lowercased()
        return candidate == expected
            || candidate.hasPrefix(expected + "-")
            || candidate.hasPrefix(expected + "_")
    }

    var requiresAPIKey: Bool { runtime.cloudProvider != nil }
    var usesNeuralEngine: Bool { runtime.usesCoreML }

    /// Minimum macOS version, when a model needs more than the app's own.
    var minimumMacOSVersion: Int?
}

enum ModelCatalog {
    static let all: [TranscriptionModelInfo] = whisperModels + parakeetModels + appleModels + cloudModels

    static let defaultModelID = "whisper.base.en"

    static func model(withID id: String) -> TranscriptionModelInfo? {
        all.first { $0.id == id }
    }

    // MARK: - WhisperKit

    private static let whisperCapabilities = ModelCapabilities(
        streaming: false,
        batch: true,
        wordTimestamps: true,
        segmentTimestamps: true,
        languageDetection: true
    )

    private static let whisperRepository = "argmaxinc/whisperkit-coreml"

    private static let whisperModels: [TranscriptionModelInfo] = [
        TranscriptionModelInfo(
            id: "whisper.tiny.en",
            displayName: "Whisper Tiny (English)",
            runtime: .whisperKit,
            engineIdentifier: "tiny.en",
            version: "v20231117",
            downloadSizeMB: 78,
            recommendedMemoryGB: 4,
            accuracyScore: 2,
            speedScore: 5,
            languageSummary: "English",
            isMultilingual: false,
            capabilities: whisperCapabilities,
            source: .download(repository: whisperRepository, directoryName: "openai_whisper-tiny.en"),
            summary: "The fastest option. Fine for short notes, but it misspells names and technical terms."
        ),
        TranscriptionModelInfo(
            id: "whisper.base.en",
            displayName: "Whisper Base (English)",
            runtime: .whisperKit,
            engineIdentifier: "base.en",
            version: "v20231117",
            downloadSizeMB: 145,
            recommendedMemoryGB: 4,
            accuracyScore: 3,
            speedScore: 5,
            languageSummary: "English",
            isMultilingual: false,
            capabilities: whisperCapabilities,
            source: .download(repository: whisperRepository, directoryName: "openai_whisper-base.en"),
            summary: "A good starting point: noticeably better than Tiny and still very fast."
        ),
        TranscriptionModelInfo(
            id: "whisper.small.en",
            displayName: "Whisper Small (English)",
            runtime: .whisperKit,
            engineIdentifier: "small.en",
            version: "v20231117",
            downloadSizeMB: 483,
            recommendedMemoryGB: 8,
            accuracyScore: 4,
            speedScore: 4,
            languageSummary: "English",
            isMultilingual: false,
            capabilities: whisperCapabilities,
            source: .download(repository: whisperRepository, directoryName: "openai_whisper-small.en"),
            summary: "Handles punctuation and unusual words much better. A reasonable everyday choice."
        ),
        TranscriptionModelInfo(
            id: "whisper.small",
            displayName: "Whisper Small",
            runtime: .whisperKit,
            engineIdentifier: "small",
            version: "v20231117",
            downloadSizeMB: 483,
            recommendedMemoryGB: 8,
            accuracyScore: 4,
            speedScore: 4,
            languageSummary: "99 languages",
            isMultilingual: true,
            capabilities: whisperCapabilities,
            source: .download(repository: whisperRepository, directoryName: "openai_whisper-small"),
            summary: "The multilingual Small. Pick this over Small (English) only if you dictate in more than one language."
        ),
        TranscriptionModelInfo(
            id: "whisper.large-v3-turbo",
            displayName: "Whisper Large v3 Turbo",
            runtime: .whisperKit,
            engineIdentifier: "large-v3_turbo",
            version: "v3-turbo",
            downloadSizeMB: 1600,
            recommendedMemoryGB: 16,
            accuracyScore: 5,
            speedScore: 3,
            languageSummary: "99 languages",
            isMultilingual: true,
            capabilities: whisperCapabilities,
            source: .download(repository: whisperRepository, directoryName: "openai_whisper-large-v3_turbo"),
            summary: "The most accurate local Whisper. Large download, and it wants a roomy Mac."
        ),
    ]

    // MARK: - FluidAudio / Parakeet

    private static let parakeetCapabilities = ModelCapabilities(
        streaming: true,
        batch: true,
        wordTimestamps: true,
        segmentTimestamps: true
    )

    private static let parakeetModels: [TranscriptionModelInfo] = [
        TranscriptionModelInfo(
            id: "fluid.parakeet-tdt-0.6b-v2",
            displayName: "Parakeet TDT 0.6B",
            runtime: .fluidAudio,
            engineIdentifier: "v2",
            version: "0.6b-v2",
            downloadSizeMB: 600,
            recommendedMemoryGB: 8,
            accuracyScore: 5,
            speedScore: 5,
            languageSummary: "English",
            isMultilingual: false,
            capabilities: parakeetCapabilities,
            source: .download(repository: "FluidInference/parakeet-tdt-0.6b-v2-coreml", directoryName: "parakeet-tdt-0.6b-v2"),
            summary: "Accurate and very fast on Apple Silicon. The best local option for English if you have the space."
        ),
        TranscriptionModelInfo(
            id: "fluid.parakeet-tdt-0.6b-v3",
            displayName: "Parakeet TDT 0.6B (Multilingual)",
            runtime: .fluidAudio,
            engineIdentifier: "v3",
            version: "0.6b-v3",
            downloadSizeMB: 600,
            recommendedMemoryGB: 8,
            accuracyScore: 4,
            speedScore: 5,
            languageSummary: "25 European languages",
            isMultilingual: true,
            capabilities: parakeetCapabilities,
            source: .download(repository: "FluidInference/parakeet-tdt-0.6b-v3-coreml", directoryName: "parakeet-tdt-0.6b-v3"),
            summary: "Same speed as v2 across 25 languages. English is very slightly behind v2 on rare words."
        ),
    ]

    // MARK: - Apple Speech

    private static let appleModels: [TranscriptionModelInfo] = [
        TranscriptionModelInfo(
            id: "apple.speech.system",
            displayName: "Apple Speech",
            runtime: .appleSpeech,
            engineIdentifier: "system",
            version: "system",
            downloadSizeMB: 0,
            recommendedMemoryGB: 0,
            accuracyScore: 3,
            speedScore: 4,
            languageSummary: "Follows your Mac's languages",
            isMultilingual: true,
            capabilities: ModelCapabilities(
                streaming: true,
                batch: true,
                segmentTimestamps: true
            ),
            source: .systemManaged,
            summary: "Built into macOS. Nothing to download, but accuracy and offline support depend on what your Mac has installed."
        ),
    ]

    // MARK: - Cloud

    private static let cloudModels: [TranscriptionModelInfo] = [
        TranscriptionModelInfo(
            id: "groq.whisper-large-v3-turbo",
            displayName: "Whisper Large v3 Turbo",
            runtime: .cloud(.groq),
            engineIdentifier: "whisper-large-v3-turbo",
            version: "v3-turbo",
            downloadSizeMB: 0,
            recommendedMemoryGB: 0,
            accuracyScore: 5,
            speedScore: 5,
            languageSummary: "99 languages",
            isMultilingual: true,
            capabilities: ModelCapabilities(
                batch: true,
                wordTimestamps: true,
                segmentTimestamps: true,
                translation: true,
                languageDetection: true
            ),
            source: .remote,
            summary: "Large-model accuracy at high speed, on Groq's servers. Your audio leaves this Mac."
        ),
        TranscriptionModelInfo(
            id: "deepgram.nova-3",
            displayName: "Nova-3",
            runtime: .cloud(.deepgram),
            engineIdentifier: "nova-3",
            version: "nova-3",
            downloadSizeMB: 0,
            recommendedMemoryGB: 0,
            accuracyScore: 5,
            speedScore: 5,
            languageSummary: "Multilingual",
            isMultilingual: true,
            capabilities: ModelCapabilities(
                streaming: true,
                batch: true,
                wordTimestamps: true,
                segmentTimestamps: true,
                diarization: true,
                languageDetection: true
            ),
            source: .remote,
            summary: "Deepgram's newest model, with punctuation and formatting applied. Your audio leaves this Mac."
        ),
        TranscriptionModelInfo(
            id: "assemblyai.best",
            displayName: "Universal",
            runtime: .cloud(.assemblyAI),
            engineIdentifier: "best",
            version: "best",
            downloadSizeMB: 0,
            recommendedMemoryGB: 0,
            accuracyScore: 5,
            speedScore: 2,
            languageSummary: "Multilingual",
            isMultilingual: true,
            capabilities: ModelCapabilities(
                batch: true,
                wordTimestamps: true,
                segmentTimestamps: true,
                diarization: true,
                languageDetection: true
            ),
            source: .remote,
            summary: "Very accurate, but it uploads and queues each recording, so expect a wait. Your audio leaves this Mac."
        ),
    ]
}
