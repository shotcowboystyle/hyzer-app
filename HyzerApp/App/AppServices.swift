import SwiftData
import Observation
import UIKit
import os.log
import HyzerKit

/// Composition root for all app services.
///
/// Created once at app startup and injected into the SwiftUI environment.
/// ViewModels receive individual services via constructor injection — never this container.
@MainActor
@Observable
final class AppServices {
    let modelContainer: ModelContainer
    let scoringService: ScoringService
    private(set) var iCloudRecordName: String?

    private let iCloudIdentityProvider: any ICloudIdentityProvider
    private let iCloudLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "ICloudIdentity")
    private let seederLogger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "CourseSeeder")

    init(modelContainer: ModelContainer, iCloudIdentityProvider: any ICloudIdentityProvider) {
        self.modelContainer = modelContainer
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.scoringService = ScoringService(modelContext: modelContainer.mainContext, deviceID: deviceID)
        self.iCloudIdentityProvider = iCloudIdentityProvider
    }

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
