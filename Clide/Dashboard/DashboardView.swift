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
                        .font(.clideDisplay(26))
                        .foregroundStyle(ClideTheme.ink)
                    Spacer()
                    SettingsButton(isSpotlighted: isSpotlightingSettings)
                }

                ReadinessCard(model: modelManager.activeModel, monitor: shortcutMonitor)
                TodaySection(summary: statistics.todaySummary, isEnabled: statistics.isEnabled)

                if history.isEnabled {
                    RecentActivitySection(entries: Array(history.entries.prefix(4)))
                }

                ModelsSection(modelManager: modelManager, isShowingBrowser: $isShowingBrowser)
            }
            .padding(24)
            // The window has a transparent, full-size-content titlebar, so
            // SwiftUI content starts at y=0 — without this the greeting sits
            // directly behind the traffic-light buttons.
            .padding(.top, 14)
        }
        .frame(minWidth: 460, minHeight: 420)
        .clideCanvas()
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
                    .foregroundStyle(isSpotlighted ? ClideTheme.accent : .secondary)
                    .padding(7)
                    .background(
                        Circle()
                            .fill(isSpotlighted ? ClideTheme.accentWash : (isHovering ? Color.primary.opacity(0.06) : .clear))
                    )
                    .clideMotion { icon in icon.scaleEffect(isSpotlighted ? 1.12 : (isHovering ? 1.05 : 1)) }
            }
            .buttonStyle(.plain)
            .help("Settings")
            .onHover { isHovering = $0 }
            .clideAnimation(ClideTheme.Motion.pop, value: isSpotlighted)
            .clideAnimation(ClideTheme.Motion.hover, value: isHovering)

            if isSpotlighted {
                Text("Shortcut, models and privacy live here")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clideAnimation(.easeOut(duration: 0.25), value: isSpotlighted)
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
                HStack(spacing: 6) {
                    ClideRecDot()
                    Text("Ready to dictate")
                        .font(.clideHeadline)
                }
                Text(model.displayName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HardwareFitBadge(model: model)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .clideCard(padding: 18)
    }
}

// MARK: - Today

private struct TodaySection: View {
    let summary: DictationStatistics.Summary
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClideSectionHeader("Today")

            if !isEnabled {
                ClideEmptyState(
                    symbol: "chart.bar",
                    title: "Statistics are off",
                    message: "Turn them on in Settings to see your dictation totals here.",
                    tone: .neutral
                )
                .clideCard(padding: 0)
            } else if summary.dictationCount == 0 {
                ClideEmptyState(
                    symbol: "waveform",
                    title: "Nothing yet today",
                    message: "Press ⌥ . in any text field to start."
                )
                .clideCard(padding: 0)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let saved = summary.timeSaved {
                        TimeSavedHeadline(saved: saved)
                    }
                    SupportingStats(summary: summary)
                }
                .clideAnimation(.snappy(duration: 0.3), value: summary.wordCount)
                .clideCard(padding: 18)
            }
        }
    }
}

private struct TimeSavedHeadline: View {
    let saved: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("~\(TimeSavedCalculator.friendlyDescription(ofSaved: saved))")
                .font(.clideDisplay(32))
                .foregroundStyle(ClideTheme.ink)
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
            ClideBadge(
                text: summary.localPercentage == 100 ? "All local" : "\(summary.localPercentage)% local",
                symbol: summary.localPercentage == 100 ? "lock.fill" : "lock.open",
                tone: summary.localPercentage == 100 ? .positive : .neutral
            )
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
                ClideSectionHeader("Your models")
                Spacer()
                Button("Browse all") { isShowingBrowser = true }
                    .buttonStyle(.clideQuiet)
                    .font(.caption)
            }

            ClideRowGroup(items: relevantModels, dividerInset: 14) { model in
                ModelRow(
                    model: model,
                    isActive: model.id == modelManager.activeModelID,
                    isInstalled: modelManager.isInstalled(model),
                    activate: { modelManager.setActiveModel(model.id) }
                )
            }
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
                    .fill(isActive ? ClideTheme.accent : Color.secondary.opacity(0.25))
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
                    ClideBadge(text: "Active", symbol: "checkmark", tone: .accent)
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
        .background(isHovering && !isActive ? ClideTheme.surfaceHover : .clear)
        .onHover { isHovering = $0 }
        .clideAnimation(ClideTheme.Motion.hover, value: isHovering)
        .accessibilityLabel("\(model.displayName)\(isActive ? ", active" : "")")
        .accessibilityHint(isActive ? "" : "Activate this model")
    }
}

// MARK: - Recent activity

private struct RecentActivitySection: View {
    let entries: [TranscriptEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClideSectionHeader("Recent")

            if entries.isEmpty {
                ClideEmptyState(
                    symbol: "clock",
                    title: "Nothing recorded yet",
                    message: "Your recent transcripts will show up here after you dictate."
                )
                .clideCard(padding: 0)
            } else {
                ClideRowGroup(items: entries, dividerInset: 14) { entry in
                    RecentActivityRow(entry: entry)
                }
            }
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

            ClideIconButton(
                symbol: didCopy ? "checkmark" : "doc.on.doc",
                help: "Copy transcript",
                tint: didCopy ? ClideTheme.positive : nil
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
                didCopy = true
            }
            .opacity(isHovering || didCopy ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if !hovering { didCopy = false }
        }
        .clideAnimation(ClideTheme.Motion.hover, value: isHovering)
    }
}

#Preview {
    DashboardView()
}
