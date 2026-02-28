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
/// Tapping any player row (scored or unscored) expands an inline `ScoreInputView`.
/// - Unscored row: initial score entry, calls `onScore`
/// - Scored row: correction flow, calls `onCorrection` with the previous event ID
struct HoleCardView: View {
    let holeNumber: Int
    let par: Int
    let courseName: String
    let players: [ScorecardPlayer]
    let scores: [ScoreEvent]
    /// When `true`, score tap targets are disabled — the round is in awaitingFinalization or completed.
    var isRoundFinished: Bool = false
    let onScore: (String, Int) -> Void
    /// Called when a correction is confirmed: (playerID, previousEventID, newStrokeCount).
    let onCorrection: (String, UUID, Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedPlayerID: String?
    /// Non-nil when the expanded picker is for a correction; holds the previous event's ID.
    @State private var correctionPreviousEventID: UUID?

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
                let currentScore = resolveCurrentScore(for: player.id, hole: holeNumber, in: scores)
                if expandedPlayerID == player.id {
                    ScoreInputView(
                        playerName: player.displayName,
                        par: par,
                        preSelectedScore: correctionPreviousEventID != nil ? currentScore?.strokeCount : nil,
                        isRoundFinished: isRoundFinished,
                        onSelect: { strokeCount in
                            if let prevID = correctionPreviousEventID {
                                onCorrection(player.id, prevID, strokeCount)
                            } else {
                                onScore(player.id, strokeCount)
                            }
                            expandedPlayerID = nil
                            correctionPreviousEventID = nil
                        },
                        onCancel: {
                            expandedPlayerID = nil
                            correctionPreviousEventID = nil
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    playerRow(player: player, score: currentScore)
                }
            }
        }
        .animation(AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion: reduceMotion), value: expandedPlayerID)
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
            guard !isRoundFinished else { return }
            withAnimation(AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion: reduceMotion)) {
                expandedPlayerID = player.id
                // Non-nil for scored rows (correction), nil for unscored (initial entry)
                correctionPreviousEventID = score?.id
            }
        }
        .opacity(isRoundFinished ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isRoundFinished ? [] : [.isButton])
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
