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

    // MARK: - correctScore: creates event with non-nil supersedesEventID

    @Test("correctScore creates event with non-nil supersedesEventID matching previous event ID")
    func test_correctScore_createsSupersedesEventID() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")

        let roundID = UUID()
        let playerID = "player-abc"
        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4, reportedByPlayerID: UUID()
        )

        let correction = try service.correctScore(
            previousEventID: original.id,
            roundID: roundID,
            holeNumber: 1,
            playerID: playerID,
            strokeCount: 3,
            reportedByPlayerID: UUID()
        )

        #expect(correction.supersedesEventID == original.id)
        #expect(correction.strokeCount == 3)
    }

    // MARK: - correctScore: original event is preserved (append-only, NFR19)

    @Test("correctScore preserves original event — both events exist after correction")
    func test_correctScore_preservesOriginalEvent() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")

        let roundID = UUID()
        let playerID = "player-abc"
        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 5, reportedByPlayerID: UUID()
        )

        try service.correctScore(
            previousEventID: original.id,
            roundID: roundID,
            holeNumber: 2,
            playerID: playerID,
            strokeCount: 4,
            reportedByPlayerID: UUID()
        )

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 2)
        let ids = Set(fetched.map(\.id))
        #expect(ids.contains(original.id))
    }

    // MARK: - correctScore: throws when previous event not found

    @Test("correctScore throws ScoringServiceError.previousEventNotFound when previous event does not exist")
    func test_correctScore_throwsWhenPreviousEventNotFound() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")
        let missingID = UUID()

        #expect(throws: ScoringServiceError.previousEventNotFound(missingID)) {
            try service.correctScore(
                previousEventID: missingID,
                roundID: UUID(),
                holeNumber: 1,
                playerID: "p",
                strokeCount: 3,
                reportedByPlayerID: UUID()
            )
        }
    }

    // MARK: - correctScore: sets all event properties correctly

    @Test("correctScore sets correct roundID, holeNumber, playerID, strokeCount, reportedByPlayerID, deviceID")
    func test_correctScore_setsAllProperties() throws {
        let (_, context) = try makeContext()
        let deviceID = "correction-device"
        let service = ScoringService(modelContext: context, deviceID: deviceID)

        let roundID = UUID()
        let reporterID = UUID()
        let playerID = "player-xyz"

        let original = try service.createScoreEvent(
            roundID: roundID, holeNumber: 3, playerID: playerID, strokeCount: 5, reportedByPlayerID: UUID()
        )

        let correction = try service.correctScore(
            previousEventID: original.id,
            roundID: roundID,
            holeNumber: 3,
            playerID: playerID,
            strokeCount: 2,
            reportedByPlayerID: reporterID
        )

        #expect(correction.roundID == roundID)
        #expect(correction.holeNumber == 3)
        #expect(correction.playerID == playerID)
        #expect(correction.strokeCount == 2)
        #expect(correction.reportedByPlayerID == reporterID)
        #expect(correction.deviceID == deviceID)
        #expect(correction.supersedesEventID == original.id)
    }

    // MARK: - correctScore: correction chain A -> B -> C

    @Test("multiple corrections chain correctly — A -> B -> C all persist")
    func test_correctScore_chainPreservesAllEvents() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")

        let roundID = UUID()
        let playerID = "player-chain"

        let eventA = try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 5, reportedByPlayerID: UUID()
        )
        let eventB = try service.correctScore(
            previousEventID: eventA.id,
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4, reportedByPlayerID: UUID()
        )
        let eventC = try service.correctScore(
            previousEventID: eventB.id,
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, reportedByPlayerID: UUID()
        )

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 3)

        let ids = Set(fetched.map(\.id))
        #expect(ids.contains(eventA.id))
        #expect(ids.contains(eventB.id))
        #expect(ids.contains(eventC.id))

        #expect(eventB.supersedesEventID == eventA.id)
        #expect(eventC.supersedesEventID == eventB.id)
    }

    // MARK: - Leaf-node resolution: returns C in chain A -> B -> C

    @Test("leaf-node resolution returns C (the latest correction) in chain A -> B -> C")
    func test_correctScore_leafNodeResolutionReturnsLatestCorrection() throws {
        let (_, context) = try makeContext()
        let service = ScoringService(modelContext: context, deviceID: "d")

        let roundID = UUID()
        let playerID = "player-leaf"

        let eventA = try service.createScoreEvent(
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 5, reportedByPlayerID: UUID()
        )
        let eventB = try service.correctScore(
            previousEventID: eventA.id,
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4, reportedByPlayerID: UUID()
        )
        let eventC = try service.correctScore(
            previousEventID: eventB.id,
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, reportedByPlayerID: UUID()
        )

        let allEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        let holeEvents = allEvents.filter { $0.playerID == playerID && $0.holeNumber == 1 }
        let supersededIDs = Set(holeEvents.compactMap(\.supersedesEventID))
        let leaf = holeEvents.first { !supersededIDs.contains($0.id) }

        #expect(leaf?.id == eventC.id)
        #expect(leaf?.strokeCount == 3)
    }
}
