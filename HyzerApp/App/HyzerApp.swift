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
            iCloudIdentityProvider: LiveICloudIdentityProvider()
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appServices)
                .modelContainer(appServices.modelContainer)
                .task { await appServices.resolveICloudIdentity() }
                .task { await appServices.seedCoursesIfNeeded() }
        }
    }

    // MARK: - Private

    private static func makeModelContainer() -> ModelContainer {
        // Domain store: Player, Course, Hole, Round, ScoreEvent — synced via manual CloudKit
        let domainConfig = ModelConfiguration(
            "DomainStore",
            schema: Schema([Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self])
        )
        // Note: Operational store (for SyncMetadata) is added when SyncMetadata is implemented.
        // An empty Schema([]) configuration causes CoreData to reject the store at startup.
        do {
            return try ModelContainer(
                for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
                configurations: domainConfig
            )
        } catch {
            // Fatal: the app cannot function without persistent storage.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
