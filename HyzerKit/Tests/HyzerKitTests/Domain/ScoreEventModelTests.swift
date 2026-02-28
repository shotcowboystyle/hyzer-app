import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("ScoreEvent model")
struct ScoreEventModelTests {

    // MARK: - Init creates ScoreEvent with correct properties and nil supersedesEventID

    @Test("init creates ScoreEvent with correct properties and nil supersedesEventID")
    func test_init_createsScoreEventWithCorrectProperties() {
        let roundID = UUID()
        let reporterID = UUID()

        let event = ScoreEvent(
            roundID: roundID,
            holeNumber: 5,
            playerID: "player-uuid-string",
            strokeCount: 4,
            reportedByPlayerID: reporterID,
            deviceID: "device-123"
        )

        #expect(event.roundID == roundID)
        #expect(event.holeNumber == 5)
        #expect(event.playerID == "player-uuid-string")
        #expect(event.strokeCount == 4)
        #expect(event.reportedByPlayerID == reporterID)
        #expect(event.deviceID == "device-123")
        #expect(event.supersedesEventID == nil)
        #expect(event.createdAt <= Date())
        #expect(event.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    // MARK: - ScoreEvent persists and fetches in SwiftData (in-memory)

    @Test("ScoreEvent persists and fetches correctly in SwiftData")
    @MainActor
    func test_scoreEvent_persistsAndFetches() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let roundID = UUID()
        let reporterID = UUID()
        let event = ScoreEvent(
            roundID: roundID,
            holeNumber: 3,
            playerID: "player-abc",
            strokeCount: 2,
            reportedByPlayerID: reporterID,
            deviceID: "device-xyz"
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 1)
        #expect(fetched[0].roundID == roundID)
        #expect(fetched[0].holeNumber == 3)
        #expect(fetched[0].playerID == "player-abc")
        #expect(fetched[0].strokeCount == 2)
        #expect(fetched[0].reportedByPlayerID == reporterID)
        #expect(fetched[0].deviceID == "device-xyz")
        #expect(fetched[0].supersedesEventID == nil)
    }

    // MARK: - CloudKit compatibility — all properties have defaults

    @Test("all properties have defaults for CloudKit compatibility")
    func test_cloudKitCompatibility_allPropertiesHaveDefaults() {
        let event = ScoreEvent(
            roundID: UUID(),
            holeNumber: 1,
            playerID: "p",
            strokeCount: 3,
            reportedByPlayerID: UUID(),
            deviceID: "d"
        )
        // All non-optional properties are populated after init
        #expect(event.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(!event.playerID.isEmpty)
        #expect(!event.deviceID.isEmpty)
        // Optional property starts nil (OK for CloudKit)
        #expect(event.supersedesEventID == nil)
    }

    // MARK: - Multiple ScoreEvents for same {round, hole, player} coexist (append-only)

    @Test("multiple ScoreEvents for same round/hole/player all persist (append-only)")
    @MainActor
    func test_appendOnly_multipleEventsCoexist() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let roundID = UUID()
        let playerID = "player-123"

        let event1 = ScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3,
                                reportedByPlayerID: UUID(), deviceID: "d1")
        let event2 = ScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4,
                                reportedByPlayerID: UUID(), deviceID: "d2")
        let event3 = ScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 2,
                                reportedByPlayerID: UUID(), deviceID: "d3")

        context.insert(event1)
        context.insert(event2)
        context.insert(event3)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 3)
    }

    // MARK: - fixture helper

    @Test("fixture() creates ScoreEvent with expected default values")
    func test_fixture_createsScoreEventWithDefaults() {
        let event = ScoreEvent.fixture()
        #expect(event.holeNumber == 1)
        #expect(event.strokeCount == 3)
        #expect(event.deviceID == "test-device")
        #expect(event.supersedesEventID == nil)
    }

    @Test("fixture() with custom values sets those values")
    func test_fixture_withCustomValues_setsCorrectly() {
        let roundID = UUID()
        let playerID = "guest:Alice"
        let event = ScoreEvent.fixture(
            roundID: roundID,
            holeNumber: 9,
            playerID: playerID,
            strokeCount: 5,
            deviceID: "custom-device"
        )
        #expect(event.roundID == roundID)
        #expect(event.holeNumber == 9)
        #expect(event.playerID == "guest:Alice")
        #expect(event.strokeCount == 5)
        #expect(event.deviceID == "custom-device")
    }
}
