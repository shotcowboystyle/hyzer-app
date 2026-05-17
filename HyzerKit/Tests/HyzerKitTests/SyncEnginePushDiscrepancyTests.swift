import Testing
import Foundation
import SwiftData
import CloudKit
@testable import HyzerKit

@Suite("SyncEngine.pushDiscrepancy")
struct SyncEnginePushDiscrepancyTests {

    @MainActor
    private func makeEngine(container: ModelContainer, mockCK: MockCloudKitClient) -> SyncEngine {
        SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
    }

    // MARK: - Happy path

    @Test("pushDiscrepancy saves a Discrepancy CKRecord with correct fields")
    @MainActor
    func test_pushDiscrepancy_savesCKRecord() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let engine = makeEngine(container: container, mockCK: mockCK)

        let did = UUID()
        let rid = UUID()
        let oid = UUID()
        await engine.pushDiscrepancy(
            discrepancyID: did,
            roundID: rid,
            organizerID: oid,
            playerID: "player-abc",
            holeNumber: 4,
            createdAt: Date()
        )

        #expect(mockCK.savedRecords.count == 1)
        let record = mockCK.savedRecords[0]
        #expect(record.recordType == DiscrepancyRecord.recordType)
        #expect(record.recordID.recordName == did.uuidString)
        #expect(record["roundID"] as? String == rid.uuidString)
        #expect(record["organizerID"] as? String == oid.uuidString)
        #expect(record["playerID"] as? String == "player-abc")
        #expect(record["holeNumber"] as? Int == 4)
    }

    @Test("pushDiscrepancy marks SyncMetadata .synced on success")
    @MainActor
    func test_pushDiscrepancy_marksSynced_onSuccess() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext
        let mockCK = MockCloudKitClient()
        let engine = makeEngine(container: container, mockCK: mockCK)

        let did = UUID()
        await engine.pushDiscrepancy(
            discrepancyID: did,
            roundID: UUID(),
            organizerID: UUID(),
            playerID: "p-1",
            holeNumber: 1,
            createdAt: Date()
        )

        await awaitCondition {
            let all = (try? context.fetch(FetchDescriptor<SyncMetadata>())) ?? []
            return all.contains { $0.recordID == did.uuidString && $0.syncStatus == .synced }
        }
        let all = try context.fetch(FetchDescriptor<SyncMetadata>())
        let entry = all.first { $0.recordID == did.uuidString }
        #expect(entry?.syncStatus == .synced)
    }

    // MARK: - serverRecordChanged → .synced idempotency

    @Test("pushDiscrepancy treats serverRecordChanged as success — marks .synced")
    @MainActor
    func test_pushDiscrepancy_serverRecordChanged_marksSynced() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext
        let mockCK = MockCloudKitClient()
        mockCK.shouldSimulateError = CKError(.serverRecordChanged)
        let engine = makeEngine(container: container, mockCK: mockCK)

        let did = UUID()
        await engine.pushDiscrepancy(
            discrepancyID: did,
            roundID: UUID(),
            organizerID: UUID(),
            playerID: "p-2",
            holeNumber: 2,
            createdAt: Date()
        )

        await awaitCondition {
            let all = (try? context.fetch(FetchDescriptor<SyncMetadata>())) ?? []
            return all.contains { $0.recordID == did.uuidString && $0.syncStatus == .synced }
        }
        let all = try context.fetch(FetchDescriptor<SyncMetadata>())
        let entry = all.first { $0.recordID == did.uuidString }
        #expect(entry?.syncStatus == .synced)
    }

    // MARK: - Network error → .failed

    @Test("pushDiscrepancy marks .failed on network error")
    @MainActor
    func test_pushDiscrepancy_networkError_marksFailed() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext
        let mockCK = MockCloudKitClient()
        mockCK.shouldSimulateError = CKError(.networkUnavailable)
        let engine = makeEngine(container: container, mockCK: mockCK)

        let did = UUID()
        await engine.pushDiscrepancy(
            discrepancyID: did,
            roundID: UUID(),
            organizerID: UUID(),
            playerID: "p-3",
            holeNumber: 3,
            createdAt: Date()
        )

        await awaitCondition {
            let all = (try? context.fetch(FetchDescriptor<SyncMetadata>())) ?? []
            return all.contains { $0.recordID == did.uuidString && $0.syncStatus == .failed }
        }
        let all = try context.fetch(FetchDescriptor<SyncMetadata>())
        let entry = all.first { $0.recordID == did.uuidString }
        #expect(entry?.syncStatus == .failed)
    }

    // MARK: - .synced idempotency (already-synced skips save)

    @Test("pushDiscrepancy is idempotent — skips when SyncMetadata is already .synced")
    @MainActor
    func test_pushDiscrepancy_alreadySynced_skips() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let context = container.mainContext
        let mockCK = MockCloudKitClient()
        let engine = makeEngine(container: container, mockCK: mockCK)

        let did = UUID()
        let meta = SyncMetadata(recordID: did.uuidString, recordType: DiscrepancyRecord.recordType)
        meta.syncStatus = .synced
        context.insert(meta)
        try context.save()

        await engine.pushDiscrepancy(
            discrepancyID: did,
            roundID: UUID(),
            organizerID: UUID(),
            playerID: "p-4",
            holeNumber: 4,
            createdAt: Date()
        )

        #expect(mockCK.savedRecords.isEmpty, "Already .synced entry must not trigger another CK save")
    }

    // MARK: - Uses default save policy (CREATE-only)

    @Test("pushDiscrepancy uses .ifServerRecordUnchanged save policy (CREATE-only, not UPDATE)")
    @MainActor
    func test_pushDiscrepancy_usesDefaultPolicy() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let engine = makeEngine(container: container, mockCK: mockCK)

        await engine.pushDiscrepancy(
            discrepancyID: UUID(),
            roundID: UUID(),
            organizerID: UUID(),
            playerID: "p-5",
            holeNumber: 5,
            createdAt: Date()
        )

        #expect(mockCK.savedPolicies == [.ifServerRecordUnchanged],
                "Discrepancy push is CREATE-only — must use default .ifServerRecordUnchanged, not .changedKeys")
    }
}
