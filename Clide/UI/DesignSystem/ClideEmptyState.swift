import SwiftUI

/// What a surface shows when it has nothing to show. An empty screen is a
/// place to say what to do next, so this always takes a line of guidance and
/// usually an action.
struct ClideEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    /// A caution-toned variant for "this is switched off", which is a choice
    /// the user made rather than something missing.
    var tone: ClideBadge.Tone = .accent

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(tone.foreground)
                .frame(width: 42, height: 42)
                .background(Circle().fill(tone.background))

            Text(title)
                .font(.clideDisplay(14, weight: .medium))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.clideSecondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VStack(spacing: 16) {
        ClideEmptyState(
            symbol: "waveform",
            title: "Nothing yet today",
            message: "Press ⌥ . in any text field and start talking.",
            actionTitle: "Show me how",
            action: {}
        )
        .clideCard()

        ClideEmptyState(
            symbol: "eye.slash",
            title: "Statistics are off",
            message: "Clide isn't counting anything. You can turn counters back on in Settings.",
            actionTitle: "Open Settings",
            action: {},
            tone: .neutral
        )
        .clideCard()
    }
    .padding(20)
    .frame(width: 460)
    .clideCanvas()
}
