import SwiftData
import Observation
import UIKit
import os.log
import HyzerKit

/// Deep-link destinations the app can navigate to from a remote notification tap.
enum DeepLink: Equatable {
    case activeRound(roundID: UUID)
    case roundSummary(roundID: UUID)
}

/// Composition root for all app services.
///
/// Created once at app startup and injected into the SwiftUI environment.
/// ViewModels receive individual services via constructor injection — never this container.
///
/// Construction order:
///   ModelContainer → StandingsEngine → RoundLifecycleManager
///   → CloudKitClient → NetworkMonitor → SyncEngine → SyncScheduler → ScoringService
///   → PhoneConnectivityService (Story 7.1)
///   → NotificationService (Story 12.1)
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
    let notificationService: any NotificationService
    private(set) var iCloudRecordName: String?

    /// Pending navigation target set when a "Round Started" notification is tapped.
    /// `ContentView` / `HomeView` observes this and routes to the active round, then nils it (consume-once).
    var pendingDeepLink: DeepLink?

    /// Observable sync state, bridged from the `SyncEngine` actor via an async stream.
    /// Drives `SyncIndicatorView`.
    private(set) var syncState: SyncState = .idle

    private let iCloudIdentityProvider: any ICloudIdentityProvider
    private let iCloudLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "ICloudIdentity")
    private let seederLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "CourseSeeder")
    private let notificationLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "AppServices.Notification")

    init(
        modelContainer: ModelContainer,
        iCloudIdentityProvider: any ICloudIdentityProvider,
        cloudKitClient: any CloudKitClient,
        networkMonitor: any NetworkMonitor,
        notificationService: any NotificationService = LiveNotificationService()
    ) {
        self.modelContainer = modelContainer
        self.notificationService = notificationService
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
            networkMonitor: networkMonitor,
            userDefaults: UserDefaults.standard
        )
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let scoring = ScoringService(modelContext: modelContainer.mainContext, deviceID: deviceID)
        self.scoringService = scoring
        let voice = VoiceRecognitionService()
        self.voiceRecognitionService = voice
        let connectivity = PhoneConnectivityService()
        connectivity.scoringService = scoring
        connectivity.localPlayerID = Self.resolveLocalPlayerID(from: modelContainer.mainContext)
        connectivity.voiceRecognitionService = voice
        self.phoneConnectivityService = connectivity
        self.iCloudIdentityProvider = iCloudIdentityProvider
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

    /// Notifies the scheduler that a round ended — stops periodic polling and clears
    /// the Watch-sync round context so stale standings aren't pushed for a finished round.
    func roundDidEnd() async {
        phoneConnectivityService.activeRoundID = nil
        await syncScheduler.stopActiveRoundPolling()
    }

    /// Handles a CKSubscription silent push notification (ScoreEvent subscription).
    func handleRemoteNotification() async {
        await syncScheduler.handleRemoteNotification()
    }

    /// Handles a "Round Started" CKQuerySubscription notification.
    ///
    /// Dispatched from `AppDelegate` when the subscription ID is `"Round-active-creation"`.
    /// Self-exclusion gate: if the local player is the organizer, returns without setting `pendingDeepLink`.
    func handleRoundStartedNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let payload = notificationService.parseRoundStartedPayload(userInfo) else {
            notificationLogger.info("handleRoundStartedNotification: unrecognised payload — ignoring")
            return
        }

        let localPlayerID = Self.resolveLocalPlayerID(from: modelContainer.mainContext)
        if notificationService.shouldSuppressPresentation(for: payload, localPlayerID: localPlayerID) {
            notificationLogger.info("handleRoundStartedNotification: self-exclusion — suppressing")
            return
        }

        // Pull so the round is locally materialised before the user taps through.
        await syncEngine.pullRecords()
        // One-shot retry if the round didn't show up — covers notify-before-sync race (Task 7.3).
        if !Self.roundExists(payload.roundID, in: modelContainer.mainContext) {
            await syncEngine.pullRecords()
        }

        // Set deep-link; HomeView observes and switches to the Scoring tab.
        pendingDeepLink = .activeRound(roundID: payload.roundID)
        notificationLogger.info("handleRoundStartedNotification: deep-link set for round")
    }

    /// Handles a "Round Complete" CKQuerySubscription notification.
    ///
    /// Dispatched from `AppDelegate` when the subscription ID is `"Round-complete-update"`.
    /// No self-exclusion: the winner receives this notification (AC #3).
    func handleRoundCompleteNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let payload = notificationService.parseRoundCompletePayload(userInfo) else {
            notificationLogger.info("handleRoundCompleteNotification: unrecognised payload — ignoring")
            return
        }

        // Suppress the deep-link on the writer's own device: if SyncMetadata shows that
        // we pushed the completion ourselves within the recent window, the user is already
        // viewing the in-round summary cover (or just dismissed it); a second cover would race.
        if await syncEngine.didRecentlyPushCompletion(for: payload.roundID) {
            notificationLogger.info("handleRoundCompleteNotification: self-pushed completion — suppressing deep-link")
            return
        }

        // Pull so the round's final state is locally materialised before the user taps through.
        await syncEngine.pullRecords()
        // One-shot retry if the round didn't show up — covers notify-before-sync race.
        if !Self.roundExists(payload.roundID, in: modelContainer.mainContext) {
            await syncEngine.pullRecords()
        }

        // If the round is still not locally materialised, drop the deep-link rather than
        // setting it and having the summary cover appear-then-instantly-dismiss.
        guard Self.roundExists(payload.roundID, in: modelContainer.mainContext) else {
            notificationLogger.info("handleRoundCompleteNotification: round still missing after retry — dropping deep-link")
            return
        }

        // Set deep-link; HomeView observes and presents the summary card.
        // No PII in log message — no course name, no winner name.
        pendingDeepLink = .roundSummary(roundID: payload.roundID)
        notificationLogger.info("handleRoundCompleteNotification: deep-link set for round summary")
    }

    /// Returns the local player's UUID (or nil pre-onboarding). Exposed for views that need
    /// to construct ViewModels keyed by the local user identity (e.g., `RoundCompletionSummaryHost`).
    static func resolveLocalPlayerID(from context: ModelContext) -> UUID? {
        var descriptor = FetchDescriptor<Player>()
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first?.id
        } catch {
            Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "AppServices")
                .error("resolveLocalPlayerID failed: \(error)")
            return nil
        }
    }

    /// Seeds `pendingDeepLink` from a cold-launch remote notification (Task 7.4).
    ///
    /// Call during `AppDelegate.application(_:didFinishLaunchingWithOptions:)` before
    /// the first view renders so the Scoring tab is pre-selected.
    ///
    /// Eagerly sets `pendingDeepLink` so HomeView's `.onAppear` observer routes immediately;
    /// then kicks off a fire-and-forget pull so the active Round is materialised in SwiftData
    /// before the user reaches the Scoring tab. Retries `pullRecords()` once if the round is
    /// not yet present locally — covers the case where the notification arrived before sync.
    func seedDeepLinkFromLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] else { return }

        // Try round-complete first, then round-started (both may arrive at launch).
        if let completePayload = notificationService.parseRoundCompletePayload(userInfo) {
            pendingDeepLink = .roundSummary(roundID: completePayload.roundID)
            let container = modelContainer
            let engine = syncEngine
            Task {
                await engine.pullRecords()
                if !Self.roundExists(completePayload.roundID, in: container.mainContext) {
                    await engine.pullRecords()
                }
            }
            return
        }

        guard let payload = notificationService.parseRoundStartedPayload(userInfo) else { return }

        let localPlayerID = Self.resolveLocalPlayerID(from: modelContainer.mainContext)
        guard !notificationService.shouldSuppressPresentation(for: payload, localPlayerID: localPlayerID) else { return }

        pendingDeepLink = .activeRound(roundID: payload.roundID)

        // Ensure the Round is locally materialised so ScoringTabView's @Query picks it up.
        let container = modelContainer
        let engine = syncEngine
        Task {
            await engine.pullRecords()
            if !Self.roundExists(payload.roundID, in: container.mainContext) {
                await engine.pullRecords()  // One-shot retry per Task 7.3
            }
        }
    }

    /// Returns true iff a `Round` with the given ID is present in SwiftData.
    /// Used by the cold-launch deep-link path to decide whether to retry a pull.
    private static func roundExists(_ roundID: UUID, in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == roundID })
        descriptor.fetchLimit = 1
        do {
            return try !context.fetch(descriptor).isEmpty
        } catch {
            Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "AppServices")
                .error("roundExists fetch failed: \(error)")
            return false
        }
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
            var descriptor = FetchDescriptor<Player>()
            descriptor.fetchLimit = 1
            let players = try context.fetch(descriptor)
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
