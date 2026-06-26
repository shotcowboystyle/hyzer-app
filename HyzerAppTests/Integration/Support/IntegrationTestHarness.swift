import CloudKit
import Foundation
import SwiftData
import Testing
@testable import HyzerApp
@testable import HyzerKit
import TestSupport

/// One-call wiring of `AppServices` + all mocks for HyzerAppTests integration suites.
///
/// Use `IntegrationTestHarness.make()` in a test's setup, then drive the journey
/// through `harness.services` (the configured `AppServices`) while asserting on
/// the captured state of `harness.cloudKit`, `harness.nearby`, `harness.notifications`.
///
/// **Pattern modeled after** `AppServicesNearbyDiscoveryTests.makeServices(...)` —
/// the gold-standard integration test pattern in this repo (see CLAUDE.md and
/// the Story 15.11 plan).
///
/// **In-memory SwiftData container:** Includes all domain models + `SyncMetadata`
/// + `Discrepancy` (matches `TestContainerFactory.makeConflictTestContainer()`).
///
/// **Seeded by default:** A local Player ("Test Player"). Pass
/// `seedLocalPlayer: false` to start without one (e.g., onboarding tests).
@MainActor
struct IntegrationTestHarness {

    // MARK: Captured references

    let services: AppServices
    let container: ModelContainer
    let cloudKit: StubCloudKitClient
    let nearby: MockNearbyDiscoveryClient
    let notifications: MockNotificationService
    let networkMonitor: StubNetworkMonitor
    let identityProvider: StubICloudIdentityProvider

    /// The local Player seeded at `make()` time (nil if `seedLocalPlayer: false`).
    let localPlayer: Player?

    var localPlayerID: UUID? { localPlayer?.id }

    // MARK: Factory

    /// Wires up a fully-mocked `AppServices` and returns the harness.
    /// - Parameters:
    ///   - seedLocalPlayer: When true (default), inserts a `Player` named
    ///     `localPlayerDisplayName` so identity-dependent flows have a local user.
    ///   - localPlayerDisplayName: Display name of the seeded local player.
    ///   - localPlayerICloudRecordName: Optional iCloud record name on the seeded
    ///     local player. Used when tests need `Player.iCloudRecordName` set
    ///     without round-tripping through `services.resolveICloudIdentity()`.
    ///   - identityProvider: Override the default `.unavailable` identity provider.
    static func make(
        seedLocalPlayer: Bool = true,
        localPlayerDisplayName: String = "Test Player",
        localPlayerICloudRecordName: String? = nil,
        identityProvider: StubICloudIdentityProvider = StubICloudIdentityProvider.unavailable()
    ) throws -> IntegrationTestHarness {
        let cloudKit = StubCloudKitClient()
        let nearby = MockNearbyDiscoveryClient()
        let notifications = MockNotificationService()
        let networkMonitor = StubNetworkMonitor()

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self,
            ScoreEvent.self, SyncMetadata.self, Discrepancy.self,
            configurations: config
        )

        let services = AppServices(
            modelContainer: container,
            iCloudIdentityProvider: identityProvider,
            cloudKitClient: cloudKit,
            networkMonitor: networkMonitor,
            notificationService: notifications,
            nearbyDiscoveryClient: nearby
        )

        var seededPlayer: Player?
        if seedLocalPlayer {
            let player = Player(displayName: localPlayerDisplayName)
            player.iCloudRecordName = localPlayerICloudRecordName
            container.mainContext.insert(player)
            try container.mainContext.save()
            // After seeding, refresh the PhoneConnectivityService's localPlayerID —
            // AppServices.init resolved it from an empty context.
            services.phoneConnectivityService.localPlayerID = player.id
            seededPlayer = player
        }

        return IntegrationTestHarness(
            services: services,
            container: container,
            cloudKit: cloudKit,
            nearby: nearby,
            notifications: notifications,
            networkMonitor: networkMonitor,
            identityProvider: identityProvider,
            localPlayer: seededPlayer
        )
    }

    // MARK: Seeders

    /// Inserts a Course and `holeCount` `Hole` rows (all par `parPerHole`) and saves.
    @discardableResult
    func seedCourse(
        name: String = "Test Course",
        holeCount: Int = 18,
        parPerHole: Int = 3
    ) throws -> Course {
        let course = Course(name: name, holeCount: holeCount)
        container.mainContext.insert(course)
        for n in 1...holeCount {
            let hole = Hole(courseID: course.id, number: n, par: parPerHole)
            container.mainContext.insert(hole)
        }
        try container.mainContext.save()
        return course
    }

    /// Inserts an additional Player (besides the seeded local player) and returns it.
    @discardableResult
    func seedPlayer(displayName: String) throws -> Player {
        let player = Player(displayName: displayName)
        container.mainContext.insert(player)
        try container.mainContext.save()
        return player
    }

    /// Inserts an active Round and saves.
    @discardableResult
    func seedActiveRound(
        courseID: UUID,
        organizerID: UUID,
        playerIDs: [String],
        guestNames: [String] = [],
        holeCount: Int = 18
    ) throws -> Round {
        let round = Round(
            courseID: courseID,
            organizerID: organizerID,
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: holeCount
        )
        round.start()
        container.mainContext.insert(round)
        try container.mainContext.save()
        return round
    }

    // MARK: Sync helpers

    /// Spawns `services.startSync()` in a Task, awaits the initial `pullRecords` to
    /// settle (`cloudKit.fetchCallCount > 0`), and returns the task so the caller
    /// can `.cancel()` it on teardown.
    ///
    /// Matches the pattern at
    /// `AppServicesNearbyDiscoveryTests.swift:114-118` — extract once, use everywhere.
    @discardableResult
    func startSyncAndAwaitInitialPull(
        timeout: Duration = .seconds(5)
    ) async throws -> Task<Void, Never> {
        let cloudKit = self.cloudKit
        let services = self.services
        let task = Task { @MainActor in
            await services.startSync()
        }
        try await waitUntil(
            { cloudKit.fetchCallCount > 0 },
            timeout: timeout,
            conditionDescription: "startSync completes initial pull"
        )
        return task
    }
}
