import FluidAudio
import Foundation

/// Owns model selection and hands out (and caches) the TranscriptionEngine for
/// whichever model is active. One instance for the app's lifetime — there's
/// exactly one active dictation pipeline, so a singleton avoids threading this
/// through every initializer for no real benefit yet.
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    private static let activeModelKey = "Clide.activeModelID"

    @Published private(set) var activeModelID: String {
        didSet { UserDefaults.standard.set(activeModelID, forKey: Self.activeModelKey) }
    }

    let catalog: [TranscriptionModelInfo] = ModelCatalog.all
    private var engineCache: [String: TranscriptionEngine] = [:]

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.activeModelKey)
        activeModelID = ModelCatalog.all.first(where: { $0.id == stored })?.id ?? ModelCatalog.defaultModelID
    }

    var activeModel: TranscriptionModelInfo {
        catalog.first(where: { $0.id == activeModelID }) ?? catalog[0]
    }

    func setActiveModel(_ id: String) {
        guard catalog.contains(where: { $0.id == id }) else { return }
        activeModelID = id
    }

    /// The engine for the currently active model, constructing (and caching)
    /// it on first use so switching back to a model already used this launch
    /// doesn't reload it.
    func currentEngine() -> TranscriptionEngine {
        let model = activeModel
        if let cached = engineCache[model.id] { return cached }

        let engine = Self.makeEngine(for: model)
        engineCache[model.id] = engine
        return engine
    }

    private static func makeEngine(for model: TranscriptionModelInfo) -> TranscriptionEngine {
        switch model.runtime {
        case .whisperKit:
            return WhisperKitTranscriptionEngine(modelName: model.engineIdentifier)
        case .fluidAudio:
            let version: AsrModelVersion = model.engineIdentifier == "v3" ? .v3 : .v2
            return FluidAudioTranscriptionEngine(modelVersion: version)
        case .groq:
            return GroqTranscriptionEngine(modelName: model.engineIdentifier)
        }
    }
}
