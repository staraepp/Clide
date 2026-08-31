import SwiftUI

/// A physical-looking Mac keycap. Clide's shortcut is its primary interface,
/// so the keys get rendered as real objects rather than described in prose —
/// reused by the dashboard and the onboarding tutorial.
struct KeycapView: View {
    let label: String
    var isPressed: Bool = false
    var size: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.42, weight: .medium, design: .rounded))
            .foregroundStyle(isPressed ? ClideTheme.accentDeep : .primary)
            .frame(width: size, height: size)
            .background(keycapBackground)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(isPressed ? ClideTheme.accent.opacity(0.5) : .primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isPressed ? 0.05 : 0.16), radius: isPressed ? 1 : 3, y: isPressed ? 0.5 : 2)
            .clideMotion { keycap in
                keycap
                    .scaleEffect(isPressed ? 0.93 : 1)
                    .offset(y: isPressed ? 1 : 0)
            }
            .clideAnimation(ClideTheme.Motion.pop, value: isPressed)
            .accessibilityLabel(Text(label))
    }

    private var keycapBackground: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(isPressed ? ClideTheme.accentWash : ClideTheme.surface)
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(isPressed ? 0.04 : 0.22), .clear],
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
