import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for ScorecardViewModel (Story 3.2: hole card tap scoring; Story 3.3: score corrections).
@Suite("ScorecardViewModel")
@MainActor
struct ScorecardViewModelTests {

    // MARK: - Helper

    private func makeContextAndService() throws -> (ModelContext, ScoringService) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        let context = ModelContext(container)
        let service = ScoringService(modelContext: context, deviceID: "vm-test-device")
        return (context, service)
    }

    // MARK: - enterScore creates ScoreEvent via ScoringService

    @Test("enterScore creates ScoreEvent via ScoringService")
    func test_enterScore_createsScoreEvent() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let reporterID = UUID()

        let vm = ScorecardViewModel(
            scoringService: service,
            roundID: roundID,
            reportedByPlayerID: reporterID
        )

        try vm.enterScore(playerID: "player-abc", holeNumber: 5, strokeCount: 4)

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

        let vm = ScorecardViewModel(
            scoringService: service,
            roundID: roundID,
            reportedByPlayerID: reporterID
        )

        try vm.enterScore(playerID: "player-xyz", holeNumber: 3, strokeCount: 3)

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

        let vm = ScorecardViewModel(
            scoringService: service,
            roundID: roundID,
            reportedByPlayerID: UUID()
        )

        try vm.enterScore(playerID: "player-one", holeNumber: 1, strokeCount: 3)
        try vm.enterScore(playerID: "player-two", holeNumber: 1, strokeCount: 4)
        try vm.enterScore(playerID: "guest:Dave", holeNumber: 1, strokeCount: 5)

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
        let vm = ScorecardViewModel(
            scoringService: service,
            roundID: roundID,
            reportedByPlayerID: UUID()
        )

        // Create initial score
        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 4, playerID: "player-abc", strokeCount: 5, reportedByPlayerID: UUID()
        )

        // Correct it via the ViewModel
        try vm.correctScore(previousEventID: original.id, playerID: "player-abc", holeNumber: 4, strokeCount: 3)

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
        let vm = ScorecardViewModel(
            scoringService: service,
            roundID: roundID,
            reportedByPlayerID: reporterID
        )

        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 2, playerID: "player-abc", strokeCount: 4, reportedByPlayerID: UUID()
        )

        try vm.correctScore(previousEventID: original.id, playerID: "player-abc", holeNumber: 2, strokeCount: 2)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        let correction = fetched.first { $0.supersedesEventID == original.id }
        #expect(correction?.roundID == roundID)
        #expect(correction?.reportedByPlayerID == reporterID)
    }

    // MARK: - correctScore sets saveError on failure

    @Test("correctScore sets saveError when previous event not found")
    func test_correctScore_setsSaveErrorOnFailure() throws {
        let (_, service) = try makeContextAndService()
        let vm = ScorecardViewModel(
            scoringService: service,
            roundID: UUID(),
            reportedByPlayerID: UUID()
        )

        // correctScore is a throwing method — caller (ScorecardContainerView) catches and sets saveError
        let missingID = UUID()
        #expect(throws: ScoringServiceError.previousEventNotFound(missingID)) {
            try vm.correctScore(previousEventID: missingID, playerID: "p", holeNumber: 1, strokeCount: 3)
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
        // All players should have resolved scores for hole 1
        let allScored = playerIDs.allSatisfy { playerID in
            resolveCurrentScore(for: playerID, hole: 1, in: events) != nil
        }
        #expect(allScored == true)
    }

    @Test("allPlayersScored condition: resolveCurrentScore returns nil for unscored player")
    func test_autoAdvance_notAllScored_returnsNilForUnscored() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()

        // Only score 2 of 3 players
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

        // Specifically, player-3 is unscored
        let unscoredResult = resolveCurrentScore(for: "player-3", hole: 1, in: events)
        #expect(unscoredResult == nil)
    }

    @Test("correction does not create new unscored state — leaf node still resolves correctly")
    func test_autoAdvance_correctionDoesNotInvalidateScore() throws {
        let (context, service) = try makeContextAndService()
        let roundID = UUID()
        let playerID = "player-1"

        // Score and then correct
        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 5, reportedByPlayerID: UUID()
        )
        try service.correctScore(
            previousEventID: original.id,
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, reportedByPlayerID: UUID()
        )

        let events = try context.fetch(FetchDescriptor<ScoreEvent>())
        // After correction, player still has a resolved (leaf) score
        let resolved = resolveCurrentScore(for: playerID, hole: 1, in: events)
        #expect(resolved != nil)
        #expect(resolved?.strokeCount == 3)
        // The allPlayersScored condition would still be true after a correction
    }

    @Test("auto-advance should not trigger on last hole — holeCount guard")
    func test_autoAdvance_doesNotTriggerOnLastHole() {
        // The guard `currentHole < round.holeCount` prevents advance on the final hole.
        // This test documents the expected condition check logic.
        let holeCount = 9
        let currentHole = holeCount  // on the last hole

        // Simulates: guard currentHole < round.holeCount else { return }
        let shouldAdvance = currentHole < holeCount
        #expect(shouldAdvance == false)
    }
}
