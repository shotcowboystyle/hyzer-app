import SwiftUI
import HyzerKit

/// A persistent floating pill showing condensed leaderboard standings.
///
/// Overlays the top of `ScorecardContainerView` via a `ZStack`.
/// Tapping opens `LeaderboardExpandedView` as a `.sheet` modal.
/// Pulses briefly after standings change to signal a position update.
struct LeaderboardPillView: View {
    let viewModel: LeaderboardViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(viewModel.currentStandings) { standing in
                        pillEntry(standing: standing)
                            .id(standing.playerID)
                    }
                }
                .padding(.horizontal, SpacingTokens.sm)
            }
            .frame(height: 32)
            .background(.ultraThinMaterial)
            .background(Color.backgroundElevated.opacity(0.5))
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                viewModel.isExpanded = true
            }
            .scaleEffect(viewModel.showPulse ? 1.03 : 1.0)
            .animation(
                AnimationCoordinator.animation(.easeInOut(duration: 0.3), reduceMotion: reduceMotion),
                value: viewModel.showPulse
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(voiceOverLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap to expand full leaderboard")
            .onChange(of: viewModel.currentStandings) { _, _ in
                if let index = viewModel.currentPlayerStandingIndex,
                   index < viewModel.currentStandings.count {
                    let playerID = viewModel.currentStandings[index].playerID
                    withAnimation(AnimationCoordinator.animation(.easeInOut(duration: 0.3), reduceMotion: reduceMotion)) {
                        proxy.scrollTo(playerID, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Pill Entry

    private func pillEntry(standing: Standing) -> some View {
        HStack(spacing: 2) {
            Text("\(standing.position).")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
            Text(standing.playerName)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text(standing.formattedScore)
                .font(TypographyTokens.caption)
                .foregroundStyle(standing.scoreColor)
        }
        .padding(.horizontal, SpacingTokens.xs)
    }

    // MARK: - Helpers

    private var voiceOverLabel: String {
        guard let leader = viewModel.currentStandings.first else {
            return "Leaderboard: no scores yet"
        }
        return "Leaderboard: \(leader.playerName) leads at \(leader.formattedScore) par"
    }

}
