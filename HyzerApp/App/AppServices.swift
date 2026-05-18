import SwiftData
import Observation
import UIKit
import os.log
import HyzerKit

/// Deep-link destinations the app can navigate to from a remote notification tap.
enum DeepLink: Equatable {
    case activeRound(roundID: UUID)
    case roundSummary(roundID: UUID)
    case discrepancyResolution(roundID: UUID, playerID: String, holeNumber: Int)

    /// Ordering used when two deep-links contend for `AppServices.pendingDeepLink`.
    ///
    /// Higher value wins. A lower-precedence handler must not clobber a higher-precedence
    /// link that has not yet been consumed by `HomeView`. Order:
    /// `discrepancyResolution` (organizer action required) > `roundSummary` (informational
    /// post-round) > `activeRound` (passive routing).
    var precedence: Int {
        switch self {
        case .discrepancyResolution: return 2
        case .roundSummary: return 1
        case .activeRound: return 0
        }
    }
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
    let nearbyDiscoveryClient: any NearbyDiscoveryClient
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
    private let nearbyLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "AppServices.Nearby")
    private static let helperLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "AppServices")

    /// Per-roundID throttle window for nearby-triggered pulls (AC #9).
    ///
    /// Uses `ContinuousClock.Instant` (monotonic) so the window is immune to wall-clock
    /// changes (NTP correction, manual time-set, time-zone rollover).
    private var lastPullByRoundID: [UUID: ContinuousClock.Instant] = [:]

    /// Unstructured consumer Task for `nearbyDiscoveryClient.discoveredRounds`.
    /// Held to prevent double-spawn if `startSync()` is invoked twice in the AppServices lifetime.
    private var nearbyConsumerTask: Task<Void, Never>?

    init(
        modelContainer: ModelContainer,
        iCloudIdentityProvider: any ICloudIdentityProvider,
        cloudKitClient: any CloudKitClient,
        networkMonitor: any NetworkMonitor,
        notificationService: any NotificationService = LiveNotificationService(),
        nearbyDiscoveryClient: any NearbyDiscoveryClient = LiveNearbyDiscoveryClient()
    ) {
        self.modelContainer = modelContainer
        self.notificationService = notificationService
        self.nearbyDiscoveryClient = nearbyDiscoveryClient
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
            userDefaults: UserDefaults.standard,
            localPlayerIDProvider: { [container = modelContainer] in
                await MainActor.run { AppServices.resolveLocalPlayerID(from: container.mainContext) }
            }
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

        // Spawn the nearby-discovery consumer BEFORE startBrowsing() so any peers found
        // immediately after browsing begins are received (the live client's continuation
        // is set up at init time, so iteration order is not load-bearing, but subscribing
        // first preserves the invariant for future implementations).
        // Guard against double-spawn if startSync() is re-entered during the AppServices lifetime.
        if nearbyConsumerTask == nil {
            nearbyConsumerTask = Task { [weak self] in
                guard let self else { return }
                for await payload in self.nearbyDiscoveryClient.discoveredRounds {
                    await self.handleDiscoveredRound(payload)
                }
            }
        }

        await nearbyDiscoveryClient.startBrowsing()

        // Bridge: consume the syncStateStream and propagate to the @MainActor-observable property.
        for await state in await syncEngine.syncStateStream {
            syncState = state
        }
    }

    /// Handles a discovered nearby round payload from `NearbyDiscoveryClient`.
    ///
    /// Applies participant filter (AC #5), idempotency check (AC #8), and 30s throttle (AC #9)
    /// before triggering a `syncEngine.pullRecords()` to materialize the round locally.
    private func handleDiscoveredRound(_ payload: DiscoveredRoundPayload) async {
        guard let localID = Self.resolveLocalPlayerID(from: modelContainer.mainContext) else {
            nearbyLogger.info("nearby: handleDiscoveredRound — no local player (pre-onboarding), skipping")
            return
        }

        guard payload.playerIDs.contains(localID.uuidString) else {
            // Log roundID only — never player UUIDs (log volume + no diagnostic value).
            nearbyLogger.info("nearby: skipped — local user not in payload for roundID=\(payload.roundID, privacy: .private)")
            return
        }

        // 30s throttle window per roundID (AC #9). Uses ContinuousClock — immune to
        // wall-clock changes (NTP, manual time-set).
        let now = ContinuousClock.now
        if let last = lastPullByRoundID[payload.roundID], now < last.advanced(by: .seconds(30)) {
            return
        }
        // Stamp on every observation for which the participant filter passed (D1 decision):
        // suppress repeat SwiftData fetches AND repeat pulls for the same roundID within 30s.
        // Stamping before the fetch (rather than only on the pull path) prevents bursty
        // re-broadcasts from churning bounded fetches on the main context.
        lastPullByRoundID[payload.roundID] = now

        // Already-materialized check (AC #8 step a).
        let targetRoundID = payload.roundID
        var descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == targetRoundID })
        descriptor.fetchLimit = 1
        do {
            let existing = try modelContainer.mainContext.fetch(descriptor)
            if !existing.isEmpty {
                nearbyLogger.info("nearby: already materialized — skipping pull for roundID=\(payload.roundID, privacy: .private)")
                return
            }
        } catch {
            nearbyLogger.error("nearby: fetch failed for roundID=\(payload.roundID, privacy: .private): \(error)")
            return
        }

        nearbyLogger.info("nearby: triggering pullRecords for roundID=\(payload.roundID, privacy: .private)")
        await syncEngine.pullRecords()
    }

    /// Returns the local user's organized active round, if any. Used to drive advertiser lifecycle.
    ///
    /// Returns nil for participants (round's organizerID differs from local player).
    private func currentOrganizedActiveRound() -> Round? {
        guard let localID = Self.resolveLocalPlayerID(from: modelContainer.mainContext) else { return nil }
        let activeStatus = RoundStatus.active
        var descriptor = FetchDescriptor<Round>(
            predicate: #Predicate { $0.status == activeStatus && $0.organizerID == localID }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContainer.mainContext.fetch(descriptor).first
        } catch {
            nearbyLogger.error("currentOrganizedActiveRound fetch failed: \(error)")
            return nil
        }
    }

    /// Notifies the scheduler that an active round started — begins periodic polling.
    func roundDidStart() async {
        await syncScheduler.startActiveRoundPolling()
        if let round = currentOrganizedActiveRound() {
            await nearbyDiscoveryClient.startAdvertising(roundID: round.id, playerIDs: round.playerIDs)
        } else {
            // No active organized round (participant, or save not yet committed) — ensure
            // any stale advertiser from a prior round is stopped so it can't continue
            // broadcasting a finished round's TXT record.
            await nearbyDiscoveryClient.stopAdvertising()
        }
    }

    /// Notifies the scheduler that a round ended — stops periodic polling and clears
    /// the Watch-sync round context so stale standings aren't pushed for a finished round.
    func roundDidEnd() async {
        phoneConnectivityService.activeRoundID = nil
        await syncScheduler.stopActiveRoundPolling()
        await nearbyDiscoveryClient.stopAdvertising()
        // Clear nearby-pull throttle entries: re-discovering a recently-ended round
        // should not be suppressed by a stale 30s stamp.
        lastPullByRoundID.removeAll()
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
        setPendingDeepLinkIfHigherOrEqualPrecedence(.activeRound(roundID: payload.roundID), source: "handleRoundStartedNotification")
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
        setPendingDeepLinkIfHigherOrEqualPrecedence(.roundSummary(roundID: payload.roundID), source: "handleRoundCompleteNotification")
    }

    /// Handles a "Discrepancy Detected" CKQuerySubscription notification.
    ///
    /// Dispatched from `AppDelegate` when the subscription ID is `"Discrepancy-creation"`.
    /// No self-exclusion: the subscription predicate `organizerID == <localPlayerID>` guarantees
    /// server-side that only the organizer receives this push.
    func handleDiscrepancyDetectedNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let payload = notificationService.parseDiscrepancyDetectedPayload(userInfo) else {
            notificationLogger.info("handleDiscrepancyDetectedNotification: unrecognised payload — ignoring")
            return
        }

        await syncEngine.pullRecords()

        let context = modelContainer.mainContext
        if !Self.discrepancyExists(roundID: payload.roundID, playerID: payload.playerID, holeNumber: payload.holeNumber, in: context) {
            await syncEngine.pullRecords()
        }

        guard Self.discrepancyExists(
            roundID: payload.roundID, playerID: payload.playerID, holeNumber: payload.holeNumber, in: context
        ) else {
            notificationLogger.info("handleDiscrepancyDetectedNotification: discrepancy missing after retry — dropping deep-link")
            return
        }

        setPendingDeepLinkIfHigherOrEqualPrecedence(
            .discrepancyResolution(roundID: payload.roundID, playerID: payload.playerID, holeNumber: payload.holeNumber),
            source: "handleDiscrepancyDetectedNotification"
        )
    }

    /// Assigns `pendingDeepLink` only when `candidate.precedence >= current.precedence`.
    ///
    /// Discrepancy resolution outranks round summary outranks active round (see `DeepLink.precedence`).
    /// A lower-precedence handler that arrives while a higher-precedence link is still pending logs
    /// the skip rather than silently dropping the queued action.
    private func setPendingDeepLinkIfHigherOrEqualPrecedence(_ candidate: DeepLink, source: String) {
        if let current = pendingDeepLink, current.precedence > candidate.precedence {
            notificationLogger.info("\(source): skipping deep-link overwrite — higher-precedence link still pending")
            return
        }
        pendingDeepLink = candidate
        notificationLogger.info("\(source): deep-link set")
    }

    /// Returns the local player's UUID (or nil pre-onboarding). Exposed for views that need
    /// to construct ViewModels keyed by the local user identity (e.g., `RoundCompletionSummaryHost`).
    static func resolveLocalPlayerID(from context: ModelContext) -> UUID? {
        var descriptor = FetchDescriptor<Player>()
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first?.id
        } catch {
            helperLogger.error("resolveLocalPlayerID failed: \(error)")
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

        // Try discrepancy-detected first (most specific routing target), then round-complete, then round-started.
        if let discrepancyPayload = notificationService.parseDiscrepancyDetectedPayload(userInfo) {
            setPendingDeepLinkIfHigherOrEqualPrecedence(
                .discrepancyResolution(
                    roundID: discrepancyPayload.roundID,
                    playerID: discrepancyPayload.playerID,
                    holeNumber: discrepancyPayload.holeNumber
                ),
                source: "seedDeepLinkFromLaunchOptions[discrepancy]"
            )
            let container = modelContainer
            let engine = syncEngine
            let payload = discrepancyPayload
            Task {
                await engine.pullRecords()
                let exists = Self.discrepancyExists(
                    roundID: payload.roundID,
                    playerID: payload.playerID,
                    holeNumber: payload.holeNumber,
                    in: container.mainContext
                )
                if !exists {
                    await engine.pullRecords()
                }
            }
            return
        }

        // Try round-complete, then round-started.
        if let completePayload = notificationService.parseRoundCompletePayload(userInfo) {
            setPendingDeepLinkIfHigherOrEqualPrecedence(
                .roundSummary(roundID: completePayload.roundID),
                source: "seedDeepLinkFromLaunchOptions[complete]"
            )
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

        setPendingDeepLinkIfHigherOrEqualPrecedence(
            .activeRound(roundID: payload.roundID),
            source: "seedDeepLinkFromLaunchOptions[started]"
        )

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
            helperLogger.error("roundExists fetch failed: \(error)")
            return false
        }
    }

    /// Returns true iff a `Discrepancy` for the given {roundID, playerID, holeNumber} exists locally.
    /// Used by `handleDiscrepancyDetectedNotification` to decide whether to set the deep-link.
    /// Does NOT filter by status — an already-resolved discrepancy still routes to the read-only view (AC #4).
    private static func discrepancyExists(roundID: UUID, playerID: String, holeNumber: Int, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Discrepancy>(
            predicate: #Predicate { $0.roundID == roundID && $0.playerID == playerID && $0.holeNumber == holeNumber }
        )
        do {
            var bounded = descriptor
            bounded.fetchLimit = 1
            return try !context.fetch(bounded).isEmpty
        } catch {
            helperLogger.error("discrepancyExists fetch failed: \(error)")
            return false
        }
    }

    /// Performs app-foreground round discovery (covers missed CKSubscription pushes).
    func performForegroundDiscovery() async {
        // Nearby discovery has no iCloud dependency — resume browsing/advertising
        // regardless of `iCloudRecordName`. Without this hoist, a foreground after
        // signing out of iCloud (or before identity resolution completes) would leave
        // nearby discovery suspended for the rest of the foreground session.
        await nearbyDiscoveryClient.startBrowsing()
        if let round = currentOrganizedActiveRound() {
            await nearbyDiscoveryClient.startAdvertising(roundID: round.id, playerIDs: round.playerIDs)
        }

        guard let userID = iCloudRecordName else { return }
        await syncScheduler.foregroundDiscovery(currentUserID: userID)
    }

    /// Stops active round polling when the app enters background.
    ///
    /// Separate from `roundDidEnd()` because the round is still logically active —
    /// polling resumes when the app returns to foreground via `roundDidStart()`.
    func handleAppBackground() async {
        await syncScheduler.stopActiveRoundPolling()
        await nearbyDiscoveryClient.stopAdvertising()
        await nearbyDiscoveryClient.stopBrowsing()
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
