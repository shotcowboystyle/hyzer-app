import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for ScorecardViewModel (Story 3.2: hole card tap scoring).
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
    func test_enterScore_differentPlayerIDs_createsSeperateEvents() throws {
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
}
