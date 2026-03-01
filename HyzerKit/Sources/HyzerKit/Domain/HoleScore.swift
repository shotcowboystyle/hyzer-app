import SwiftUI

/// Per-hole score for one player in a completed round.
///
/// Produced by `PlayerHoleBreakdownViewModel` from resolved `ScoreEvent` leaf nodes.
/// Immutable value type — never persisted; always derived from `ScoreEvent` data.
public struct HoleScore: Identifiable, Sendable, Equatable {
    public let holeNumber: Int
    public let par: Int
    public let strokeCount: Int
    /// `strokeCount` minus `par`. Negative = under par.
    public let relativeToPar: Int

    public var id: Int { holeNumber }

    public init(holeNumber: Int, par: Int, strokeCount: Int) {
        self.holeNumber = holeNumber
        self.par = par
        self.strokeCount = strokeCount
        self.relativeToPar = strokeCount - par
    }
}

// MARK: - Formatting

extension HoleScore {
    /// Displays `relativeToPar` as "-1", "E", "+1", "+2", etc.
    public var formattedRelativeToPar: String {
        if relativeToPar < 0 { return "\(relativeToPar)" }
        if relativeToPar == 0 { return "E" }
        return "+\(relativeToPar)"
    }

    /// 4-tier score color per the UX spec (matches `HoleCardView` color coding).
    ///
    /// | Condition          | Color            |
    /// |--------------------|------------------|
    /// | strokes < par      | `scoreUnderPar`  |
    /// | strokes == par     | `scoreAtPar`     |
    /// | strokes == par + 1 | `scoreOverPar`   |
    /// | strokes >= par + 2 | `scoreWayOver`   |
    public var scoreColor: Color {
        if relativeToPar < 0 { return .scoreUnderPar }
        if relativeToPar == 0 { return .scoreAtPar }
        if relativeToPar == 1 { return .scoreOverPar }
        return .scoreWayOver
    }
}
