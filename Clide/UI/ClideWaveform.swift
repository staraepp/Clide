import SwiftUI

/// Bars that follow microphone amplitude. Clide's one piece of live, physical
/// feedback — it's how you know the app is actually hearing you — so it's a
/// shared component rather than something the pill owns privately.
///
/// Each bar eases at a slightly different rate and has its own height bias, so
/// the motion reads as a voice rather than a level meter.
struct ClideWaveform: View {
    let level: Float
    var barCount: Int = 5
    var height: CGFloat = 16
    var barWidth: CGFloat = 3
    var tint: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fixed per-bar bias. Deterministic on purpose: random values would make
    /// the waveform jitter on every redraw rather than follow the voice.
    private static let bias: [CGFloat] = [0.5, 0.86, 1.0, 0.72, 0.42]

    var body: some View {
        HStack(spacing: barWidth) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(tint)
                    .frame(width: barWidth, height: barHeight(at: index))
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.085 + Double(index) * 0.014),
                        value: level
                    )
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func barHeight(at index: Int) -> CGFloat {
        let bias = Self.bias[index % Self.bias.count]
        // A floor so the bars stay visible in silence, then amplitude on top.
        // Normal speech lands around 0.05–0.3 RMS, hence the 70x scaling.
        let floor = barWidth
        let boost = CGFloat(min(max(level * 70, 0), 1) ) * (height - floor)
        return min(floor + boost * bias * 1.35, height)
    }
}

#Preview {
    VStack(spacing: 20) {
        ClideWaveform(level: 0, tint: .primary)
        ClideWaveform(level: 0.08, tint: .primary)
        ClideWaveform(level: 0.25, tint: .primary)
        ClideWaveform(level: 0.25, height: 30, barWidth: 5, tint: ClideTheme.accent)
    }
    .padding(40)
}
