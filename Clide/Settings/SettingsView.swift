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
    @State private var groqAPIKey = KeychainService.groqAPIKey() ?? ""
    @State private var isShowingConsole = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTestingConnection = false

    private enum ConnectionStatus: Equatable {
        case unknown
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Dictation") {
                KeyboardShortcuts.Recorder("Shortcut", name: .toggleDictation)

                Text("Press it once to start, again to stop. Escape cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        Text("\(model.displayName) — \(model.isLocal ? "Local" : "Cloud")")
                            .tag(model.id)
                    }
                }
            }

            Section("Groq (Cloud, bring your own key)") {
                SecureField("API Key", text: $groqAPIKey)
                    .textContentType(.password)

                HStack {
                    Button("Save") {
                        KeychainService.setGroqAPIKey(groqAPIKey)
                        connectionStatus = .unknown
                    }
                    .disabled(groqAPIKey.isEmpty)

                    Button(isTestingConnection ? "Testing…" : "Test Connection") {
                        Task { await testConnection() }
                    }
                    .disabled(groqAPIKey.isEmpty || isTestingConnection)

                    Spacer()
                    connectionStatusView
                }

                Text("Audio you dictate while a Groq model is active is sent directly to Groq using your key — never through a Clide server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    @ViewBuilder
    private var connectionStatusView: some View {
        switch connectionStatus {
        case .unknown:
            EmptyView()
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    private func testConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }

        let succeeded = await GroqTranscriptionEngine.testConnection(apiKey: groqAPIKey)
        connectionStatus = succeeded ? .success : .failure("Couldn't connect — check your key.")
    }
}

#Preview {
    SettingsView()
}
