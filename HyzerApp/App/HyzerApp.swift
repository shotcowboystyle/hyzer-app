import SwiftUI
import SwiftData
import HyzerKit

@main
struct HyzerApp: App {
    let appServices: AppServices

    init() {
        let container = Self.makeModelContainer()
        appServices = AppServices(modelContainer: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appServices)
                .modelContainer(appServices.modelContainer)
        }
    }

    // MARK: - Private

    private static func makeModelContainer() -> ModelContainer {
        // Domain store: Player (and future: Round, Course, Hole, ScoreEvent) — synced via manual CloudKit
        let domainConfig = ModelConfiguration(
            "DomainStore",
            schema: Schema([Player.self])
        )
        // Operational store: future SyncMetadata — local only, never syncs
        let operationalConfig = ModelConfiguration(
            "OperationalStore",
            schema: Schema([]),
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(
                for: Player.self,
                configurations: domainConfig, operationalConfig
            )
        } catch {
            // Fatal: the app cannot function without persistent storage.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
