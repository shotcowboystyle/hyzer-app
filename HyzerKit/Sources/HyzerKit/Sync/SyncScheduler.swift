import Foundation
import os.log
import CloudKit

private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "SyncScheduler")

/// Coordinates the sync lifecycle: periodic polling, connectivity-triggered flushes,
/// CKSubscription setup, and remote-notification-triggered pulls.
///
/// **Actor** — serializes timer control, connectivity observation, and notification handling.
///
/// State machine:
/// ```
/// App Launch
///   └─→ setupSubscriptions()          — idempotent CKQuerySubscription per record type
///   └─→ startConnectivityListener()   — observe NetworkMonitor.pathUpdates
///          ├── lost     → syncEngine marks .offline
///          └── restored → retryFailed() + pushPending()
///
/// Active Round Started
///   └─→ startActiveRoundPolling()     — every 45s: pushPending() + pullRecords()
///
/// Round Completed / App Backgrounds
///   └─→ stopActiveRoundPolling()
///
/// Remote Notification (CKSubscription)
///   └─→ handleRemoteNotification()    → pullRecords()
///
/// App Foreground (no active round)
///   └─→ foregroundDiscovery(currentUserID:)
/// ```
public actor SyncScheduler {
    private let syncEngine: SyncEngine
    private let cloudKitClient: any CloudKitClient
    private let networkMonitor: any NetworkMonitor
    private let userDefaults: any UserDefaultsStorage
    /// Resolves the local player's UUID at subscription-setup time.
    /// Injected from the `AppServices` composition root so `SyncScheduler` avoids a direct
    /// `ModelContainer` dependency. Returns `nil` if the player hasn't onboarded yet.
    ///
    /// **Identity stability note:** `Player.id` is set once at onboarding and never reassigned.
    /// If a future story supports re-onboarding under a new iCloud account, this closure must
    /// return the new player ID and `setupSubscriptions()` must be re-called to register a new
    /// predicate. Today, the subscription is stable for the device lifetime.
    private let localPlayerIDProvider: @Sendable () async -> UUID?

    /// Active polling task; non-nil while a round is in progress.
    private var pollingTask: Task<Void, Never>?

    /// Active connectivity listener task.
    private var connectivityTask: Task<Void, Never>?

    /// Timestamp of the last foreground discovery call (throttle guard).
    private var lastForegroundDiscovery: Date?

    // MARK: - Init

    public init(
        syncEngine: SyncEngine,
        cloudKitClient: any CloudKitClient,
        networkMonitor: any NetworkMonitor,
        userDefaults: any UserDefaultsStorage = UserDefaults.standard,
        localPlayerIDProvider: @Sendable @escaping () async -> UUID?
    ) {
        self.syncEngine = syncEngine
        self.cloudKitClient = cloudKitClient
        self.networkMonitor = networkMonitor
        self.userDefaults = userDefaults
        self.localPlayerIDProvider = localPlayerIDProvider
    }

    // MARK: - App lifecycle

    /// Called at app launch. Sets up CKSubscriptions (idempotent) and starts the connectivity listener.
    public func start() async {
        await setupSubscriptions()
        startConnectivityListener()
    }

    // MARK: - Active round polling

    /// Starts a periodic sync timer that fires every 45 seconds while a round is active.
    ///
    /// Uses `Task.sleep(for:)` in a loop — NOT `Timer` or `DispatchQueue`.
    /// Calling this again while already polling is a no-op (guard prevents duplicate tasks).
    public func startActiveRoundPolling() {
        guard pollingTask == nil else { return }
        logger.info("SyncScheduler: starting active round polling (45s interval)")
        let engine = syncEngine
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(45))
                } catch {
                    break  // Task was cancelled during sleep
                }
                guard !Task.isCancelled else { break }
                await engine.pushPending()
                await engine.pullRecords()
            }
        }
    }

    /// Stops the periodic polling timer.
    public func stopActiveRoundPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        logger.info("SyncScheduler: stopped active round polling")
    }

    // MARK: - Remote notification

    /// Called when a CKSubscription silent push notification arrives.
    ///
    /// Triggers an immediate `pullRecords()` to fetch the new remote data.
    public func handleRemoteNotification() async {
        logger.info("SyncScheduler: remote notification received — pulling records")
        await syncEngine.pullRecords()
    }

    // MARK: - Foreground discovery

    /// Performs round discovery when the app enters foreground without an active round.
    ///
    /// Covers missed CKSubscription silent pushes (iOS throttles in Low Power Mode,
    /// background-killed apps). Throttled to at most once per 30 seconds to prevent
    /// rapid scene phase flapping from triggering repeated queries.
    ///
    /// - Note: Current implementation pulls all ScoreEvent records via `pullRecords()`
    ///   rather than executing a targeted CKQuery for active rounds containing the user
    ///   (as specified by AC5). The generic pull approach is functionally correct —
    ///   deduplication handles it — but less efficient than the specified round-specific
    ///   query. The `currentUserID` parameter is preserved for the future optimization.
    ///
    /// - Parameter currentUserID: The iCloud record name of the current user.
    public func foregroundDiscovery(currentUserID: String) async {
        let now = Date()
        if let last = lastForegroundDiscovery, now.timeIntervalSince(last) < 30 {
            return  // Throttle: skip if last discovery was < 30s ago
        }
        lastForegroundDiscovery = now

        logger.info("SyncScheduler: foreground discovery for user \(currentUserID)")
        // Pull any missed records — SyncEngine.pullRecords() already deduplicates
        await syncEngine.pullRecords()
    }

    // MARK: - Private

    /// Creates CKQuerySubscriptions for each record type (idempotent — checks existing first).
    ///
    /// Idempotency strategy: fetch all subscription IDs from CloudKit. If any IDs
    /// were previously saved to UserDefaults AND are still present in CloudKit,
    /// skip creation. Otherwise subscribe and persist the new ID.
    ///
    /// Subscriptions created:
    /// - `ScoreEvent-creation`: silent push (existing) for live-score syncing
    /// - `Round-active-creation`: alert push (Story 12.1) for "Round Started" notification
    private func setupSubscriptions() async {
        let existingIDs: [CKSubscription.ID]
        do {
            existingIDs = try await cloudKitClient.fetchAllSubscriptionIDs()
        } catch {
            logger.error("SyncScheduler: failed to fetch existing subscriptions: \(error)")
            return
        }

        // Silent-push subscriptions (ScoreEvent)
        let silentRecordTypes = [ScoreEventRecord.recordType]
        for recordType in silentRecordTypes {
            let defaultsKey = "HyzerApp.subscriptionID.\(recordType)"
            let storedID = userDefaults.string(forKey: defaultsKey)
            if let storedID, existingIDs.contains(storedID) {
                logger.info("SyncScheduler: subscription for \(recordType) already active — skipping")
                continue
            }
            do {
                let subID = try await cloudKitClient.subscribe(
                    to: recordType,
                    predicate: NSPredicate(value: true)
                )
                userDefaults.setString(subID, forKey: defaultsKey)
                logger.info("SyncScheduler: registered CKSubscription \(subID) for \(recordType)")
            } catch {
                logger.error("SyncScheduler: failed to subscribe to \(recordType): \(error)")
            }
        }

        // Alert-push subscription for Round-active-creation (Story 12.1, AC #1/#2)
        await setupRoundActiveSubscription(existingIDs: existingIDs)

        // Alert-push subscription for Round-complete-update (Story 12.2, AC #1)
        await setupRoundCompleteSubscription(existingIDs: existingIDs)

        // Alert-push subscription for Discrepancy-creation (Story 12.3, AC #1/#2)
        let localPlayerID = await localPlayerIDProvider()
        await setupDiscrepancyCreationSubscription(existingIDs: existingIDs, localPlayerID: localPlayerID)
    }

    /// Creates the `Round-active-creation` CKQuerySubscription that drives "Round Started" push notifications.
    ///
    /// Predicate: `status == "active"` — fires only when a Round record is created with active status.
    /// `alertLocalizationKey` / `alertLocalizationArgs` let CloudKit compose the alert body server-side
    /// from the record's `organizerFirstName` and `courseName` fields — no PII travels through APNs payload (AC #2).
    /// `desiredKeys` delivers organizer/course data to `parseRoundStartedPayload` without a refetch.
    ///
    /// Note: UserDefaults key is now keyed by full subscription ID (not record type) to avoid
    /// collision with the Round-complete-update subscription added in Story 12.2 (deferred-work.md:31).
    /// Migration: on first launch post-upgrade, the old key "HyzerApp.subscriptionID.Round" is absent
    /// so this method re-attempts subscription; CloudKit returns a graceful error for duplicate IDs
    /// (the subscription is still alive in CloudKit). The error is caught and logged — non-fatal.
    private func setupRoundActiveSubscription(existingIDs: [CKSubscription.ID]) async {
        let roundSubID = "Round-active-creation"
        let defaultsKey = "HyzerApp.subscriptionID.\(roundSubID)"
        let storedID = userDefaults.string(forKey: defaultsKey)
        if let storedID, existingIDs.contains(storedID) {
            logger.info("SyncScheduler: Round-active-creation subscription already active — skipping")
            return
        }

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldSendMutableContent = false
        notificationInfo.alertLocalizationKey = "ROUND_STARTED_FORMAT"
        notificationInfo.alertLocalizationArgs = ["organizerFirstName", "courseName"]
        notificationInfo.desiredKeys = ["organizerFirstName", "courseName", "organizerID"]

        do {
            let subID = try await cloudKitClient.subscribeWithAlert(
                to: RoundRecord.recordType,
                predicate: NSPredicate(format: "status == %@", "active"),
                subscriptionID: roundSubID,
                notificationInfo: notificationInfo
            )
            userDefaults.setString(subID, forKey: defaultsKey)
            logger.info("SyncScheduler: registered Round-active-creation subscription \(subID)")
        } catch {
            // Partial-failure recovery is automatic: we do NOT persist the defaults key on
            // failure, so the next launch's idempotency check will re-attempt this subscription
            // even if the ScoreEvent subscription above succeeded and persisted its own key.
            logger.error("SyncScheduler: failed to subscribe to Round-active-creation — will retry on next launch: \(error)")
        }
    }

    /// Creates the `Round-complete-update` CKQuerySubscription that drives "Round Complete" push notifications.
    ///
    /// Predicate: `status == "completed"` with `firesOnRecordUpdate` — fires when a Round record
    /// is UPDATED to completed status. NOT `firesOnRecordCreation` because the Round record already
    /// exists (created on round-start by Story 12.1); creation would never fire for this case.
    ///
    /// `alertLocalizationKey` / `alertLocalizationArgs` compose the alert body server-side —
    /// PII never enters the APNs payload (PMVP-NFR1 structural guarantee, same mechanism as Story 12.1).
    ///
    /// `aps-environment` remains `development` — do NOT flip to `production` until the Epic 12
    /// release-train story; this constraint blocks BOTH 12.1 and 12.2 (and 12.3 when complete).
    private func setupRoundCompleteSubscription(existingIDs: [CKSubscription.ID]) async {
        let roundSubID = "Round-complete-update"
        let defaultsKey = "HyzerApp.subscriptionID.\(roundSubID)"
        let storedID = userDefaults.string(forKey: defaultsKey)
        if let storedID, existingIDs.contains(storedID) {
            logger.info("SyncScheduler: Round-complete-update subscription already active — skipping")
            return
        }

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldSendMutableContent = false
        notificationInfo.alertLocalizationKey = "ROUND_COMPLETE_FORMAT"
        notificationInfo.alertLocalizationArgs = ["courseName", "winnerFirstName", "winnerScoreDisplay"]
        notificationInfo.desiredKeys = ["courseName", "winnerFirstName", "winnerScoreDisplay"]

        do {
            let subID = try await cloudKitClient.subscribeWithAlert(
                to: RoundRecord.recordType,
                predicate: NSPredicate(format: "status == %@", "completed"),
                subscriptionID: roundSubID,
                notificationInfo: notificationInfo
            )
            userDefaults.setString(subID, forKey: defaultsKey)
            logger.info("SyncScheduler: registered Round-complete-update subscription \(subID)")
        } catch {
            logger.error("SyncScheduler: failed to subscribe to Round-complete-update — will retry on next launch: \(error)")
        }
    }

    /// Creates the `Discrepancy-creation` CKQuerySubscription that drives "Discrepancy Detected"
    /// organizer-only push notifications (Story 12.3, AC #1, #2).
    ///
    /// Predicate: `organizerID == <localPlayerID>` — fires server-side only for Discrepancy records
    /// whose `organizerID` matches the local device's player UUID. Non-organizer devices register
    /// a subscription with their own player ID, which never matches rounds where they are not the
    /// organizer. This is the structural enforcement of AC #2: server-side, not client-side.
    ///
    /// If `localPlayerID` is nil (pre-onboarding edge case), subscription registration is skipped.
    /// The next launch's `setupSubscriptions()` retries. Do NOT subscribe with a nil/empty predicate —
    /// that would send every device every discrepancy (catastrophic PII leak and AC #2 failure).
    ///
    /// `firesOnRecordCreation` is correct — Discrepancy records are immutable per event-sourcing.
    ///
    /// **Identity stability:** `Player.id` is stable per device (set once at onboarding). If a future
    /// story supports re-onboarding, this subscription must be explicitly re-registered with the new
    /// player ID predicate. Delete the UserDefaults key and call `setupSubscriptions()` again.
    private func setupDiscrepancyCreationSubscription(existingIDs: [CKSubscription.ID], localPlayerID: UUID?) async {
        guard let localPlayerID else {
            logger.info("SyncScheduler: localPlayerID unavailable — skipping Discrepancy-creation subscription (will retry on next launch)")
            return
        }

        let subID = "Discrepancy-creation"
        let defaultsKey = "HyzerApp.subscriptionID.\(subID)"
        let storedID = userDefaults.string(forKey: defaultsKey)
        if let storedID, existingIDs.contains(storedID) {
            logger.info("SyncScheduler: Discrepancy-creation subscription already active — skipping")
            return
        }

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldSendMutableContent = false
        notificationInfo.alertLocalizationKey = "DISCREPANCY_DETECTED_FORMAT"
        notificationInfo.alertLocalizationArgs = ["holeNumber"]
        notificationInfo.desiredKeys = ["roundID", "playerID", "holeNumber"]

        do {
            let resultID = try await cloudKitClient.subscribeWithAlert(
                to: "Discrepancy",
                predicate: NSPredicate(format: "organizerID == %@", localPlayerID.uuidString),
                subscriptionID: subID,
                notificationInfo: notificationInfo
            )
            userDefaults.setString(resultID, forKey: defaultsKey)
            logger.info("SyncScheduler: registered Discrepancy-creation subscription \(resultID) for player \(localPlayerID.uuidString)")
        } catch {
            logger.error("SyncScheduler: failed to subscribe to Discrepancy-creation — will retry on next launch: \(error)")
        }
    }

    /// Observes `NetworkMonitor.pathUpdates` and reacts to connectivity changes.
    private func startConnectivityListener() {
        connectivityTask?.cancel()
        connectivityTask = Task { [weak self] in
            guard let self else { return }
            for await isConnected in networkMonitor.pathUpdates {
                guard !Task.isCancelled else { break }
                if isConnected {
                    logger.info("SyncScheduler: connectivity restored — retrying failed entries")
                    await self.syncEngine.retryFailed()
                    await self.syncEngine.pushPending()
                } else {
                    logger.info("SyncScheduler: connectivity lost")
                    // SyncEngine will mark .offline when next push/pull fails naturally.
                }
            }
        }
    }
}
