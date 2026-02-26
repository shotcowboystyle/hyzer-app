import SwiftData
import Observation

/// Composition root for all app services.
///
/// Created once at app startup and injected into the SwiftUI environment.
/// ViewModels receive individual services via constructor injection — never this container.
@MainActor
@Observable
final class AppServices {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
}
