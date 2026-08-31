import SwiftUI

/// Clide's home surface (clide.md §25). Three things, in the order they matter:
/// is Clide ready, what did dictating give back today, and which model is running.
struct DashboardView: View {
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var statistics = DictationStatistics.shared
    @ObservedObject private var history = TranscriptHistory.shared
    @StateObject private var shortcutMonitor = ShortcutPressMonitor()
    @State private var isShowingBrowser = false
    @State private var isSpotlightingSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Self.greeting)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Spacer()
                    SettingsButton(isSpotlighted: isSpotlightingSettings)
                }

                ReadinessCard(model: modelManager.activeModel, monitor: shortcutMonitor)
                TodaySection(summary: statistics.todaySummary, isEnabled: statistics.isEnabled)

                // History is off by default, so this section simply isn't
                // there rather than sitting empty (clide.md §25).
                if history.isEnabled, !history.entries.isEmpty {
                    RecentActivitySection(entries: Array(history.entries.prefix(4)))
                }

                ModelsSection(modelManager: modelManager, isShowingBrowser: $isShowingBrowser)
            }
            .padding(24)
        }
        .frame(minWidth: 440, minHeight: 400)
        .background(.background)
        .onAppear {
            shortcutMonitor.start()
            runSettingsSpotlightIfNeeded()
        }
        .onDisappear { shortcutMonitor.stop() }
        .sheet(isPresented: $isShowingBrowser) {
            ModelBrowserSheet(isPresented: $isShowingBrowser)
        }
    }

    /// A one-time nudge toward Settings right after onboarding, so people know
    /// where customisation lives (clide.md §7). Shown once, ever.
    private func runSettingsSpotlightIfNeeded() {
        guard SettingsSpotlight.shouldShow else { return }
        SettingsSpotlight.markShown()

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            isSpotlightingSettings = true
            try? await Task.sleep(for: .seconds(4))
            isSpotlightingSettings = false
        }
    }

    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

@MainActor
private enum SettingsSpotlight {
    private static let key = "Clide.hasSeenSettingsSpotlight"

    static var shouldShow: Bool {
        OnboardingState.hasCompleted && !UserDefaults.standard.bool(forKey: key)
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

private struct SettingsButton: View {
    let isSpotlighted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundStyle(isSpotlighted ? Color.accentColor : .secondary)
                    .padding(7)
                    .background(
                        Circle()
                            .fill(isSpotlighted ? Color.accentColor.opacity(0.15) : .clear)
                    )
                    .scaleEffect(isSpotlighted && !reduceMotion ? 1.12 : (isHovering ? 1.05 : 1))
            }
            .buttonStyle(.plain)
            .help("Settings")
            .onHover { isHovering = $0 }
            .animation(
                reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6),
                value: isSpotlighted
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)

            if isSpotlighted {
                Text("Shortcut, models and privacy live here")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isSpotlighted)
    }
}

// MARK: - Readiness

private struct ReadinessCard: View {
    let model: TranscriptionModelInfo
    @ObservedObject var monitor: ShortcutPressMonitor

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            HStack(spacing: 7) {
                KeycapView(label: "⌥", isPressed: monitor.isOptionDown)
                KeycapView(label: ".", isPressed: monitor.isPeriodDown)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Ready to dictate")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(model.displayName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HardwareFitBadge(model: model)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Today

private struct TodaySection: View {
    let summary: DictationStatistics.Summary
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Today")

            if !isEnabled {
                CardText("Statistics are off. Turn them on in Settings to see your dictation totals here.")
            } else if summary.dictationCount == 0 {
                CardText("Nothing yet today. Press ⌥ . in any text field to start.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let saved = summary.timeSaved {
                        TimeSavedHeadline(saved: saved)
                    }
                    SupportingStats(summary: summary)
                }
                .animation(.snappy(duration: 0.3), value: summary.wordCount)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct TimeSavedHeadline: View {
    let saved: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("~\(TimeSavedCalculator.friendlyDescription(ofSaved: saved))")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("saved by speaking instead of typing")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(TimeSavedCalculator.methodologyDisclaimer)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 3)
        }
    }
}

private struct SupportingStats: View {
    let summary: DictationStatistics.Summary

    private var minutesSpoken: Int {
        max(Int((summary.speakingDuration / 60).rounded()), 1)
    }

    var body: some View {
        HStack(spacing: 6) {
            statText("\(summary.wordCount.formatted()) words")
            dot
            statText("\(summary.dictationCount) dictation\(summary.dictationCount == 1 ? "" : "s")")
            dot
            statText("\(minutesSpoken) min spoken")
            dot
            Label(
                summary.localPercentage == 100 ? "all local" : "\(summary.localPercentage)% local",
                systemImage: summary.localPercentage == 100 ? "lock.fill" : "lock.open"
            )
            .font(.caption)
            .foregroundStyle(summary.localPercentage == 100 ? .green : .secondary)
        }
    }

    private func statText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(.secondary)
    }

    private var dot: some View {
        Text("·").font(.caption).foregroundStyle(.tertiary)
    }
}

// MARK: - Models

private struct ModelsSection: View {
    @ObservedObject var modelManager: ModelManager

    @Binding var isShowingBrowser: Bool

    /// Only what's relevant here: the active model, anything already
    /// downloaded, and cloud providers that have a key. Everything else lives
    /// in the browser rather than making this a wall of eleven rows.
    private var relevantModels: [TranscriptionModelInfo] {
        modelManager.catalog.filter { model in
            model.id == modelManager.activeModelID || modelManager.isReadyToUse(model)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader("Your models")
                Spacer()
                Button("Browse all") { isShowingBrowser = true }
                    .buttonStyle(.link)
                    .font(.caption)
            }

            VStack(spacing: 0) {
                ForEach(Array(relevantModels.enumerated()), id: \.element.id) { index, model in
                    if index > 0 { Divider().padding(.leading, 14) }
                    ModelRow(
                        model: model,
                        isActive: model.id == modelManager.activeModelID,
                        isInstalled: modelManager.isInstalled(model),
                        activate: { modelManager.setActiveModel(model.id) }
                    )
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct ModelRow: View {
    let model: TranscriptionModelInfo
    let isActive: Bool
    let isInstalled: Bool
    let activate: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: activate) {
            HStack(spacing: 11) {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 5) {
                        Text(model.isLocal ? "On this Mac" : "Cloud · \(model.runtime.displayName)")
                        if model.isLocal, isInstalled {
                            Text("·")
                            Text(model.formattedDownloadSize)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if isActive {
                    Text("Active")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                } else {
                    HardwareFitBadge(model: model, showsSummary: false)
                        .opacity(isHovering ? 1 : 0.55)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering && !isActive ? Color.primary.opacity(0.04) : .clear)
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(model.displayName)\(isActive ? ", active" : "")")
        .accessibilityHint(isActive ? "" : "Activate this model")
    }
}

// MARK: - Recent activity

private struct RecentActivitySection: View {
    let entries: [TranscriptEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recent")

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider().padding(.leading, 14) }
                    RecentActivityRow(entry: entry)
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct RecentActivityRow: View {
    let entry: TranscriptEntry

    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Text(entry.date, format: .dateTime.hour().minute())
                    if let app = entry.sourceApplication {
                        Text("·")
                        Text(app)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
                didCopy = true
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(didCopy ? .green : .secondary)
            .opacity(isHovering || didCopy ? 1 : 0)
            .help("Copy transcript")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if !hovering { didCopy = false }
        }
    }
}

// MARK: - Shared bits

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.4)
    }
}

private struct CardText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    DashboardView()
}
