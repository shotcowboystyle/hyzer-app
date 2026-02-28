import SwiftUI
import HyzerKit

/// Translucent overlay shown after voice recognition completes.
///
/// Displays parsed player-score pairs with a 1.5-second auto-commit progress indicator.
/// Supports inline correction via an expanded score picker (same `ScoreInputView` pattern).
/// Presented as a `.overlay()` on `ScorecardContainerView` — not a sheet or fullScreenCover.
struct VoiceOverlayView: View {
    @Bindable var viewModel: VoiceOverlayViewModel
    let par: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var overlayFocused: Bool

    @State private var progress: Double = 0
    @State private var progressAnimation: Animation? = nil
    @State private var correctionIndex: Int? = nil

    var body: some View {
        Group {
            switch viewModel.state {
            case .listening:
                listeningView
            case .confirming(let candidates):
                confirmingView(candidates: candidates)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Listening state

    private var listeningView: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentPrimary)
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityHidden(true)
            Text("Listening…")
                .font(TypographyTokens.h3)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, SpacingTokens.md)
    }

    // MARK: - Confirming state

    private func confirmingView(candidates: [ScoreCandidate]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Scores heard")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, SpacingTokens.md)

            ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                if correctionIndex == index {
                    ScoreInputView(
                        playerName: candidate.displayName,
                        par: par,
                        preSelectedScore: candidate.strokeCount,
                        onSelect: { newScore in
                            viewModel.correctScore(at: index, newStrokeCount: newScore)
                            correctionIndex = nil
                        },
                        onCancel: { correctionIndex = nil }
                    )
                    .padding(.horizontal, SpacingTokens.sm)
                } else {
                    playerScoreRow(candidate: candidate, index: index, par: par)
                }
            }

            progressBar

            Text("Tap to correct")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            Button(action: { viewModel.commitScores() }) {
                Text("Commit Scores")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.xs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Commit Scores")
            .padding(.horizontal, SpacingTokens.md)
        }
        .padding(.vertical, SpacingTokens.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, SpacingTokens.md)
        .onAppear { startProgress() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityFocused($overlayFocused)
        .onChange(of: overlayFocused) { _, focused in
            viewModel.isVoiceOverFocused = focused
        }
    }

    // MARK: - Player row

    private func playerScoreRow(candidate: ScoreCandidate, index: Int, par: Int) -> some View {
        Button(action: { correctionIndex = index }) {
            HStack(alignment: .center, spacing: SpacingTokens.xs) {
                Text(candidate.displayName)
                    .font(TypographyTokens.h2)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                // Dotted leader
                DottedLeader()
                    .accessibilityHidden(true)

                Text("\(candidate.strokeCount)")
                    .font(TypographyTokens.scoreLarge)
                    .foregroundStyle(scoreColor(strokes: candidate.strokeCount, par: par))
                    .monospacedDigit()
            }
            .frame(minHeight: 56)
            .padding(.horizontal, SpacingTokens.md)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: candidate, par: par))
        .accessibilityHint("Double-tap to correct")
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.backgroundTertiary)
                    .frame(height: 4)
                Capsule()
                    .fill(Color.accentPrimary)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(progressAnimation, value: progress)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, SpacingTokens.md)
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func startProgress() {
        progress = 0
        if reduceMotion {
            progress = 1
        } else {
            progressAnimation = .linear(duration: 1.5)
            progress = 1
        }
    }

    private func scoreColor(strokes: Int, par: Int) -> Color {
        let delta = strokes - par
        switch delta {
        case ..<0:  return .scoreUnderPar
        case 0:     return .scoreAtPar
        case 1:     return .scoreOverPar
        default:    return .scoreWayOver
        }
    }

    private func accessibilityLabel(for candidate: ScoreCandidate, par: Int) -> String {
        let delta = candidate.strokeCount - par
        let parDescription: String
        switch delta {
        case ..<(-1): parDescription = "\(abs(delta)) under par"
        case -1:      parDescription = "birdie"
        case 0:       parDescription = "par"
        case 1:       parDescription = "bogey"
        default:      parDescription = "\(delta) over par"
        }
        return "\(candidate.displayName), \(candidate.strokeCount), \(parDescription)"
    }
}

// MARK: - DottedLeader

/// A horizontal dotted line used as a leader between player name and score.
private struct DottedLeader: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let y = geo.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geo.size.width, y: y))
            }
            .stroke(
                Color.textSecondary.opacity(0.5),
                style: StrokeStyle(lineWidth: 1, dash: [3, 4])
            )
        }
        .frame(height: 1)
    }
}
