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
    func save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws -> [CKRecord] { [] }
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

    // MARK: - Task 8.5: handleRoundCompleteNotification

    @Test("handleRoundCompleteNotification sets pendingDeepLink to .roundSummary when round is locally materialised")
    func test_handleRoundCompleteNotification_setsRoundSummaryDeepLink() async throws {
        let mockNotif = MockNotificationService()
        let services = try makeServices(notificationService: mockNotif)

        let roundID = UUID()
        let payload = RoundCompletePayload(
            roundID: roundID,
            courseName: "Cedar Creek",
            winnerFirstName: "Alice",
            winnerScoreDisplay: "-3"
        )
        mockNotif.completePayloadToReturn = payload
        try insertRound(id: roundID, into: services.modelContainer.mainContext)

        await services.handleRoundCompleteNotification(["test": "value"])

        if case .roundSummary(let id) = services.pendingDeepLink {
            #expect(id == roundID)
        } else {
            #expect(Bool(false), "pendingDeepLink should be .roundSummary(roundID:)")
        }
    }

    @Test("handleRoundCompleteNotification does NOT self-exclude even when organizer matches local player (AC #3)")
    func test_handleRoundCompleteNotification_doesNotSelfExclude() async throws {
        let mockNotif = MockNotificationService()
        let services = try makeServices(notificationService: mockNotif)

        let roundID = UUID()
        let payload = RoundCompletePayload(
            roundID: roundID,
            courseName: "Hawk Ridge",
            winnerFirstName: "Bob",
            winnerScoreDisplay: "E"
        )
        mockNotif.completePayloadToReturn = payload
        mockNotif.suppressionResult = true
        try insertRound(id: roundID, into: services.modelContainer.mainContext)

        await services.handleRoundCompleteNotification(["test": "value"])

        if case .roundSummary(let id) = services.pendingDeepLink {
            #expect(id == roundID)
        } else {
            #expect(Bool(false), "pendingDeepLink must be set even when suppressionResult is true (no self-exclusion for complete)")
        }

        // shouldSuppressPresentation must NOT have been called for the complete payload
        #expect(mockNotif.shouldSuppressPresentationCallCount == 0)
    }

    @Test("handleRoundCompleteNotification retries pull once when round missing after first pull")
    func test_handleRoundCompleteNotification_retriesPullOnce_whenRoundMissing() async throws {
        let mockNotif = MockNotificationService()
        let cloudKit = StubCloudKitClientApp()
        let services = try makeServices(notificationService: mockNotif, cloudKitClient: cloudKit)

        let roundID = UUID()
        let payload = RoundCompletePayload(
            roundID: roundID,
            courseName: "Pines",
            winnerFirstName: "Carol",
            winnerScoreDisplay: "+2"
        )
        mockNotif.completePayloadToReturn = payload

        await services.handleRoundCompleteNotification(["test": "value"])

        // Round was never inserted → two fetch calls (initial pull + one-shot retry).
        // StubCloudKitClientApp.fetchCallCount tracks fetch(matching:in:) calls.
        #expect(cloudKit.fetchCallCount == 2)
    }

    @Test("handleRoundCompleteNotification drops deep-link when round still missing after retry (regression: avoid appear-then-dismiss flash)")
    func test_handleRoundCompleteNotification_dropsDeepLink_whenStillMissing() async throws {
        let mockNotif = MockNotificationService()
        let services = try makeServices(notificationService: mockNotif)

        let payload = RoundCompletePayload(
            roundID: UUID(),
            courseName: "Pines",
            winnerFirstName: "Carol",
            winnerScoreDisplay: "+2"
        )
        mockNotif.completePayloadToReturn = payload
        // No Round inserted into the container — both pulls leave it missing.

        await services.handleRoundCompleteNotification(["test": "value"])

        #expect(services.pendingDeepLink == nil,
                "deep-link must not be set when the round is still missing after retry — otherwise the summary cover appears and instantly dismisses")
    }

    @Test("handleRoundCompleteNotification ignores unrecognised payload")
    func test_handleRoundCompleteNotification_nilPayload_noSideEffects() async throws {
        let mockNotif = MockNotificationService()
        let services = try makeServices(notificationService: mockNotif)

        mockNotif.completePayloadToReturn = nil

        await services.handleRoundCompleteNotification([:])

        #expect(services.pendingDeepLink == nil)
    }

    // MARK: - Helpers

    /// Inserts a minimal `Round` with the given ID into the test context so `roundExists` returns true.
    private func insertRound(id: UUID, into context: ModelContext) throws {
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: [],
            guestNames: [],
            holeCount: 18
        )
        round.id = id
        context.insert(round)
        try context.save()
    }
}
