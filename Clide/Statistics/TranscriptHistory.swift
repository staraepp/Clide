import Foundation

/// One saved transcript (clide.md §27).
struct TranscriptEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let text: String
    let modelID: String
    let speakingDuration: TimeInterval
    /// Name of the app that was frontmost, when it could be detected safely.
    let sourceApplication: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String,
        modelID: String,
        speakingDuration: TimeInterval,
        sourceApplication: String?
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.modelID = modelID
        self.speakingDuration = speakingDuration
        self.sourceApplication = sourceApplication
    }
}

/// Local transcript history, off by default.
///
/// This is the only place Clide retains what was actually said, which is why
/// it's opt-in and separate from `DictationStatistics` — statistics stay
/// useful with history off, because they hold counters only. Turning history
/// off discards what was already stored rather than merely hiding it.
@MainActor
final class TranscriptHistory: ObservableObject {
    static let shared = TranscriptHistory()

    private enum Key {
        static let entries = "Clide.transcriptHistory"
        static let enabled = "Clide.transcriptHistoryEnabled"
    }

    /// Keeps the on-disk store bounded; history is a convenience, not an archive.
    private static let maximumEntries = 200

    @Published private(set) var entries: [TranscriptEntry] = []

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: Key.enabled)
            if !isEnabled { clear() }
            clideLog(.info, "privacy", "Transcript history \(isEnabled ? "enabled" : "disabled and cleared")")
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        // Off unless the user has explicitly turned it on.
        isEnabled = defaults.bool(forKey: Key.enabled)

        if isEnabled,
           let data = defaults.data(forKey: Key.entries),
           let decoded = try? JSONDecoder().decode([TranscriptEntry].self, from: data) {
            entries = decoded
        }
    }

    func record(text: String, model: TranscriptionModelInfo, speakingDuration: TimeInterval, sourceApplication: String?) {
        guard isEnabled, !text.isEmpty else { return }

        entries.insert(
            TranscriptEntry(
                text: text,
                modelID: model.id,
                speakingDuration: speakingDuration,
                sourceApplication: sourceApplication
            ),
            at: 0
        )
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
        persist()
    }

    func delete(_ entry: TranscriptEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries = []
        UserDefaults.standard.removeObject(forKey: Key.entries)
    }

    private func persist() {
        guard isEnabled, let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Key.entries)
    }
}
