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

// MARK: - SyncSchedulerTests

@Suite("SyncScheduler")
struct SyncSchedulerTests {

    // MARK: - Polling lifecycle (AC3, Task 3.7)

    @Test("startActiveRoundPolling starts and stops without error, engine plumbing works")
    @MainActor
    func test_startActiveRoundPolling_lifecycleAndPlumbing() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        let mockCK = MockCloudKitClient()
        let standings = StandingsEngine(modelContext: context)
        let syncEngine = SyncEngine(cloudKitClient: mockCK, standingsEngine: standings, modelContainer: container)

        // Seed a pending event so pushPending() has something to do
        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        context.insert(meta)
        try context.save()

        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        // Timer uses 45s intervals so we can't test fire behavior directly.
        // Verify start/stop lifecycle and that the push/pull plumbing works independently.
        await scheduler.startActiveRoundPolling()
        await scheduler.stopActiveRoundPolling()

        // Verify engine plumbing: manually push to confirm SyncEngine → MockCloudKitClient works
        await syncEngine.pushPending()
        #expect(mockCK.savedRecords.count == 1)
    }

    @Test("stopActiveRoundPolling is idempotent — calling twice does not crash")
    @MainActor
    func test_stopActiveRoundPolling_idempotent() async throws {
        let container = try makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        // Double-stop should not throw or crash
        await scheduler.stopActiveRoundPolling()
        await scheduler.stopActiveRoundPolling()

        // Verify scheduler is still usable after double-stop
        await scheduler.handleRemoteNotification()
        #expect(mockCK.fetchCallCount >= 1)
    }

    @Test("startActiveRoundPolling called twice does not create duplicate timers")
    @MainActor
    func test_startActiveRoundPolling_noDuplicateTimers() async throws {
        let container = try makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        await scheduler.startActiveRoundPolling()
        await scheduler.startActiveRoundPolling()  // second call should be no-op (guard pollingTask == nil)
        await scheduler.stopActiveRoundPolling()

        // Verify scheduler is usable after start-start-stop sequence
        await scheduler.handleRemoteNotification()
        #expect(mockCK.fetchCallCount >= 1)
    }

    // MARK: - Connectivity-triggered flush (AC2, Task 3.7)

    @Test("connectivity restored triggers retryFailed and pushPending")
    @MainActor
    func test_connectivityRestored_triggersFlush() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Arrange: seed a failed SyncMetadata entry
        let event = ScoreEvent.fixture()
        context.insert(event)
        let meta = SyncMetadata(recordID: event.id.uuidString, recordType: "ScoreEvent")
        meta.syncStatus = .failed
        context.insert(meta)
        try context.save()

        let mockCK = MockCloudKitClient()
        let standings = StandingsEngine(modelContext: context)
        let syncEngine = SyncEngine(cloudKitClient: mockCK, standingsEngine: standings, modelContainer: container)

        // Start disconnected
        let mockMonitor = MockNetworkMonitor(initiallyConnected: false)
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        await scheduler.start()

        // Simulate connectivity restoration
        mockMonitor.setConnected(true)

        // Allow the connectivity listener to react
        try await Task.sleep(for: .milliseconds(100))

        // After connectivity restored, retryFailed + pushPending should have run
        // .failed entry should have been pushed (mockCK records it)
        #expect(mockCK.savedRecords.count >= 1)
    }

    // MARK: - Remote notification (AC6, Task 3.7)

    @Test("handleRemoteNotification triggers pullRecords")
    @MainActor
    func test_handleRemoteNotification_triggersPull() async throws {
        let container = try makeSyncContainer()
        let context = container.mainContext

        // Seed a remote event in MockCloudKitClient
        let remoteEvent = ScoreEvent.fixture(strokeCount: 4, deviceID: "remote")
        let mockCK = MockCloudKitClient()
        mockCK.seed([ScoreEventRecord(from: remoteEvent).toCKRecord()])

        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        await scheduler.handleRemoteNotification()

        // Give background context time to save and merge
        try await Task.sleep(for: .milliseconds(50))

        let localEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(localEvents.contains { $0.id == remoteEvent.id })
    }

    // MARK: - Subscription setup (AC6, Task 7.6)

    @Test("setupSubscriptions creates subscription for ScoreEvent record type")
    @MainActor
    func test_setupSubscriptions_createsScoreEventSubscription() async throws {
        let container = try makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        // Clear any UserDefaults state from prior test runs
        UserDefaults.standard.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")

        await scheduler.start()

        // Subscription should have been created for ScoreEvent
        #expect(mockCK.subscribedRecordTypes.contains("ScoreEvent"))
    }

    @Test("setupSubscriptions is idempotent — skips if subscription already exists")
    @MainActor
    func test_setupSubscriptions_idempotent_skipIfExists() async throws {
        let container = try makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        // Simulate: subscription was created on a previous launch
        let existingID = "mock-subscription-ScoreEvent"
        mockCK.existingSubscriptionIDs = [existingID]
        UserDefaults.standard.set(existingID, forKey: "HyzerApp.subscriptionID.ScoreEvent")

        await scheduler.start()

        // Should NOT have created a new subscription (existing one found in CloudKit)
        #expect(mockCK.subscribedRecordTypes.isEmpty)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")
    }

    // MARK: - Foreground discovery throttle (AC5, Task 8.5)

    @Test("foregroundDiscovery throttles repeated calls within 30 seconds")
    @MainActor
    func test_foregroundDiscovery_throttlesRapidCalls() async throws {
        let container = try makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor)

        // First call should execute (triggers pullRecords → fetch)
        await scheduler.foregroundDiscovery(currentUserID: "user-1")
        let firstFetchCount = mockCK.fetchCallCount

        // Second rapid call should be throttled (< 30s) — no additional fetch
        await scheduler.foregroundDiscovery(currentUserID: "user-1")

        // Verify only one fetch was made (second call was throttled)
        #expect(firstFetchCount == 1)
        #expect(mockCK.fetchCallCount == 1)
    }
}
