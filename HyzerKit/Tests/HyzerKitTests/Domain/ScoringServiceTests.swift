import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("ScoringService")
@MainActor
struct ScoringServiceTests {

    // MARK: - Helper

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        return (container, ModelContext(container))
    }

    // MARK: - createScoreEvent persists event with correct properties

    @Test("createScoreEvent persists event with correct roundID, holeNumber, playerID, strokeCount")
    func test_createScoreEvent_persistsCorrectProperties() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "test-device-1")

        let roundID = UUID()
        let reporterID = UUID()
        let playerID = "player-uuid-abc"

        let event = try service.createScoreEvent(
            roundID: roundID,
            holeNumber: 3,
            playerID: playerID,
            strokeCount: 4,
            reportedByPlayerID: reporterID
        )

        #expect(event.roundID == roundID)
        #expect(event.holeNumber == 3)
        #expect(event.playerID == playerID)
        #expect(event.strokeCount == 4)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 1)
        #expect(fetched[0].roundID == roundID)
        #expect(fetched[0].holeNumber == 3)
        #expect(fetched[0].playerID == playerID)
        #expect(fetched[0].strokeCount == 4)
    }

    // MARK: - createScoreEvent sets reportedByPlayerID and deviceID correctly

    @Test("createScoreEvent sets reportedByPlayerID and deviceID correctly")
    func test_createScoreEvent_setsReporterAndDevice() throws {
        let (_, context) = try makeContext()
        let deviceID = "my-device-id-42"
        let service = ScoringService(modelContext: context, deviceID: deviceID)

        let reporterID = UUID()
        let event = try service.createScoreEvent(
            roundID: UUID(),
            holeNumber: 1,
            playerID: "player-x",
            strokeCount: 3,
            reportedByPlayerID: reporterID
        )

        #expect(event.reportedByPlayerID == reporterID)
        #expect(event.deviceID == deviceID)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched[0].reportedByPlayerID == reporterID)
        #expect(fetched[0].deviceID == deviceID)
    }

    // MARK: - createScoreEvent sets supersedesEventID to nil

    @Test("createScoreEvent sets supersedesEventID to nil")
    func test_createScoreEvent_supersedesEventIDIsNil() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")

        let event = try service.createScoreEvent(
            roundID: UUID(),
            holeNumber: 1,
            playerID: "p",
            strokeCount: 3,
            reportedByPlayerID: UUID()
        )

        #expect(event.supersedesEventID == nil)

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched[0].supersedesEventID == nil)
    }

    // MARK: - createScoreEvent returns the created ScoreEvent

    @Test("createScoreEvent returns the created ScoreEvent")
    func test_createScoreEvent_returnsCreatedEvent() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")

        let roundID = UUID()
        let event = try service.createScoreEvent(
            roundID: roundID,
            holeNumber: 7,
            playerID: "player-xyz",
            strokeCount: 2,
            reportedByPlayerID: UUID()
        )

        #expect(event.roundID == roundID)
        #expect(event.holeNumber == 7)
        #expect(event.strokeCount == 2)
    }

    // MARK: - Multiple events for same {round, hole, player} all persist (no uniqueness constraint)

    @Test("multiple events for same round/hole/player all persist (no uniqueness constraint)")
    func test_createScoreEvent_noUniquenessConstraint() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")

        let roundID = UUID()
        let playerID = "player-same"

        try service.createScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 3, reportedByPlayerID: UUID())
        try service.createScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 4, reportedByPlayerID: UUID())
        try service.createScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 5, reportedByPlayerID: UUID())

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 3)
        let strokeCounts = fetched.map(\.strokeCount).sorted()
        #expect(strokeCounts == [3, 4, 5])
    }
}
