import SwiftUI

/// Clide's buttons. Native `.bordered` styles are fine in a Form; these exist
/// for the surfaces Clide draws itself, where a button needs to answer the
/// pointer — lifting on hover, sinking on press.
struct ClideButtonStyle: ButtonStyle {
    enum Kind {
        /// The one action a surface wants you to take.
        case primary
        /// Everything else that's still a real action.
        case secondary
        /// Reads as text until you point at it. For destructive or rare actions.
        case quiet
    }

    var kind: Kind = .secondary
    var isFullWidth = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ClideButtonBody(
            configuration: configuration,
            kind: kind,
            isFullWidth: isFullWidth,
            isEnabled: isEnabled
        )
    }
}

private struct ClideButtonBody: View {
    let configuration: ClideButtonStyle.Configuration
    let kind: ClideButtonStyle.Kind
    let isFullWidth: Bool
    let isEnabled: Bool

    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .quiet ? 8 : 12)
            .padding(.vertical, 6)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(background)
            .contentShape(RoundedRectangle(cornerRadius: ClideTheme.Radius.inner, style: .continuous))
            .clideMotion { label in
                label.scaleEffect(configuration.isPressed ? 0.97 : 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .clideAnimation(ClideTheme.Motion.hover, value: isHovering)
            .clideAnimation(ClideTheme.Motion.snap, value: configuration.isPressed)
            .onHover { isHovering = isEnabled && $0 }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return .primary
        case .quiet: return isHovering ? .primary : .secondary
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: ClideTheme.Radius.inner, style: .continuous)
        switch kind {
        case .primary:
            shape
                .fill(configuration.isPressed ? ClideTheme.accentDeep : ClideTheme.accent)
                .shadow(color: ClideTheme.accent.opacity(isHovering ? 0.35 : 0.2), radius: 5, y: 2)
        case .secondary:
            shape
                .fill(isHovering ? ClideTheme.surfaceHover : ClideTheme.surface)
                .overlay(shape.strokeBorder(ClideTheme.hairline, lineWidth: 1))
        case .quiet:
            shape.fill(isHovering ? Color.primary.opacity(0.06) : .clear)
        }
    }
}

extension ButtonStyle where Self == ClideButtonStyle {
    static var clidePrimary: ClideButtonStyle { ClideButtonStyle(kind: .primary) }
    static var clideSecondary: ClideButtonStyle { ClideButtonStyle(kind: .secondary) }
    static var clideQuiet: ClideButtonStyle { ClideButtonStyle(kind: .quiet) }
}

/// Press feedback for a button that draws its own entire appearance — a list
/// row, a filter pill, a card — where `.buttonStyle(.plain)` was leaving taps
/// completely silent. Touches nothing about how the label looks; it only adds
/// the compress-and-release every tappable thing in the app was missing.
/// Apple Music is the reference point: everything answers a tap immediately,
/// even things that already respond to hover.
struct ClideRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .clideMotion { label in
                label.scaleEffect(configuration.isPressed ? 0.97 : 1)
            }
            .clideAnimation(ClideTheme.Motion.snap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ClideRowButtonStyle {
    static var clideRow: ClideRowButtonStyle { ClideRowButtonStyle() }
}

/// A borderless icon button — the toolbar vocabulary Clide uses for copy,
/// delete and settings. Grows a soft backing plate when pointed at, so it
/// stops being invisible the moment it becomes clickable.
struct ClideIconButton: View {
    let symbol: String
    let help: String
    var tint: Color?
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? (isHovering ? .primary : .secondary))
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(isHovering ? Color.primary.opacity(0.08) : .clear)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.clideRow)
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovering = $0 }
        .clideAnimation(ClideTheme.Motion.hover, value: isHovering)
    }
}
