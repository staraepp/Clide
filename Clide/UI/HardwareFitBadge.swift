import SwiftUI

/// The hardware-fit stars plus the reasoning behind them. The rating is a
/// claim about the user's Mac, so it's always clickable to explain itself
/// rather than sitting there as decoration (clide.md §13).
struct HardwareFitBadge: View {
    let model: TranscriptionModelInfo
    var showsSummary: Bool = true

    @State private var isShowingExplanation = false

    private var fit: HardwareFit { HardwareFit.evaluate(model: model) }

    var body: some View {
        Button {
            isShowingExplanation = true
        } label: {
            HStack(spacing: 5) {
                StarRow(filled: fit.stars)
                if showsSummary {
                    Text(fit.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Why this rating?")
        .accessibilityLabel("\(fit.stars) out of 5 stars. \(fit.summary). Click to find out why.")
        .popover(isPresented: $isShowingExplanation, arrowEdge: .bottom) {
            ExplanationView(model: model, fit: fit)
        }
    }
}

private struct StarRow: View {
    let filled: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= filled ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(index <= filled ? Color.accentColor : Color.secondary.opacity(0.4))
            }
        }
    }
}

private struct ExplanationView: View {
    let model: TranscriptionModelInfo
    let fit: HardwareFit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why this rating?")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(fit.positives, id: \.self) { reason in
                    ReasonRow(symbol: "checkmark", tint: .green, text: reason)
                }
                ForEach(fit.cautions, id: \.self) { reason in
                    ReasonRow(symbol: "exclamationmark.triangle", tint: .orange, text: reason)
                }
            }

            Divider()

            Text(model.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
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
