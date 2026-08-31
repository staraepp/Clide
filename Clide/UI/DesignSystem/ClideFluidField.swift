import SwiftUI

/// The native port of clide.dev's own WebGL hero shader — see
/// `Clide/UI/Shaders/FluidField.metal` for the actual ported noise/colour
/// math (same simplex domain-warp, same five-stop blend, same light/
/// vignette/grain terms as the site's `FLUID_FRAG`). Runs as a real
/// per-pixel Metal shader via SwiftUI's `.colorEffect`, not an approximation
/// drawn with gradients.
struct ClideFluidField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSinceReferenceDate

                Rectangle()
                    .fill(.black)
                    .colorEffect(
                        ShaderLibrary.default.fluidField(
                            .float(t),
                            .float2(geo.size),
                            .float(Palette.scale),
                            .float2(Palette.offset),
                            .float(Palette.grain),
                            .color(Palette.c1(colorScheme)),
                            .color(Palette.c2(colorScheme)),
                            .color(Palette.c3(colorScheme)),
                            .color(Palette.c4(colorScheme)),
                            .color(Palette.c5(colorScheme)),
                            .color(Palette.glow1),
                            .color(Palette.glow2),
                            .color(Palette.glow3),
                            .float(Palette.glowIntensity),
                            .float2(Palette.lightPos),
                            .float(Palette.lightCore),
                            .float(Palette.lightHalo),
                            .float(Palette.vignette)
                        )
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Values mirror the site's own `FLUID_PARAMS` exactly (offsetX/offsetY
    /// divided by 100 there too). Dark-mode colours are darkened analogues
    /// of the same five stops — the site itself has no dark variant, so
    /// these keep the field harmonising with Clide's dark surfaces rather
    /// than blazing the site's white/pale-blue straight through them.
    private enum Palette {
        static let scale: Double = 1.77
        static let offset = CGSize(width: -1.24, height: -0.48)
        static let grain: Double = 0.006
        static let glowIntensity: Double = 0.22
        static let lightPos = CGSize(width: 0.89, height: 0.46)
        static let lightCore: Double = 0.09
        static let lightHalo: Double = 0.14
        static let vignette: Double = 0.16

        static func c1(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 0.055, green: 0.086, blue: 0.114) : .white
        }
        static func c2(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 0.086, green: 0.157, blue: 0.204) : Color(red: 0.894, green: 0.953, blue: 0.984)
        }
        static func c3(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 0.063, green: 0.235, blue: 0.31) : Color(red: 0.545, green: 0.843, blue: 0.949)
        }
        static func c4(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 0.047, green: 0.31, blue: 0.408) : Color(red: 0.184, green: 0.612, blue: 0.831)
        }
        static func c5(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 0.055, green: 0.086, blue: 0.114) : .white
        }

        static let glow1 = Color.white
        static let glow2 = Color(red: 0.2, green: 0.769, blue: 0.902)   // #33c4e6
        static let glow3 = Color(red: 0.047, green: 0.498, blue: 0.682) // #0c7fae
    }
}

extension View {
    /// The flat canvas colour with the real fluid-field shader layered over
    /// it — for the two screens meant to feel alive to sit in front of
    /// (Dashboard, Onboarding). Denser, text-heavy surfaces stay on plain
    /// `.clideCanvas()`: the same reason clide.dev's own shader lives on its
    /// hero section and nowhere else on the site.
    func clideFluidCanvas() -> some View {
        background {
            ZStack {
                ClideTheme.canvas
                ClideFluidField()
                    .opacity(0.55)
            }
            .ignoresSafeArea()
        }
    }
}
