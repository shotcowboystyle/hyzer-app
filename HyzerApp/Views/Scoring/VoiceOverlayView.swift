import HyzerKit
import SwiftUI
import UIKit

/// Translucent overlay shown after voice recognition completes.
///
/// Delegates to state-specific subviews:
/// `VoiceListeningView`, `VoiceConfirmingView`, `VoicePartialView`, `VoiceFailedView`.
/// Presented as a `.overlay()` on `ScorecardContainerView` — not a sheet or fullScreenCover.
struct VoiceOverlayView: View {
    @Bindable var viewModel: VoiceOverlayViewModel
    let par: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch viewModel.state {
            case .listening:
                VoiceListeningView()
            case .confirming(let candidates):
                VoiceConfirmingView(
                    viewModel: viewModel,
                    candidates: candidates,
                    par: par,
                    reduceMotion: reduceMotion
                )
            case .partial(let recognized, let unresolved):
                VoicePartialView(
                    viewModel: viewModel,
                    recognized: recognized,
                    unresolved: unresolved,
                    par: par
                )
            case .failed:
                VoiceFailedView(viewModel: viewModel)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - VoiceListeningView

private struct VoiceListeningView: View {
    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "waveform.circle.fill")
                .font(TypographyTokens.hero)
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
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .padding(.horizontal, SpacingTokens.md)
    }
}

// MARK: - VoiceConfirmingView

private struct VoiceConfirmingView: View {
    @Bindable var viewModel: VoiceOverlayViewModel
    let candidates: [ScoreCandidate]
    let par: Int
    let reduceMotion: Bool

    @State private var correctionIndex: Int? = nil
    @State private var progress: Double = 0
    @State private var progressAnimation: Animation? = nil

