import SwiftUI

/// Clide's visual vocabulary in one place: the palette, the spacing rhythm,
/// the corner radii and the named motion curves.
///
/// Colours live in `Assets.xcassets` rather than as literals here, so light and
/// dark both come from one definition and macOS resolves them the way it
/// resolves every other system colour.
enum ClideTheme {
    // MARK: - Colour

    /// Clide's identity colour. Also the app's global accent, so native
    /// controls tint to it without every view having to say so.
    static let accent = Color("AccentColor")
    /// For pressed states and text that needs to stay legible on a wash.
    static let accentDeep = Color("ClideAccentDeep")
    /// A translucent accent fill, for selection and highlight backgrounds.
    static let accentWash = Color("ClideAccentWash")

    /// The ground a window sits on — a touch cooler than the system default,
    /// so surfaces read as raised without needing heavy shadows.
    static let canvas = Color("ClideCanvas")
    static let surface = Color("ClideSurface")
    static let surfaceHover = Color("ClideSurfaceHover")
    static let hairline = Color("ClideHairline")

    /// Reserved for "this stayed on your Mac". Not a generic success colour —
    /// privacy is the thing Clide uses green to mean.
    static let positive = Color("ClidePositive")
    /// Something the user may want to act on. Never used for hard failures.
    static let caution = Color("ClideCaution")

    /// A navy ink instead of pure black, the way clide.dev sets its headline
    /// text — used sparingly, for the couple of places a display headline
    /// wants that identity rather than the system label colour.
    static let ink = Color("ClideInk")

    // MARK: - Shape

    /// Matches the panel/media radii clide.dev actually ships (16 / 10 / 8),
    /// not arbitrary numbers.
    enum Radius {
        static let card: CGFloat = 16
        static let inner: CGFloat = 10
        static let chip: CGFloat = 8
    }

    // MARK: - Motion

    /// One named curve per job, so the whole app accelerates alike.
    enum Motion {
        /// State changes that should feel immediate: hover, selection, toggles.
        static let snap = Animation.spring(response: 0.28, dampingFraction: 0.86)
        /// Layout that grows or moves — cards appearing, sections expanding.
        static let gentle = Animation.spring(response: 0.44, dampingFraction: 0.82)
        /// Moments that deserve a little overshoot: success, arrival, keycaps.
        static let pop = Animation.spring(response: 0.34, dampingFraction: 0.6)
        /// Pointer feedback, where a spring would feel loose.
        static let hover = Animation.easeOut(duration: 0.13)
        /// What every animation degrades to under Reduce Motion: the state
        /// still changes visibly, it just doesn't travel.
        static let reduced = Animation.easeOut(duration: 0.12)
    }
}

// MARK: - Reduce Motion

/// `.animation(_:value:)` that honours Reduce Motion without every call site
/// having to read the environment and write the same ternary.
private struct ClideAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? ClideTheme.Motion.reduced : animation, value: value)
    }
}

extension View {
    /// Animates `value` changes, substituting a plain fade under Reduce Motion.
    func clideAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ClideAnimationModifier(animation: animation, value: value))
    }

    /// Applies a transform only when motion is allowed. Use for the parts of a
    /// design that move — a fade or colour change should still happen, so that
    /// state never becomes invisible to someone with Reduce Motion on.
    @ViewBuilder
    func clideMotion<Result: View>(@ViewBuilder _ transform: @escaping (Self) -> Result) -> some View {
        ReduceMotionGate(content: self, transform: transform)
    }
}

private struct ReduceMotionGate<Content: View, Result: View>: View {
    let content: Content
    let transform: (Content) -> Result

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content
        } else {
            transform(content)
        }
    }
}

// MARK: - Typography

extension Font {
    /// Numbers and titles use the rounded face: it's the friendlier half of
    /// Clide's voice, and it keeps figures from looking like a spreadsheet.
    /// Weight defaults to medium rather than semibold — clide.dev sets its
    /// own display headlines at 500, not bold, for a quieter kind of emphasis.
    static func clideDisplay(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let clideTitle = Font.clideDisplay(20)
    static let clideHeadline = Font.clideDisplay(15, weight: .semibold)
    /// The small uppercase mono label clide.dev uses for its eyebrow tags
    /// ("clide v1.0 · MIT licensed"). Section headers borrow that same voice.
    static let clideSectionLabel = Font.system(size: 10.5, weight: .medium, design: .monospaced)
}
