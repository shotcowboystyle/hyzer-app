import SwiftUI
import SwiftData
import HyzerKit

/// Root view after onboarding — 3-tab navigation shell (Story 1.3).
struct HomeView: View {
    let player: Player

    var body: some View {
        TabView {
            Tab("Scoring", systemImage: "sportscourt") {
                ScoringTabView(player: player)
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryTabView(player: player)
            }
            Tab("Courses", systemImage: "map") {
                NavigationStack {
                    CourseListView()
                }
            }
        }
        .tint(Color.accentPrimary)
    }
}

// MARK: - Scoring Tab

private struct ScoringTabView: View {
    let player: Player

    @Query(
        filter: #Predicate<Round> { $0.status == "active" || $0.status == "awaitingFinalization" },
        sort: \Round.startedAt
    ) private var activeRounds: [Round]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingRoundSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if let activeRound = activeRounds.first {
                    ScorecardContainerView(round: activeRound)
                        .transition(.opacity)
                } else {
                    noRoundView
                        .transition(.opacity)
                }
            }
            .animation(AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion), value: activeRounds.isEmpty)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("Scoring")
        }
        .sheet(isPresented: $isShowingRoundSetup) {
            RoundSetupView(organizer: player)
        }
    }

    private var noRoundView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Text("No round in progress.")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
            Button("Start Round") {
                isShowingRoundSetup = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
        }
    }

}

// MARK: - History Tab

private struct HistoryTabView: View {
    let player: Player

    var body: some View {
        HistoryListView(currentPlayerID: player.id.uuidString)
    }
}
