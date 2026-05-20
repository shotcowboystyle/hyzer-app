import Testing
import SwiftData
import CloudKit
import Foundation
import UIKit
@testable import HyzerKit
@testable import HyzerApp
import TestSupport

// MARK: - Stubs

private final class CountingCloudKitClient: CloudKitClient, @unchecked Sendable {
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

private struct NeverConnectedNetworkMonitor: NetworkMonitor {
    var isConnected: Bool { true }
    var pathUpdates: AsyncStream<Bool> { AsyncStream { _ in } }
}

private struct ReturnsAvailableIdentityProvider: ICloudIdentityProvider, @unchecked Sendable {
    let recordName: String
    func resolveIdentity() async throws -> ICloudIdentityResult { .available(recordName: recordName) }
}

private struct UnavailableIdentityProvider: ICloudIdentityProvider, @unchecked Sendable {
    func resolveIdentity() async throws -> ICloudIdentityResult { .unavailable(reason: .couldNotDetermine) }
}

// MARK: - AppServicesNearbyDiscoveryTests

@Suite("AppServices — Nearby Discovery")
@MainActor
struct AppServicesNearbyDiscoveryTests {

    // MARK: - Helpers

    private func makeServices(
        cloudKitClient: CountingCloudKitClient = CountingCloudKitClient(),
        nearbyDiscoveryClient: MockNearbyDiscoveryClient = MockNearbyDiscoveryClient(),
        iCloudIdentityProvider: any ICloudIdentityProvider = UnavailableIdentityProvider()
    ) throws -> (AppServices, ModelContainer, CountingCloudKitClient, MockNearbyDiscoveryClient) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self, Discrepancy.self,
            configurations: config
        )
        let services = AppServices(
            modelContainer: container,
            iCloudIdentityProvider: iCloudIdentityProvider,
            cloudKitClient: cloudKitClient,
            networkMonitor: NeverConnectedNetworkMonitor(),
            nearbyDiscoveryClient: nearbyDiscoveryClient
        )
        return (services, container, cloudKitClient, nearbyDiscoveryClient)
    }

    /// Inserts a Player and returns their ID. Used as the "local player" in tests.
    private func insertLocalPlayer(in context: ModelContext) throws -> UUID {
        let player = Player(displayName: "Test Player")
        context.insert(player)
        try context.save()
        return player.id
    }

    /// Inserts an active Round organized by `organizerID` with the given `playerIDs`.
    private func insertActiveRound(
        organizerID: UUID,
        playerIDs: [String],
        in context: ModelContext
    ) throws -> Round {
        let round = Round(
            courseID: UUID(),
            organizerID: organizerID,
            playerIDs: playerIDs,
            guestNames: [],
            holeCount: 18
        )
        round.start()
        context.insert(round)
        try context.save()
        return round
    }

    // MARK: - Participant filter (AC #5)

    @Test("handleDiscoveredRound: local player not in payload — skips pull")
    func test_handleDiscoveredRound_localPlayerNotInPayload_skipsPull() async throws {
        let cloudKit = CountingCloudKitClient()
        let mockNearby = MockNearbyDiscoveryClient()
        let (services, container, _, _) = try makeServices(
            cloudKitClient: cloudKit,
            nearbyDiscoveryClient: mockNearby
        )

        let localID = try insertLocalPlayer(in: container.mainContext)
        _ = localID // local player is in the context; payload deliberately excludes them

        let syncTask = Task { @MainActor in await services.startSync() }
        try await waitUntil(
            { cloudKit.fetchCallCount > 0 },
            conditionDescription: "startSync completes initial pull"
        )

        // Capture fetch count AFTER startSync's initial pullRecords has settled — this
        // isolates the assertion to the effect of `simulateFoundPeer` alone.
        let baselineFetchCount = cloudKit.fetchCallCount

        // Inject a payload where local user is NOT in the playerIDs list.
        let differentPlayerID = UUID().uuidString
        mockNearby.simulateFoundPeer(roundID: UUID(), playerIDs: [differentPlayerID])
        // Deliberate guard: allow the async pipeline to process this ignored event.
        // Negative assertion — waitUntil requires a positive condition to poll.
        for _ in 0..<20 { await Task.yield() }

        syncTask.cancel()
        #expect(
            cloudKit.fetchCallCount == baselineFetchCount,
            "pull must be skipped when local player is not in the payload (no new fetches after baseline)"
        )
    }

    // MARK: - Already-materialized check (AC #8 step a)

    @Test("handleDiscoveredRound: round already in SwiftData — skips pull")
    func test_handleDiscoveredRound_roundAlreadyMaterialized_skipsPull() async throws {
        let cloudKit = CountingCloudKitClient()
        let mockNearby = MockNearbyDiscoveryClient()
        let (services, container, _, _) = try makeServices(
            cloudKitClient: cloudKit,
            nearbyDiscoveryClient: mockNearby
        )

        let localID = try insertLocalPlayer(in: container.mainContext)

        // Pre-insert the round that the payload will advertise.
        let round = Round(courseID: UUID(), organizerID: UUID(), playerIDs: [], guestNames: [], holeCount: 18)
        container.mainContext.insert(round)
        try container.mainContext.save()

        let syncTask = Task { @MainActor in await services.startSync() }
        try await waitUntil(
            { cloudKit.fetchCallCount > 0 },
            conditionDescription: "startSync completes initial pull"
        )

        // Capture fetch count AFTER startSync's initial pullRecords has settled — this
        // isolates the assertion to the effect of `simulateFoundPeer` alone.
        let baselineFetchCount = cloudKit.fetchCallCount

        mockNearby.simulateFoundPeer(roundID: round.id, playerIDs: [localID.uuidString])
        // Deliberate guard: allow the async pipeline to process this ignored event.
        // Negative assertion — waitUntil requires a positive condition to poll.
        for _ in 0..<20 { await Task.yield() }

        syncTask.cancel()
        #expect(
            cloudKit.fetchCallCount == baselineFetchCount,
            "pull must be skipped when the round is already in SwiftData (no new fetches after baseline)"
        )
    }

    // MARK: - 30s throttle window (AC #9)

    @Test("handleDiscoveredRound: two rapid payloads for the same roundID trigger only one pull")
    func test_handleDiscoveredRound_throttleWindow_secondCallWithin30sIsSkipped() async throws {
        let cloudKit = CountingCloudKitClient()
        let mockNearby = MockNearbyDiscoveryClient()
        let (services, container, _, _) = try makeServices(
            cloudKitClient: cloudKit,
            nearbyDiscoveryClient: mockNearby
        )

        let localID = try insertLocalPlayer(in: container.mainContext)
        let roundID = UUID()

        let syncTask = Task { @MainActor in await services.startSync() }
        try await waitUntil(
            { cloudKit.fetchCallCount > 0 },
            conditionDescription: "startSync completes initial pull"
        )

        // Capture fetch count AFTER startSync's initial pullRecords has settled — this
        // isolates the assertion to the effect of `simulateFoundPeer` alone.
        let baselineFetchCount = cloudKit.fetchCallCount

        // First injection: round is not in SwiftData → should pull (one new fetch).
        mockNearby.simulateFoundPeer(roundID: roundID, playerIDs: [localID.uuidString])
        try await waitUntil(
            { cloudKit.fetchCallCount > baselineFetchCount },
            conditionDescription: "first peer discovery triggers pull"
        )

        // Second injection within 30s: throttle should suppress (no new fetch).
        mockNearby.simulateFoundPeer(roundID: roundID, playerIDs: [localID.uuidString])
        // Deliberate guard: allow the async pipeline to process the throttled event.
        // Negative assertion — waitUntil requires a positive condition to poll.
        for _ in 0..<20 { await Task.yield() }

        syncTask.cancel()
        #expect(
            cloudKit.fetchCallCount - baselineFetchCount == 1,
            "throttle window must suppress the second pull for the same roundID within 30s (exactly one new fetch over baseline)"
        )
    }

    // MARK: - Organizer advertises (AC #4)

    @Test("roundDidStart: local player is organizer — calls startAdvertising")
    func test_roundDidStart_localPlayerIsOrganizer_callsStartAdvertising() async throws {
        let mockNearby = MockNearbyDiscoveryClient()
        let (services, container, _, _) = try makeServices(nearbyDiscoveryClient: mockNearby)

        let localID = try insertLocalPlayer(in: container.mainContext)
        let round = try insertActiveRound(organizerID: localID, playerIDs: [localID.uuidString], in: container.mainContext)

        await services.roundDidStart()

        #expect(mockNearby.startAdvertisingCallCount == 1)
        #expect(mockNearby.lastAdvertisedRoundID == round.id)
    }

    // MARK: - Participant does NOT advertise (AC #6)

    @Test("roundDidStart: local player is participant only — does NOT call startAdvertising")
    func test_roundDidStart_localPlayerIsParticipantOnly_doesNotAdvertise() async throws {
        let mockNearby = MockNearbyDiscoveryClient()
        let (services, container, _, _) = try makeServices(nearbyDiscoveryClient: mockNearby)

        let localID = try insertLocalPlayer(in: container.mainContext)
        // Different organizer — local player is a participant, not the organizer.
        let differentOrganizerID = UUID()
        _ = try insertActiveRound(
            organizerID: differentOrganizerID,
            playerIDs: [localID.uuidString],
            in: container.mainContext
        )

        await services.roundDidStart()

        #expect(mockNearby.startAdvertisingCallCount == 0, "participants must NOT advertise")
    }

    // MARK: - Advertiser teardown on roundDidEnd (AC #4)

    @Test("roundDidEnd: calls stopAdvertising")
    func test_roundDidEnd_callsStopAdvertising() async throws {
        let mockNearby = MockNearbyDiscoveryClient()
        let (services, _, _, _) = try makeServices(nearbyDiscoveryClient: mockNearby)

        await services.roundDidEnd()

        #expect(mockNearby.stopAdvertisingCallCount == 1)
    }

    // MARK: - Background (AC #4)

    @Test("handleAppBackground: calls stopAdvertising and stopBrowsing")
    func test_handleAppBackground_callsStopAdvertisingAndStopBrowsing() async throws {
        let mockNearby = MockNearbyDiscoveryClient()
        let (services, _, _, _) = try makeServices(nearbyDiscoveryClient: mockNearby)

        await services.handleAppBackground()

        #expect(mockNearby.stopAdvertisingCallCount == 1)
        #expect(mockNearby.stopBrowsingCallCount == 1)
    }

    // MARK: - Foreground resume (AC #4)

    @Test("performForegroundDiscovery: organizer case — resumes browsing and advertises active round")
    func test_performForegroundDiscovery_organizerCase_resumesBrowsingAndAdvertising() async throws {
        let mockNearby = MockNearbyDiscoveryClient()
        let iCloudID = UUID().uuidString
        let (services, container, _, _) = try makeServices(
            nearbyDiscoveryClient: mockNearby,
            iCloudIdentityProvider: ReturnsAvailableIdentityProvider(recordName: iCloudID)
        )

        // Insert a Player (no iCloudRecordName yet) so resolveICloudIdentity can update it.
        let player = Player(displayName: "Test Player")
        container.mainContext.insert(player)
        try container.mainContext.save()

        // Set iCloudRecordName so performForegroundDiscovery proceeds past the guard.
        await services.resolveICloudIdentity()
        let localID = player.id

        // Insert an active round organized by the local player.
        let round = try insertActiveRound(organizerID: localID, playerIDs: [localID.uuidString], in: container.mainContext)

        await services.performForegroundDiscovery()

        #expect(mockNearby.startBrowsingCallCount >= 1)
        #expect(mockNearby.startAdvertisingCallCount == 1)
        #expect(mockNearby.lastAdvertisedRoundID == round.id)
    }
}
