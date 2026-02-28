import SwiftUI
import HyzerKit

/// Full-screen leaderboard presented as a modal sheet when the user taps the floating pill.
///
/// Animates row positions using `AnimationTokens.springGentle` when standings change.
/// Position-change arrows appear briefly using a fade-in/hold/fade-out sequence.
/// Dismisses by swiping down (sheet presentation), returning to the exact hole card.
struct LeaderboardExpandedView: View {
    let viewModel: LeaderboardViewModel
    /// Total holes in the round, used for the "Through X of Y" progress display.
    let totalHoles: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.top, SpacingTokens.sm)
                    .padding(.bottom, SpacingTokens.md)

                Divider()
                    .overlay(Color.backgroundTertiary)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.currentStandings) { standing in
                            standingRow(standing: standing)
                            Divider()
                                .overlay(Color.backgroundTertiary)
                        }
                    }
                }
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        let holesPlayed = viewModel.currentStandings.map(\.holesPlayed).max() ?? 0
        return Text("Through \(holesPlayed) of \(totalHoles) holes")
            .font(TypographyTokens.caption)
            .foregroundStyle(Color.textSecondary)
    }

    // MARK: - Standing Row

    private func standingRow(standing: Standing) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("\(standing.position)")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 24, alignment: .trailing)

            Text(standing.playerName)
                .font(TypographyTokens.h3)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Spacer()

            positionArrow(for: standing)

            Text(formatScore(standing.scoreRelativeToPar))
                .font(TypographyTokens.score)
                .foregroundStyle(scoreColor(standing.scoreRelativeToPar))
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, SpacingTokens.md)
        .frame(minHeight: SpacingTokens.minimumTouchTarget)
        .animation(
            AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion),
            value: standing.position
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(for: standing))
    }

    // MARK: - Position Arrow

    @ViewBuilder
    private func positionArrow(for standing: Standing) -> some View {
        if let change = viewModel.positionChanges[standing.playerID] {
            if change.to < change.from {
                Text("▲")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.scoreUnderPar)
                    .transition(.opacity)
            } else if change.to > change.from {
                Text("▼")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.scoreOverPar)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Helpers

    private func rowAccessibilityLabel(for standing: Standing) -> String {
        let scoreText = formatScore(standing.scoreRelativeToPar)
        return "Position \(standing.position), \(standing.playerName), \(scoreText) par, \(standing.holesPlayed) holes played"
    }

    private func formatScore(_ relative: Int) -> String {
        if relative < 0 { return "\(relative)" }
        if relative == 0 { return "E" }
        return "+\(relative)"
    }

    private func scoreColor(_ relative: Int) -> Color {
        if relative < 0 { return .scoreUnderPar }
        if relative == 0 { return .scoreAtPar }
        return .scoreOverPar
    }
}
