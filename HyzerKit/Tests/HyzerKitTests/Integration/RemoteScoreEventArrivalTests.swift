import Testing
import SwiftData
import CloudKit
import Foundation
@testable import HyzerKit
import TestSupport

/// Story 15.11 — Journey 3 (kit half): non-conflicting remote `ScoreEvent`
/// arrival via `SyncEngine.pullRecords` merges cleanly into the local store.
///
/// Companion to `ScoreCorrectionConflictTests` which exercises the conflicting path.
@Suite("Integration — Remote ScoreEvent Arrival (kit)")
@MainActor
struct RemoteScoreEventArrivalTests {

    @Test("pullRecords with a remote ScoreEvent for a new (round, player, hole) inserts the event locally")
    func test_pullRecords_newRemoteEvent_insertsLocally() async throws {
        let harness = try IntegrationKitHarness.make(deviceID: "phone-local")
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let bob = try harness.seedPlayer(displayName: "Bob")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString, bob.id.uuidString],
            holeCount: 3
        )

        // No local score events yet. Remote: Bob scored 2 on hole 1.
        let remoteID = UUID()
        let record = ScoreEventRecord(
            id: remoteID,
            roundID: round.id,
            holeNumber: 1,
            playerID: bob.id.uuidString,
            strokeCount: 2,
            supersedesEventID: nil,
            reportedByPlayerID: bob.id,
            deviceID: "phone-remote",
            createdAt: Date()
        ).toCKRecord()
        harness.cloudKit.seed([record])

        await harness.syncEngine.pullRecords()

        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        let materialized = try #require(events.first { $0.id == remoteID })
        #expect(materialized.playerID == bob.id.uuidString)
        #expect(materialized.holeNumber == 1)
        #expect(materialized.strokeCount == 2)
        #expect(materialized.deviceID == "phone-remote")

        // No discrepancy — non-conflicting.
        let discrepancies = try harness.container.mainContext.fetch(FetchDescriptor<Discrepancy>())
        #expect(discrepancies.isEmpty)
    }

    @Test("pullRecords is idempotent: same remote event delivered twice yields one local record")
    func test_pullRecords_idempotentOnSameRecord() async throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        let remoteID = UUID()
        let record = ScoreEventRecord(
            id: remoteID,
            roundID: round.id,
            holeNumber: 1,
            playerID: alice.id.uuidString,
            strokeCount: 3,
            supersedesEventID: nil,
            reportedByPlayerID: alice.id,
            deviceID: "phone-remote",
            createdAt: Date()
        ).toCKRecord()
        // `MockCloudKitClient.seed` keeps records in a stable store — every fetch
        // returns the same set, which mimics CloudKit's persistent store.
        harness.cloudKit.seed([record])

        await harness.syncEngine.pullRecords()
        await harness.syncEngine.pullRecords()

        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        let matching = events.filter { $0.id == remoteID }
        #expect(matching.count == 1, "second pull must NOT duplicate the event — idempotent on record ID")
    }

    @Test("Recompute after remote arrival: standings reflect the materialised remote event")
    func test_pullRecords_thenRecompute_standingsReflectRemoteEvent() async throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let bob = try harness.seedPlayer(displayName: "Bob")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString, bob.id.uuidString],
            holeCount: 3
        )

        // Alice scores 3 locally on hole 1.
        _ = try harness.scoringService.createScoreEvent(
            roundID: round.id,
            holeNumber: 1,
            playerID: alice.id.uuidString,
            strokeCount: 3,
            reportedByPlayerID: alice.id
        )

        // Bob's hole 1 arrives via CloudKit.
        let record = ScoreEventRecord(
            id: UUID(),
            roundID: round.id,
            holeNumber: 1,
            playerID: bob.id.uuidString,
            strokeCount: 2,
            supersedesEventID: nil,
            reportedByPlayerID: bob.id,
            deviceID: "phone-remote",
            createdAt: Date()
        ).toCKRecord()
        harness.cloudKit.seed([record])
        await harness.syncEngine.pullRecords()

        harness.standingsEngine.recompute(for: round.id, trigger: .remoteSync)
        let standings = harness.standingsEngine.currentStandings
        #expect(standings.count == 2)
        // Bob (2 strokes) leads Alice (3 strokes).
        #expect(standings[0].playerID == bob.id.uuidString)
        #expect(standings[0].totalStrokes == 2)
        #expect(standings[1].playerID == alice.id.uuidString)
        #expect(standings[1].totalStrokes == 3)
    }
}
