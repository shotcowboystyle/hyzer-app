import SwiftData
import Observation
import UIKit
import os.log
import HyzerKit

/// Composition root for all app services.
///
/// Created once at app startup and injected into the SwiftUI environment.
/// ViewModels receive individual services via constructor injection — never this container.
///
/// Construction order:
///   ModelContainer → StandingsEngine → RoundLifecycleManager
///   → CloudKitClient → NetworkMonitor → SyncEngine → SyncScheduler → ScoringService
///   → PhoneConnectivityService (Story 7.1)
@MainActor
@Observable
final class AppServices {
    let modelContainer: ModelContainer
    let scoringService: ScoringService
    let standingsEngine: StandingsEngine
    let roundLifecycleManager: RoundLifecycleManager
    let syncEngine: SyncEngine
    let syncScheduler: SyncScheduler
    let voiceRecognitionService: VoiceRecognitionService
    let phoneConnectivityService: PhoneConnectivityService
    private(set) var iCloudRecordName: String?

    /// Observable sync state, bridged from the `SyncEngine` actor via an async stream.
    /// Drives `SyncIndicatorView`.
    private(set) var syncState: SyncState = .idle

    private let iCloudIdentityProvider: any ICloudIdentityProvider
    private let iCloudLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "ICloudIdentity")
    private let seederLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "CourseSeeder")

    init(
        modelContainer: ModelContainer,
        iCloudIdentityProvider: any ICloudIdentityProvider,
        cloudKitClient: any CloudKitClient,
        networkMonitor: any NetworkMonitor
    ) {
        self.modelContainer = modelContainer
        self.standingsEngine = StandingsEngine(modelContext: modelContainer.mainContext)
        self.roundLifecycleManager = RoundLifecycleManager(modelContext: modelContainer.mainContext)
        self.syncEngine = SyncEngine(
            cloudKitClient: cloudKitClient,
            standingsEngine: standingsEngine,
            modelContainer: modelContainer
        )
        self.syncScheduler = SyncScheduler(
            syncEngine: syncEngine,
            cloudKitClient: cloudKitClient,
            networkMonitor: networkMonitor
        )
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let scoring = ScoringService(modelContext: modelContainer.mainContext, deviceID: deviceID)
        self.scoringService = scoring
        self.voiceRecognitionService = VoiceRecognitionService()
        let connectivity = PhoneConnectivityService()
        connectivity.scoringService = scoring
        connectivity.localPlayerID = Self.resolveLocalPlayerID(from: modelContainer.mainContext)
        self.phoneConnectivityService = connectivity
        self.iCloudIdentityProvider = iCloudIdentityProvider
    }

    // MARK: - Private helpers

    /// Fetches the local player's UUID from SwiftData for use as `reportedByPlayerID`.
    /// Returns `nil` on first launch before onboarding creates a Player record.
    private static func resolveLocalPlayerID(from context: ModelContext) -> UUID? {
        let players = try? context.fetch(FetchDescriptor<Player>())
        return players?.first?.id
    }

    // MARK: - Sync

    /// Starts the SyncScheduler (subscriptions + connectivity listener) and bridges
    /// `SyncEngine.syncState` to the `@Observable` `syncState` property for SwiftUI.
    ///
    /// Must be called from a `.task` modifier so it runs in a cancellable async context.
    func startSync() async {
        phoneConnectivityService.startObservingStandings(standingsEngine)
        await syncScheduler.start()
        await syncEngine.start()

        // Bridge: consume the syncStateStream and propagate to @MainActor-observable property.
        for await state in await syncEngine.syncStateStream {
            syncState = state
        }
    }

    /// Notifies the scheduler that an active round started — begins periodic polling.
    func roundDidStart() async {
        await syncScheduler.startActiveRoundPolling()
    }

    /// Notifies the scheduler that a round ended — stops periodic polling.
    func roundDidEnd() async {
        await syncScheduler.stopActiveRoundPolling()
    }

    /// Handles a CKSubscription silent push notification.
    func handleRemoteNotification() async {
        await syncScheduler.handleRemoteNotification()
    }

    /// Performs app-foreground round discovery (covers missed CKSubscription pushes).
    func performForegroundDiscovery() async {
        guard let userID = iCloudRecordName else { return }
        await syncScheduler.foregroundDiscovery(currentUserID: userID)
    }

    /// Stops active round polling when the app enters background.
    ///
    /// Separate from `roundDidEnd()` because the round is still logically active —
    /// polling resumes when the app returns to foreground via `roundDidStart()`.
    func handleAppBackground() async {
        await syncScheduler.stopActiveRoundPolling()
    }

    // MARK: - iCloud Identity

    /// Resolves iCloud identity and updates the Player record.
    ///
    /// Called via `.task` modifier after first frame render (Amendment A5).
    /// Never throws — errors are logged and the app continues with local identity.
    /// Idempotent: skips resolution if Player already has an `iCloudRecordName`.
    func resolveICloudIdentity() async {
        if iCloudRecordName != nil { return }

        do {
            let context = ModelContext(modelContainer)
            let players = try context.fetch(FetchDescriptor<Player>())
            guard let player = players.first else {
                iCloudLogger.info("iCloud identity: no player found, skipping")
                return
            }

            if player.iCloudRecordName != nil {
                return
            }

            let result = try await iCloudIdentityProvider.resolveIdentity()
            switch result {
            case .available(let recordName):
                player.iCloudRecordName = recordName
                try context.save()
                iCloudRecordName = recordName
                iCloudLogger.info("iCloud identity resolved: \(recordName)")
            case .unavailable(let reason):
                iCloudLogger.info("iCloud unavailable: \(String(describing: reason))")
            }
        } catch {
            iCloudLogger.error("iCloud identity resolution failed: \(error)")
        }
    }

    // MARK: - Course seeding

    /// Seeds pre-defined local courses on first launch.
    ///
    /// Called via `.task` modifier after first frame render.
    /// Safe to continue on failure — the user can manually add courses.
    func seedCoursesIfNeeded() async {
        do {
            let context = ModelContext(modelContainer)
            try CourseSeeder.seedIfNeeded(in: context)
        } catch {
            seederLogger.error("Course seeding failed: \(error)")
        }
    }
}
