import SwiftUI
import HyzerKit

/// Watch leaderboard — displays current standings during an active round.
///
/// Design spec (Story 7.1):
/// - Full-width rows, no horizontal scrolling
/// - Position + player name + score relative to par
/// - Score colour-coded via `ColorTokens`
/// - Stale indicator when standings are >30s old and phone is unreachable
/// - Standings reshuffles animate with `AnimationCoordinator`
///
/// Story 7.2 addition: Player rows are tappable — navigates to `WatchScoringView`.
struct WatchLeaderboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var viewModel: WatchLeaderboardViewModel
    var connectivityClient: any WatchConnectivityClient

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.standings.isEmpty {
                    emptyStateView
                } else {
                    leaderboardList
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                TimelineView(.periodic(from: .now, by: 5)) { _ in
                    if viewModel.isStale {
                        WatchStaleIndicatorView(durationText: viewModel.staleDurationText)
                            .padding(.bottom, SpacingTokens.xs)
                    }
                }
            }
            .navigationDestination(for: Standing.self) { standing in
                if let snapshot = viewModel.snapshot {
                    WatchScoringView(
                        viewModel: WatchScoringViewModel(
                            playerName: standing.playerName,
                            playerID: standing.playerID,
                            holeNumber: snapshot.currentHole,
                            parValue: snapshot.currentHolePar,
                            roundID: snapshot.roundID,
                            connectivityClient: connectivityClient
                        )
                    )
                }
            }
        }
    }

    // MARK: - Leaderboard list

    private var leaderboardList: some View {
        List(viewModel.standings) { standing in
            NavigationLink(value: standing) {
                StandingRowView(standing: standing)
            }
            .listRowBackground(Color.backgroundElevated)
        }
        .listStyle(.plain)
        .animation(
            AnimationCoordinator.animation(
                .spring(response: AnimationTokens.leaderboardReshuffleDuration, dampingFraction: 0.8),
                reduceMotion: reduceMotion
            ),
            value: viewModel.standings.map(\.playerID)
        )
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Text("Waiting for round")
                .font(TypographyTokens.h3)
                .foregroundStyle(Color.textSecondary)
            if !viewModel.isConnected {
                Text("Phone not connected")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.warning)
            }
        }
    }
}

// MARK: - Standing row

private struct StandingRowView: View {
    let standing: Standing

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("#\(standing.position)")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 28, alignment: .leading)

            Text(standing.playerName)
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer()

            Text(standing.formattedScore)
                .font(TypographyTokens.score)
                .foregroundStyle(standing.scoreColor)
        }
        .padding(.vertical, SpacingTokens.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: standing))
    }

    private func accessibilityLabel(for standing: Standing) -> String {
        let scoreDesc: String
        let rel = standing.scoreRelativeToPar
        if rel < 0 {
            scoreDesc = "\(abs(rel)) under par"
        } else if rel == 0 {
            scoreDesc = "at par"
        } else {
            scoreDesc = "\(rel) over par"
        }
        return "\(standing.playerName), position \(standing.position), \(scoreDesc)"
    }
}
