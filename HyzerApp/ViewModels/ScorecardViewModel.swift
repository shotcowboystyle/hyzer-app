import Foundation
import HyzerKit

/// Handles the score entry action for an active round.
///
/// Created in `ScorecardContainerView.onAppear` and owned by the view.
/// Receives `ScoringService` via constructor injection (never `AppServices` container).
@MainActor
@Observable
final class ScorecardViewModel {
    private let scoringService: ScoringService
    let roundID: UUID
    let reportedByPlayerID: UUID

    var saveError: Error?

    init(scoringService: ScoringService, roundID: UUID, reportedByPlayerID: UUID) {
        self.scoringService = scoringService
        self.roundID = roundID
        self.reportedByPlayerID = reportedByPlayerID
    }

    /// Records a score for a player on a specific hole.
    ///
    /// - Parameters:
    ///   - playerID: Player.id.uuidString or "guest:{name}" for guests.
    ///   - holeNumber: 1-based hole number.
    ///   - strokeCount: The score (1-10).
    func enterScore(playerID: String, holeNumber: Int, strokeCount: Int) throws {
        try scoringService.createScoreEvent(
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID
        )
    }
}
