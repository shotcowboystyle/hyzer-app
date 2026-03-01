import SwiftUI
import HyzerKit

@main
struct HyzerWatchApp: App {
    @State private var connectivityService = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            WatchLeaderboardView(
                viewModel: WatchLeaderboardViewModel(provider: connectivityService),
                connectivityService: connectivityService
            )
        }
    }
}
