import SwiftUI

/// The local developer console shown when Debug Mode is on. Entirely local —
/// nothing here is transmitted anywhere.
struct DeveloperConsoleView: View {
    @ObservedObject private var log = DiagnosticsLog.shared
    @State private var minimumLevel: DiagnosticsLog.Level = .debug

    private var visibleEntries: [DiagnosticsLog.Entry] {
        log.entries.filter { $0.level >= minimumLevel }.reversed()
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if visibleEntries.isEmpty {
                ContentUnavailableView(
                    "No log entries",
                    systemImage: "text.alignleft",
                    description: Text("Activity shows up here as you use Clide.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(visibleEntries) { entry in
                    LogRow(entry: entry)
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 520, minHeight: 380)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("Level", selection: $minimumLevel) {
                ForEach(DiagnosticsLog.Level.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)

            Spacer()

            Button("Copy Diagnostics") { DiagnosticsReport.copyToPasteboard() }
            Button("Export…") { DiagnosticsReport.export() }
            Button("Clear") { log.clear() }
        }
        .padding(10)
    }
}

private struct LogRow: View {
    let entry: DiagnosticsLog.Entry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.date, format: .dateTime.hour().minute().second())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)

            Text(entry.level.rawValue.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 54, alignment: .leading)

            Text(entry.category)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var tint: Color {
        switch entry.level {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    DeveloperConsoleView()
}
