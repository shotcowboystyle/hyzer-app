import SwiftUI
import HyzerKit

/// A persistent floating pill showing condensed leaderboard standings.
///
/// Overlays the top of `ScorecardContainerView` via a `ZStack`.
/// Tapping opens `LeaderboardExpandedView` as a `.sheet` modal.
/// Pulses briefly after standings change to signal a position update.
///
/// When `badgeCount > 0`, a red circle badge overlays the trailing edge of the pill.
/// Tapping the badge triggers `onBadgeTap` — separate from the leaderboard expand action.
struct LeaderboardPillView: View {
    let viewModel: LeaderboardViewModel

    /// Number of unresolved discrepancies to show in the badge. `nil` hides the badge.
    var badgeCount: Int? = nil

    /// Called when the organizer taps the discrepancy badge (distinct from pill tap).
    var onBadgeTap: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            if let count = badgeCount, count > 0 {
                discrepancyBadge(count: count)
                    .offset(x: SpacingTokens.xs, y: -SpacingTokens.xs)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    .animation(
                        AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion),
                        value: count
                    )
            }
        }
    }

    // MARK: - Badge

    private func discrepancyBadge(count: Int) -> some View {
        Button(action: { onBadgeTap?() }) {
            Text("\(count)")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.backgroundPrimary)
                .padding(.horizontal, SpacingTokens.xs)
                .padding(.vertical, 2)
                .background(Color.scoreWayOver)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) unresolved score discrepanc\(count == 1 ? "y" : "ies")")
        .accessibilityHint("Double tap to review and resolve score discrepancies")
        .accessibilityAddTraits(.isButton)
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
