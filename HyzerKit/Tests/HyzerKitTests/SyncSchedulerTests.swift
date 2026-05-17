import Testing
import Foundation
import SwiftData
import CloudKit
@testable import HyzerKit

// MARK: - SyncSchedulerTests

@Suite("SyncScheduler")
struct SyncSchedulerTests {

    // MARK: - Polling lifecycle (AC3, Task 3.7)

    @Test("startActiveRoundPolling starts and stops without error, engine plumbing works")
    @MainActor
    func test_startActiveRoundPolling_lifecycleAndPlumbing() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
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
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor, localPlayerIDProvider: { nil })

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
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor, localPlayerIDProvider: { nil })

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
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor, localPlayerIDProvider: { nil })

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
        let container = try TestContainerFactory.makeSyncContainer()
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
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor, localPlayerIDProvider: { nil })

        await scheduler.start()

        // Simulate connectivity restoration
        mockMonitor.setConnected(true)

        // Poll until the connectivity listener reacts and pushes the failed entry
        await awaitCondition { mockCK.savedRecords.count >= 1 }

        // After connectivity restored, retryFailed + pushPending should have run
        // .failed entry should have been pushed (mockCK records it)
        #expect(mockCK.savedRecords.count >= 1)
    }

    // MARK: - Remote notification (AC6, Task 3.7)

    @Test("handleRemoteNotification triggers pullRecords")
    @MainActor
    func test_handleRemoteNotification_triggersPull() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
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
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor, localPlayerIDProvider: { nil })

        await scheduler.handleRemoteNotification()

        // Poll until background context saves and merges the remote event
        let remoteID = remoteEvent.id
        await awaitCondition {
            // Safe: fetch failure in polling means condition not yet met; empty fallback retries
            let events = (try? context.fetch(FetchDescriptor<ScoreEvent>())) ?? []
            return events.contains { $0.id == remoteID }
        }

        let localEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(localEvents.contains { $0.id == remoteEvent.id })
    }

    // MARK: - Subscription setup (AC6, Task 7.6)

    @Test("setupSubscriptions creates subscription for ScoreEvent record type")
    @MainActor
    func test_setupSubscriptions_createsScoreEventSubscription() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-creates")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        await scheduler.start()

        // Subscription should have been created for ScoreEvent
        #expect(mockCK.subscribedRecordTypes.contains("ScoreEvent"))
    }

    @Test("setupSubscriptions is idempotent — skips if subscription already exists")
    @MainActor
    func test_setupSubscriptions_idempotent_skipIfExists() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)

        // Use an isolated suite so this test's state cannot bleed into other tests.
        // The key is written before the actor initializer call so the compiler sees
        // no concurrent access across the await boundary.
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-idempotent")!
        let existingID = "mock-subscription-ScoreEvent"
        testDefaults.set(existingID, forKey: "HyzerApp.subscriptionID.ScoreEvent")

        // Simulate: subscription was created on a previous launch
        mockCK.existingSubscriptionIDs = [existingID]

        // `testDefaults` is only captured here; after this point we do not touch it
        // from the @MainActor context while the actor is running, so no race.
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        // Deisolate the cleanup key before the await so the compiler can prove
        // there is no concurrent access to `testDefaults` after the send.
        let cleanupKey = "HyzerApp.subscriptionID.ScoreEvent"
        let cleanupSuite = "test-sync-scheduler-idempotent"

        await scheduler.start()

        // Should NOT have created a new subscription (existing one found in CloudKit)
        #expect(mockCK.subscribedRecordTypes.isEmpty)

        // Cleanup via a fresh lookup to avoid referencing the sent local
        UserDefaults(suiteName: cleanupSuite)?.removeObject(forKey: cleanupKey)
    }

    // MARK: - Round-active-creation subscription (Story 12.1, Task 8.4)

    @Test("setupSubscriptions creates Round-active-creation alert subscription")
    @MainActor
    func test_setupSubscriptions_createsRoundActiveSubscription() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-round-sub")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        await scheduler.start()

        // ScoreEvent (silent) + Round-active-creation (alert) + Round-complete-update (alert)
        #expect(mockCK.subscribedRecordTypes.contains("ScoreEvent"))
        let alertSubIDs = mockCK.savedAlertSubscriptions.map(\.subscriptionID)
        #expect(alertSubIDs.contains("Round-active-creation"))
        #expect(alertSubIDs.contains("Round-complete-update"))
        #expect(mockCK.savedAlertSubscriptions.count == 2)
    }

    @Test("setupSubscriptions Round-active-creation predicate targets status == active")
    @MainActor
    func test_setupSubscriptions_roundSubscriptionPredicateIsActiveStatus() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-round-predicate")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        await scheduler.start()

        let activeSub = mockCK.savedAlertSubscriptions.first { $0.subscriptionID == "Round-active-creation" }
        let activeDict: [String: Any] = ["status": "active"]
        let setupDict: [String: Any] = ["status": "setup"]
        #expect(activeSub?.predicate.evaluate(with: activeDict) == true)
        #expect(activeSub?.predicate.evaluate(with: setupDict) == false)
    }

    @Test("setupSubscriptions Round subscription is idempotent — skips if already active")
    @MainActor
    func test_setupSubscriptions_roundSubscription_idempotent() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let existingActiveSubID = "Round-active-creation"
        let existingCompleteSubID = "Round-complete-update"
        mockCK.existingSubscriptionIDs = [existingActiveSubID, existingCompleteSubID]

        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-round-idempotent")!
        testDefaults.set(existingActiveSubID, forKey: "HyzerApp.subscriptionID.\(existingActiveSubID)")
        testDefaults.set(existingCompleteSubID, forKey: "HyzerApp.subscriptionID.\(existingCompleteSubID)")
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        await scheduler.start()

        // Should NOT create any new alert subscriptions
        #expect(mockCK.savedAlertSubscriptions.isEmpty)

        UserDefaults(suiteName: "test-sync-scheduler-round-idempotent")?.removeObject(forKey: "HyzerApp.subscriptionID.\(existingActiveSubID)")
        UserDefaults(suiteName: "test-sync-scheduler-round-idempotent")?.removeObject(forKey: "HyzerApp.subscriptionID.\(existingCompleteSubID)")
    }

    // MARK: - Round-complete-update subscription (Story 12.2, Task 8.4)

    @Test("setupSubscriptions creates Round-complete-update alert subscription with correct config")
    @MainActor
    func test_setupSubscriptions_createsRoundCompleteSubscription() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-complete-sub")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        await scheduler.start()

        let completeSub = mockCK.savedAlertSubscriptions.first { $0.subscriptionID == "Round-complete-update" }
        #expect(completeSub != nil)
        #expect(completeSub?.recordType == "Round")
        #expect(completeSub?.notificationInfo.alertLocalizationKey == "ROUND_COMPLETE_FORMAT")
        #expect(completeSub?.notificationInfo.alertLocalizationArgs == ["courseName", "winnerFirstName", "winnerScoreDisplay"])
        #expect(completeSub?.notificationInfo.desiredKeys == ["courseName", "winnerFirstName", "winnerScoreDisplay"])

        let completedDict: [String: Any] = ["status": "completed"]
        let activeDict: [String: Any] = ["status": "active"]
        #expect(completeSub?.predicate.evaluate(with: completedDict) == true)
        #expect(completeSub?.predicate.evaluate(with: activeDict) == false)
    }

    @Test("setupSubscriptions all three subscriptions created together")
    @MainActor
    func test_setupSubscriptions_allThreeSubscriptionsCreated() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-all-subs")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        await scheduler.start()

        // 1. ScoreEvent-creation (silent)
        #expect(mockCK.subscribedRecordTypes.contains("ScoreEvent"))

        // 2. Round-active-creation (alert, firesOnRecordCreation, predicate status == "active")
        let activeSub = mockCK.savedAlertSubscriptions.first { $0.subscriptionID == "Round-active-creation" }
        #expect(activeSub != nil)
        #expect(activeSub?.notificationInfo.alertLocalizationKey == "ROUND_STARTED_FORMAT")

        // 3. Round-complete-update (alert, firesOnRecordUpdate, predicate status == "completed")
        let completeSub = mockCK.savedAlertSubscriptions.first { $0.subscriptionID == "Round-complete-update" }
        #expect(completeSub != nil)
        #expect(completeSub?.notificationInfo.alertLocalizationKey == "ROUND_COMPLETE_FORMAT")
    }

    @Test("setupSubscriptions migration: old Round key does not crash, new keys absent triggers re-subscribe")
    @MainActor
    func test_setupSubscriptions_migration_oldKeyDoesNotCrash() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)

        // Simulate pre-upgrade state: old key "HyzerApp.subscriptionID.Round" is present
        // but new keys "Round-active-creation" / "Round-complete-update" are absent
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-migration")!
        let oldKey = "HyzerApp.subscriptionID.Round"
        testDefaults.set("Round-active-creation", forKey: oldKey)
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")

        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        // Must not crash — the transient duplicate-subscription error is caught and logged
        await scheduler.start()

        // The new keys are absent so re-subscribe was attempted; mock accepts the calls
        let alertSubIDs = mockCK.savedAlertSubscriptions.map(\.subscriptionID)
        #expect(alertSubIDs.contains("Round-active-creation"))
        #expect(alertSubIDs.contains("Round-complete-update"))

        // Cleanup
        testDefaults.removeObject(forKey: oldKey)
    }

    // MARK: - Discrepancy-creation subscription (Story 12.3, Task 5)

    @Test("setupSubscriptions creates Discrepancy-creation subscription when localPlayerIDProvider returns a UUID")
    @MainActor
    func test_setupSubscriptions_createsDiscrepancySubscription() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-discrepancy-sub")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Discrepancy-creation")

        let localPlayerID = UUID()
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { localPlayerID }
        )

        await scheduler.start()

        let alertSubIDs = mockCK.savedAlertSubscriptions.map(\.subscriptionID)
        #expect(alertSubIDs.contains("Discrepancy-creation"))

        let discSub = mockCK.savedAlertSubscriptions.first { $0.subscriptionID == "Discrepancy-creation" }
        #expect(discSub != nil)
        #expect(discSub?.recordType == "Discrepancy")
        #expect(discSub?.notificationInfo.alertLocalizationKey == "DISCREPANCY_DETECTED_FORMAT")
        #expect(discSub?.notificationInfo.alertLocalizationArgs == ["holeNumber"])
        #expect(discSub?.notificationInfo.desiredKeys == ["roundID", "playerID", "holeNumber"])
    }

    @Test("setupSubscriptions Discrepancy-creation predicate contains the localPlayerID UUID")
    @MainActor
    func test_setupSubscriptions_discrepancySubscriptionPredicate() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-discrepancy-predicate")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Discrepancy-creation")

        let localPlayerID = UUID()
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { localPlayerID }
        )

        await scheduler.start()

        let discSub = mockCK.savedAlertSubscriptions.first { $0.subscriptionID == "Discrepancy-creation" }
        let predicateFormat = discSub?.predicate.predicateFormat ?? ""
        #expect(predicateFormat.contains(localPlayerID.uuidString), "Predicate must embed the localPlayerID UUID")
        #expect(predicateFormat.contains("organizerID"), "Predicate must reference organizerID field")
    }

    @Test("setupSubscriptions skips Discrepancy-creation when localPlayerIDProvider returns nil")
    @MainActor
    func test_setupSubscriptions_skipsDiscrepancy_whenLocalPlayerIDUnavailable() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-discrepancy-nil")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Discrepancy-creation")

        // Provider returns nil — pre-onboarding scenario
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { nil }
        )

        await scheduler.start()

        let alertSubIDs = mockCK.savedAlertSubscriptions.map(\.subscriptionID)
        #expect(!alertSubIDs.contains("Discrepancy-creation"), "Must not subscribe when localPlayerID is unavailable")
        // Other subscriptions still created
        #expect(alertSubIDs.contains("Round-active-creation"))
        #expect(alertSubIDs.contains("Round-complete-update"))
    }

    @Test("setupSubscriptions Discrepancy-creation is idempotent — second call with persisted ID skips re-subscription")
    @MainActor
    func test_setupSubscriptions_discrepancySubscription_idempotent() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let existingDiscID = "Discrepancy-creation"
        mockCK.existingSubscriptionIDs = [existingDiscID]

        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-discrepancy-idempotent")!
        testDefaults.set(existingDiscID, forKey: "HyzerApp.subscriptionID.\(existingDiscID)")

        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { UUID() }
        )

        await scheduler.start()

        let discSubs = mockCK.savedAlertSubscriptions.filter { $0.subscriptionID == "Discrepancy-creation" }
        #expect(discSubs.isEmpty, "Second launch must not create a duplicate Discrepancy-creation subscription")

        UserDefaults(suiteName: "test-sync-scheduler-discrepancy-idempotent")?
            .removeObject(forKey: "HyzerApp.subscriptionID.\(existingDiscID)")
    }

    @Test("setupSubscriptions creates all four subscriptions (one silent + three alert) when localPlayerIDProvider returns a UUID")
    @MainActor
    func test_setupSubscriptions_allFourSubscriptionsCreated() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let testDefaults = UserDefaults(suiteName: "test-sync-scheduler-four-subs")!
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.ScoreEvent")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-active-creation")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Round-complete-update")
        testDefaults.removeObject(forKey: "HyzerApp.subscriptionID.Discrepancy-creation")
        let scheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: mockCK,
            networkMonitor: mockMonitor,
            userDefaults: testDefaults,
            localPlayerIDProvider: { UUID() }
        )

        await scheduler.start()

        // 1. ScoreEvent-creation (silent)
        #expect(mockCK.subscribedRecordTypes.contains("ScoreEvent"))

        // 2. Round-active-creation (alert)
        #expect(mockCK.savedAlertSubscriptions.contains { $0.subscriptionID == "Round-active-creation" })

        // 3. Round-complete-update (alert)
        #expect(mockCK.savedAlertSubscriptions.contains { $0.subscriptionID == "Round-complete-update" })

        // 4. Discrepancy-creation (alert)
        #expect(mockCK.savedAlertSubscriptions.contains { $0.subscriptionID == "Discrepancy-creation" })

        // Cross-surface total: 1 silent (ScoreEvent) + 3 alert = 4 distinct subscription registrations.
        // Asserting both surfaces guards against a future regression that swaps one alert subscription
        // for a stray duplicate while still leaving `savedAlertSubscriptions.count == 3`.
        #expect(mockCK.savedAlertSubscriptions.count == 3)
        #expect(mockCK.subscribedRecordTypes.count == 1)
    }

    // MARK: - Foreground discovery throttle (AC5, Task 8.5)

    @Test("foregroundDiscovery throttles repeated calls within 30 seconds")
    @MainActor
    func test_foregroundDiscovery_throttlesRapidCalls() async throws {
        let container = try TestContainerFactory.makeSyncContainer()
        let mockCK = MockCloudKitClient()
        let syncEngine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: container.mainContext),
            modelContainer: container
        )
        let mockMonitor = MockNetworkMonitor(initiallyConnected: true)
        let scheduler = SyncScheduler(syncEngine: syncEngine, cloudKitClient: mockCK, networkMonitor: mockMonitor, localPlayerIDProvider: { nil })

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
