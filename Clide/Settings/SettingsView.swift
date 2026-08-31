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
            Section("Dictation") {
                KeyboardShortcuts.Recorder("Shortcut", name: .toggleDictation)

                Text("Press it once to start, again to stop. Escape cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Accessibility") {
                    HStack(spacing: 8) {
                        if accessibilityStatus == .granted {
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.callout)
                        } else {
                            Label("Not granted", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.callout)
                        }
                        Button("Open Settings") { PermissionsManager.openAccessibilitySettings() }
                    }
                }

                if accessibilityStatus != .granted {
                    Text("Without it Clide still transcribes and copies the text to your clipboard — it just can't type it for you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("General") {
                Toggle("Open Clide at login", isOn: $launchAtLogin.isEnabled)

                if launchAtLogin.needsApproval {
                    Text("macOS needs you to approve this in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Transcription Model") {
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

                Button("Browse Models…") { isShowingModelBrowser = true }
            }

            Section("Cloud Providers") {
                Text("Bring your own key. Audio goes straight from this Mac to the provider you pick — never through a Clide server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(CloudProvider.allCases) { provider in
                    CloudProviderRow(provider: provider)
                }
            }

            Section("Formatting") {
                Picker("Filler word removal", selection: $formatting.fillerRemovalMode) {
                    ForEach(FormattingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Text("Removes “um” and “uh”. Words like “so” and “well” are left alone — they're too often part of what you meant.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("AI formatting", selection: $formatting.aiFormattingMode) {
                    ForEach(FormattingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Text("No on-device formatting model is available yet, so this setting has no effect for now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle("Keep local statistics", isOn: $statistics.isEnabled)

                HStack {
                    Text("\(statistics.lifetimeSummary.dictationCount) dictations recorded")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Statistics") { statistics.clear() }
                        .disabled(statistics.records.isEmpty)
                }

                Text("Statistics are counters only — they stay on this Mac and never include what you said.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Developer Data") {
                Toggle("Share developer diagnostics with Clide", isOn: $developer.hasConsentedToDeveloperData)

                Text("Off by default. Turning this on also unlocks Debug Mode, including a local console and developer tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Your transcripts, recordings, API keys, custom vocabulary and clipboard contents stay on this Mac and are never included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("No diagnostics are uploaded yet — Clide has no server to send them to. For now this only enables Debug Mode and local diagnostics.")
                    .font(.caption)
                    .foregroundStyle(.orange)

                HStack {
                    Button("Copy Diagnostics") { DiagnosticsReport.copyToPasteboard() }
                    Button("Export Diagnostics…") { DiagnosticsReport.export() }
                    Spacer()
                    Text("Clide \(DiagnosticsReport.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if developer.isDebugModeEnabled {
                Section("Developer") {
                    Button("Open Console") { isShowingConsole = true }
                    Button("Open Model Folder") {
                        NSWorkspace.shared.open(ClideStorage.modelsDirectory)
                    }
                    Button("Run Onboarding Again") {
                        OnboardingState.hasCompleted = false
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(statusPoll) { _ in
            accessibilityStatus = PermissionsManager.accessibilityStatus()
        }
        .sheet(isPresented: $isShowingModelBrowser) {
            ModelBrowserSheet(isPresented: $isShowingModelBrowser)
        }
        .sheet(isPresented: $isShowingConsole) {
            VStack(spacing: 0) {
                DeveloperConsoleView()
                Divider()
                HStack {
                    Spacer()
                    Button("Done") { isShowingConsole = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(10)
            }
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
                Text("Key saved").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Not set up").font(.caption).foregroundStyle(.tertiary)
            }
        case .testing:
            ProgressView().controlSize(.small)
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.caption)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red).font(.caption)
        }
    }

    private func test() async {
        status = .testing
        switch await provider.testConnection() {
        case .success:
            status = .success
        case .failure(let error):
            status = .failure(error.errorDescription ?? "Couldn't connect")
        }
    }
}

#Preview {
    SettingsView()
}
