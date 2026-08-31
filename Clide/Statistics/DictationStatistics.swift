import Foundation

/// One completed dictation, reduced to counters. Deliberately holds no
/// transcript text — statistics stay useful with history disabled, and
/// clide.md §26 keeps these strictly separate concerns.
struct DictationRecord: Codable, Sendable {
    let date: Date
    let wordCount: Int
    let speakingDuration: TimeInterval
    let modelID: String
    let wasLocal: Bool
}

/// On-device counters for the dashboard (clide.md §26). Local only, and the
/// user can switch them off or clear them.
@MainActor
final class DictationStatistics: ObservableObject {
    static let shared = DictationStatistics()

    private enum Key {
        static let records = "Clide.statisticsRecords"
        static let enabled = "Clide.statisticsEnabled"
    }

    @Published private(set) var records: [DictationRecord] = []

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Key.enabled) }
    }

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true

        if let data = defaults.data(forKey: Key.records),
           let decoded = try? JSONDecoder().decode([DictationRecord].self, from: data) {
            records = decoded
        }
    }

    func record(transcript: String, speakingDuration: TimeInterval, model: TranscriptionModelInfo) {
        guard isEnabled else { return }

        records.append(
            DictationRecord(
                date: Date(),
                wordCount: TimeSavedCalculator.wordCount(of: transcript),
                speakingDuration: speakingDuration,
                modelID: model.id,
                wasLocal: model.isLocal
            )
        )
        persist()
    }

    func clear() {
        records = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: Key.records)
    }

    // MARK: - Aggregates

    struct Summary {
        let dictationCount: Int
        let wordCount: Int
        let speakingDuration: TimeInterval
        let localPercentage: Int
        /// `nil` when speaking wasn't collectively faster than typing.
        let timeSaved: TimeInterval?
    }

    func summary(since startDate: Date? = nil) -> Summary {
        let scoped = startDate.map { start in records.filter { $0.date >= start } } ?? records

        let words = scoped.reduce(0) { $0 + $1.wordCount }
        let duration = scoped.reduce(0) { $0 + $1.speakingDuration }
        let localCount = scoped.filter(\.wasLocal).count

        return Summary(
            dictationCount: scoped.count,
            wordCount: words,
            speakingDuration: duration,
            localPercentage: scoped.isEmpty ? 100 : Int((Double(localCount) / Double(scoped.count) * 100).rounded()),
            timeSaved: TimeSavedCalculator.timeSaved(wordCount: words, speakingDuration: duration)
        )
    }

    var todaySummary: Summary {
        summary(since: Calendar.current.startOfDay(for: Date()))
    }

    var lifetimeSummary: Summary {
        summary()
    }
}
