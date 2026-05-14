import SwiftUI
import HyzerKit

/// A unified player row model combining registered players and guests.
struct ScorecardPlayer: Identifiable {
    /// Player.id.uuidString for registered players; opaque `"guest:<uuid>"` for guests.
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
    /// Keyed on `Player.id.uuidString`. Used for "Scored by [name]" attribution.
    let scorerNamesByID: [String: String]
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
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
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
        HStack(alignment: .center) {
            Text(player.displayName)
                .font(TypographyTokens.h3)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer()
            if let score {
                let scorerName = scorerNamesByID[score.reportedByPlayerID.uuidString]
                VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                    Text("\(score.strokeCount)")
                        .font(TypographyTokens.score)
                        .foregroundStyle(Color.scoreColor(strokes: score.strokeCount, par: par))
                    if let name = scorerName {
                        Text("Scored by \(name)")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("—")
                    .font(TypographyTokens.score)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .frame(minHeight: SpacingTokens.minimumTouchTarget)
        .background(Color.backgroundPrimary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusInline))
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
        .accessibilityLabel(rowAccessibilityLabel(player: player, score: score))
        .accessibilityAddTraits(isRoundFinished ? [] : [.isButton])
    }

    private func rowAccessibilityLabel(player: ScorecardPlayer, score: ScoreEvent?) -> String {
        guard let score else {
            return "\(player.displayName), no score"
        }
        let scorerName = scorerNamesByID[score.reportedByPlayerID.uuidString]
        let parPhrase = relativeToParPhrase(strokes: score.strokeCount, par: par)
        var label = "\(player.displayName), score \(score.strokeCount), \(parPhrase)"
        if let name = scorerName {
            label += ". Scored by \(name)."
        }
        return label
    }

    private func relativeToParPhrase(strokes: Int, par: Int) -> String {
        let delta = strokes - par
        switch delta {
        case ..<(-1): return "\(abs(delta)) under par"
        case -1:      return "one under par"
        case 0:       return "even par"
        case 1:       return "one over par"
        default:      return "\(delta) over par"
        }
    }

}
