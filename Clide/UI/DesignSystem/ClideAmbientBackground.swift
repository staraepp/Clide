import SwiftUI

/// A soft field of blurred colour, drifting slowly behind Clide's most-seen
/// surfaces. The native answer to clide.dev's canvas-based hero shader —
/// not a copy of it (SwiftUI doesn't have a canvas particle field to borrow),
/// but the same idea: the window should have real depth and quiet motion
/// even when nothing is actively responding to a click.
///
/// Three translucent blobs orbit their resting positions on independent,
/// slow cycles (40–70 seconds) so the drift reads as ambient rather than as
/// an animation loop you can catch repeating. Purely decorative — sits
/// behind every card, ignores hit testing, and freezes under Reduce Motion
/// rather than animating at a token pace.
struct ClideAmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Blob {
        let color: Color
        let radius: CGFloat
        let orbitRadius: CGFloat
        /// Full cycles per second — kept tiny so a cycle takes the better
        /// part of a minute rather than being something you'd ever catch
        /// repeating.
        let speed: Double
        let phase: Double
        let rest: UnitPoint
    }

    private let blobs: [Blob] = [
        Blob(color: ClideTheme.accent, radius: 260, orbitRadius: 46, speed: 0.021, phase: 0, rest: UnitPoint(x: 0.16, y: 0.12)),
        Blob(color: ClideTheme.accentDeep, radius: 230, orbitRadius: 38, speed: 0.016, phase: 2.4, rest: UnitPoint(x: 0.9, y: 0.22)),
        Blob(color: ClideTheme.accent, radius: 240, orbitRadius: 42, speed: 0.013, phase: 4.6, rest: UnitPoint(x: 0.5, y: 0.95)),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for blob in blobs {
                    let angle = t * blob.speed * 2 * .pi + blob.phase
                    let cx = blob.rest.x * size.width + cos(angle) * blob.orbitRadius
                    let cy = blob.rest.y * size.height + sin(angle) * blob.orbitRadius

                    context.fill(
                        Path(ellipseIn: CGRect(x: cx - blob.radius, y: cy - blob.radius, width: blob.radius * 2, height: blob.radius * 2)),
                        with: .radialGradient(
                            Gradient(colors: [blob.color.opacity(0.16), blob.color.opacity(0)]),
                            center: CGPoint(x: cx, y: cy),
                            startRadius: 0,
                            endRadius: blob.radius
                        )
                    )
                }
            }
        }
        .blur(radius: 60)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// The flat canvas colour with the ambient blob field layered over it —
    /// for the screens that are meant to feel alive to sit in front of
    /// (Dashboard, Onboarding). Denser, text-heavy surfaces (Settings, the
    /// model browser, the dev console) stay on plain `.clideCanvas()` —
    /// atmosphere behind a wall of text fights readability rather than
    /// helping it, the same reason clide.dev's own shader lives on its hero
    /// section and nowhere else on the site.
    func clideAmbientCanvas() -> some View {
        background {
            ZStack {
                ClideTheme.canvas
                ClideAmbientBackground()
            }
            .ignoresSafeArea()
        }
    }
}
