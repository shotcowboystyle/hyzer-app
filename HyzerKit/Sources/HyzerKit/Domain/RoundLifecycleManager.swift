import Foundation
import SwiftData

// MARK: - Result types

/// Result of `RoundLifecycleManager.checkCompletion(roundID:)`.
public enum CompletionCheckResult: Sendable {
    /// Not all (player, hole) pairs have a resolved score. `missing` is the count of gaps.
    case incomplete(missing: Int)
    /// All scores are in; round has been transitioned to `awaitingFinalization`.
    case nowAwaitingFinalization
}

/// Result of `RoundLifecycleManager.finishRound(roundID:force:)`.
public enum FinishRoundResult: Sendable {
    /// `force == false` and some holes are unscored. `count` is the number of gaps.
    case hasMissingScores(count: Int)
    /// Round has been transitioned to `completed`.
    case completed
}

/// Error type for `RoundLifecycleManager` operations.
public enum RoundLifecycleError: Error, Sendable, Equatable {
    /// A player-list mutation was attempted on a round that is no longer in "setup".
    case playerMutationForbidden(String)
    /// The specified round could not be found in the store.
    case roundNotFound(UUID)
    /// A lifecycle operation was attempted on a round in an invalid state.
    case invalidStateForTransition(current: String, expected: String)
}

// MARK: - RoundLifecycleManager

/// Enforces round lifecycle state transitions and player list immutability.
///
/// All callers must be `@MainActor` (same isolation as the `ModelContext`).
/// Follows the same structural pattern as `ScoringService` and `StandingsEngine`.
///
/// **Player list immutability (FR13):** Call `validatePlayerMutation(round:)` before
/// any code that would mutate `round.playerIDs` or `round.guestNames`. It throws
/// `RoundLifecycleError.playerMutationForbidden` when the round is not in "setup".
///
/// **Auto-completion (FR14):** Call `checkCompletion(roundID:)` after each score entry.
/// When all (player, hole) pairs have resolved scores the round is automatically
/// transitioned to `.awaitingFinalization`.
///
/// **Manual finish (FR15):** Call `finishRound(roundID:force:)` to handle early termination.
/// With `force == false` a warning result is returned when missing scores exist.
/// With `force == true` the round transitions directly to `.completed`.
///
/// **Finalization (FR14 confirmation):** Call `finalizeRound(roundID:)` when the user
/// confirms the "All scores recorded" prompt to transition from `awaitingFinalization`
/// to `completed`.
@MainActor
public final class RoundLifecycleManager {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Player mutation guard

    /// Throws if the round's player list may no longer be mutated.
    ///
    /// Currently no production code path mutates players after round start —
    /// `RoundSetupView` only exists before a round is created. This method is provided
    /// as a programmatic guard for any future feature that adds player editing (e.g., mid-round
    /// substitutions). Any such feature MUST call this before mutating `playerIDs`/`guestNames`.
    ///
    /// - Parameter round: The round to validate.
    /// - Throws: `RoundLifecycleError.playerMutationForbidden` when status is not "setup".
    public func validatePlayerMutation(round: Round) throws {
        guard round.isSetup else {
            throw RoundLifecycleError.playerMutationForbidden(round.status)
        }
    }

    // MARK: - Completion detection

    /// Checks whether all (player, hole) pairs have a resolved score for the given round.
    ///
    /// If all scores are present and the round is still "active", it is transitioned to
    /// `awaitingFinalization` and saved. If the round is not active (already awaiting
    /// finalization or completed), returns `.incomplete` without side effects.
    ///
    /// - Parameter roundID: The UUID of the round to check.
    /// - Returns: `.incomplete(missing:)` if gaps remain; `.nowAwaitingFinalization` if complete.
    /// - Throws: `RoundLifecycleError.roundNotFound` if the round doesn't exist.
    ///           Rethrows SwiftData persistence errors. Never uses `try?`.
    @discardableResult
    public func checkCompletion(roundID: UUID) throws -> CompletionCheckResult {
        let round = try fetchRound(roundID)
        guard round.isActive else {
            // Round is already in awaitingFinalization or completed — no action needed
            return .incomplete(missing: 0)
        }

        let missing = try missingScoreCount(for: round)
        if missing > 0 {
            return .incomplete(missing: missing)
        }

        round.awaitFinalization()
        try modelContext.save()
        return .nowAwaitingFinalization
    }

    // MARK: - Manual finish

    /// Finishes the round, optionally warning about missing scores.
    ///
    /// When `force == false` and missing scores exist, returns `.hasMissingScores(count:)`
    /// without modifying the round — the UI must show a warning and call again with `force: true`.
    /// When `force == true` (or no scores are missing), transitions round to `.completed`.
    ///
    /// - Parameters:
    ///   - roundID: The UUID of the round to finish.
    ///   - force: When `true`, completes the round even if some holes are unscored.
    /// - Returns: `.hasMissingScores(count:)` when a warning is needed; `.completed` otherwise.
    /// - Throws: `RoundLifecycleError.roundNotFound` if the round doesn't exist.
    @discardableResult
    public func finishRound(roundID: UUID, force: Bool) throws -> FinishRoundResult {
        let round = try fetchRound(roundID)
        guard round.isActive || round.isAwaitingFinalization else {
            throw RoundLifecycleError.invalidStateForTransition(
                current: round.status,
                expected: "\(RoundStatus.active) or \(RoundStatus.awaitingFinalization)"
            )
        }
        let missingCount = try missingScoreCount(for: round)

        if !force && missingCount > 0 {
            return .hasMissingScores(count: missingCount)
        }

        round.complete()
        try modelContext.save()
        return .completed
    }

    // MARK: - Finalization confirmation

    /// Transitions the round from `awaitingFinalization` to `completed`.
    ///
    /// Called when the user confirms the "All scores recorded. Finalize round?" prompt.
    ///
    /// - Parameter roundID: The UUID of the round to finalize.
    /// - Throws: `RoundLifecycleError.roundNotFound` if the round doesn't exist.
    ///           Rethrows SwiftData persistence errors.
    public func finalizeRound(roundID: UUID) throws {
        let round = try fetchRound(roundID)
        guard round.isAwaitingFinalization else {
            throw RoundLifecycleError.invalidStateForTransition(
                current: round.status,
                expected: RoundStatus.awaitingFinalization
            )
        }
        round.complete()
        try modelContext.save()
    }

    // MARK: - Private helpers

    private func fetchRound(_ roundID: UUID) throws -> Round {
        let id = roundID
        let descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == id })
        guard let round = try modelContext.fetch(descriptor).first else {
            throw RoundLifecycleError.roundNotFound(roundID)
        }
        return round
    }

    /// Counts (player, hole) pairs with no resolved (leaf-node) score.
    private func missingScoreCount(for round: Round) throws -> Int {
        let id = round.id
        let descriptor = FetchDescriptor<ScoreEvent>(predicate: #Predicate { $0.roundID == id })
        let allEvents = try modelContext.fetch(descriptor)

        let allPlayerIDs = round.playerIDs + round.guestNames.map { "guest:\($0)" }
        var missing = 0
        for playerID in allPlayerIDs {
            for holeNumber in 1...max(1, round.holeCount) {
                if resolveCurrentScore(for: playerID, hole: holeNumber, in: allEvents) == nil {
                    missing += 1
                }
            }
        }
        return missing
    }
}
