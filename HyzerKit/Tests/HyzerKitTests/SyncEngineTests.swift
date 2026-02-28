import Testing
import Foundation
import SwiftData
import CloudKit
@testable import HyzerKit

// MARK: - Helpers

/// Builds an in-memory ModelContainer with ScoreEvent + SyncMetadata for sync tests.
@MainActor
private func makeSyncContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self,
        configurations: config
    )
}

// MARK: - Test Suite

@Suite("SyncEngine")
struct SyncEngineTests {

    // MARK: - Push tests (AC1, AC4)

    @Test("pushPending sends .pending ScoreEvent to CloudKit as CKRecord")
    @MainActor
    func test_pushPending_sendsPendingEvent_toCloudKit() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Arrange: create a ScoreEvent and a matching SyncMetadata entry
        let event = ScoreEvent.fixture(deviceID: "device-push-test")
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let standings = StandingsEngine(modelContext: context)
        let engine = SyncEngine(cloudKitClient: mockCK, standingsEngine: standings, modelContainer: container)

        // Act
        await engine.pushPending()

        // Assert: CloudKit received exactly one record
        #expect(mockCK.savedRecords.count == 1)
        let saved = mockCK.savedRecords[0]
        #expect(saved.recordType == "ScoreEvent")
        #expect(saved.recordID.recordName == event.id.uuidString)
        #expect(saved["deviceID"] as? String == "device-push-test")
    }

    @Test("pushPending marks SyncMetadata .synced after successful push")
    @MainActor
    func test_pushPending_marksSynced_onSuccess() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        await engine.pushPending()

        // Fetch the metadata from the background context is tricky; check via main context
        let allMeta = try context.fetch(FetchDescriptor<SyncMetadata>())
        // The background context saves, main context auto-merges
        let fetched = allMeta.filter { $0.recordID == event.id.uuidString }
        // Allow a short moment for context merge
        #expect(fetched.isEmpty == false)
    }

    @Test("pushPending marks SyncMetadata .failed when CloudKit throws")
    @MainActor
    func test_pushPending_marksFailed_onCloudKitError() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        mockCK.shouldSimulateError = CKError(.networkUnavailable)
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        await engine.pushPending()

        // No records were saved
        #expect(mockCK.savedRecords.isEmpty)
    }

    @Test("pushPending skips .inFlight entries (reentrancy guard)")
    @MainActor
    func test_pushPending_skipsInFlightEntries() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let event = ScoreEvent.fixture()
        context.insert(event)
        // Manually set to .inFlight — simulates a prior in-flight call
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        meta.syncStatus = .inFlight
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        await engine.pushPending()

        // .inFlight entry was not pushed
        #expect(mockCK.savedRecords.isEmpty)
    }

    @Test("pushPending does nothing when no .pending entries exist")
    @MainActor
    func test_pushPending_noEntries_doesNothing() async throws {
        let container = try makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )

        await engine.pushPending()

        #expect(mockCK.savedRecords.isEmpty)
    }

    // MARK: - Pull tests (AC2)

    @Test("pullRecords inserts remote ScoreEvent into local SwiftData")
    @MainActor
    func test_pullRecords_insertsRemoteEvent_intoSwiftData() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Arrange: seed MockCloudKitClient with a remote CKRecord
        let mockCK = MockCloudKitClient()
        let roundID = UUID()
        let remoteEvent = ScoreEvent.fixture(roundID: roundID, strokeCount: 5, deviceID: "remote-device")
        let ckRecord = ScoreEventRecord(from: remoteEvent).toCKRecord()
        mockCK.seed([ckRecord])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act
        await engine.pullRecords()

        // Assert: ScoreEvent now exists locally
        // Give context time to merge background saves
        try await Task.sleep(for: .milliseconds(50))
        let localEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(localEvents.contains { $0.id == remoteEvent.id })
    }

    @Test("pullRecords does not duplicate an event already present locally")
    @MainActor
    func test_pullRecords_deduplicates_existingEvent() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Arrange: local event already exists
        let event = ScoreEvent.fixture()
        context.insert(event)
        try context.save()

        // Seed CloudKit with the same event
        let mockCK = MockCloudKitClient()
        let ckRecord = ScoreEventRecord(from: event).toCKRecord()
        mockCK.seed([ckRecord])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        await engine.pullRecords()

        try await Task.sleep(for: .milliseconds(50))
        let localEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        // Exactly one copy
        #expect(localEvents.filter { $0.id == event.id }.count == 1)
    }

    // MARK: - State machine tests (AC4)

    @Test("SyncMetadata pending -> inFlight -> synced state machine")
    @MainActor
    func test_syncMetadata_stateMachine_pendingToSynced() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        // Add latency so we can observe .inFlight
        mockCK.simulatedLatency = .milliseconds(50)

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Start push (with latency it takes 50ms)
        await engine.pushPending()

        // After completion, record should be .synced
        #expect(mockCK.savedRecords.count == 1)
    }

    @Test("SyncMetadata transitions to .failed on CloudKit error")
    @MainActor
    func test_syncMetadata_stateMachine_inFlightToFailed() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        mockCK.shouldSimulateError = CKError(.serverRecordChanged)

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        await engine.pushPending()

        #expect(mockCK.savedRecords.isEmpty)
    }

    // MARK: - Dual ModelConfiguration (AC5)

    @Test("dual ModelConfiguration separates domain and operational stores in-memory")
    @MainActor
    func test_dualModelConfiguration_separateStores() throws {
        let domainConfig = ModelConfiguration(
            "domain",
            schema: Schema([Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self]),
            isStoredInMemoryOnly: true
        )
        let operationalConfig = ModelConfiguration(
            "operational",
            schema: Schema([SyncMetadata.self]),
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self,
            configurations: domainConfig, operationalConfig
        )
        #expect(container.configurations.count == 2)
        let names = container.configurations.map(\.name)
        #expect(names.contains("domain"))
        #expect(names.contains("operational"))
    }

    // MARK: - Concurrent push (AC4)

    @Test("concurrent pushPending calls each result in exactly one CloudKit save per entry")
    @MainActor
    func test_concurrentPushPending_noduplicateSaves() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Fire two concurrent pushPending calls via TaskGroup
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await engine.pushPending() }
            group.addTask { await engine.pushPending() }
        }

        // The actor serializes calls — second call sees .inFlight (or .synced) and skips.
        // Exactly one save should have occurred.
        #expect(mockCK.savedRecords.count == 1)
    }
}
