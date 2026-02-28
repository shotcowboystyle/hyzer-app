import Foundation
import HyzerKit
import os.log

/// Handles the score entry and correction actions for an active round.
///
/// Created in `ScorecardContainerView.onAppear` and owned by the view.
/// Receives `ScoringService` and `RoundLifecycleManager` via constructor injection
/// (never `AppServices` container).
@MainActor
@Observable
final class ScorecardViewModel {
    private let scoringService: ScoringService
    private let lifecycleManager: RoundLifecycleManager
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "ScorecardViewModel")

    let roundID: UUID
    let reportedByPlayerID: UUID

    var saveError: Error?
    /// True when all (player, hole) pairs are scored — prompts the finalization confirmation.
    /// Reset to `false` when the user dismisses the prompt (so the alert can be re-triggered later
    /// without creating an infinite presentation loop).
    var isAwaitingFinalization: Bool = false
    /// Set to `true` after `finalizeRound` or `finishRound` completes successfully.
    private(set) var isRoundCompleted: Bool = false

    init(
        scoringService: ScoringService,
        lifecycleManager: RoundLifecycleManager,
        roundID: UUID,
        reportedByPlayerID: UUID
    ) {
        self.scoringService = scoringService
        self.lifecycleManager = lifecycleManager
        self.roundID = roundID
        self.reportedByPlayerID = reportedByPlayerID
    }

    /// Records a score for a player on a specific hole.
    ///
    /// - Parameters:
    ///   - playerID: Player.id.uuidString or "guest:{name}" for guests.
    ///   - holeNumber: 1-based hole number.
    ///   - strokeCount: The score (1-10).
    func enterScore(playerID: String, holeNumber: Int, strokeCount: Int, isRoundFinished: Bool) throws {
        guard !isRoundFinished else { return }
        try scoringService.createScoreEvent(
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID
        )
        checkCompletionIfActive()
    }

    /// Corrects a previously entered score by creating a superseding ScoreEvent.
    ///
    /// The original event is never mutated or deleted (NFR19).
    ///
    /// - Parameters:
    ///   - previousEventID: The UUID of the event being corrected.
    ///   - playerID: Player.id.uuidString or "guest:{name}" for guests.
    ///   - holeNumber: 1-based hole number.
    ///   - strokeCount: The corrected score (1-10).
    func correctScore(previousEventID: UUID, playerID: String, holeNumber: Int, strokeCount: Int, isRoundFinished: Bool) throws {
        guard !isRoundFinished else { return }
        try scoringService.correctScore(
            previousEventID: previousEventID,
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID
        )
        checkCompletionIfActive()
    }

    // MARK: - Lifecycle actions (delegated from the View)

    /// Attempts to finish the round. Returns `.hasMissingScores` if a warning is needed.
    func finishRound(force: Bool) throws -> FinishRoundResult {
        let result = try lifecycleManager.finishRound(roundID: roundID, force: force)
        if case .completed = result {
            isRoundCompleted = true
        }
        return result
    }

    /// Confirms the finalization prompt — transitions awaitingFinalization → completed.
    func finalizeRound() throws {
        try lifecycleManager.finalizeRound(roundID: roundID)
        isRoundCompleted = true
    }

    /// Dismisses the finalization prompt so the user can keep scoring.
    func dismissFinalizationPrompt() {
        isAwaitingFinalization = false
    }

    // MARK: - Private

    /// Checks round completion after each score; sets `isAwaitingFinalization` if all holes are scored.
    ///
    /// Only runs if `isAwaitingFinalization` is not already set (avoids redundant checks after
    /// the round has transitioned state). Completion check errors are logged and ignored —
    /// the scoring flow is non-critical relative to completion detection.
    private func checkCompletionIfActive() {
        guard !isAwaitingFinalization else { return }
        do {
            let result = try lifecycleManager.checkCompletion(roundID: roundID)
            if case .nowAwaitingFinalization = result {
                isAwaitingFinalization = true
            }
        } catch {
            // Safe to continue: completion check is advisory; scoring flow is unaffected
            logger.error("RoundLifecycleManager.checkCompletion failed: \(error)")
        }
    }
}
