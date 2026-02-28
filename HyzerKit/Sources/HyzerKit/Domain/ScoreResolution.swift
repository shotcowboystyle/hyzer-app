import Foundation

/// Returns the current (leaf node) ScoreEvent for a player on a specific hole.
///
/// The current score is the ScoreEvent not superseded by any other event in the set
/// (Amendment A7 leaf-node resolution). Works for chains of any length.
///
/// Used by `HoleCardView` (display), `ScorecardContainerView` (auto-advance detection),
/// and `StandingsEngine` (standings computation).
public func resolveCurrentScore(for playerID: String, hole: Int, in events: [ScoreEvent]) -> ScoreEvent? {
    let holeEvents = events.filter { $0.playerID == playerID && $0.holeNumber == hole }
    let supersededIDs = Set(holeEvents.compactMap(\.supersedesEventID))
    return holeEvents.first { !supersededIDs.contains($0.id) }
}
