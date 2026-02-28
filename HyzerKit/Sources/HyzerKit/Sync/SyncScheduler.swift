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

    /// Active polling task; non-nil while a round is in progress.
    private var pollingTask: Task<Void, Never>?

    /// Active connectivity listener task.
    private var connectivityTask: Task<Void, Never>?

    /// Timestamp of the last foreground discovery call (throttle guard).
    private var lastForegroundDiscovery: Date?

    // MARK: - Init

    public init(syncEngine: SyncEngine, cloudKitClient: any CloudKitClient, networkMonitor: any NetworkMonitor) {
        self.syncEngine = syncEngine
        self.cloudKitClient = cloudKitClient
        self.networkMonitor = networkMonitor
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
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(45))
                } catch {
                    break  // Task was cancelled during sleep
                }
                guard let self, !Task.isCancelled else { break }
                await self.syncEngine.pushPending()
                await self.syncEngine.pullRecords()
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

    /// Performs a round-discovery CKQuery when the app enters foreground without an active round.
    ///
    /// Covers missed CKSubscription silent pushes (iOS throttles in Low Power Mode,
    /// background-killed apps). Throttled to at most once per 30 seconds to prevent
    /// rapid scene phase flapping from triggering repeated queries.
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
    private func setupSubscriptions() async {
        let recordTypes = [ScoreEventRecord.recordType]

        let existingIDs: [CKSubscription.ID]
        do {
            existingIDs = try await cloudKitClient.fetchAllSubscriptionIDs()
        } catch {
            logger.error("SyncScheduler: failed to fetch existing subscriptions: \(error)")
            return
        }

        for recordType in recordTypes {
            let defaultsKey = "HyzerApp.subscriptionID.\(recordType)"
            let storedID = UserDefaults.standard.string(forKey: defaultsKey)

            // Skip creation if the stored subscription ID still exists in CloudKit
            if let storedID, existingIDs.contains(storedID) {
                logger.info("SyncScheduler: subscription for \(recordType) already active — skipping")
                continue
            }

            do {
                let subID = try await cloudKitClient.subscribe(
                    to: recordType,
                    predicate: NSPredicate(value: true)
                )
                UserDefaults.standard.set(subID, forKey: defaultsKey)
                logger.info("SyncScheduler: registered CKSubscription \(subID) for \(recordType)")
            } catch {
                logger.error("SyncScheduler: failed to subscribe to \(recordType): \(error)")
            }
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
