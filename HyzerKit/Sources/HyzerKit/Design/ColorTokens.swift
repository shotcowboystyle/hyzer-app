import SwiftUI

// MARK: - Hex initializer

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        let success = Scanner(string: hex).scanHexInt64(&int)
        precondition(success && hex.count == 6, "Invalid hex color: #\(hex)")
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Design token colors
//
// This is a dark-first app. Light mode is deferred.
// All tokens are defined against #0A0A0C background and satisfy 4.5:1 contrast ratio.

public extension Color {
    // Backgrounds
    static let backgroundPrimary  = Color(hex: "#0A0A0C")
    static let backgroundElevated = Color(hex: "#1C1C1E")
    static let backgroundTertiary = Color(hex: "#2C2C2E")

    // Text
    static let textPrimary   = Color(hex: "#F5F5F7")
    static let textSecondary = Color(hex: "#8E8E93")

    // Accent
    static let accentPrimary = Color(hex: "#30D5C8")
    static let accentInk     = Color(hex: "#0A0A0C")  // Text/icon over teal fills

    // Score states
    static let scoreUnderPar = Color(hex: "#34C759")  // Birdie / under par
    static let scoreOverPar  = Color(hex: "#FF9F0A")  // Bogey / over par
    static let scoreAtPar    = Color(hex: "#F5F5F7")  // Par
    static let scoreWayOver  = Color(hex: "#FF453A")  // Double bogey+

    // Warning state (sync errors, non-destructive alerts)
    static let warning = Color(hex: "#FF9F0A")

    // Destructive actions only
    static let destructive = Color(hex: "#FF3B30")

    // Hairlines / Overlays
    static let hairline      = Color(.sRGB, red: 0.961, green: 0.961, blue: 0.969, opacity: 0.08)
    /// Divider/border token — alias of `hairline`. Provided for semantic clarity at call sites where the intent is "border" rather than "hairline divider".
    static let border        = Color.hairline  // Divider token — same as hairline
    static let rowBackground = Color(.sRGB, red: 0.039, green: 0.039, blue: 0.047, opacity: 0.50)
    static let pillGlass     = Color(.sRGB, red: 0.110, green: 0.110, blue: 0.118, opacity: 0.50)

    /// 4-tier score colour based on strokes relative to par.
    ///
    /// | Condition        | Color          |
    /// |------------------|----------------|
    /// | strokes < par    | scoreUnderPar  |
    /// | strokes == par   | scoreAtPar     |
    /// | strokes == par+1 | scoreOverPar   |
    /// | strokes >= par+2 | scoreWayOver   |
    static func scoreColor(strokes: Int, par: Int) -> Color {
        let delta = strokes - par
        if delta < 0 { return .scoreUnderPar }
        if delta == 0 { return .scoreAtPar }
        if delta == 1 { return .scoreOverPar }
        return .scoreWayOver
    }
}

// MARK: - Gradient tokens
//
// Two brand gradients introduced in the design pass. Returned as `LinearGradient` values
// (not `Color`) because every consumer applies them as fills/backgrounds.

public extension LinearGradient {
    /// "Tropic Tide" — primary CTA gradient (135°, teal → mint → lime).
    static let hyzerPrimary = LinearGradient(
        stops: [
            .init(color: Color(hex: "#30D5C8"), location: 0.00),
            .init(color: Color(hex: "#2BE8B5"), location: 0.50),
            .init(color: Color(hex: "#6CF079"), location: 1.00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// "Halo Cyan" — alternate CTA gradient (135°, cyan → blue).
    static let hyzerHalo = LinearGradient(
        stops: [
            .init(color: Color(hex: "#2DE3E1"), location: 0.00),
            .init(color: Color(hex: "#2C9BFF"), location: 1.00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Sheet background ramp — near-black at the top lifting to the canvas at the bottom.
    /// Gives sheets a slight depth against the phone canvas without introducing color noise.
    static let hyzerSheet = LinearGradient(
        stops: [
            .init(color: Color(hex: "#1C1C20"), location: 0.00),
            .init(color: Color(hex: "#121215"), location: 0.30),
            .init(color: Color.backgroundPrimary, location: 0.80)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Footer scrim — transparent-to-canvas fade behind CTA buttons pinned to `safeAreaInset(.bottom)`.
    /// Ensures the button is legible when list content scrolls under it.
    static let hyzerFooterScrim = LinearGradient(
        colors: [Color.clear, Color.backgroundPrimary.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
    )
}
