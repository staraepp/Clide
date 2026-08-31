import AppKit
import Foundation

/// Builds the sanitized diagnostics snapshot (clide.md §3).
///
/// The allow-list here is deliberate: every field is technical state about the
/// app and machine. Transcript text, audio, API keys, clipboard contents,
/// vocabulary and field contents are never included — and because this is the
/// only place a report is assembled, that's enforceable in one spot.
@MainActor
enum DiagnosticsReport {
    static func generate() -> String {
        let hardware = HardwareProfile.current
        let model = ModelManager.shared.activeModel
        let os = ProcessInfo.processInfo.operatingSystemVersion

        var lines: [String] = [
            "Clide Diagnostics",
            "",
            "App version:        \(appVersion)",
            "macOS:              \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "Hardware model:     \(hardware.modelIdentifier)",
            "Architecture:       \(hardware.isAppleSilicon ? "Apple Silicon" : "Intel")",
            "Memory:             \(hardware.formattedMemory)",
            "CPU cores:          \(hardware.coreCount)",
            "Neural Engine:      \(hardware.hasNeuralEngine ? "yes" : "no")",
            "",
            "Active model ID:    \(model.id)",
            "Runtime:            \(model.runtime.displayName)",
            "Model location:     \(model.isLocal ? "local" : "cloud")",
            "",
            "Microphone:         \(describe(PermissionsManager.microphoneStatus()))",
            "Accessibility:      \(describe(PermissionsManager.accessibilityStatus()))",
            "",
            "Filler removal:     \(FormattingPreferences.shared.fillerRemovalMode.rawValue)",
            "AI formatting:      \(FormattingPreferences.shared.aiFormattingMode.rawValue)",
            "Statistics:         \(DictationStatistics.shared.isEnabled ? "on" : "off")",
            "Dictations logged:  \(DictationStatistics.shared.lifetimeSummary.dictationCount)",
            "",
            "--- Recent log ---",
        ]

        let log = DiagnosticsLog.shared.formattedTranscript()
        lines.append(log.isEmpty ? "(no entries)" : log)

        return lines.joined(separator: "\n")
    }

    static func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generate(), forType: .string)
    }

    /// Writes the report next to Clide's other data and reveals it in Finder.
    @discardableResult
    static func export() -> URL? {
        let filename = "Clide-Diagnostics-\(Int(Date().timeIntervalSince1970)).txt"
        let url = ClideStorage.applicationSupportDirectory.appendingPathComponent(filename)

        do {
            try generate().write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return url
        } catch {
            clideLog(.error, "diagnostics", "Export failed: \(error.localizedDescription)")
            return nil
        }
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private static func describe(_ status: PermissionStatus) -> String {
        switch status {
        case .granted: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "not determined"
        }
    }
}
