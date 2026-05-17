import Testing
import SwiftData
import CloudKit
import Foundation
@testable import HyzerKit
@testable import HyzerApp

// MARK: - Test stubs

private final class StubCloudKitClientApp: CloudKitClient, @unchecked Sendable {
    /// Count of `fetch(matching:in:)` invocations. Used as a proxy for `SyncEngine.pullRecords()` calls.
    private(set) var fetchCallCount = 0
    func save(_ records: [CKRecord]) async throws -> [CKRecord] { [] }
    func fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord] {
        fetchCallCount += 1
        return []
    }
    func subscribe(to recordType: CKRecord.RecordType, predicate: NSPredicate) async throws -> CKSubscription.ID { "" }
    func deleteSubscription(_ subscriptionID: CKSubscription.ID) async throws {}
    func fetchAllSubscriptionIDs() async throws -> [CKSubscription.ID] { [] }
    func subscribeWithAlert(
        to recordType: CKRecord.RecordType,
        predicate: NSPredicate,
        subscriptionID: CKSubscription.ID,
        notificationInfo: CKSubscription.NotificationInfo
    ) async throws -> CKSubscription.ID { subscriptionID }
}

private struct StubNetworkMonitorApp: NetworkMonitor {
    var isConnected: Bool { true }
    var pathUpdates: AsyncStream<Bool> { AsyncStream { _ in } }
}

private struct StubICloudIdentityProvider: ICloudIdentityProvider, @unchecked Sendable {
    func resolveIdentity() async throws -> ICloudIdentityResult { .unavailable(reason: .couldNotDetermine) }
}

// MARK: - AppServicesTests

@Suite("AppServices")
@MainActor
struct AppServicesTests {

    private func makeServices(
        notificationService: MockNotificationService = MockNotificationService(),
        cloudKitClient: StubCloudKitClientApp = StubCloudKitClientApp()
    ) throws -> AppServices {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self, Discrepancy.self,
            configurations: config
        )
        return AppServices(
            modelContainer: container,
            iCloudIdentityProvider: StubICloudIdentityProvider(),
            cloudKitClient: cloudKitClient,
            networkMonitor: StubNetworkMonitorApp(),
            notificationService: notificationService
        )
    }

    // MARK: - Task 8.5: Self-exclusion at AppServices level

    @Test("handleRoundStartedNotification does NOT set pendingDeepLink (and does NOT trigger pullRecords) when organizer matches local player")
    func test_handleRoundStartedNotification_selfExclusion_doesNotSetDeepLink() async throws {
        let mockNotif = MockNotificationService()
        let cloudKit = StubCloudKitClientApp()
        let services = try makeServices(notificationService: mockNotif, cloudKitClient: cloudKit)

        let organizerID = UUID()
        let payload = RoundStartedPayload(
            roundID: UUID(),
            organizerID: organizerID,
            organizerFirstName: "Mike",
            courseName: "Cedar Creek"
        )
        mockNotif.payloadToReturn = payload
        mockNotif.suppressionResult = true // simulate organizer == localPlayer

        await services.handleRoundStartedNotification(["test": "value"])

        #expect(services.pendingDeepLink == nil)
        // Self-exclusion must short-circuit BEFORE pullRecords — verifies the battery /
        // CloudKit-chatter contract documented at AppServices.handleRoundStartedNotification.
        #expect(cloudKit.fetchCallCount == 0)
    }

    @Test("handleRoundStartedNotification sets pendingDeepLink when organizer is different player")
    func test_handleRoundStartedNotification_nonOrganizer_setsDeepLink() async throws {
        let mockNotif = MockNotificationService()
        let services = try makeServices(notificationService: mockNotif)

        let roundID = UUID()
        let payload = RoundStartedPayload(
            roundID: roundID,
            organizerID: UUID(),
            organizerFirstName: "Mike",
            courseName: "Cedar Creek"
        )
        mockNotif.payloadToReturn = payload
        mockNotif.suppressionResult = false // different player

        await services.handleRoundStartedNotification(["test": "value"])

        if case .activeRound(let id) = services.pendingDeepLink {
            #expect(id == roundID)
        } else {
            #expect(Bool(false), "pendingDeepLink should be .activeRound(roundID:)")
        }
    }

    @Test("handleRoundStartedNotification ignores unrecognised payload")
    func test_handleRoundStartedNotification_nilPayload_noSideEffects() async throws {
        let mockNotif = MockNotificationService()
        let services = try makeServices(notificationService: mockNotif)

        mockNotif.payloadToReturn = nil // simulate unrecognised payload

        await services.handleRoundStartedNotification([:])

        #expect(services.pendingDeepLink == nil)
    }

    // MARK: - Task 8.7: Lazy permission — startSync must NOT request authorization

    @Test("startSync does NOT invoke notificationService.requestAuthorization")
    func test_startSync_doesNotRequestAuthorization() async throws {
        let mockNotif = MockNotificationService()
        let services = try makeServices(notificationService: mockNotif)

        // Run startSync; yield deterministically to let internal awaits make progress
        // without a timing-based Task.sleep (retro-debt rule from CLAUDE.md).
        let task = Task { @MainActor in
            await services.startSync()
        }
        for _ in 0..<20 { await Task.yield() }
        task.cancel()

        #expect(mockNotif.requestAuthorizationCallCount == 0)
    }

    @Test("AppServices init does NOT invoke notificationService.requestAuthorization")
    func test_init_doesNotRequestAuthorization() throws {
        let mockNotif = MockNotificationService()
        _ = try makeServices(notificationService: mockNotif)

        #expect(mockNotif.requestAuthorizationCallCount == 0)
    }
}
