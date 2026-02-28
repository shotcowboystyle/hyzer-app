import SwiftUI
import HyzerKit

/// A unified player row model combining registered players and guests.
struct ScorecardPlayer: Identifiable {
    /// Player.id.uuidString for registered players; "guest:{name}" for guests.
    let id: String
    let displayName: String
    let isGuest: Bool
}

/// A single hole card showing hole info and all player score rows.
///
/// Displayed inside a `TabView(.page)` in `ScorecardContainerView`.
/// Tapping an unscored player row expands an inline `ScoreInputView`.
struct HoleCardView: View {
    let holeNumber: Int
    let par: Int
    let courseName: String
    let players: [ScorecardPlayer]
    let scores: [ScoreEvent]
    let onScore: (String, Int) -> Void

    @State private var expandedPlayerID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.md) {
                holeHeader
                Divider()
                    .overlay(Color.backgroundTertiary)
                playerRows
            }
            .padding(SpacingTokens.md)
        }
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, SpacingTokens.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hole \(holeNumber), Par \(par)")
    }

    // MARK: - Hole Header

    private var holeHeader: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("Hole \(holeNumber)")
                .font(TypographyTokens.h2)
                .foregroundStyle(Color.textPrimary)
            HStack(spacing: SpacingTokens.sm) {
                Text("Par \(par)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Text("·")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Text(courseName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.top, SpacingTokens.sm)
    }

    // MARK: - Player Rows

    private var playerRows: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(players) { player in
                let currentScore = resolveCurrentScore(playerID: player.id)
                if expandedPlayerID == player.id {
                    ScoreInputView(
                        playerName: player.displayName,
                        par: par,
                        onSelect: { strokeCount in
                            onScore(player.id, strokeCount)
                            expandedPlayerID = nil
                        },
                        onCancel: {
                            expandedPlayerID = nil
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    playerRow(player: player, score: currentScore)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expandedPlayerID)
    }

    private func playerRow(player: ScorecardPlayer, score: ScoreEvent?) -> some View {
        HStack {
            Text(player.displayName)
                .font(TypographyTokens.h3)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Spacer()
            if let score {
                Text("\(score.strokeCount)")
                    .font(TypographyTokens.score)
                    .foregroundStyle(scoreColor(strokeCount: score.strokeCount, par: par))
                    .accessibilityLabel("\(player.displayName), score \(score.strokeCount)")
            } else {
                Text("—")
                    .font(TypographyTokens.score)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityLabel("\(player.displayName), no score")
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .frame(minHeight: SpacingTokens.minimumTouchTarget)
        .background(Color.backgroundPrimary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                expandedPlayerID = player.id
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Score Resolution (Amendment A7)

    /// Returns the current (leaf node) ScoreEvent for a player on this hole.
    ///
    /// The current score is the ScoreEvent that no other ScoreEvent supersedes.
    /// For Story 3.2, all events have `supersedesEventID = nil`, so every event is a leaf.
    private func resolveCurrentScore(playerID: String) -> ScoreEvent? {
        let playerScores = scores.filter { $0.playerID == playerID }
        let supersededIDs = Set(playerScores.compactMap(\.supersedesEventID))
        return playerScores.first { !supersededIDs.contains($0.id) }
    }

    // MARK: - Score Color

    private func scoreColor(strokeCount: Int, par: Int) -> Color {
        let diff = strokeCount - par
        if diff <= -1 { return .scoreUnderPar }
        if diff == 0  { return .scoreAtPar }
        if diff == 1  { return .scoreOverPar }
        return .scoreWayOver
    }
}
