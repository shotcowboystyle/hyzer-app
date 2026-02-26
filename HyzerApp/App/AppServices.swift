import SwiftData
import Observation
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
    private(set) var iCloudRecordName: String?

    private let iCloudIdentityProvider: any ICloudIdentityProvider
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "ICloudIdentity")

    init(modelContainer: ModelContainer, iCloudIdentityProvider: any ICloudIdentityProvider) {
        self.modelContainer = modelContainer
        self.iCloudIdentityProvider = iCloudIdentityProvider
    }

    /// Resolves iCloud identity and updates the Player record.
    ///
    /// Called via `.task` modifier after first frame render (Amendment A5).
    /// Never throws — errors are logged and the app continues with local identity.
    /// Idempotent: skips resolution if Player already has an `iCloudRecordName`.
    func resolveICloudIdentity() async {
        do {
            let context = ModelContext(modelContainer)
            let players = try context.fetch(FetchDescriptor<Player>())
            guard let player = players.first else {
                logger.info("iCloud identity: no player found, skipping")
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
                logger.info("iCloud identity resolved: \(recordName)")
            case .unavailable(let reason):
                logger.info("iCloud unavailable: \(String(describing: reason))")
            }
        } catch {
            logger.error("iCloud identity resolution failed: \(error)")
        }
    }
}
