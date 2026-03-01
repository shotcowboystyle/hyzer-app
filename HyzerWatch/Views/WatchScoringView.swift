import SwiftUI
import WatchKit
import HyzerKit

/// Crown-driven score entry screen for watchOS.
///
/// Appears when the user taps a player name on `WatchLeaderboardView`.
/// Score defaults to par for the current hole. Rotating the Digital Crown
/// increments/decrements by 1 per detent (system haptic per detent via
/// `isHapticFeedbackEnabled: true`). Confirm button sends the score to the phone
/// via `transferUserInfo` for guaranteed delivery.
struct WatchScoringView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var viewModel: WatchScoringViewModel

    /// Double backing store for smooth Crown tracking; rounded to Int for display.
    @State private var crownValue: Double

    init(viewModel: WatchScoringViewModel) {
        self.viewModel = viewModel
        self._crownValue = State(initialValue: Double(viewModel.parValue))
    }

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            playerNameLabel
            scoreDisplay
            holeInfoLabel
            confirmButton
        }
        .padding(.horizontal, SpacingTokens.sm)
        .digitalCrownRotation(
            $crownValue,
            from: 1.0,
            through: 10.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            viewModel.currentScore = Int(newValue.rounded())
        }
        .onChange(of: viewModel.isConfirmed) { _, confirmed in
            if confirmed { dismiss() }
        }
    }

    // MARK: - Subviews

    private var playerNameLabel: some View {
        Text(viewModel.playerName)
            .font(TypographyTokens.body)
            .foregroundStyle(Color.textSecondary)
            .lineLimit(1)
    }

    private var scoreDisplay: some View {
        Text("\(viewModel.currentScore)")
            .font(TypographyTokens.hero)
            .foregroundStyle(viewModel.scoreColor)
            .animation(
                AnimationCoordinator.animation(
                    .linear(duration: AnimationTokens.scoreEntryDuration),
                    reduceMotion: reduceMotion
                ),
                value: viewModel.scoreColor
            )
            .accessibilityLabel("Score: \(viewModel.currentScore), \(accessibleRelativeScore)")
    }

    private var holeInfoLabel: some View {
        Text("Hole \(viewModel.holeNumber) · Par \(viewModel.parValue)")
            .font(TypographyTokens.caption)
            .foregroundStyle(Color.textSecondary)
    }

    private var confirmButton: some View {
        Button {
            WKInterfaceDevice.current().play(.success)
            viewModel.confirmScore()
        } label: {
            Text("Confirm")
                .font(TypographyTokens.body)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentPrimary)
        .frame(minHeight: SpacingTokens.scoringTouchTarget)
    }

    // MARK: - Accessibility helpers

    private var accessibleRelativeScore: String {
        let rel = viewModel.currentScore - viewModel.parValue
        if rel < 0 { return "\(abs(rel)) under par" }
        if rel == 0 { return "at par" }
        return "\(rel) over par"
    }
}
