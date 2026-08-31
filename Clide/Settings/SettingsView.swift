import KeyboardShortcuts
import SwiftUI

/// Foundation settings surface — active model selection and the Groq BYOK key.
/// A single form rather than the full tabbed Settings from clide.md §29, since
/// the sections that would justify tabs (Formatting, Privacy, Developer) don't
/// exist yet.
struct SettingsView: View {
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var formatting = FormattingPreferences.shared
    @ObservedObject private var statistics = DictationStatistics.shared
    @ObservedObject private var history = TranscriptHistory.shared
    @ObservedObject private var dictation = DictationPreferences.shared
    @ObservedObject private var audioDevices = AudioDeviceManager.shared
    private let formatter: TranscriptFormatter = AppleFormatter()
    @ObservedObject private var launchAtLogin = LaunchAtLogin.shared
    @ObservedObject private var developer = DeveloperSettings.shared
    @State private var isShowingConsole = false
    @State private var isShowingModelBrowser = false
    @State private var accessibilityStatus = PermissionsManager.accessibilityStatus()

    /// Accessibility is granted outside the app, so poll while Settings is
    /// open rather than showing a stale state. This only reads the status —
    /// it never triggers the system prompt.
    private let statusPoll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Shortcut", name: .toggleDictation)

                Picker("When you press it", selection: $dictation.activation) {
                    ForEach(DictationActivation.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                caption("Escape cancels a recording in progress.")

                Picker("Microphone", selection: $audioDevices.selectedDeviceUID) {
                    Text("System default").tag(String?.none)
                    ForEach(audioDevices.devices) { device in
                        Text(device.name).tag(String?.some(device.uid))
                    }
                }

                if audioDevices.selectedDeviceIsMissing {
                    caution("That microphone isn't connected right now, so Clide will use the system default.")
                }

                LabeledContent("Accessibility") {
                    HStack(spacing: 8) {
                        if accessibilityStatus == .granted {
                            ClideBadge(text: "Granted", symbol: "checkmark", tone: .positive)
                        } else {
                            ClideBadge(text: "Not granted", symbol: "exclamationmark", tone: .caution)
                        }
                        Button("Open Settings") { PermissionsManager.openAccessibilitySettings() }
                    }
                }

                if accessibilityStatus != .granted {
                    caption("Without it Clide still transcribes and copies the text to your clipboard — it just can't type it for you.")
                }
            } header: {
                SectionLabel("Dictation", symbol: "mic.fill")
            }

            Section {
                Toggle("Open Clide at login", isOn: $launchAtLogin.isEnabled)

                if launchAtLogin.needsApproval {
                    caution("macOS needs you to approve this in System Settings → General → Login Items.")
                }
            } header: {
                SectionLabel("General", symbol: "gearshape.fill")
            }

            Section {
                Picker(
                    "Active model",
                    selection: Binding(
                        get: { modelManager.activeModelID },
                        set: { modelManager.setActiveModel($0) }
                    )
                ) {
                    ForEach(modelManager.catalog) { model in
                        Text("\(model.displayName) — \(model.runtime.displayName)")
                            .tag(model.id)
                    }
                }

                HStack {
                    HardwareFitBadge(model: modelManager.activeModel)
                    Spacer()
                    Button("Browse Models…") { isShowingModelBrowser = true }
                }
            } header: {
                SectionLabel("Transcription Model", symbol: "cube.fill")
            }

            Section {
                caption("Bring your own key. Audio goes straight from this Mac to the provider you pick — never through a Clide server.")

                ForEach(CloudProvider.allCases) { provider in
                    CloudProviderRow(provider: provider)
                }
            } header: {
                SectionLabel("Cloud Providers", symbol: "cloud.fill")
            }

            Section {
                Picker("Filler word removal", selection: $formatting.fillerRemovalMode) {
                    ForEach(FormattingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                caption("Removes “um” and “uh”. Words like “so” and “well” are left alone — they're too often part of what you meant.")

                Picker("AI formatting", selection: $formatting.aiFormattingMode) {
                    ForEach(FormattingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .disabled(!formatter.isAvailable)

                if formatter.isAvailable {
                    caption("Uses \(formatter.displayName) on this Mac to punctuate and paragraph your dictation. It never changes your wording, and dictation still works if it fails.")
                } else {
                    caution(formatter.unavailableReason ?? "No on-device formatter is available on this Mac.")
                }
            } header: {
                SectionLabel("Formatting", symbol: "sparkles")
            }

            Section {
                Toggle("Save transcript history", isOn: $history.isEnabled)

                if history.isEnabled {
                    HStack {
                        Text("\(history.entries.count) transcript\(history.entries.count == 1 ? "" : "s") saved")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear History") { history.clear() }
                            .disabled(history.entries.isEmpty)
                    }
                }

                caption("Off by default. This is the only place Clide keeps what you actually said — turning it off deletes what's stored.")
            } header: {
                SectionLabel("Privacy", symbol: "lock.fill")
            }

            Section {
                Toggle("Keep local statistics", isOn: $statistics.isEnabled)

                HStack {
                    Text("\(statistics.lifetimeSummary.dictationCount) dictations recorded")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Statistics") { statistics.clear() }
                        .disabled(statistics.records.isEmpty)
                }

                caption("Statistics are counters only — they stay on this Mac and never include what you said.")
            } header: {
                SectionLabel("Statistics", symbol: "chart.bar.fill")
            }

            Section {
                Toggle("Share developer diagnostics with Clide", isOn: $developer.hasConsentedToDeveloperData)

                caption("Off by default. Turning this on also unlocks Debug Mode, including a local console and developer tools.")
                caption("Your transcripts, recordings, API keys, custom vocabulary and clipboard contents stay on this Mac and are never included.")
                caution("No diagnostics are uploaded yet — Clide has no server to send them to. For now this only enables Debug Mode and local diagnostics.")

                HStack {
                    Button("Copy Diagnostics") { DiagnosticsReport.copyToPasteboard() }
                    Button("Export Diagnostics…") { DiagnosticsReport.export() }
                    Spacer()
                    Text("Clide \(DiagnosticsReport.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                SectionLabel("Developer Data", symbol: "chart.bar.doc.horizontal.fill")
            }

            if developer.isDebugModeEnabled {
                Section {
                    Button("Open Console") { isShowingConsole = true }
                    Button("Open Model Folder") {
                        NSWorkspace.shared.open(ClideStorage.modelsDirectory)
                    }
                    Button("Run Onboarding Again") {
                        OnboardingState.hasCompleted = false
                    }
                } header: {
                    SectionLabel("Developer", symbol: "hammer.fill")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 470)
        .clideCanvas()
        .onReceive(statusPoll) { _ in
            accessibilityStatus = PermissionsManager.accessibilityStatus()
        }
        .sheet(isPresented: $isShowingModelBrowser) {
            ModelBrowserSheet(isPresented: $isShowingModelBrowser)
        }
        .sheet(isPresented: $isShowingConsole) {
            VStack(spacing: 0) {
                DeveloperConsoleView()
                Rectangle().fill(ClideTheme.hairline).frame(height: 1)
                HStack {
                    Spacer()
                    Button("Done") { isShowingConsole = false }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.clidePrimary)
                }
                .padding(10)
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func caution(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(ClideTheme.caution)
    }
}

/// A section header with a small tinted icon, so the form reads at a glance
/// rather than as a stack of identical grey labels.
private struct SectionLabel: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(ClideTheme.accent)
        }
    }
}

/// One BYOK provider: key entry, save, and a real connection test.
private struct CloudProviderRow: View {
    let provider: CloudProvider

    @State private var key: String = ""
    @State private var status: TestStatus = .idle

    private enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(provider.displayName)
                    .font(.callout.weight(.medium))
                Spacer()
                statusView
            }

            HStack(spacing: 8) {
                SecureField("API key", text: $key)
                    .textContentType(.password)

                Button("Save") {
                    provider.setAPIKey(key)
                    ModelManager.shared.refreshProviderKeys()
                    status = .idle
                }
                .disabled(key.isEmpty)

                Button("Test") { Task { await test() } }
                    .disabled(!provider.hasAPIKey || status == .testing)
            }

            if let url = provider.apiKeyURL {
                Link("Get a \(provider.displayName) key", destination: url)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .onAppear { key = provider.apiKey ?? "" }
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            if provider.hasAPIKey {
                ClideBadge(text: "Key saved", tone: .neutral)
            } else {
                Text("Not set up").font(.caption).foregroundStyle(.tertiary)
            }
        case .testing:
            ProgressView().controlSize(.small)
        case .success:
            ClideBadge(text: "Connected", symbol: "checkmark", tone: .positive)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        case .failure(let message):
            ClideBadge(text: message, symbol: "xmark", tone: .caution)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private func test() async {
        status = .testing
        let result = await provider.testConnection()
        withAnimation(ClideTheme.Motion.pop) {
            switch result {
            case .success:
                status = .success
            case .failure(let error):
                status = .failure(error.errorDescription ?? "Couldn't connect")
            }
        }
    }
}

#Preview {
    SettingsView()
}
