import SwiftUI

/// A physical-looking Mac keycap. Clide's shortcut is its primary interface,
/// so the keys get rendered as real objects rather than described in prose —
/// reused by the dashboard and, later, the onboarding tutorial.
struct KeycapView: View {
    let label: String
    var isPressed: Bool = false
    var size: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.42, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(keycapBackground)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isPressed ? 0.06 : 0.18), radius: isPressed ? 1 : 2, y: isPressed ? 0.5 : 1.5)
            .scaleEffect(isPressed ? 0.94 : 1)
            .offset(y: isPressed ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.55), value: isPressed)
            .accessibilityLabel(Text(label))
    }

    private var keycapBackground: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(.background.secondary)
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(isPressed ? 0.05 : 0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            )
    }
}

#Preview {
    HStack(spacing: 8) {
        KeycapView(label: "⌥")
        KeycapView(label: ".", isPressed: true)
    }
    .padding(40)
}
