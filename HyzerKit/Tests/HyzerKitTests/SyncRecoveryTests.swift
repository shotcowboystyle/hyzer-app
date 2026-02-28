import Testing
import Foundation
import SwiftData
import CloudKit
@testable import HyzerKit

// MARK: - Helpers

@MainActor
private func makeSyncContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self,
        configurations: config
    )
}

// MARK: - SyncRecoveryTests

@Suite("SyncRecovery")
struct SyncRecoveryTests {

    // MARK: - Offline → Online recovery (AC2, AC7, Task 10.1)

    @Test("offline events sync to CloudKit when connectivity is restored")
    @MainActor
    func test_offlineOnlineRecovery_pushesAllPendingEvents() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Arrange: create 3 events as if entered offline (SyncMetadata = .pending)
        let roundID = UUID()
        var eventIDs: [UUID] = []
        for i in 1...3 {
            let event = ScoreEvent.fixture(roundID: roundID, holeNumber: i)
            context.insert(event)
            let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
            meta.syncStatus = .pending
            context.insert(meta)
            eventIDs.append(event.id)
        }
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act: simulate connectivity restore via pushPending
        await engine.pushPending()

        // Assert: all 3 events were pushed to CloudKit
        #expect(mockCK.savedRecords.count == 3)
        let savedIDs = Set(mockCK.savedRecords.map { $0.recordID.recordName })
        for id in eventIDs {
            #expect(savedIDs.contains(id.uuidString))
        }
    }

    // MARK: - Extended offline recovery (AC7, Task 10.2)

    @Test("extended offline recovery — many local events all sync without duplication")
    @MainActor
    func test_extendedOfflineRecovery_noDataLossOrDuplication() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Simulate many events from a 4-hour offline period (18 holes × 4 players = 72 events)
        let roundID = UUID()
        let playerIDs = (1...4).map { _ in UUID().uuidString }
        var allEventIDs: [UUID] = []

        for hole in 1...18 {
            for playerID in playerIDs {
                let event = ScoreEvent.fixture(roundID: roundID, holeNumber: hole, playerID: playerID)
                context.insert(event)
                let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
                meta.syncStatus = .pending
                context.insert(meta)
                allEventIDs.append(event.id)
            }
        }
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act: flush all pending events
        await engine.pushPending()

        // Assert: all 72 events pushed, no duplicates
        #expect(mockCK.savedRecords.count == 72)
        let savedIDs = mockCK.savedRecords.map { $0.recordID.recordName }
        let uniqueIDs = Set(savedIDs)
        #expect(savedIDs.count == uniqueIDs.count)  // No duplicates in savedRecords

        // Verify each event was pushed exactly once
        for id in allEventIDs {
            #expect(savedIDs.filter { $0 == id.uuidString }.count == 1)
        }
    }

    // MARK: - Retry after failure (AC2, Task 4.4)

    @Test("retryFailed resets .failed entries to .pending and pushes them")
    @MainActor
    func test_retryFailed_resetsToPendingAndPushes() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Arrange: create events with .failed SyncMetadata
        let event1 = ScoreEvent.fixture(deviceID: "device-retry-1")
        let event2 = ScoreEvent.fixture(deviceID: "device-retry-2")
        context.insert(event1)
        context.insert(event2)

        let meta1 = SyncMetadata(recordID: event1.id.uuidString, recordType: "ScoreEvent")
        meta1.syncStatus = .failed
        let meta2 = SyncMetadata(recordID: event2.id.uuidString, recordType: "ScoreEvent")
        meta2.syncStatus = .failed
        context.insert(meta1)
        context.insert(meta2)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act: retry failed
        await engine.retryFailed()

        // Assert: both events were pushed to CloudKit
        #expect(mockCK.savedRecords.count == 2)

        // Verify SyncMetadata status is now .synced
        try await Task.sleep(for: .milliseconds(50))
        let allMeta = try context.fetch(FetchDescriptor<SyncMetadata>())
        let event1Meta = allMeta.first { $0.recordID == event1.id.uuidString }
        let event2Meta = allMeta.first { $0.recordID == event2.id.uuidString }
        #expect(event1Meta?.syncStatus == .synced)
        #expect(event2Meta?.syncStatus == .synced)
    }

    @Test("pushPending picks up both .pending and .failed entries")
    @MainActor
    func test_pushPending_picksBothPendingAndFailed() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let event1 = ScoreEvent.fixture(deviceID: "device-pending")
        let event2 = ScoreEvent.fixture(deviceID: "device-failed")
        context.insert(event1)
        context.insert(event2)

        let meta1 = SyncMetadata(recordID: event1.id.uuidString, recordType: "ScoreEvent")
        meta1.syncStatus = .pending
        let meta2 = SyncMetadata(recordID: event2.id.uuidString, recordType: "ScoreEvent")
        meta2.syncStatus = .failed
        context.insert(meta1)
        context.insert(meta2)
        try context.save()

        let mockCK = MockCloudKitClient()
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        await engine.pushPending()

        // Both .pending and .failed entries should be pushed
        #expect(mockCK.savedRecords.count == 2)
    }

    // MARK: - Deduplication under concurrent sync (Task 10.6)

    @Test("concurrent push and pull produce no duplicates in SwiftData")
    @MainActor
    func test_concurrentPushAndPull_noSwiftDataDuplicates() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Create a local event that will also arrive via pull
        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        // Also seed the same event in CloudKit (simulates remote copy)
        let mockCK = MockCloudKitClient()
        mockCK.seed([ScoreEventRecord(from: event).toCKRecord()])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Concurrent push and pull
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await engine.pushPending() }
            group.addTask { await engine.pullRecords() }
        }

        try await Task.sleep(for: .milliseconds(100))

        // Should have exactly one ScoreEvent (not a duplicate from pull)
        let localEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        let matchingEvents = localEvents.filter { $0.id == event.id }
        #expect(matchingEvents.count == 1)
    }

    // MARK: - SyncState bridge (Task 10.7)

    @Test("SyncEngine emits state changes on syncStateStream")
    @MainActor
    func test_syncStateStream_emitsSyncingState() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Seed a pending event
        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        // Add latency to observe .syncing state
        mockCK.simulatedLatency = .milliseconds(50)
        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        let collector = ValueCollector<String>()
        let streamTask = Task {
            for await state in await engine.syncStateStream {
                switch state {
                case .idle: await collector.append("idle")
                case .syncing: await collector.append("syncing")
                case .offline: await collector.append("offline")
                case .error: await collector.append("error")
                }
                if await collector.count >= 3 { break }
            }
        }

        // Trigger a sync cycle
        await engine.pushPending()

        try await Task.sleep(for: .milliseconds(200))
        streamTask.cancel()
        await streamTask.value

        let states = await collector.values
        // Should have observed: syncing, idle (state changes on pushPending)
        #expect(states.contains("syncing"))
        #expect(states.contains("idle"))
    }

    @Test("SyncEngine syncState is .offline when network error occurs")
    @MainActor
    func test_syncStateStream_emitsOffline_onNetworkError() async throws {
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

        let offlineReceived = OfflineReceivedBox()
        let streamTask = Task {
            for await state in await engine.syncStateStream {
                switch state {
                case .offline:
                    await offlineReceived.setTrue()
                    return
                case .syncing, .idle:
                    continue
                case .error:
                    return
                }
            }
        }

        await engine.pushPending()

        try await Task.sleep(for: .milliseconds(100))
        streamTask.cancel()
        await streamTask.value

        let received = await offlineReceived.value
        #expect(received == true)
    }

    // MARK: - CloudKitClient subscription tests (Task 2.4)

    @Test("MockCloudKitClient tracks subscribed record types")
    func test_mockCloudKitClient_tracksSubscriptions() async throws {
        let mockCK = MockCloudKitClient()
        let id = try await mockCK.subscribe(to: "ScoreEvent", predicate: NSPredicate(value: true))

        #expect(mockCK.subscribedRecordTypes == ["ScoreEvent"])
        #expect(id == "mock-subscription-ScoreEvent")
    }

    @Test("MockCloudKitClient tracks deleted subscription IDs")
    func test_mockCloudKitClient_tracksDeletedSubscriptions() async throws {
        let mockCK = MockCloudKitClient()
        try await mockCK.deleteSubscription("some-sub-id")

        #expect(mockCK.deletedSubscriptionIDs == ["some-sub-id"])
    }

    @Test("MockCloudKitClient returns pre-seeded existingSubscriptionIDs")
    func test_mockCloudKitClient_returnsExistingIDs() async throws {
        let mockCK = MockCloudKitClient()
        mockCK.existingSubscriptionIDs = ["id-1", "id-2"]

        let ids = try await mockCK.fetchAllSubscriptionIDs()
        #expect(ids == ["id-1", "id-2"])
    }
}

// MARK: - Thread-safe helpers for test assertions

private actor ValueCollector<T> {
    private(set) var values: [T] = []
    var count: Int { values.count }
    func append(_ value: T) { values.append(value) }
}

private actor OfflineReceivedBox {
    private(set) var value: Bool = false
    func setTrue() { value = true }
}
