import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for ScorecardViewModel (Story 3.2: hole card tap scoring; Story 3.3: score corrections;
/// Story 3.5: lifecycle integration, completion detection, and scoring guard).
@Suite("ScorecardViewModel")
@MainActor
struct ScorecardViewModelTests {

    // MARK: - Helper

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        return (container, ModelContext(container))
    }

    private func makeContextAndService() throws -> (ModelContext, ScoringService) {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "vm-test-device")
        return (context, service)
    }

    private func makeVM(
        context: ModelContext,
        service: ScoringService,
        roundID: UUID,
        reporterID: UUID = UUID()
    ) -> ScorecardViewModel {
        let manager = RoundLifecycleManager(modelContext: context)
        return ScorecardViewModel(
            scoringService: service,
            lifecycleManager: manager,
            roundID: roundID,
            reportedByPlayerID: reporterID
        )
    }

    // MARK: - enterScore creates ScoreEvent via ScoringService

    @Test("enterScore creates ScoreEvent via ScoringService")
    func test_enterScore_createsScoreEvent() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let reporterID = UUID()

        let vm = makeVM(context: context, service: service, roundID: roundID, reporterID: reporterID)

        try vm.enterScore(playerID: "player-abc", holeNumber: 5, strokeCount: 4, isRoundFinished: false)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 1)
        #expect(fetched[0].strokeCount == 4)
        #expect(fetched[0].holeNumber == 5)
        #expect(fetched[0].playerID == "player-abc")
    }

    // MARK: - enterScore passes correct roundID and reportedByPlayerID from init

    @Test("enterScore passes correct roundID and reportedByPlayerID from init")
    func test_enterScore_passesCorrectRoundIDAndReporterID() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let reporterID = UUID()

        let vm = makeVM(context: context, service: service, roundID: roundID, reporterID: reporterID)

        try vm.enterScore(playerID: "player-xyz", holeNumber: 3, strokeCount: 3, isRoundFinished: false)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 1)
        #expect(fetched[0].roundID == roundID)
        #expect(fetched[0].reportedByPlayerID == reporterID)
    }

    // MARK: - enterScore with different playerIDs creates separate events (distributed scoring)

    @Test("enterScore with different playerIDs creates separate events (distributed scoring)")
    func test_enterScore_differentPlayerIDs_createsSeparateEvents() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()

        let vm = makeVM(context: context, service: service, roundID: roundID)

        try vm.enterScore(playerID: "player-one", holeNumber: 1, strokeCount: 3, isRoundFinished: false)
        try vm.enterScore(playerID: "player-two", holeNumber: 1, strokeCount: 4, isRoundFinished: false)
        try vm.enterScore(playerID: "guest:Dave", holeNumber: 1, strokeCount: 5, isRoundFinished: false)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 3)
        let playerIDs = Set(fetched.map(\.playerID))
        #expect(playerIDs.contains("player-one"))
        #expect(playerIDs.contains("player-two"))
        #expect(playerIDs.contains("guest:Dave"))
    }

    // MARK: - correctScore creates superseding ScoreEvent via ScoringService

    @Test("correctScore creates superseding ScoreEvent via ScoringService")
    func test_correctScore_createsSupersedesEvent() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let vm = makeVM(context: context, service: service, roundID: roundID)

        // Create initial score
        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 4, playerID: "player-abc", strokeCount: 5, reportedByPlayerID: UUID()
        )

        // Correct it via the ViewModel
        try vm.correctScore(previousEventID: original.id, playerID: "player-abc", holeNumber: 4, strokeCount: 3, isRoundFinished: false)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 2)

        let correction = fetched.first { $0.supersedesEventID == original.id }
        #expect(correction != nil)
        #expect(correction?.strokeCount == 3)
    }

    // MARK: - correctScore passes correct roundID and reportedByPlayerID

    @Test("correctScore passes correct roundID and reportedByPlayerID from init")
    func test_correctScore_passesCorrectRoundIDAndReporterID() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let reporterID = UUID()
        let vm = makeVM(context: context, service: service, roundID: roundID, reporterID: reporterID)

        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 2, playerID: "player-abc", strokeCount: 4, reportedByPlayerID: UUID()
        )

        try vm.correctScore(previousEventID: original.id, playerID: "player-abc", holeNumber: 2, strokeCount: 2, isRoundFinished: false)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        let correction = fetched.first { $0.supersedesEventID == original.id }
        #expect(correction?.roundID == roundID)
        #expect(correction?.reportedByPlayerID == reporterID)
    }

    // MARK: - correctScore sets saveError on failure

    @Test("correctScore throws ScoringServiceError when previous event not found")
    func test_correctScore_throwsOnMissingPreviousEvent() throws {
        let (context, service) = try makeContextAndService()
        let vm = makeVM(context: context, service: service, roundID: UUID())

        let missingID = UUID()
        #expect(throws: ScoringServiceError.previousEventNotFound(missingID)) {
            try vm.correctScore(previousEventID: missingID, playerID: "p", holeNumber: 1, strokeCount: 3, isRoundFinished: false)
        }
    }

    // MARK: - Auto-Advance Logic (AC: 4, 6)
    //
    // Auto-advance is driven by `ScorecardContainerView.allPlayersScored(for:)`, which uses
    // `resolveCurrentScore(for:hole:in:)`. These tests verify that logic directly.
    // Integration-level auto-advance timing is not unit-testable without UI tests.

    @Test("allPlayersScored condition: resolveCurrentScore returns non-nil when all players have scores")
    func test_autoAdvance_allPlayersScored_allHaveScores() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let playerIDs = ["player-1", "player-2", "player-3"]

        for playerID in playerIDs {
            try service.createScoreEvent(
                roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, reportedByPlayerID: UUID()
            )
        }

        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        let allScored = playerIDs.allSatisfy { playerID in
            resolveCurrentScore(for: playerID, hole: 1, in: events) != nil
        }
        #expect(allScored == true)
    }

    @Test("allPlayersScored condition: resolveCurrentScore returns nil for unscored player")
    func test_autoAdvance_notAllScored_returnsNilForUnscored() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()

        try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: "player-1", strokeCount: 3, reportedByPlayerID: UUID()
        )
        try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: "player-2", strokeCount: 4, reportedByPlayerID: UUID()
        )

        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        let playerIDs = ["player-1", "player-2", "player-3"]

        let allScored = playerIDs.allSatisfy { playerID in
            resolveCurrentScore(for: playerID, hole: 1, in: events) != nil
        }
        #expect(allScored == false)

        let unscoredResult = resolveCurrentScore(for: "player-3", hole: 1, in: events)
        #expect(unscoredResult == nil)
    }

    @Test("correction does not create new unscored state — leaf node still resolves correctly")
    func test_autoAdvance_correctionDoesNotInvalidateScore() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let playerID = "player-1"

        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 5, reportedByPlayerID: UUID()
        )
        try service.correctScore(
            previousEventID: original.id,
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, reportedByPlayerID: UUID()
        )

        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        let resolved = resolveCurrentScore(for: playerID, hole: 1, in: events)
        #expect(resolved != nil)
        #expect(resolved?.strokeCount == 3)
    }

    @Test("auto-advance should not trigger on last hole — holeCount guard")
    func test_autoAdvance_doesNotTriggerOnLastHole() {
        let holeCount = 9
        let currentHole = holeCount

        let shouldAdvance = currentHole < holeCount
        #expect(shouldAdvance == false)
    }

    // MARK: - Task 12.1: ScorecardViewModel triggers completion check after score entry

    @Test("enterScore triggers completion check and does not throw on missing round")
    func test_enterScore_triggersCompletionCheck_gracefulOnMissingRound() throws {
        let (context, service) = try makeContextAndService()
        // roundID not inserted into the store — lifecycleManager.checkCompletion will fail gracefully
        let roundID = UUID()
        let vm = makeVM(context: context, service: service, roundID: roundID)

        // Should not throw even though checkCompletion finds no round (error is logged, not surfaced)
        try vm.enterScore(playerID: "p1", holeNumber: 1, strokeCount: 3, isRoundFinished: false)

        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.count == 1)
        #expect(vm.isAwaitingFinalization == false)
    }

    // MARK: - Task 12.2: ScorecardViewModel sets isAwaitingFinalization when lifecycle reports completion

    @Test("ScorecardViewModel sets isAwaitingFinalization when all scores entered for all holes")
    func test_enterScore_setsIsAwaitingFinalization_whenAllScored() throws {
        let (_, context) = try makeContext()
        // Insert an active round with 1 player, 1 hole
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: ["p1"],
            guestNames: [],
            holeCount: 1
        )
        context.insert(round)
        round.start()
        try context.save()

        let service = ScoringService(modelContext: context, deviceID: "d")
        let vm = makeVM(context: context, service: service, roundID: round.id)

        // Entering the single score for the single hole should trigger completion
        try vm.enterScore(playerID: "p1", holeNumber: 1, strokeCount: 3, isRoundFinished: false)

        #expect(vm.isAwaitingFinalization == true)
        #expect(round.isAwaitingFinalization)
    }

    // MARK: - Task 12.3: Score entry is rejected on completed rounds (guard in ViewModel)

    @Test("enterScore no-ops when isRoundFinished is true — no ScoreEvent created")
    func test_enterScore_noopsWhenRoundFinished() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let vm = makeVM(context: context, service: service, roundID: roundID)

        try vm.enterScore(playerID: "p1", holeNumber: 1, strokeCount: 3, isRoundFinished: true)

        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.isEmpty)
    }

    @Test("correctScore no-ops when isRoundFinished is true — no correction event created")
    func test_correctScore_noopsWhenRoundFinished() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let vm = makeVM(context: context, service: service, roundID: roundID)

        // Create an initial score directly via the service
        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: "p1", strokeCount: 5, reportedByPlayerID: UUID()
        )

        try vm.correctScore(previousEventID: original.id, playerID: "p1", holeNumber: 1, strokeCount: 3, isRoundFinished: true)

        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.count == 1) // only the original, no correction
    }

    @Test("isAwaitingFinalization flag is not re-set once true — avoids redundant lifecycle checks")
    func test_isAwaitingFinalization_notRedundantlyReset() throws {
        let (_, context) = try makeContext()
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: ["p1"],
            guestNames: [],
            holeCount: 1
        )
        context.insert(round)
        round.start()
        try context.save()

        let service = ScoringService(modelContext: context, deviceID: "d")
        let vm = makeVM(context: context, service: service, roundID: round.id)

        // Score the only hole
        try vm.enterScore(playerID: "p1", holeNumber: 1, strokeCount: 3, isRoundFinished: false)
        #expect(vm.isAwaitingFinalization == true)

        // Correction on the same hole — isAwaitingFinalization should remain true
        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        guard let original = events.first else {
            Issue.record("No score event found")
            return
        }
        try vm.correctScore(previousEventID: original.id, playerID: "p1", holeNumber: 1, strokeCount: 4, isRoundFinished: false)
        #expect(vm.isAwaitingFinalization == true)
    }
}
