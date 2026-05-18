import SwiftUI
import HyzerKit

/// Deterministic generative visual rendered on the round summary card.
///
/// **Pure rendering.** No `@State`, no `@StateObject`, no `Task { }`, no IO.
/// The view body is a function of `input` and `reduceMotion` only — pixel-identical
/// output is guaranteed for identical inputs (AC #1).
///
/// **Design constraints (UX-PMVP-DR6):**
/// - Only colors from `ColorTokens` are drawn.
/// - Only geometric primitives are used: `Circle`, `Rectangle`, `RoundedRectangle`,
///   `Path` with arc/line segments, and the three `Gradient` types.
/// - No `Image(systemName:)`, no `Text`, no emoji, no illustrations.
/// - Fixed 120pt height inside the summary card layout.
struct RoundSignature: View, Equatable {
    let input: RoundSignatureInput

    // `reduceMotion` is read-only environment; no animation in v1, so this is unused.
    // Retained so the Reduce Motion gate (AC #4) is wired up if Task 5 is revisited.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hash = RoundSignatureHasher.hash(input)
        let params = RenderParams(hash: hash)

        ZStack {
            RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard)
                .fill(Color.backgroundElevated)

            concentricRings(params: params)

            flourish(params: params)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .accessibilityElement()
        .accessibilityLabel("Round signature")
    }

    // MARK: - Subviews

    @ViewBuilder
    private func concentricRings(params: RenderParams) -> some View {
        GeometryReader { geo in
            // `max(0, …)` floor guards against degenerate proposed sizes during layout
            // transitions (e.g., GeometryReader briefly proposing 0×0). Without it, a
            // negative radius would trigger SwiftUI's "Invalid frame dimension" runtime warning.
            let maxRadius = max(0, min(geo.size.width, geo.size.height) / 2 - SpacingTokens.sm)
            let minRadius = maxRadius * params.innerOuterRatio
            let step = (maxRadius - minRadius) / Double(params.ringCount - 1)
            ZStack {
                ForEach(0..<params.ringCount, id: \.self) { i in
                    let radius = minRadius + step * Double(i)
                    Circle()
                        .stroke(ringColor(params: params, index: i), lineWidth: 1.5)
                        .frame(width: radius * 2, height: radius * 2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func ringColor(params: RenderParams, index: Int) -> Color {
        switch index % 3 {
        case 0:  return params.primaryColor
        case 1:  return params.secondaryColor
        default: return params.accentColor
        }
    }

    @ViewBuilder
    private func flourish(params: RenderParams) -> some View {
        // `params.gradientDirection` shifts the flourish disc off-center along one of 8
        // compass directions, mapping hash byte [7] into a visible parameter (AC #8b).
        AngularGradient(
            gradient: Gradient(colors: [
                params.primaryColor.opacity(0.6),
                params.accentColor.opacity(0.0),
                params.secondaryColor.opacity(0.6)
            ]),
            center: params.gradientDirection.startPoint,
            startAngle: .degrees(params.rotationDegrees),
            endAngle: .degrees(params.rotationDegrees + 360)
        )
        .mask(
            Circle()
                .frame(width: 60, height: 60)
        )
    }

    // Equatable conformance: SwiftUI skips body re-eval when `input` is unchanged (AC #8c).
    // `nonisolated` is required by Swift 6 strict concurrency — `input` is a `let` Sendable
    // constant so comparing it off the main actor is data-race-free.
    nonisolated static func == (lhs: RoundSignature, rhs: RoundSignature) -> Bool {
        lhs.input == rhs.input
    }
}

// MARK: - RenderParams

private struct RenderParams {
    // Byte index assignments are documented inline — do NOT change without a versioned migration plan.
    let primaryColor: Color         // hash[0] indexes the palette; secondary/accent draw from the remaining palette
    let secondaryColor: Color       // hash[1] indexes the palette minus primaryColor
    let accentColor: Color          // hash[2] indexes the palette minus primary + secondary
    let rotationDegrees: Double     // (hash[3]*256 + hash[4]) / 65536 * 360  →  0..<360
    let ringCount: Int              // 3 + hash[5] % 5  →  3...7
    let innerOuterRatio: Double     // 0.3 + (hash[6] / 255.0) * 0.4  →  0.3...0.7
    let gradientDirection: GradientDirection  // hash[7] & 0x07  →  one of 8 compass directions

    init(hash: Data) {
        // 8-color palette drawn exclusively from ColorTokens (AC #3, UX-PMVP-DR6).
        let palette: [Color] = [
            .scoreUnderPar, .scoreAtPar, .scoreOverPar, .scoreWayOver,
            .accentPrimary, .textPrimary, .textSecondary, .backgroundTertiary
        ]
        // Pick three DISTINCT colors by removing each chosen color from the remaining palette.
        // Independent indexing would produce a ~34% per-round collision rate across the three
        // slots, weakening visual distinctness (AC #2). The remove-then-index approach guarantees
        // primary, secondary, and accent are always three different palette entries.
        var remaining = palette
        let primaryIdx = Int(hash[0]) % remaining.count
        primaryColor = remaining.remove(at: primaryIdx)
        let secondaryIdx = Int(hash[1]) % remaining.count
        secondaryColor = remaining.remove(at: secondaryIdx)
        let accentIdx = Int(hash[2]) % remaining.count
        accentColor = remaining.remove(at: accentIdx)
        rotationDegrees   = (Double(hash[3]) * 256 + Double(hash[4])) / 65536 * 360
        ringCount         = 3 + Int(hash[5] % 5)
        innerOuterRatio   = 0.3 + (Double(hash[6]) / 255.0) * 0.4
        gradientDirection = GradientDirection.allCases[Int(hash[7] & 0x07)]
    }
}

// MARK: - GradientDirection

private enum GradientDirection: CaseIterable {
    case top, topTrailing, trailing, bottomTrailing,
         bottom, bottomLeading, leading, topLeading

    var startPoint: UnitPoint {
        switch self {
        case .top:           return .top
        case .topTrailing:   return .topTrailing
        case .trailing:      return .trailing
        case .bottomTrailing: return .bottomTrailing
        case .bottom:        return .bottom
        case .bottomLeading: return .bottomLeading
        case .leading:       return .leading
        case .topLeading:    return .topLeading
        }
    }
}
