import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)

            ProgressDots(step: state.step)
                .padding(.bottom, 20)
        }
        .frame(width: 520, height: 460)
        .background(.background)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch state.step {
        case .welcome:
            WelcomeStep(next: state.advance)
        case .microphone:
            MicrophoneStep(state: state)
        case .accessibility:
            AccessibilityStep(state: state)
        case .model:
            ModelStep(state: state)
        case .tryIt:
            TryItStep(state: state)
        case .result:
            ResultStep(state: state)
        case .preferences:
            PreferencesStep(next: state.advance)
        case .done:
            DoneStep(finish: onFinish)
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    let next: () -> Void

    var body: some View {
        StepLayout(
            title: "Your voice, wherever you type.",
            message: "Press a shortcut, speak naturally, and Clide puts the words where your cursor already is.",
            symbol: "waveform"
        ) {
            Button("Get Started", action: next)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }
}

private struct MicrophoneStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        StepLayout(
            title: "Clide needs your microphone.",
            message: "That's how it hears you. Audio is transcribed by the model you choose and isn't stored by Clide.",
            symbol: "mic"
        ) {
            switch state.microphoneStatus {
            case .granted:
                GrantedRow(text: "Microphone access granted", next: state.advance)
            case .notDetermined:
                Button("Allow Microphone Access") { state.requestMicrophone() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            case .denied:
                VStack(spacing: 8) {
                    Text("Microphone access was denied. Turn it on in System Settings → Privacy & Security → Microphone.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    Button("Skip for now", action: state.advance)
                }
            }
        }
    }
}

private struct AccessibilityStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        StepLayout(
            title: "One more permission.",
            message: "Accessibility access lets Clide type into the text field you're already using. Without it, Clide can still copy transcripts to your clipboard.",
            symbol: "keyboard"
        ) {
            if state.accessibilityStatus == .granted {
                GrantedRow(text: "Accessibility access granted", next: state.advance)
            } else {
                VStack(spacing: 10) {
                    Button("Open System Settings") {
                        state.requestAccessibility()
                        state.openAccessibilitySettings()
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)

                    Text("Turn on Clide in the list. This screen updates on its own.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Skip for now", action: state.advance)
                        .buttonStyle(.link)
                }
            }
        }
    }
}

private struct ModelStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        StepLayout(
            title: "Getting \(state.activeModel.displayName) ready.",
            message: "It runs entirely on your Mac, so your voice never leaves this machine.",
            symbol: "cube"
        ) {
            if state.isPreparingModel {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Downloading about \(state.activeModel.formattedDownloadSize) the first time…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let error = state.modelError {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { state.goTo(.model) }
                }
            } else {
                GrantedRow(text: "\(state.activeModel.displayName) is ready", next: state.advance)
            }
        }
    }
}

private struct TryItStep: View {
    @ObservedObject var state: OnboardingState
    @StateObject private var monitor = ShortcutPressMonitor()

    var body: some View {
        StepLayout(
            title: "Try Clide.",
            message: "Press the shortcut and say any sentence. Press it again when you're done.",
            symbol: nil
        ) {
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    KeycapView(label: "⌥", isPressed: monitor.isOptionDown, size: 52)
                    Text("+").foregroundStyle(.secondary)
                    KeycapView(label: ".", isPressed: monitor.isPeriodDown, size: 52)
                }

                Text("Watch for the Clide pill at the top of your screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}

private struct ResultStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        StepLayout(
            title: "That's it — that's the whole thing.",
            message: nil,
            symbol: nil
        ) {
            VStack(spacing: 16) {
                if let transcript = state.transcript {
                    Text("“\(transcript)”")
                        .font(.system(size: 15, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let saved = state.timeSaved {
                    VStack(spacing: 3) {
                        Text("You just saved about \(TimeSavedCalculator.friendlyDescription(ofSaved: saved)) by speaking ✨")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        Text(TimeSavedCalculator.methodologyDisclaimer)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 10) {
                    Button("Try Again") { state.retryDictation() }
                    Button("Continue", action: state.advance)
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                }
            }
        }
    }
}

private struct PreferencesStep: View {
    let next: () -> Void
    @ObservedObject private var formatting = FormattingPreferences.shared
    private let formatter: TranscriptFormatter = AppleFormatter()

    private var formatterDetail: String {
        formatter.isAvailable
            ? "Uses \(formatter.displayName) to punctuate and paragraph, without changing your words."
            : formatter.unavailableReason ?? "No on-device formatter is available on this Mac."
    }

    var body: some View {
        StepLayout(
            title: "How much tidying should Clide do?",
            message: "Clide always fixes spacing and capitalisation. These two are up to you.",
            symbol: nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                PreferencePicker(
                    title: "Remove filler words",
                    detail: "Drops “um” and “uh”. Leaves words like “so” alone.",
                    selection: $formatting.fillerRemovalMode
                )

                PreferencePicker(
                    title: "AI formatting",
                    detail: formatterDetail,
                    selection: $formatting.aiFormattingMode
                )
                .disabled(!formatter.isAvailable)

                Button("Continue", action: next)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
}

private struct PreferencePicker: View {
    let title: String
    let detail: String
    @Binding var selection: FormattingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(title, selection: $selection) {
                ForEach(FormattingMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DoneStep: View {
    let finish: () -> Void

    var body: some View {
        StepLayout(
            title: "You're ready.",
            message: "Press ⌥ . in any text field, anywhere on your Mac. Everything else lives in Settings, from the Clide icon in your menu bar.",
            symbol: "checkmark.circle"
        ) {
            Button("Open Clide", action: finish)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }
}

// MARK: - Shared

private struct StepLayout<Actions: View>: View {
    let title: String
    var message: String?
    var symbol: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .padding(.bottom, 4)
            }

            Text(title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
            actions
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 400)
    }
}

private struct GrantedRow: View {
    let text: String
    let next: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label(text, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
            Button("Continue", action: next)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }
}

private struct ProgressDots: View {
    let step: OnboardingState.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingState.Step.allCases, id: \.rawValue) { candidate in
                Circle()
                    .fill(candidate.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingState.Step.allCases.count)")
    }
}
