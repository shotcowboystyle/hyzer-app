import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("Round model")
struct RoundModelTests {

    // MARK: - 7.2: Init creates Round with "setup" status and correct properties

    @Test("init creates Round with setup status and correct properties")
    func test_init_createsRoundWithSetupStatus() {
        let courseID = UUID()
        let organizerID = UUID()
        let playerIDs = [organizerID.uuidString]
        let guestNames = ["Alice Guest"]

        let round = Round(
            courseID: courseID,
            organizerID: organizerID,
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: 9
        )

        #expect(round.courseID == courseID)
        #expect(round.organizerID == organizerID)
        #expect(round.playerIDs == playerIDs)
        #expect(round.guestNames == guestNames)
        #expect(round.holeCount == 9)
        #expect(round.status == "setup")
        #expect(round.isSetup)
        #expect(!round.isActive)
        #expect(round.startedAt == nil)
        #expect(round.createdAt <= Date())
        #expect(round.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    // MARK: - 7.3: start() transitions status from "setup" to "active" and sets startedAt

    @Test("start() transitions status to active and sets startedAt")
    func test_start_transitionsToActiveAndSetsStartedAt() {
        let round = Round.fixture()
        #expect(round.status == "setup")
        #expect(round.startedAt == nil)

        round.start()

        #expect(round.status == "active")
        #expect(round.isActive)
        #expect(!round.isSetup)
        #expect(round.startedAt != nil)
        #expect(round.startedAt! <= Date())
    }

    // MARK: - 7.4: start() on already-active round triggers precondition failure

    @Test("start() on active round documents invariant — precondition prevents double-start")
    func test_start_onActiveRound_documentsInvariant() {
        let round = Round.fixture()
        round.start()
        #expect(round.isActive)

        // After start(), the round is active and calling start() again would trigger
        // `precondition(status == "setup")` — a fatal error in debug builds.
        // Swift Testing cannot catch precondition failures (they terminate the process),
        // so we verify the guard condition instead: status is no longer "setup".
        #expect(round.status == "active")
        #expect(!round.isSetup)
    }

    // MARK: - 7.5: Round persists and fetches correctly in SwiftData (in-memory)

    @Test("Round persists and fetches correctly in SwiftData")
    @MainActor
    func test_round_persistsAndFetches() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Round.self, configurations: config)
        let context = ModelContext(container)

        let courseID = UUID()
        let organizerID = UUID()
        let round = Round(
            courseID: courseID,
            organizerID: organizerID,
            playerIDs: [organizerID.uuidString, UUID().uuidString],
            guestNames: ["Guest One"],
            holeCount: 18
        )
        context.insert(round)
        round.start()
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Round>())
        #expect(fetched.count == 1)
        #expect(fetched[0].courseID == courseID)
        #expect(fetched[0].organizerID == organizerID)
        #expect(fetched[0].playerIDs.count == 2)
        #expect(fetched[0].guestNames == ["Guest One"])
        #expect(fetched[0].holeCount == 18)
        #expect(fetched[0].status == "active")
        #expect(fetched[0].startedAt != nil)
    }

    // MARK: - 7.6: CloudKit compatibility — all properties have defaults

    @Test("all properties have defaults for CloudKit compatibility")
    func test_cloudKitCompatibility_allPropertiesHaveDefaults() {
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: [],
            guestNames: [],
            holeCount: 18
        )
        // Verify all non-optional properties have sensible defaults after init
        #expect(round.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(round.status == "setup")
        #expect(round.holeCount == 18)
        #expect(round.playerIDs == [])
        #expect(round.guestNames == [])
        #expect(round.startedAt == nil) // optional — OK for CloudKit
    }

    // MARK: - fixture helper

    @Test("fixture() creates Round with expected default values")
    func test_fixture_createsRoundWithDefaults() {
        let round = Round.fixture()
        #expect(round.status == "setup")
        #expect(round.holeCount == 18)
        #expect(round.playerIDs.isEmpty)
        #expect(round.guestNames.isEmpty)
    }

    @Test("fixture() with custom values sets those values")
    func test_fixture_withCustomValues_setsCorrectly() {
        let courseID = UUID()
        let organizerID = UUID()
        let round = Round.fixture(
            courseID: courseID,
            organizerID: organizerID,
            playerIDs: ["id1", "id2"],
            guestNames: ["Guest"],
            holeCount: 9
        )
        #expect(round.courseID == courseID)
        #expect(round.organizerID == organizerID)
        #expect(round.playerIDs == ["id1", "id2"])
        #expect(round.guestNames == ["Guest"])
        #expect(round.holeCount == 9)
    }
}