    var body: some View {
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
                    playerScoreRow(candidate: candidate, index: index)
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
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .padding(.horizontal, SpacingTokens.md)
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                viewModel.isVoiceOverFocused = true
                announceScores(candidates)
            }
        }
        .onChange(of: viewModel.timerResetCount) { _, _ in
            startProgress()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func playerScoreRow(candidate: ScoreCandidate, index: Int) -> some View {
        let rowContent = HStack(alignment: .center, spacing: SpacingTokens.xs) {
            Text(candidate.displayName)
                .font(TypographyTokens.h2)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            DottedLeader()
                .accessibilityHidden(true)
            Text("\(candidate.strokeCount)")
                .font(TypographyTokens.scoreLarge)
                .foregroundStyle(Color.scoreColor(strokes: candidate.strokeCount, par: par))
                .monospacedDigit()
        }
        .frame(minHeight: 56)
        .padding(.horizontal, SpacingTokens.md)

        return Button(action: { correctionIndex = index }) { rowContent }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: candidate))
            .accessibilityHint("Double-tap to correct")
    }

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
        .onAppear { startProgress() }
    }

    private func startProgress() {
        progressAnimation = nil
        progress = 0
        Task { @MainActor in
            if reduceMotion {
                progress = 1
            } else {
                progressAnimation = .linear(duration: AnimationTokens.autoCommitDuration)
                progress = 1
            }
        }
    }

    private func announceScores(_ candidates: [ScoreCandidate]) {
        let descriptions = candidates.map { "\($0.displayName), \($0.strokeCount)" }.joined(separator: ". ")
        let announcement = "Voice scores confirmed. \(descriptions). Tap any score to correct."
        Task { @MainActor in
            // Delay lets the UI settle before VoiceOver speaks; CancellationError is harmless if Task is deallocated.
            try? await Task.sleep(for: .milliseconds(500))
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    private func accessibilityLabel(for candidate: ScoreCandidate) -> String {
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

// MARK: - VoicePartialView

private struct VoicePartialView: View {
    @Bindable var viewModel: VoiceOverlayViewModel
    let recognized: [ScoreCandidate]
    let unresolved: [UnresolvedCandidate]
    let par: Int

    @State private var unresolvedIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Partial recognition")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, SpacingTokens.md)

            ForEach(Array(recognized.enumerated()), id: \.offset) { _, candidate in
                staticPlayerScoreRow(candidate: candidate)
            }

            ForEach(Array(unresolved.enumerated()), id: \.offset) { index, entry in
                unresolvedRow(entry: entry, index: index)
            }

            Text("Tap unresolved names to correct")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            Button(action: { viewModel.cancel() }) {
                Text("Cancel")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.xs)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.md)
        }
        .padding(.vertical, SpacingTokens.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .padding(.horizontal, SpacingTokens.md)
        .sheet(item: Binding(
            get: { unresolvedIndex.map { IdentifiableIndex(value: $0) } },
            set: { unresolvedIndex = $0?.value }
        )) { item in
            PlayerPickerSheet(
                players: viewModel.pickablePlayers,
                onSelect: { player in
                    viewModel.resolveUnresolved(at: item.value, player: player)
                    unresolvedIndex = nil
                }
            )
        }
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                announcePartial(recognizedCount: recognized.count, unresolvedCount: unresolved.count)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func staticPlayerScoreRow(candidate: ScoreCandidate) -> some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            Text(candidate.displayName)
                .font(TypographyTokens.h2)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            DottedLeader()
                .accessibilityHidden(true)
            Text("\(candidate.strokeCount)")
                .font(TypographyTokens.scoreLarge)
                .foregroundStyle(Color.scoreColor(strokes: candidate.strokeCount, par: par))
                .monospacedDigit()
        }
        .frame(minHeight: 56)
        .padding(.horizontal, SpacingTokens.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.displayName), \(candidate.strokeCount)")
    }

    private func unresolvedRow(entry: UnresolvedCandidate, index: Int) -> some View {
        Button(action: { unresolvedIndex = index }) {
            HStack(alignment: .center, spacing: SpacingTokens.xs) {
                Text(entry.spokenName)
                    .font(TypographyTokens.h2)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                DottedLeader()
                    .accessibilityHidden(true)
                Text("?")
                    .font(TypographyTokens.scoreLarge)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }
            .frame(minHeight: 56)
            .padding(.horizontal, SpacingTokens.md)
            .background(Color.scoreOverPar.opacity(0.1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.spokenName), unresolved, score \(entry.strokeCount)")
        .accessibilityHint("Double-tap to pick the correct player")
    }

    private func announcePartial(recognizedCount: Int, unresolvedCount: Int) {
        let announcement = "Partial recognition. " +
            "\(recognizedCount) scores confirmed, " +
            "\(unresolvedCount) unresolved. " +
            "Tap the highlighted names to select the correct player."
        Task { @MainActor in
            // Delay lets the UI settle before VoiceOver speaks; CancellationError is harmless if Task is deallocated.
            try? await Task.sleep(for: .milliseconds(500))
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

// MARK: - VoiceFailedView

private struct VoiceFailedView: View {
    @Bindable var viewModel: VoiceOverlayViewModel

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Text("Couldn't understand")
                .font(TypographyTokens.h3)
                .foregroundStyle(Color.textPrimary)

            Text("Try again?")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)

            Button(action: { viewModel.retry() }) {
                Text("Try Again")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.backgroundPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: SpacingTokens.minimumTouchTarget)
                    .background(Color.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusInline))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.md)

            Button(action: { viewModel.cancel() }) {
                Text("Cancel")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: SpacingTokens.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.md)
        }
        .padding(SpacingTokens.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .padding(.horizontal, SpacingTokens.md)
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                announceFailure()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func announceFailure() {
        let announcement = "Couldn't understand. Double-tap Try Again to retry, or Cancel to return to scoring."
        Task { @MainActor in
            // Delay lets the UI settle before VoiceOver speaks; CancellationError is harmless if Task is deallocated.
            try? await Task.sleep(for: .milliseconds(500))
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

// MARK: - IdentifiableIndex

/// Wraps an `Int` index to make it `Identifiable` for use with `sheet(item:)`.
private struct IdentifiableIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

// MARK: - PlayerPickerSheet

/// Sheet that presents all round players so the user can resolve an unrecognised name.
private struct PlayerPickerSheet: View {
    let players: [VoicePlayerEntry]
    let onSelect: (VoicePlayerEntry) -> Void

    var body: some View {
        NavigationStack {
            List(players, id: \.playerID) { player in
                Button(action: { onSelect(player) }) {
                    Text(player.displayName)
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: SpacingTokens.minimumTouchTarget)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Player")
            .navigationBarTitleDisplayMode(.inline)
        }
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
