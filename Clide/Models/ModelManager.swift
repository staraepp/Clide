import FluidAudio
import Foundation

/// Owns model selection, hands out (and caches) engines, and tracks which
/// local models are actually on disk. One instance for the app's lifetime.
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    private static let activeModelKey = "Clide.activeModelID"

    @Published private(set) var activeModelID: String {
        didSet { UserDefaults.standard.set(activeModelID, forKey: Self.activeModelKey) }
    }

    /// Local models found on disk. Recomputed rather than persisted, so it
    /// can't drift from reality when a user clears the models folder.
    @Published private(set) var installedModelIDs: Set<String> = []

    /// Models currently downloading, so the browser can show progress.
    @Published private(set) var preparingModelIDs: Set<String> = []

    let catalog: [TranscriptionModelInfo] = ModelCatalog.all
    private var engineCache: [String: TranscriptionEngine] = [:]

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.activeModelKey)
        activeModelID = ModelCatalog.all.first(where: { $0.id == stored })?.id ?? ModelCatalog.defaultModelID
        refreshInstalledModels()
    }

    var activeModel: TranscriptionModelInfo {
        catalog.first(where: { $0.id == activeModelID }) ?? catalog[0]
    }

    func setActiveModel(_ id: String) {
        guard catalog.contains(where: { $0.id == id }) else { return }
        activeModelID = id
        clideLog(.info, "models", "Active model set to \(id)")
    }

    /// The engine for the currently active model.
    func currentEngine() -> TranscriptionEngine {
        engine(for: activeModel)
    }

    func engine(for model: TranscriptionModelInfo) -> TranscriptionEngine {
        if let cached = engineCache[model.id] { return cached }
        let engine = Self.makeEngine(for: model)
        engineCache[model.id] = engine
        return engine
    }

    /// Downloads and loads a local model up front so the user isn't left
    /// staring at a silent pause on first use.
    func prepare(_ model: TranscriptionModelInfo) async throws {
        guard !preparingModelIDs.contains(model.id) else { return }
        preparingModelIDs.insert(model.id)
        defer {
            preparingModelIDs.remove(model.id)
            refreshInstalledModels()
        }

        clideLog(.info, "models", "Preparing \(model.id)")
        do {
            try await engine(for: model).prepare()
            clideLog(.info, "models", "\(model.id) ready")
        } catch {
            clideLog(.error, "models", "\(model.id) failed to prepare: \(error.localizedDescription)")
            throw error
        }
    }

    func isInstalled(_ model: TranscriptionModelInfo) -> Bool {
        switch model.source {
        case .systemManaged, .remote: return true
        case .download: return installedModelIDs.contains(model.id)
        }
    }

    /// Whether the model can actually be used right now — a cloud model needs
    /// its key, a downloadable one needs to be on disk.
    func isReadyToUse(_ model: TranscriptionModelInfo) -> Bool {
        if let provider = model.runtime.cloudProvider { return provider.hasAPIKey }
        return isInstalled(model)
    }

    /// Scans Clide's models directory for each downloadable model's files.
    /// Both runtimes lay their downloads out under directories named after the
    /// model, so a name match is a reliable enough signal without reaching
    /// into either library's private layout.
    func refreshInstalledModels() {
        let root = ClideStorage.modelsDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            installedModelIDs = []
            return
        }

        var directoryNames: Set<String> = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            directoryNames.insert(url.lastPathComponent.lowercased())
        }

        installedModelIDs = Set(
            catalog
                .filter { if case .download = $0.source { return true } else { return false } }
                .filter { model in
                    let needle = model.engineIdentifier.lowercased()
                    return directoryNames.contains { $0 == needle || $0.contains(needle) }
                }
                .map(\.id)
        )
    }

    func deleteDownload(for model: TranscriptionModelInfo) {
        guard case .download = model.source else { return }

        let root = ClideStorage.modelsDirectory
        let needle = model.engineIdentifier.lowercased()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents where url.lastPathComponent.lowercased().contains(needle) {
            try? FileManager.default.removeItem(at: url)
        }

        engineCache[model.id] = nil
        refreshInstalledModels()
        clideLog(.info, "models", "Deleted local files for \(model.id)")
    }

    private static func makeEngine(for model: TranscriptionModelInfo) -> TranscriptionEngine {
        switch model.runtime {
        case .whisperKit:
            return WhisperKitTranscriptionEngine(modelName: model.engineIdentifier)
        case .fluidAudio:
            let version: AsrModelVersion = model.engineIdentifier == "v3" ? .v3 : .v2
            return FluidAudioTranscriptionEngine(modelVersion: version)
        case .appleSpeech:
            return AppleSpeechTranscriptionEngine()
        case .cloud(.groq):
            return GroqTranscriptionEngine(modelName: model.engineIdentifier)
        case .cloud(.deepgram):
            return DeepgramTranscriptionEngine(modelName: model.engineIdentifier)
        case .cloud(.assemblyAI):
            return AssemblyAITranscriptionEngine(modelName: model.engineIdentifier)
        }
    }
}
