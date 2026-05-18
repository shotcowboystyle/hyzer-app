import SwiftUI

extension Standing {
    /// Formats `scoreRelativeToPar` for display: "-2", "E", "+1".
    public var formattedScore: String {
        Standing.formatScore(scoreRelativeToPar)
    }

    /// Static formatter — same convention as `formattedScore`. Use when a `Standing` instance
    /// is not available (e.g., `PlayerTrendViewModel` formatting `TrendSummary` statistics).
    public static func formatScore(_ score: Int) -> String {
        if score < 0 { return "\(score)" }
        if score == 0 { return "E" }
        return "+\(score)"
    }

    /// Design-token color for `scoreRelativeToPar`: green (under), white (even), amber (over).
    public var scoreColor: Color {
        if scoreRelativeToPar < 0 { return .scoreUnderPar }
        if scoreRelativeToPar == 0 { return .scoreAtPar }
        return .scoreOverPar
    }
}
