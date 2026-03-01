import SwiftUI
import WatchKit
import HyzerKit

/// Voice scoring overlay for watchOS.
///
/// Presents when the user taps the mic button on `WatchScoringView`.
/// Shows listening state, confirmation, partial/failed results, and unavailable state.
/// Wires `voiceResultHandler` on the connectivity service for the duration of presentation.
struct WatchVoiceOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var viewModel: WatchVoiceViewModel
    var connectivityService: WatchConnectivityService

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                idleView
            case .listening:
                listeningView
            case .confirming(let candidates):
                confirmingView(candidates: candidates)
            case .partial(_, let unresolved):
                partialView(unresolved: unresolved)
            case .failed(let transcript):
                failedView(transcript: transcript)
            case .committed:
                committedView
            case .unavailable:
                unavailableView
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .onAppear {
            connectivityService.voiceResultHandler = { [weak viewModel] result in
                viewModel?.handleVoiceResult(result)
            }
            viewModel.startVoiceRequest()
        }
        .onDisappear {
            connectivityService.voiceResultHandler = nil
        }
        .onChange(of: isCommitted) { _, committed in
            if committed {
                WKInterfaceDevice.current().play(.success)
                dismiss()
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - State Views

    private var idleView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "mic.fill")
                .font(TypographyTokens.hero)
                .foregroundStyle(Color.accentPrimary)
            Text("Voice")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private var listeningView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "mic.fill")
                .font(TypographyTokens.hero)
                .foregroundStyle(Color.accentPrimary)
                .opacity(reduceMotion ? 1 : pulsingOpacity)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulsingOpacity = 1.0
                    }
                }
                .onDisappear {
                    pulsingOpacity = 0.4
                }
            Text("Listening…")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
        }
        .accessibilityLabel("Listening for voice input")
    }

    private func confirmingView(candidates: [ScoreCandidate]) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(candidates, id: \.playerID) { candidate in
                HStack {
                    Text(candidate.displayName)
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(candidate.strokeCount)")
                        .font(TypographyTokens.score)
                        .foregroundStyle(Color.accentPrimary)
                }
            }
            Text("Auto-confirming…")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
            Button {
                viewModel.confirmScores()
            } label: {
                Text("Confirm")
                    .font(TypographyTokens.body)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
            .frame(minHeight: SpacingTokens.scoringTouchTarget)
        }
        .accessibilityLabel("Confirming scores. \(candidates.map { "\($0.displayName) \($0.strokeCount)" }.joined(separator: ", "))")
    }

    private func partialView(unresolved: [UnresolvedCandidate]) -> some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.scoreOverPar)
            Text("Couldn't recognize all names")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            retryOrCrownButtons
        }
        .accessibilityLabel("Voice recognition partially succeeded. \(unresolved.count) name(s) unrecognized. Tap retry or use Crown.")
    }

    private func failedView(transcript: String) -> some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "mic.slash.fill")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.scoreOverPar)
            if !transcript.isEmpty {
                Text(transcript)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text("Not recognized")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            retryOrCrownButtons
        }
        .accessibilityLabel("Voice recognition failed. Tap retry or use Crown input.")
    }

    private var committedView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(TypographyTokens.hero)
                .foregroundStyle(Color.scoreUnderPar)
            Text("Score saved")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textPrimary)
        }
        .accessibilityLabel("Score confirmed and saved")
    }

    private var unavailableView: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "iphone.slash")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
            Text("Phone required for voice")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Dismiss")
                    .font(TypographyTokens.body)
                    .frame(maxWidth: .infinity)
            }
            .frame(minHeight: SpacingTokens.minimumTouchTarget)
        }
        .accessibilityLabel("Voice unavailable. Phone required. Use Crown input instead.")
    }

    private var retryOrCrownButtons: some View {
        VStack(spacing: SpacingTokens.xs) {
            Button {
                viewModel.retry()
            } label: {
                Text("Retry")
                    .font(TypographyTokens.body)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(minHeight: SpacingTokens.minimumTouchTarget)

            Button {
                dismiss()
            } label: {
                Text("Use Crown")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var isCommitted: Bool {
        if case .committed = viewModel.state { return true }
        return false
    }

    @State private var pulsingOpacity: Double = 0.4
}
