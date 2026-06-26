import Testing
import SwiftData
import CloudKit
import Foundation
@testable import HyzerKit
import TestSupport

/// Story 15.11 — Journey 2 (kit half): score correction + conflict detection.
///
/// Covers the kit-level invariants:
///   1. `ScoringService.correctScore` is append-only: the original event is
///      preserved, the new event has `supersedesEventID` pointing to the original.
///   2. `SyncEngine.pullRecords` materializes a remote `ScoreEvent` that conflicts
///      with a local one (same round/player/hole, different stroke count) by
///      creating a `Discrepancy` record (the conflict path in SyncEngine).
@Suite("Integration — Score Correction & Conflict (kit)")
@MainActor
struct ScoreCorrectionConflictTests {

    @Test("correctScore creates new ScoreEvent with supersedesEventID set; original is unmodified")
    func test_correctScore_appendOnlyInvariant() throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        // Original score.
        let original = try harness.scoringService.createScoreEvent(
            roundID: round.id,
            holeNumber: 1,
            playerID: alice.id.uuidString,
            strokeCount: 5,
            reportedByPlayerID: alice.id
        )
        #expect(original.supersedesEventID == nil)
        let originalID = original.id

        // Correction.
        let corrected = try harness.scoringService.correctScore(
            previousEventID: original.id,
            roundID: round.id,
            holeNumber: 1,
            playerID: alice.id.uuidString,
            strokeCount: 3,
            reportedByPlayerID: alice.id
        )
        #expect(corrected.supersedesEventID == originalID)
        #expect(corrected.strokeCount == 3)
        #expect(corrected.id != originalID)

        // Original event is still present and unmodified.
        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.count == 2)
        let originalReloaded = try #require(events.first { $0.id == originalID })
        #expect(originalReloaded.strokeCount == 5)
        #expect(originalReloaded.supersedesEventID == nil)
    }

    @Test("correctScore with unknown previousEventID throws previousEventNotFound")
    func test_correctScore_unknownPreviousID_throws() throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        #expect(throws: ScoringServiceError.self) {
            _ = try harness.scoringService.correctScore(
                previousEventID: UUID(), // unknown
                roundID: round.id,
                holeNumber: 1,
                playerID: alice.id.uuidString,
                strokeCount: 3,
                reportedByPlayerID: alice.id
            )
        }
    }

    @Test("SyncEngine.pullRecords with a remote ScoreEvent conflicting with a local one creates a Discrepancy")
    func test_pullRecords_conflictingRemoteEvent_createsDiscrepancy() async throws {
        let harness = try IntegrationKitHarness.make(deviceID: "phone-local")
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        // Seed a LOCAL ScoreEvent for (round, alice, hole 1, strokes 3).
        let localEvent = try harness.scoringService.createScoreEvent(
            roundID: round.id,
            holeNumber: 1,
            playerID: alice.id.uuidString,
            strokeCount: 3,
            reportedByPlayerID: alice.id
        )

        // Construct a REMOTE CKRecord ScoreEvent for the same (round, alice, hole 1)
        // but with a different id and a different strokeCount → conflict.
        let remoteEventID = UUID()
        let remoteReportedByID = UUID()
        let remoteRecord = ScoreEventRecord(
            id: remoteEventID,
            roundID: round.id,
            holeNumber: 1,
            playerID: alice.id.uuidString,
            strokeCount: 5,
            supersedesEventID: nil,
            reportedByPlayerID: remoteReportedByID,
            deviceID: "phone-remote",
            createdAt: localEvent.createdAt.addingTimeInterval(1)
        ).toCKRecord()
        harness.cloudKit.seed([remoteRecord])

        // Pull — SyncEngine materializes the remote event and the conflict path
        // creates a Discrepancy because two different events exist for the same
        // (round, player, hole) and neither supersedes the other.
        await harness.syncEngine.pullRecords()

        let discrepancies = try harness.container.mainContext.fetch(FetchDescriptor<Discrepancy>())
        let roundIDLocal = round.id
        let playerIDLocal = alice.id.uuidString
        let matching = discrepancies.first { d in
            d.roundID == roundIDLocal && d.playerID == playerIDLocal && d.holeNumber == 1
        }
        let conflict = try #require(matching,
            "SyncEngine.pullRecords must create a Discrepancy for (round, alice, hole 1) when a conflicting remote event arrives")
        #expect(conflict.status == .unresolved)
        // The two event IDs reference the conflicting pair (order may vary by sort).
        let pair: Set<UUID> = [conflict.eventID1, conflict.eventID2]
        #expect(pair == [localEvent.id, remoteEventID])
    }
}
