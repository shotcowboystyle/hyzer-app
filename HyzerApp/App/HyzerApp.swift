import SwiftUI
import SwiftData
import UIKit
import HyzerKit

@main
struct HyzerApp: App {
    let appServices: AppServices
    @Environment(\.scenePhase) private var scenePhase

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        MetricKitObserver.shared.register()
        let container = Self.makeModelContainer()
        let networkMonitor = LiveNetworkMonitor()
        let services = AppServices(
            modelContainer: container,
            iCloudIdentityProvider: LiveICloudIdentityProvider(),
            cloudKitClient: LiveCloudKitClient(),
            networkMonitor: networkMonitor,
            notificationService: LiveNotificationService()
        )
        appServices = services
        // Give AppDelegate a reference to forward remote notifications
        AppDelegate.shared = services
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appServices)
                .modelContainer(appServices.modelContainer)
                .task {
                    // Sequential: identity must resolve before seeds, seeds before sync
                    await appServices.resolveICloudIdentity()
                    await appServices.seedCoursesIfNeeded()
                    await appServices.startSync()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task { await appServices.performForegroundDiscovery() }
                    case .background:
                        Task { await appServices.handleAppBackground() }
                    default:
                        break
                    }
                }
        }
    }

    // MARK: - Private

    /// Constructs the dual-store `ModelContainer`:
    ///
    /// - **Domain store** (`DomainStore`): Player, Course, Hole, Round, ScoreEvent.
    ///   Backed by an iCloud-synced SQLite file (manual CloudKit push/pull).
    /// - **Operational store** (`OperationalStore`): SyncMetadata.
    ///   Local-only, never synced to CloudKit. Safely recoverable by deletion.
    ///
    /// Recovery strategy (Amendment A6):
    /// 1. If the operational store fails, delete its file and recreate it.
    /// 2. If the domain store fails, delete both stores and recreate them
    ///    (safe: CloudKit holds the full event history; SyncEngine will re-pull).
    private static func makeModelContainer() -> ModelContainer {
        let domainConfig = ModelConfiguration(
            "DomainStore",
            schema: Schema([Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, Discrepancy.self])
        )
        let operationalConfig = ModelConfiguration(
            "OperationalStore",
            schema: Schema([SyncMetadata.self])
        )

        // Attempt 1: normal startup with both stores
        do {
            return try ModelContainer(
                for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, Discrepancy.self, SyncMetadata.self,
                configurations: domainConfig, operationalConfig
            )
        } catch {
            // Attempt 2: operational store may be corrupt — delete it and retry
            deleteStore(named: "OperationalStore")
            let freshOperational = ModelConfiguration(
                "OperationalStore",
                schema: Schema([SyncMetadata.self])
            )
            do {
                return try ModelContainer(
                    for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, Discrepancy.self, SyncMetadata.self,
                    configurations: domainConfig, freshOperational
                )
            } catch {
                // Attempt 3: domain store is corrupt — delete both and start fresh.
                // CloudKit has the full event history; SyncEngine will re-pull on next launch.
                deleteStore(named: "DomainStore")
                deleteStore(named: "OperationalStore")
                let freshDomain = ModelConfiguration(
                    "DomainStore",
                    schema: Schema([Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, Discrepancy.self])
                )
                let freshOp = ModelConfiguration(
                    "OperationalStore",
                    schema: Schema([SyncMetadata.self])
                )
                do {
                    return try ModelContainer(
                        for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, Discrepancy.self, SyncMetadata.self,
                        configurations: freshDomain, freshOp
                    )
                } catch {
                    fatalError("Failed to create ModelContainer after recovery attempt: \(error)")
                }
            }
        }
    }

    private static func deleteStore(named name: String) {
        let fm = FileManager.default
        guard let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeURL = url.appendingPathComponent("\(name).store")
        let walURL = storeURL.appendingPathExtension("wal")
        let shmURL = storeURL.appendingPathExtension("shm")
        for url in [storeURL, walURL, shmURL] {
            // Safe to ignore: files may not exist (WAL/SHM are only present in WAL mode).
            // Cleanup failure is non-fatal — makeModelContainer retries on next launch.
            try? fm.removeItem(at: url)
        }
    }
}

// MARK: - AppDelegate (remote notification handler)

/// Minimal UIApplicationDelegate to handle CKSubscription silent push notifications.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by `HyzerApp.init` so `AppDelegate` can forward notifications to `AppServices`.
    static weak var shared: AppServices?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        application.registerForRemoteNotifications()
        // Seed deep-link before first view renders if launched from a notification tap.
        AppDelegate.shared?.seedDeepLinkFromLaunchOptions(launchOptions)
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            guard let services = AppDelegate.shared else {
                completionHandler(.noData)
                return
            }
            // Branch on subscription ID: Round-active-creation → handleRoundStartedNotification
            // ScoreEvent-creation (and any other) → existing silent-push handler
            if CKNotificationEnvelope.subscriptionID(from: userInfo) == "Round-active-creation" {
                await services.handleRoundStartedNotification(userInfo)
            } else {
                await services.handleRemoteNotification()
            }
            completionHandler(.newData)
        }
    }
}
