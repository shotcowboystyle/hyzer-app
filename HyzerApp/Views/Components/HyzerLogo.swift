import SwiftUI
import HyzerKit

/// Onboarding logo lockup: disc ring + dashed flight arc + landing dot,
/// stacked above the "Hyzer" wordmark.
///
/// Rendered as native `Shape`/`Path` geometry — no bitmap assets. The mark
/// scales proportionally to `size`; the wordmark tracks the design-token
/// typography scale.
struct HyzerLogo: View {
    /// Overall diameter of the disc ring in points.
    let size: CGFloat

    init(size: CGFloat = 84) {
        self.size = size
    }

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            mark
                .frame(width: size, height: size)
            wordmark
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hyzer")
    }

    // MARK: - Mark (disc + arc + dot)

    private var mark: some View {
        ZStack {
            DiscRing()
                .stroke(LinearGradient.hyzerPrimary, lineWidth: max(2, size * 0.045))

            FlightArc()
                .stroke(
                    LinearGradient.hyzerPrimary,
                    style: StrokeStyle(
                        lineWidth: max(1.5, size * 0.035),
                        lineCap: .round,
                        dash: [size * 0.055, size * 0.05]
                    )
                )

            LandingDot()
                .fill(LinearGradient.hyzerPrimary)
                .frame(width: size * 0.11, height: size * 0.11)
                .offset(x: size * 0.36, y: -size * 0.33)
        }
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        Text("Hyzer")
            .font(.system(size: TypographyTokens.wordmarkBaseSize, weight: .heavy, design: .rounded))
            .tracking(TypographyTokens.wordmarkTracking)
            .foregroundStyle(Color.textPrimary)
    }
}

// MARK: - Shapes

private struct DiscRing: Shape {
    func path(in rect: CGRect) -> Path {
        // Slight vertical squash reads as a disc tilted toward the viewer.
        let insetY = rect.height * 0.12
        let ellipse = CGRect(
            x: rect.minX,
            y: rect.minY + insetY,
            width: rect.width,
            height: rect.height - insetY * 2
        )
        return Path(ellipseIn: ellipse)
    }
}

private struct FlightArc: Shape {
    func path(in rect: CGRect) -> Path {
        // Arcs from the left edge of the disc up-and-right to the landing dot,
        // giving the "hyzer" (S-curve) flight signature.
        var path = Path()
        let start = CGPoint(x: rect.minX + rect.width * 0.10, y: rect.midY + rect.height * 0.05)
        let end   = CGPoint(x: rect.midX + rect.width * 0.36, y: rect.midY - rect.height * 0.33)
        let control1 = CGPoint(x: rect.midX - rect.width * 0.10, y: rect.minY - rect.height * 0.10)
        let control2 = CGPoint(x: rect.midX + rect.width * 0.20, y: rect.minY - rect.height * 0.05)
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }
}

private struct LandingDot: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }
}

#Preview("HyzerLogo") {
    HyzerLogo()
        .padding(SpacingTokens.xl)
        .background(Color.backgroundPrimary)
}
