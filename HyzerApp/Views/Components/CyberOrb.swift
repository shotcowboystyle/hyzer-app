import SwiftUI
import HyzerKit

/// Decorative empty-state orb: three concentric teal-tinted rings around a
/// glowing gradient core. Slow breathing loop when Motion is allowed; a static
/// frozen frame when Reduce Motion is on (AnimationCoordinator pattern).
struct CyberOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            ring(diameter: 200)
            ring(diameter: 150)
            ring(diameter: 104, innerGlow: true)
            core
        }
        .frame(width: 200, height: 200)
        .scaleEffect(reduceMotion ? 1.0 : (breathing ? 1.05 : 0.96))
        .opacity(reduceMotion ? 1.0 : (breathing ? 1.0 : 0.85))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: AnimationTokens.orbBreathingDuration)
                    .repeatForever(autoreverses: true)
            ) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Rings

    private func ring(diameter: CGFloat, innerGlow: Bool = false) -> some View {
        Circle()
            .stroke(Color.accentPrimary.opacity(0.28), lineWidth: 1)
            .frame(width: diameter, height: diameter)
            .modifier(RingGlow(enabled: innerGlow))
    }

    // MARK: - Core

    private var core: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        // Lime / accent / deep teal — visually unique glow ramp for the orb only.
                        // Non-canonical values, spec'd once in this component; not promoted to tokens.
                        Color(hex: "#6CF079"),
                        Color.accentPrimary,
                        Color(hex: "#1B8F88")
                    ]),
                    center: .center,
                    startRadius: 2,
                    endRadius: 32
                )
            )
            .frame(width: 64, height: 64)
            .shadow(color: Color.accentPrimary.opacity(0.55), radius: 24)
            .shadow(color: Color.accentPrimary.opacity(0.35), radius: 48)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .blur(radius: 0.5)
            )
    }
}

private struct RingGlow: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content
                .shadow(color: Color.accentPrimary.opacity(0.45), radius: 12)
                .overlay(
                    Circle()
                        .stroke(Color.accentPrimary.opacity(0.12), lineWidth: 4)
                        .blur(radius: 6)
                )
        } else {
            content
        }
    }
}

#Preview("CyberOrb") {
    CyberOrb()
        .padding(SpacingTokens.xxl)
        .background(Color.backgroundPrimary)
}
