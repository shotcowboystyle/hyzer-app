import Testing
import Foundation
import SwiftData
import CloudKit
@testable import HyzerKit

/// End-to-end tests for `SyncEngine.pushRoundCompletion` exercising the real actor against
/// `MockCloudKitClient`. These tests are the canonical regression for AC #1: a completed
/// round writes an UPDATE to CloudKit that fires the `Round-complete-update` subscription.
///
/// In particular, this suite locks in the P0 fix that `pushRoundCompletion` uses
/// `.changedKeys` save policy — `.ifServerRecordUnchanged` (the default) would reject
/// every fresh-CKRecord update as `serverRecordChanged`, masked as `.synced` by the
/// catch clause, leaving the server record stuck in `status == "active"`.
@Suite("SyncEngine.pushRoundCompletion")
struct SyncEnginePushRoundCompletionTests {

    // MARK: - Happy path

    @Test("pushRoundCompletion writes a Round record with completion fields and status=completed")
    @MainActor
    func test_pushRoundCompletion_writesCompletionFields() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext
        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        let roundID = UUID()
        let organizerID = UUID()
        await engine.pushRoundCompletion(
            roundID: roundID,
            organizerID: organizerID,
            organizerFirstName: "Alice",
            courseName: "Cedar Creek",
            playerIDs: [organizerID.uuidString],
            createdAt: Date(),
            winnerFirstName: "Bob",
            winnerScoreDisplay: "-3"
        )

        #expect(mockCK.savedRecords.count == 1, "expected exactly one CK save")
        let record = mockCK.savedRecords[0]
        #expect(record.recordType == RoundRecord.recordType)
        #expect(record.recordID.recordName == roundID.uuidString)
        #expect(record["status"] as? String == "completed")
        #expect(record["winnerFirstName"] as? String == "Bob")
        #expect(record["winnerScoreDisplay"] as? String == "-3")
        #expect(record["organizerFirstName"] as? String == "Alice")
        #expect(record["courseName"] as? String == "Cedar Creek")
    }

    @Test("pushRoundCompletion uses .changedKeys save policy (P0 regression — was .ifServerRecordUnchanged)")
    @MainActor
    func test_pushRoundCompletion_usesChangedKeysPolicy() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )

        await engine.pushRoundCompletion(
            roundID: UUID(),
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Cedar Creek",
            playerIDs: [],
            createdAt: Date(),
            winnerFirstName: "Bob",
            winnerScoreDisplay: "-3"
        )

        #expect(mockCK.savedPolicies == [.changedKeys],
                "completion push must use .changedKeys — otherwise the UPDATE is rejected as serverRecordChanged and the subscription never fires")
    }

    @Test("pushRoundCompletion marks SyncMetadata .synced on success")
    @MainActor
    func test_pushRoundCompletion_marksSynced_onSuccess() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext
        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        let roundID = UUID()
        await engine.pushRoundCompletion(
            roundID: roundID,
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Cedar Creek",
            playerIDs: [],
            createdAt: Date(),
            winnerFirstName: "Bob",
            winnerScoreDisplay: "-3"
        )

        let idString = roundID.uuidString
        await awaitCondition {
            let all = (try? context.fetch(FetchDescriptor<SyncMetadata>())) ?? []
            return all.contains { $0.recordID == idString && $0.syncStatus == .synced }
        }
        let all = try context.fetch(FetchDescriptor<SyncMetadata>())
        let entry = all.first { $0.recordID == idString }
        #expect(entry?.syncStatus == .synced)
        #expect(entry?.lastAttempt != nil, "lastAttempt must be set on a push (distinguishes self-pushed from pull-side .synced)")
    }

    // MARK: - Idempotency / reentrancy

    @Test("pushRoundCompletion is idempotent — second call with .synced metadata is a no-op")
    @MainActor
    func test_pushRoundCompletion_idempotent_skipsWhenSynced() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )

        let roundID = UUID()
        let args: () async -> Void = {
            await engine.pushRoundCompletion(
                roundID: roundID,
                organizerID: UUID(),
                organizerFirstName: "Alice",
                courseName: "Cedar Creek",
                playerIDs: [],
                createdAt: Date(),
                winnerFirstName: "Bob",
                winnerScoreDisplay: "-3"
            )
        }

        await args()
        await args()

        #expect(mockCK.savedRecords.count == 1, "second push should be skipped — recordID metadata is .synced")
    }

    @Test("pushRoundCompletion proceeds when SyncMetadata is stale .inFlight (regression: must not block completion)")
    @MainActor
    func test_pushRoundCompletion_proceedsWhenStaleInFlight() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext

        // Simulate a stale .inFlight entry left from a crashed prior process.
        let roundID = UUID()
        let meta = SyncMetadata(recordID: roundID.uuidString, recordType: RoundRecord.recordType)
        meta.syncStatus = .inFlight
        meta.lastAttempt = Date(timeIntervalSinceNow: -3600) // 1 hour ago — clearly stale
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        await engine.pushRoundCompletion(
            roundID: roundID,
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Cedar Creek",
            playerIDs: [],
            createdAt: Date(),
            winnerFirstName: "Bob",
            winnerScoreDisplay: "-3"
        )

        #expect(mockCK.savedRecords.count == 1, "completion push must proceed even when prior metadata is stale .inFlight")
    }

    // MARK: - didRecentlyPushCompletion

    @Test("didRecentlyPushCompletion returns true right after pushRoundCompletion succeeds")
    @MainActor
    func test_didRecentlyPushCompletion_trueAfterPush() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )

        let roundID = UUID()
        await engine.pushRoundCompletion(
            roundID: roundID,
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Cedar Creek",
            playerIDs: [],
            createdAt: Date(),
            winnerFirstName: "Bob",
            winnerScoreDisplay: "-3"
        )

        let recent = await engine.didRecentlyPushCompletion(for: roundID)
        #expect(recent == true)
    }

    @Test("didRecentlyPushCompletion returns false for an unrelated roundID")
    @MainActor
    func test_didRecentlyPushCompletion_falseForUnrelatedRound() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )

        let recent = await engine.didRecentlyPushCompletion(for: UUID())
        #expect(recent == false)
    }

    @Test("didRecentlyPushCompletion returns false outside the recent window")
    @MainActor
    func test_didRecentlyPushCompletion_falseOutsideWindow() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext

        // Seed a .synced metadata entry with lastAttempt > 5min ago.
        let roundID = UUID()
        let meta = SyncMetadata(recordID: roundID.uuidString, recordType: RoundRecord.recordType)
        meta.syncStatus = .synced
        meta.lastAttempt = Date(timeIntervalSinceNow: -3600)
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        let recent = await engine.didRecentlyPushCompletion(for: roundID, within: 300)
        #expect(recent == false)
    }

    @Test("didRecentlyPushCompletion returns false for pull-side .synced (lastAttempt nil)")
    @MainActor
    func test_didRecentlyPushCompletion_falseForPullSideSynced() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext

        // Pull-side .synced entries have lastAttempt == nil.
        let roundID = UUID()
        let meta = SyncMetadata(recordID: roundID.uuidString, recordType: RoundRecord.recordType)
        meta.syncStatus = .synced
        meta.lastAttempt = nil
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        let recent = await engine.didRecentlyPushCompletion(for: roundID)
        #expect(recent == false, "lastAttempt nil signals pull-side .synced, not a self-push")
    }
}
