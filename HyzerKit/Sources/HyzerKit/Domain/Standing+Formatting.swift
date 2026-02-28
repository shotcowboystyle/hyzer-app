import SwiftUI

extension Standing {
    /// Formats `scoreRelativeToPar` for display: "-2", "E", "+1".
    public var formattedScore: String {
        if scoreRelativeToPar < 0 { return "\(scoreRelativeToPar)" }
        if scoreRelativeToPar == 0 { return "E" }
        return "+\(scoreRelativeToPar)"
    }

    /// Design-token color for `scoreRelativeToPar`: green (under), white (even), amber (over).
    public var scoreColor: Color {
        if scoreRelativeToPar < 0 { return .scoreUnderPar }
        if scoreRelativeToPar == 0 { return .scoreAtPar }
        return .scoreOverPar
    }
}
