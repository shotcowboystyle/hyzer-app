import SwiftUI
import SwiftData
import HyzerKit

/// Root view. Checks for an existing Player via `@Query` and routes accordingly.
/// - No Player → `OnboardingView`
/// - Player exists → `HomeView`
struct ContentView: View {
    @Query(sort: \Player.createdAt) private var players: [Player]

    var body: some View {
        if let player = players.first {
            HomeView(player: player)
        } else {
            OnboardingView()
        }
    }
}
