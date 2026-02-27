import SwiftUI
import HyzerKit

/// Root view after onboarding — 3-tab navigation shell (Story 1.3).
struct HomeView: View {
    let player: Player

    var body: some View {
        TabView {
            Tab("Scoring", systemImage: "sportscourt") {
                ScoringTabView()
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

// MARK: - Scoring Tab (placeholder for Epic 3)

private struct ScoringTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.lg) {
                Text("No round in progress.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textSecondary)
                Button("Start Round") {
                    // Placeholder — Epic 3
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("Scoring")
        }
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
