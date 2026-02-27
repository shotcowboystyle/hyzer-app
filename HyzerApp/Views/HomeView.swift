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
                HistoryTabView()
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
        filter: #Predicate<Round> { $0.status == "active" },
        sort: \Round.startedAt
    ) private var activeRounds: [Round]

    @Query(sort: \Course.name) private var courses: [Course]

    @State private var isShowingRoundSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if let activeRound = activeRounds.first {
                    ActiveRoundView(round: activeRound, courseName: courseName(for: activeRound))
                } else {
                    noRoundView
                }
            }
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

    private func courseName(for round: Round) -> String {
        courses.first { $0.id == round.courseID }?.name ?? "Unknown Course"
    }
}

// MARK: - Active Round (placeholder for Story 3.2)

private struct ActiveRoundView: View {
    let round: Round
    let courseName: String

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Text("Round at \(courseName)")
                .font(TypographyTokens.h2)
                .foregroundStyle(Color.textPrimary)
            Text("\(round.holeCount) holes · \(round.playerIDs.count + round.guestNames.count) players")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
            Text("Scoring coming in Story 3.2")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(SpacingTokens.xl)
    }
}

// MARK: - History Tab (placeholder for Epic 8)

private struct HistoryTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.lg) {
                Text("Your round history will appear here after your first completed round.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("History")
        }
    }
}
