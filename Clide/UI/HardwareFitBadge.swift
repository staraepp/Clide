import SwiftUI

/// The hardware-fit stars plus the reasoning behind them. The rating is a
/// claim about the user's Mac, so it's always clickable to explain itself
/// rather than sitting there as decoration (clide.md §13).
struct HardwareFitBadge: View {
    let model: TranscriptionModelInfo
    var showsSummary: Bool = true

    @State private var isShowingExplanation = false
    @State private var isHovering = false

    private var fit: HardwareFit { HardwareFit.evaluate(model: model) }

    var body: some View {
        Button {
            isShowingExplanation = true
        } label: {
            HStack(spacing: 5) {
                StarRow(filled: fit.stars, isAnimating: isHovering)
                if showsSummary {
                    Text(fit.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Why this rating?")
        .accessibilityLabel("\(fit.stars) out of 5 stars. \(fit.summary). Click to find out why.")
        .popover(isPresented: $isShowingExplanation, arrowEdge: .bottom) {
            ExplanationView(model: model, fit: fit)
        }
    }
}

private struct ExplanationView: View {
    let model: TranscriptionModelInfo
    let fit: HardwareFit

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                StarRow(filled: fit.stars, size: 11)
                Text(fit.summary)
                    .font(.clideDisplay(13))
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(fit.positives, id: \.self) { reason in
                    ReasonRow(symbol: "checkmark", tint: ClideTheme.positive, text: reason)
                }
                ForEach(fit.cautions, id: \.self) { reason in
                    ReasonRow(symbol: "exclamationmark.triangle", tint: ClideTheme.caution, text: reason)
                }
            }

            Rectangle().fill(ClideTheme.hairline).frame(height: 1)

            Text(model.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(width: 290, alignment: .leading)
    }
}

private struct ReasonRow: View {
    let symbol: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 12)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(ModelCatalog.all) { model in
            HardwareFitBadge(model: model)
        }
    }
    .padding()
}
