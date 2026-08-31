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
        .background(
            Capsule()
                .fill(.black.opacity(0.85))
                .overlay(
                    Capsule().strokeBorder(
                        state.isAdvisory ? Color.orange.opacity(0.55) : .white.opacity(0.08),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: state)
    }

    /// The waveform is the pill's own instrument, so it collapses into the
    /// processing glyph rather than being swapped out abruptly.
    @ViewBuilder
    private var leadingGlyph: some View {
        if state == .listening {
            WaveformView(level: amplitude.level, reduceMotion: reduceMotion)
                .frame(width: 28, height: 16)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        } else {
            PillSymbol(state: state, reduceMotion: reduceMotion)
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
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.34, dampingFraction: 0.72)
    }
}

private struct PillSymbol: View {
    let state: PillState
    let reduceMotion: Bool

    var body: some View {
        Image(systemName: state.symbolName)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 18)
            .symbolRenderingMode(.hierarchical)
            .modifier(SymbolMotion(state: state, reduceMotion: reduceMotion))
            .contentTransition(.symbolEffect(.replace))
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
                            ? Color.accentColor.opacity(isHovering ? 1 : 0.85)
                            : Color.white.opacity(isHovering ? 0.28 : 0.16)
                    )
                )
                .scaleEffect(isHovering && !reduceMotion ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

/// Bars that react to microphone amplitude. Each bar eases at a slightly
/// different rate so the movement reads as organic rather than mechanical.
private struct WaveformView: View {
    let level: Float
    let reduceMotion: Bool

    private let variance: [CGFloat] = [0.55, 1.0, 0.78, 0.45]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(variance.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: barHeight(variance[index]))
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.09 + Double(index) * 0.015),
                        value: level
                    )
            }
        }
        .frame(height: 16)
    }

    private func barHeight(_ variance: CGFloat) -> CGFloat {
        let base: CGFloat = 4
        let boost = CGFloat(min(max(level * 70, 0), 16))
        return min(base + boost * variance, 16)
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
