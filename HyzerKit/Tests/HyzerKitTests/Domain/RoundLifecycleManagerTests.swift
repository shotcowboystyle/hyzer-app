import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("RoundLifecycleManager")
@MainActor
struct RoundLifecycleManagerTests {

    // MARK: - Helpers

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        return (container, ModelContext(container))
    }

    private func insertActiveRound(
        context: ModelContext,
        playerIDs: [String] = ["player-1"],
        holeCount: Int = 3
    ) throws -> Round {
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: playerIDs,
            guestNames: [],
            holeCount: holeCount
        )
        context.insert(round)
        round.start()
        try context.save()
        return round
    }

    private func insertScoreEvents(
        context: ModelContext,
        service: ScoringService,
        roundID: UUID,
        playerIDs: [String],
        holeCount: Int
    ) throws {
        for playerID in playerIDs {
            for hole in 1...holeCount {
                try service.createScoreEvent(
                    roundID: roundID,
                    holeNumber: hole,
                    playerID: playerID,
                    strokeCount: 3,
                    reportedByPlayerID: UUID()
                )
            }
        }
    }

    // MARK: - 11.1: checkCompletion returns .incomplete when scores are missing

    @Test("checkCompletion returns .incomplete when scores are missing")
    func test_checkCompletion_incomplete_whenScoresMissing() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context, playerIDs: ["p1", "p2"], holeCount: 3)

        // Score only 1 of 3 holes for p1, none for p2
        let service = ScoringService(modelContext: context, deviceID: "d")
        try service.createScoreEvent(roundID: round.id, holeNumber: 1, playerID: "p1", strokeCount: 3, reportedByPlayerID: UUID())

        let result = try manager.checkCompletion(roundID: round.id)

        if case .incomplete(let missing) = result {
            #expect(missing > 0)
        } else {
            Issue.record("Expected .incomplete, got .nowAwaitingFinalization")
        }
        #expect(round.isActive) // round should still be active
    }

    // MARK: - 11.2: checkCompletion returns .nowAwaitingFinalization when all holes scored

    @Test("checkCompletion returns .nowAwaitingFinalization when all holes scored for all players")
    func test_checkCompletion_nowAwaitingFinalization_whenAllScored() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let playerIDs = ["p1", "p2"]
        let round = try insertActiveRound(context: context, playerIDs: playerIDs, holeCount: 2)
        let service = ScoringService(modelContext: context, deviceID: "d")
        try insertScoreEvents(context: context, service: service, roundID: round.id, playerIDs: playerIDs, holeCount: 2)

        let result = try manager.checkCompletion(roundID: round.id)

        if case .nowAwaitingFinalization = result {
            // OK
        } else {
            Issue.record("Expected .nowAwaitingFinalization")
        }
        #expect(round.isAwaitingFinalization)
        #expect(round.status == "awaitingFinalization")
    }

    // MARK: - 11.3: checkCompletion handles corrections correctly

    @Test("checkCompletion handles corrections — superseded scores don't count as missing")
    func test_checkCompletion_handlesCorrections() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context, playerIDs: ["p1"], holeCount: 1)
        let service = ScoringService(modelContext: context, deviceID: "d")

        // Score then correct hole 1 for p1
        let original = try service.createScoreEvent(roundID: round.id, holeNumber: 1, playerID: "p1", strokeCount: 5, reportedByPlayerID: UUID())
        try service.correctScore(previousEventID: original.id, roundID: round.id, holeNumber: 1, playerID: "p1", strokeCount: 3, reportedByPlayerID: UUID())

        let result = try manager.checkCompletion(roundID: round.id)

        // Correction should not make hole count as "missing" — the leaf node still exists
        if case .nowAwaitingFinalization = result {
            // OK
        } else {
            Issue.record("Expected .nowAwaitingFinalization after correction completes score")
        }
    }

    // MARK: - 11.4: finishRound with force=false returns .hasMissingScores when incomplete

    @Test("finishRound(force:false) returns .hasMissingScores when scores are missing")
    func test_finishRound_noForce_returnsMissingScores_whenIncomplete() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context, playerIDs: ["p1"], holeCount: 3)

        // Score only hole 1; holes 2 and 3 are missing
        let service = ScoringService(modelContext: context, deviceID: "d")
        try service.createScoreEvent(roundID: round.id, holeNumber: 1, playerID: "p1", strokeCount: 3, reportedByPlayerID: UUID())

        let result = try manager.finishRound(roundID: round.id, force: false)

        if case .hasMissingScores(let count) = result {
            #expect(count == 2)
        } else {
            Issue.record("Expected .hasMissingScores(count: 2)")
        }
        #expect(round.isActive) // round should not have completed
    }

    // MARK: - 11.5: finishRound with force=true completes round even with missing scores

    @Test("finishRound(force:true) completes round even with missing scores")
    func test_finishRound_force_completesRound_withMissingScores() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context, playerIDs: ["p1"], holeCount: 3)
        // No scores inserted

        let result = try manager.finishRound(roundID: round.id, force: true)

        if case .completed = result {
            // OK
        } else {
            Issue.record("Expected .completed")
        }
        #expect(round.isCompleted)
        #expect(round.completedAt != nil)
    }

    // MARK: - 11.6: finalizeRound transitions awaitingFinalization → completed

    @Test("finalizeRound transitions awaitingFinalization to completed")
    func test_finalizeRound_transitionsToCompleted() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let playerIDs = ["p1"]
        let round = try insertActiveRound(context: context, playerIDs: playerIDs, holeCount: 1)
        let service = ScoringService(modelContext: context, deviceID: "d")
        try insertScoreEvents(context: context, service: service, roundID: round.id, playerIDs: playerIDs, holeCount: 1)

        // First bring to awaitingFinalization
        _ = try manager.checkCompletion(roundID: round.id)
        #expect(round.isAwaitingFinalization)

        // Finalize
        try manager.finalizeRound(roundID: round.id)

        #expect(round.isCompleted)
        #expect(round.completedAt != nil)
    }

    // MARK: - 11.7: validatePlayerMutation throws for non-setup rounds

    @Test("validatePlayerMutation throws for active rounds")
    func test_validatePlayerMutation_throwsForActiveRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context)

        #expect(throws: RoundLifecycleError.playerMutationForbidden("active")) {
            try manager.validatePlayerMutation(round: round)
        }
    }

    @Test("validatePlayerMutation throws for awaitingFinalization rounds")
    func test_validatePlayerMutation_throwsForAwaitingFinalizationRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let playerIDs = ["p1"]
        let round = try insertActiveRound(context: context, playerIDs: playerIDs, holeCount: 1)
        let service = ScoringService(modelContext: context, deviceID: "d")
        try insertScoreEvents(context: context, service: service, roundID: round.id, playerIDs: playerIDs, holeCount: 1)
        _ = try manager.checkCompletion(roundID: round.id)
        #expect(round.isAwaitingFinalization)

        #expect(throws: RoundLifecycleError.playerMutationForbidden("awaitingFinalization")) {
            try manager.validatePlayerMutation(round: round)
        }
    }

    @Test("validatePlayerMutation throws for completed rounds")
    func test_validatePlayerMutation_throwsForCompletedRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context)
        _ = try manager.finishRound(roundID: round.id, force: true)
        #expect(round.isCompleted)

        #expect(throws: RoundLifecycleError.playerMutationForbidden("completed")) {
            try manager.validatePlayerMutation(round: round)
        }
    }

    // MARK: - 11.8: validatePlayerMutation succeeds for setup rounds

    @Test("validatePlayerMutation succeeds for setup rounds")
    func test_validatePlayerMutation_succeedsForSetupRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = Round.fixture()
        context.insert(round)
        try context.save()
        #expect(round.isSetup)

        // Should not throw
        try manager.validatePlayerMutation(round: round)
    }

    // MARK: - 11.9: complete() sets completedAt timestamp

    @Test("complete() sets completedAt timestamp")
    func test_complete_setsCompletedAt() throws {
        let before = Date()
        let round = Round.fixture()
        round.start()
        round.complete()
        let after = Date()

        #expect(round.completedAt != nil)
        #expect(round.completedAt! >= before)
        #expect(round.completedAt! <= after)
    }

    // MARK: - 11.10: Round state transitions enforce valid preconditions

    @Test("awaitFinalization() documents precondition — status must be active")
    func test_stateTransitions_awaitFinalizationRequiresActive() {
        let round = Round.fixture()
        round.start()
        #expect(round.isActive)
        // After awaitFinalization, status is correct
        round.awaitFinalization()
        #expect(round.isAwaitingFinalization)
        #expect(round.status == "awaitingFinalization")
    }

    @Test("complete() from awaitingFinalization transitions to completed")
    func test_stateTransitions_completeFromAwaitingFinalization() {
        let round = Round.fixture()
        round.start()
        round.awaitFinalization()
        round.complete()
        #expect(round.isCompleted)
        #expect(round.status == "completed")
    }

    @Test("complete() from active transitions directly to completed (early finish)")
    func test_stateTransitions_completeFromActive() {
        let round = Round.fixture()
        round.start()
        round.complete()
        #expect(round.isCompleted)
        #expect(round.completedAt != nil)
    }

    @Test("isFinished is true for awaitingFinalization and completed rounds")
    func test_isFinished_trueForBothTerminalStates() {
        let awaitingRound = Round.fixture()
        awaitingRound.start()
        awaitingRound.awaitFinalization()
        #expect(awaitingRound.isFinished)

        let completedRound = Round.fixture()
        completedRound.start()
        completedRound.complete()
        #expect(completedRound.isFinished)

        let activeRound = Round.fixture()
        activeRound.start()
        #expect(!activeRound.isFinished)
    }

    // MARK: - checkCompletion is a no-op for already-finished rounds

    @Test("checkCompletion is a no-op when round is already awaitingFinalization")
    func test_checkCompletion_noopWhenAlreadyAwaitingFinalization() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let playerIDs = ["p1"]
        let round = try insertActiveRound(context: context, playerIDs: playerIDs, holeCount: 1)
        let service = ScoringService(modelContext: context, deviceID: "d")
        try insertScoreEvents(context: context, service: service, roundID: round.id, playerIDs: playerIDs, holeCount: 1)
        _ = try manager.checkCompletion(roundID: round.id)
        #expect(round.isAwaitingFinalization)

        // Calling checkCompletion again should not crash or transition further
        let result = try manager.checkCompletion(roundID: round.id)
        if case .incomplete = result {
            // OK — no-op, round stays in awaitingFinalization
        } else {
            Issue.record("Expected .incomplete(0) no-op for already-awaiting round")
        }
        #expect(round.isAwaitingFinalization) // unchanged
    }

    // MARK: - roundNotFound error

    @Test("checkCompletion throws roundNotFound for unknown roundID")
    func test_checkCompletion_throwsRoundNotFound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let fakeID = UUID()

        #expect(throws: RoundLifecycleError.roundNotFound(fakeID)) {
            try manager.checkCompletion(roundID: fakeID)
        }
    }

    // MARK: - State validation: finishRound on invalid states (L2 fix)

    @Test("finishRound throws invalidStateForTransition on a completed round")
    func test_finishRound_throwsOnCompletedRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context)
        _ = try manager.finishRound(roundID: round.id, force: true)
        #expect(round.isCompleted)

        #expect(throws: RoundLifecycleError.invalidStateForTransition(
            current: "completed",
            expected: "active or awaitingFinalization"
        )) {
            try manager.finishRound(roundID: round.id, force: true)
        }
    }

    @Test("finishRound throws invalidStateForTransition on a setup round")
    func test_finishRound_throwsOnSetupRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = Round.fixture()
        context.insert(round)
        try context.save()
        #expect(round.isSetup)

        #expect(throws: RoundLifecycleError.invalidStateForTransition(
            current: "setup",
            expected: "active or awaitingFinalization"
        )) {
            try manager.finishRound(roundID: round.id, force: true)
        }
    }

    // MARK: - State validation: finalizeRound on invalid states (L3 fix)

    @Test("finalizeRound throws invalidStateForTransition on an active round")
    func test_finalizeRound_throwsOnActiveRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context)
        #expect(round.isActive)

        #expect(throws: RoundLifecycleError.invalidStateForTransition(
            current: "active",
            expected: "awaitingFinalization"
        )) {
            try manager.finalizeRound(roundID: round.id)
        }
    }

    @Test("finalizeRound throws invalidStateForTransition on a completed round")
    func test_finalizeRound_throwsOnCompletedRound() throws {
        let (_, context) = try makeContext()
        let manager = RoundLifecycleManager(modelContext: context)
        let round = try insertActiveRound(context: context)
        _ = try manager.finishRound(roundID: round.id, force: true)
        #expect(round.isCompleted)

        #expect(throws: RoundLifecycleError.invalidStateForTransition(
            current: "completed",
            expected: "awaitingFinalization"
        )) {
            try manager.finalizeRound(roundID: round.id)
        }
    }
}
