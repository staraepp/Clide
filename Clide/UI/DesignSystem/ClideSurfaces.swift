import SwiftUI

/// The card Clide is built from: a light surface, a hairline edge, and just
/// enough shadow to lift it off the canvas. Every panel in the app uses this
/// so nothing has to reinvent a background.
struct ClideCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = ClideTheme.Radius.card
    /// Draws the accent edge — used for the active model, not for hover.
    var isHighlighted: Bool = false
    /// Pointer feedback: the surface warms and the shadow deepens slightly.
    var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isHovering ? ClideTheme.surfaceHover : ClideTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? ClideTheme.accent.opacity(0.55) : ClideTheme.hairline,
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
            .shadow(
                color: .black.opacity(isHovering ? 0.09 : 0.05),
                radius: isHovering ? 9 : 5,
                y: isHovering ? 3 : 1.5
            )
            .clideAnimation(ClideTheme.Motion.hover, value: isHovering)
            .clideAnimation(ClideTheme.Motion.snap, value: isHighlighted)
    }
}

extension View {
    func clideCard(
        padding: CGFloat = 16,
        radius: CGFloat = ClideTheme.Radius.card,
        isHighlighted: Bool = false,
        isHovering: Bool = false
    ) -> some View {
        modifier(
            ClideCardModifier(
                padding: padding,
                radius: radius,
                isHighlighted: isHighlighted,
                isHovering: isHovering
            )
        )
    }

    /// The window ground. Extends under the transparent titlebar.
    func clideCanvas() -> some View {
        background(ClideTheme.canvas.ignoresSafeArea())
    }
}

/// A quiet label that opens a group of related rows.
struct ClideSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.clideSectionLabel)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.6)
            Spacer(minLength: 8)
            trailing
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension ClideSectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// A list of rows sharing one card: dividers inset to the content, no
/// per-row backgrounds. Used for models, history and anything else enumerable.
struct ClideRowGroup<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var dividerInset: CGFloat = 14
    @ViewBuilder var row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(ClideTheme.hairline)
                        .frame(height: 1)
                        .padding(.leading, dividerInset)
                }
                row(item)
            }
        }
        .clideCard(padding: 0)
    }
}
