import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("RoundLifecycleManager — State Transitions")
@MainActor
struct RoundLifecycleStateTests {

    // MARK: - Helpers

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
