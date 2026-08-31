import SwiftUI

/// Live amplitude feed for the waveform, separate from `PillState` so a
/// stream of amplitude ticks doesn't have to reconstruct/resize the pill —
/// only real state transitions do that.
@MainActor
final class WaveformAmplitudeModel: ObservableObject {
    @Published var level: Float = 0
}

struct DictationPillView: View {
    let state: PillState
    @ObservedObject var amplitude: WaveformAmplitudeModel
    var choiceActions: PillChoiceActions?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if state.isVisible {
                pill
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.86, anchor: .top)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: -8))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(appearance, value: state.isVisible)
    }

    private var pill: some View {
        HStack(spacing: 8) {
            leadingGlyph
            if !state.message.isEmpty {
                Text(state.message)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .transition(.opacity)
            }
            if state == .awaitingChoice, let choiceActions {
                if let format = choiceActions.format {
                    PillButton(title: "✨ Format", action: format)
                }
                if let removeFillers = choiceActions.removeFillers {
                    PillButton(title: "Remove fillers", action: removeFillers)
                }
                PillButton(title: "Insert", action: choiceActions.insertAsIs, isProminent: true)
            }
            if let recovery = state.recoveryAction {
                PillButton(title: recovery.title, action: { perform(recovery) })
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(pillBackground)
        .clideAnimation(ClideTheme.Motion.snap, value: state)
    }

    /// Real frosted glass, not a flat fill — the panel behind this view is
    /// genuinely transparent (`DictationPillWindow` sets `isOpaque = false`),
    /// so `.ultraThinMaterial` blurs whatever's actually on screen beneath the
    /// pill, exactly like a native macOS overlay (Now Playing, Control
    /// Center). Forced to the dark material variant regardless of system
    /// appearance, since the pill's text and glyphs are always white — a
    /// light-mode material here would kill that contrast over a bright desktop.
    /// A soft black tint sits under the material for the same reason: pure
    /// glass over, say, a white Finder window would still read too pale.
    private var pillBackground: some View {
        Capsule()
            .fill(.black.opacity(0.32))
            .background(
                Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            )
            .overlay(
                Capsule().strokeBorder(edgeColor.opacity(state.tone == .neutral ? 0.14 : 0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
            .shadow(color: edgeColor.opacity(state.tone == .neutral ? 0 : 0.25), radius: 14, y: 0)
    }

    private var edgeColor: Color {
        switch state.tone {
        case .neutral: return .white
        case .success: return ClideTheme.positive
        case .clipboard: return ClideTheme.accent
        case .caution: return ClideTheme.caution
        case .error: return .red
        }
    }

    /// The waveform is the pill's own instrument, so it collapses into the
    /// processing glyph rather than being swapped out abruptly.
    @ViewBuilder
    private var leadingGlyph: some View {
        if state == .listening {
            ClideWaveform(level: amplitude.level, height: 16, tint: .white)
                .frame(width: 28, height: 16)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        } else if state == .formatting {
            SparkleGlyph(reduceMotion: reduceMotion)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        } else {
            PillSymbol(state: state, tint: edgeColor, reduceMotion: reduceMotion)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        }
    }

    private func perform(_ action: RecoveryAction) {
        switch action {
        case .openAccessibilitySettings: PermissionsManager.openAccessibilitySettings()
        case .openMicrophoneSettings: PermissionsManager.openMicrophoneSettings()
        case .openClideSettings, .retry: break
        }
    }

    private var appearance: Animation? {
        reduceMotion ? ClideTheme.Motion.reduced : .spring(response: 0.34, dampingFraction: 0.72)
    }
}

private struct PillSymbol: View {
    let state: PillState
    let tint: Color
    let reduceMotion: Bool

    var body: some View {
        Image(systemName: state.symbolName)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 18)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(state.tone == .neutral ? .white : tint)
            .modifier(SymbolMotion(state: state, reduceMotion: reduceMotion))
            .contentTransition(.symbolEffect(.replace))
            .clideSuccessPulse(state == .inserted, tint: ClideTheme.positive)
    }
}

/// Motion is chosen per state: work in progress pulses, a success lands once.
private struct SymbolMotion: ViewModifier {
    let state: PillState
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else if state.isBusy {
            content.symbolEffect(.pulse, options: .repeating)
        } else {
            content.symbolEffect(.bounce, value: state)
        }
    }
}

/// A quiet shimmer for the formatting step — three sparkle glyphs that fade in
/// and out slightly out of phase, so it reads as texture rather than a spinner.
private struct SparkleGlyph: View {
    let reduceMotion: Bool
    @State private var isShimmering = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 14, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(ClideTheme.accent.opacity(0.95))
            .frame(width: 18)
            .clideMotion { glyph in
                glyph
                    .opacity(isShimmering ? 1 : 0.55)
                    .scaleEffect(isShimmering ? 1.08 : 0.94)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isShimmering)
            }
            .onAppear { isShimmering = true }
    }
}

private struct PillButton: View {
    let title: String
    let action: () -> Void
    var isProminent: Bool = false

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        isProminent
                            ? ClideTheme.accent.opacity(isHovering ? 1 : 0.88)
                            : Color.white.opacity(isHovering ? 0.28 : 0.16)
                    )
                )
                .clideMotion { label in label.scaleEffect(isHovering ? 1.04 : 1) }
        }
        .buttonStyle(.clideRow)
        .clideAnimation(ClideTheme.Motion.hover, value: isHovering)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    VStack(spacing: 12) {
        DictationPillView(state: .listening, amplitude: {
            let model = WaveformAmplitudeModel()
            model.level = 0.15
            return model
        }())
        DictationPillView(state: .modelLoading("Whisper Base"), amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .transcribing, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .formatting, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .inserted, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .copiedAfterInsertionFailed, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .copiedNeedsAccessibility, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .secureFieldBlocked, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .error("Model unavailable"), amplitude: WaveformAmplitudeModel())
    }
    .padding(40)
    .background(.gray)
}
