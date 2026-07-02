import SwiftUI

/// Cyber ambient canvas for the iPhone surface.
///
/// Layers, bottom → top:
/// 1. Vertical linear ramp (near-black at top, lit charcoal at the bottom).
/// 2. Teal brand-light radial from the bottom-center.
/// 3. Indigo counter-glow from the top-right.
/// 4. Warm ember from the bottom-left.
/// 5. Film-grain overlay to break up the gradient banding.
///
/// The grain layer is a deterministic, non-animated `Canvas` — no time-based state,
/// so Reduce Motion has nothing to disable. Applied as the root background of the
/// iPhone app only; the Watch keeps its plain dark background.
public struct HyzerBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            baseRamp
            tealBrandLight
            indigoCounterGlow
            warmEmber
            grain
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var baseRamp: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#050507"), location: 0.00),
                .init(color: Color(hex: "#08080B"), location: 0.22),
                .init(color: Color(hex: "#131318"), location: 0.62),
                .init(color: Color(hex: "#1D1D22"), location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var tealBrandLight: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(hex: "#30D5C8").opacity(0.22),
                Color(hex: "#30D5C8").opacity(0.00)
            ]),
            center: .init(x: 0.5, y: 1.05),
            startRadius: 0,
            endRadius: 520
        )
        .blendMode(.screen)
    }

    private var indigoCounterGlow: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(.sRGB, red: 74/255,  green: 108/255, blue: 255/255, opacity: 0.14),
                Color(.sRGB, red: 74/255,  green: 108/255, blue: 255/255, opacity: 0.00)
            ]),
            center: .init(x: 0.95, y: -0.05),
            startRadius: 0,
            endRadius: 460
        )
        .blendMode(.screen)
    }

    private var warmEmber: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(.sRGB, red: 255/255, green: 159/255, blue: 80/255,  opacity: 0.07),
                Color(.sRGB, red: 255/255, green: 159/255, blue: 80/255,  opacity: 0.00)
            ]),
            center: .init(x: 0.05, y: 1.05),
            startRadius: 0,
            endRadius: 380
        )
        .blendMode(.screen)
    }

    private var grain: some View {
        Canvas { context, size in
            // Deterministic seeded noise — same pixels every render, no animation.
            var rng = SplitMix64(seed: 0x487D_BE71_F1C4_29A5)
            let dotCount = Int(size.width * size.height / 42)
            let dotColor = Color.white.opacity(0.05)
            for _ in 0..<dotCount {
                let x = Double(rng.next() % 10_000) / 10_000 * size.width
                let y = Double(rng.next() % 10_000) / 10_000 * size.height
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect), with: .color(dotColor))
            }
        }
        .blendMode(.overlay)
        .opacity(0.5)
        .allowsHitTesting(false)
    }
}

/// Non-cryptographic 64-bit PRNG. Deterministic given a seed — used only to place
/// static grain dots. `Foundation.Data`-free so it works in every Swift target.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

#Preview("HyzerBackground") {
    HyzerBackground()
}
