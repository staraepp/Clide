import SwiftUI

/// A small piece of status attached to something else: where a model runs,
/// whether a key is saved, whether text stayed on this Mac.
struct ClideBadge: View {
    enum Tone {
        case neutral, accent, positive, caution

        var foreground: Color {
            switch self {
            case .neutral: return .secondary
            case .accent: return ClideTheme.accentDeep
            case .positive: return ClideTheme.positive
            case .caution: return ClideTheme.caution
            }
        }

        var background: Color {
            switch self {
            case .neutral: return Color.primary.opacity(0.06)
            case .accent: return ClideTheme.accentWash
            case .positive: return ClideTheme.positive.opacity(0.13)
            case .caution: return ClideTheme.caution.opacity(0.15)
            }
        }
    }

    let text: String
    var symbol: String?
    var tone: Tone = .neutral

    var body: some View {
        HStack(spacing: 3.5) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            }
            Text(text)
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 6.5)
        .padding(.vertical, 3)
        .background(Capsule().fill(tone.background))
        .accessibilityElement(children: .combine)
    }
}

/// An unfilled capability chip. Deliberately flatter than `ClideBadge` — these
/// describe a model rather than tell you anything about its state.
struct ClideChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6.5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: ClideTheme.Radius.chip, style: .continuous)
                    .strokeBorder(ClideTheme.hairline, lineWidth: 1)
            )
    }
}

/// The small glowing status dot from clide.dev's "v1.0 · MIT licensed" eyebrow —
/// reused here for "ready to dictate", Clide's own version of a live indicator.
/// Breathes gently; goes fully static under Reduce Motion rather than fading.
struct ClideRecDot: View {
    var tint: Color = ClideTheme.positive
    var size: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDim = false

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .shadow(color: tint.opacity(0.7), radius: size)
            .opacity(reduceMotion ? 1 : (isDim ? 0.35 : 1))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    isDim = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// A 1–5 star rating. On hover the filled stars swell in sequence, left to
/// right, which reads as the rating being "counted out" rather than as decoration.
struct StarRow: View {
    let filled: Int
    var tint: Color = ClideTheme.accent
    var size: CGFloat = 9
    /// Driven by whatever contains the row, so the whole rating reacts as one.
    var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= filled ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= filled ? tint : Color.secondary.opacity(0.3))
                    .clideMotion { star in
                        star
                            .scaleEffect(isAnimating && index <= filled ? 1.22 : 1)
                            .animation(
                                ClideTheme.Motion.pop.delay(Double(index) * 0.035),
                                value: isAnimating
                            )
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) out of 5")
    }
}

/// A labelled star row, for the estimated scores that sit beside Hardware Fit.
struct RatingRow: View {
    let label: String
    let stars: Int
    var isAnimating: Bool = false
    var labelWidth: CGFloat = 78

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            StarRow(filled: stars, isAnimating: isAnimating)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(stars) out of 5")
    }
}
