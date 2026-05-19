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

// MARK: - VoiceOver-friendly verbose formatter (Story 15.9)

/// VoiceOver-friendly verbose form of a relative-to-par score.
///
/// Visual form: `Standing.formatScore(_:)` returns `"E"` / `"+3"` / `"-1"`.
/// Audio form: `verboseScore(relativeToPar:)` returns `"even par"` /
/// `"three over par"` / `"one under par"`.
///
/// Use for `accessibilityLabel` and any surface read by a screen reader.
/// The compact visual form is unchanged — only the accessibility surface
/// uses the verbose form.
public func verboseScore(relativeToPar: Int) -> String {
    if relativeToPar == 0 { return "even par" }
    let absValue = abs(relativeToPar)
    let direction = relativeToPar > 0 ? "over" : "under"
    // Fall back to digit form for unbounded counts to avoid an English-number
    // ladder. VoiceOver reads "21" as "twenty-one" via the system, which is fine.
    let valueString = absValue <= 20 ? cardinalWord(absValue) : "\(absValue)"
    return "\(valueString) \(direction) par"
}

/// 1...20 cardinal English words. Out-of-range values are an internal error —
/// the caller must filter via the `absValue <= 20` guard in `verboseScore`.
private func cardinalWord(_ n: Int) -> String {
    precondition(n >= 1 && n <= 20, "cardinalWord supports 1...20")
    return ["one", "two", "three", "four", "five",
            "six", "seven", "eight", "nine", "ten",
            "eleven", "twelve", "thirteen", "fourteen", "fifteen",
            "sixteen", "seventeen", "eighteen", "nineteen", "twenty"][n - 1]
}
