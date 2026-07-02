import SwiftUI
import UIKit
import HyzerKit

/// Inline score picker that expands within a player row.
///
/// Shows stroke values 1-10 in a horizontal row.
/// The par value is visually highlighted as the anchor (FR18).
/// Tapping a value fires haptic feedback, collapses the picker, and saves the score (FR17).
/// Touch targets are at least `SpacingTokens.scoringTouchTarget` (52pt) per NFR14.
///
/// For corrections (Story 3.3), `preSelectedScore` is set to the current score:
/// - Scroll anchors at the pre-selected value instead of par
/// - The pre-selected value shows a distinct ring indicator
/// - Tapping the same value fires `onCancel` (no new event created)
struct ScoreInputView: View {
    let playerName: String
    let par: Int
    /// When non-nil, this is a correction — anchors scroll here and shows a ring indicator.
    var preSelectedScore: Int? = nil
    /// When `true`, all score buttons are disabled — the round is finished.
    var isRoundFinished: Bool = false
    let onSelect: (Int) -> Void
    let onCancel: () -> Void

    private let scores = Array(1...10)
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            HStack {
                Text(playerName)
                    .font(TypographyTokens.h3)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel score entry")
            }
            .padding(.horizontal, SpacingTokens.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.xs) {
                    ForEach(scores, id: \.self) { value in
                        scoreButton(for: value)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, SpacingTokens.sm)
            }
            .defaultScrollAnchor(scrollAnchor)
            .disabled(isRoundFinished)
        }
        .padding(.vertical, SpacingTokens.sm)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusInline))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Select score for \(playerName)")
        .onAppear { haptic.prepare() }
    }

    // MARK: - Score button (tinted by delta-to-par)

    @ViewBuilder
    private func scoreButton(for value: Int) -> some View {
        let isPar     = value == par
        let isCurrent = value == preSelectedScore
        Button {
            if value == preSelectedScore {
                onCancel()
                return
            }
            haptic.impactOccurred()
            onSelect(value)
        } label: {
            Text("\(value)")
                .font(TypographyTokens.score)
                .foregroundStyle(isPar ? Color.accentInk : Color.textPrimary)
                .frame(
                    minWidth: SpacingTokens.scoringTouchTarget,
                    minHeight: SpacingTokens.scoringTouchTarget
                )
                .background(background(for: value))
                .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusInline))
                .shadow(
                    color: isPar ? Color.accentPrimary.opacity(0.55) : .clear,
                    radius: 14, x: 0, y: 4
                )
                .overlay(
                    isCurrent
                        ? RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusInline)
                            .stroke(Color.textSecondary, lineWidth: 2)
                        : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: value))
    }

    @ViewBuilder
    private func background(for value: Int) -> some View {
        if value == par {
            LinearGradient.hyzerPrimary
        } else {
            // Delta-to-par tint: same 4-tier logic as `ColorTokens.scoreColor`,
            // applied as a low-opacity fill over the base card colour.
            ZStack {
                Color.backgroundPrimary.opacity(0.6)
                Color.scoreColor(strokes: value, par: par).opacity(0.18)
            }
        }
    }

    /// Scroll anchor: pre-selected value for corrections, par for initial scoring.
    private var scrollAnchor: UnitPoint {
        let anchor = preSelectedScore ?? par
        let fraction = Double(anchor - 1) / Double(scores.count - 1)
        return UnitPoint(x: fraction, y: 0.5)
    }

    private func accessibilityLabel(for value: Int) -> String {
        var label = "Score \(value)"
        if value == par { label += ", par" }
        if value == preSelectedScore { label += ", current score" }
        return label
    }
}
