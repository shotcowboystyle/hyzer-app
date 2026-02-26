import SwiftUI

// MARK: - Hex initializer (internal to HyzerKit)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
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

    // Score states
    static let scoreUnderPar = Color(hex: "#34C759")  // Birdie / under par
    static let scoreOverPar  = Color(hex: "#FF9F0A")  // Bogey / over par
    static let scoreAtPar    = Color(hex: "#F5F5F7")  // Par
    static let scoreWayOver  = Color(hex: "#FF453A")  // Double bogey+

    // Destructive actions only
    static let destructive = Color(hex: "#FF3B30")
}
