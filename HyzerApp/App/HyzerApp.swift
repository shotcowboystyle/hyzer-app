import SwiftUI
import SwiftData
import HyzerKit

@main
struct HyzerApp: App {
    let appServices: AppServices

    init() {
        let container = Self.makeModelContainer()
        appServices = AppServices(
            modelContainer: container,
            iCloudIdentityProvider: LiveICloudIdentityProvider(),
            cloudKitClient: LiveCloudKitClient()
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appServices)
                .modelContainer(appServices.modelContainer)
                .task { await appServices.resolveICloudIdentity() }
                .task { await appServices.seedCoursesIfNeeded() }
                .task { await appServices.syncEngine.start() }
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
            schema: Schema([Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self])
        )
        let operationalConfig = ModelConfiguration(
            "OperationalStore",
            schema: Schema([SyncMetadata.self])
        )

        // Attempt 1: normal startup with both stores
        do {
            return try ModelContainer(
                for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self,
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
                    for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self,
                    configurations: domainConfig, freshOperational
                )
            } catch {
                // Attempt 3: domain store is corrupt — delete both and start fresh.
                // CloudKit has the full event history; SyncEngine will re-pull on next launch.
                deleteStore(named: "DomainStore")
                deleteStore(named: "OperationalStore")
                let freshDomain = ModelConfiguration(
                    "DomainStore",
                    schema: Schema([Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self])
                )
                let freshOp = ModelConfiguration(
                    "OperationalStore",
                    schema: Schema([SyncMetadata.self])
                )
                do {
                    return try ModelContainer(
                        for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self,
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
            try? fm.removeItem(at: url)
        }
    }
}
