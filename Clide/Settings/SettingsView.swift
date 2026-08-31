import SwiftUI

/// Foundation settings surface — active model selection and the Groq BYOK key.
/// A single form rather than the full tabbed Settings from clide.md §29, since
/// the sections that would justify tabs (Formatting, Privacy, Developer) don't
/// exist yet.
struct SettingsView: View {
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var groqAPIKey = KeychainService.groqAPIKey() ?? ""
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTestingConnection = false

    private enum ConnectionStatus: Equatable {
        case unknown
        case success
        case failure(String)
    }

    var body: some View {
        Form {
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
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
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
