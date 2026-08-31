import Foundation
import OSLog

/// In-memory, sanitized log for the developer console (clide.md §3).
///
/// Everything written here is assumed to be readable by the user and, if they
/// ever opt in, shareable. So nothing that touches transcript text, audio,
/// API keys, clipboard contents, or field contents may be logged — callers
/// record *what happened*, never *what was said*.
@MainActor
final class DiagnosticsLog: ObservableObject {
    static let shared = DiagnosticsLog()

    enum Level: String, CaseIterable, Comparable, Sendable {
        case debug, info, warning, error

        private var order: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            }
        }

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.order < rhs.order }
    }

    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let level: Level
        let category: String
        let message: String
    }

    /// Bounded so a long-running session can't grow without limit.
    private static let maximumEntries = 500

    @Published private(set) var entries: [Entry] = []

    private let logger = Logger(subsystem: "com.staraepp.Clide", category: "diagnostics")

    private init() {}

    func log(_ level: Level, category: String, _ message: String) {
        let entry = Entry(date: Date(), level: level, category: category, message: message)
        entries.append(entry)
        if entries.count > Self.maximumEntries {
            entries.removeFirst(entries.count - Self.maximumEntries)
        }

        switch level {
        case .debug: logger.debug("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .info: logger.info("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .warning: logger.warning("[\(category, privacy: .public)] \(message, privacy: .public)")
        case .error: logger.error("[\(category, privacy: .public)] \(message, privacy: .public)")
        }
    }

    func clear() {
        entries = []
    }

    func formattedTranscript(minimumLevel: Level = .debug) -> String {
        let formatter = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        return entries
            .filter { $0.level >= minimumLevel }
            .map { "\($0.date.formatted(formatter))  \($0.level.rawValue.uppercased())  [\($0.category)]  \($0.message)" }
            .joined(separator: "\n")
    }
}

/// Convenience so call sites read as one short line.
@MainActor
func clideLog(_ level: DiagnosticsLog.Level, _ category: String, _ message: String) {
    DiagnosticsLog.shared.log(level, category: category, message)
}
