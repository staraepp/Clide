import SwiftUI

/// Live amplitude feed for the waveform, separate from `PillState` so a
/// stream of amplitude ticks doesn't have to reconstruct/resize the pill —
/// only real state transitions (idle → listening → transcribing → …) do that.
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
        HStack(spacing: 8) {
            if state == .listening {
                WaveformView(level: amplitude.level, reduceMotion: reduceMotion)
                    .frame(width: 28, height: 16)
            } else {
                Image(systemName: state.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                    .symbolEffect(.bounce, value: state)
            }

            if !state.message.isEmpty {
                Text(state.message)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            if state == .awaitingChoice, let choiceActions {
                PillButton(title: "Remove fillers", action: choiceActions.removeFillers)
                PillButton(title: "Insert", action: choiceActions.insertAsIs, isProminent: true)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.black.opacity(0.85)))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: state)
    }
}

private struct PillButton: View {
    let title: String
    let action: () -> Void
    var isProminent: Bool = false

    @State private var isHovering = false

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
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// A handful of bars that react to microphone amplitude. Deliberately simple —
/// this is functional feedback, not the full "dopamine" animation pass from
/// clide.md §30, which is a later polish milestone.
private struct WaveformView: View {
    let level: Float
    let reduceMotion: Bool

    private let barHeightVariance: [CGFloat] = [0.6, 1.0, 0.8, 0.5]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(barHeightVariance.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: barHeight(variance: barHeightVariance[index]))
            }
        }
        .frame(height: 16)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: level)
    }

    private func barHeight(variance: CGFloat) -> CGFloat {
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
        DictationPillView(state: .transcribing, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .inserted, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .copiedToClipboard, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .secureFieldBlocked, amplitude: WaveformAmplitudeModel())
        DictationPillView(state: .error("Model unavailable"), amplitude: WaveformAmplitudeModel())
    }
    .padding()
}
