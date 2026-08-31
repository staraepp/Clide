import SwiftUI

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .id(state.step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
                .transition(stepTransition)

            ProgressDots(step: state.step)
                .padding(.bottom, 22)
        }
        .frame(width: 540, height: 480)
        .clideFluidCanvas()
        .clideAnimation(ClideTheme.Motion.gentle, value: state.step)
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(x: 14)),
                removal: .opacity.combined(with: .offset(x: -14))
            )
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
                .buttonStyle(.clidePrimary)
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
                    .buttonStyle(.clidePrimary)
                    .controlSize(.large)
            case .denied:
                VStack(spacing: 10) {
                    Text("Microphone access was denied. Turn it on in System Settings → Privacy & Security → Microphone.")
                        .font(.callout)
                        .foregroundStyle(ClideTheme.caution)
                        .multilineTextAlignment(.center)
                    Button("Skip for now", action: state.advance)
                        .buttonStyle(.clideQuiet)
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
                    .buttonStyle(.clidePrimary)
                    .controlSize(.large)

                    Text("Turn on Clide in the list. This screen updates on its own.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Skip for now", action: state.advance)
                        .buttonStyle(.clideQuiet)
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
                VStack(spacing: 12) {
                    ProgressView()
                    Text(state.discoveredModels.isEmpty
                         ? "Downloading about \(state.activeModel.formattedDownloadSize) the first time…"
                         : "Setting things up…")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let found = state.discoveredModels.first {
                        Label(
                            "Found a compatible model in \(found.locationDescription)",
                            systemImage: "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(ClideTheme.positive)
                    }
                }
            } else if let error = state.modelError {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(ClideTheme.caution)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { state.goTo(.model) }
                        .buttonStyle(.clideSecondary)
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
            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    KeycapView(label: "⌥", isPressed: monitor.isOptionDown, size: 56)
                    Text("+")
                        .font(.clideDisplay(18, weight: .regular))
                        .foregroundStyle(.secondary)
                    KeycapView(label: ".", isPressed: monitor.isPeriodDown, size: 56)
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
    @State private var didAppear = false

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
                        .clideCard(padding: 14)
                        .frame(maxWidth: .infinity)
                }

                if let saved = state.timeSaved {
                    VStack(spacing: 3) {
                        Text("You just saved about \(TimeSavedCalculator.friendlyDescription(ofSaved: saved)) by speaking ✨")
                            .font(.clideDisplay(14, weight: .medium))
                        Text(TimeSavedCalculator.methodologyDisclaimer)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .clideMotion { content in
                        content
                            .scaleEffect(didAppear ? 1 : 0.9)
                            .opacity(didAppear ? 1 : 0)
                    }
                    .onAppear {
                        withAnimation(ClideTheme.Motion.pop.delay(0.15)) { didAppear = true }
                    }
                }

                HStack(spacing: 10) {
                    Button("Try Again") { state.retryDictation() }
                        .buttonStyle(.clideSecondary)
                    Button("Continue", action: state.advance)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.clidePrimary)
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
                    .buttonStyle(.clidePrimary)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 340)
        }
    }
}

private struct PreferencePicker: View {
    let title: String
    let detail: String
    @Binding var selection: FormattingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
            Picker(title, selection: $selection) {
                ForEach(FormattingMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DoneStep: View {
    let finish: () -> Void
    @State private var didAppear = false

    var body: some View {
        StepLayout(
            title: "You're ready.",
            message: "Press ⌥ . in any text field, anywhere on your Mac. Everything else lives in Settings, from the Clide icon in your menu bar.",
            symbol: "checkmark.circle"
        ) {
            Button("Open Clide", action: finish)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.clidePrimary)
                .controlSize(.large)
        }
        .clideMotion { content in
            content
                .scaleEffect(didAppear ? 1 : 0.92)
                .opacity(didAppear ? 1 : 0)
        }
        .onAppear {
            withAnimation(ClideTheme.Motion.pop) { didAppear = true }
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
                    .foregroundStyle(ClideTheme.accent)
                    .padding(.bottom, 4)
            }

            Text(title)
                .font(.clideDisplay(22))
                .foregroundStyle(ClideTheme.ink)
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
                .foregroundStyle(ClideTheme.positive)
                .font(.callout)
            Button("Continue", action: next)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.clidePrimary)
                .controlSize(.large)
        }
    }
}

private struct ProgressDots: View {
    let step: OnboardingState.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingState.Step.allCases, id: \.rawValue) { candidate in
                Capsule()
                    .fill(candidate.rawValue <= step.rawValue ? ClideTheme.accent : Color.secondary.opacity(0.22))
                    .frame(width: candidate == step ? 16 : 5, height: 5)
                    .clideAnimation(ClideTheme.Motion.snap, value: step)
            }
        }
        .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingState.Step.allCases.count)")
    }
}
