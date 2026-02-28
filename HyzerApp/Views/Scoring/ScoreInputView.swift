import SwiftUI
import UIKit
import HyzerKit

/// Inline score picker that expands within a player row.
///
/// Shows stroke values 1-10 in a horizontal row.
/// The par value is visually highlighted as the anchor (FR18).
/// Tapping a value fires haptic feedback, collapses the picker, and saves the score (FR17).
/// Touch targets are at least `SpacingTokens.scoringTouchTarget` (52pt) per NFR14.
struct ScoreInputView: View {
    let playerName: String
    let par: Int
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
                        Button {
                            haptic.impactOccurred()
                            onSelect(value)
                        } label: {
                            Text("\(value)")
                                .font(TypographyTokens.score)
                                .foregroundStyle(value == par ? Color.backgroundPrimary : Color.textPrimary)
                                .frame(
                                    minWidth: SpacingTokens.scoringTouchTarget,
                                    minHeight: SpacingTokens.scoringTouchTarget
                                )
                                .background(
                                    value == par
                                        ? Color.accentPrimary
                                        : Color.backgroundPrimary.opacity(0.6)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Score \(value)\(value == par ? ", par" : "")")
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, SpacingTokens.sm)
            }
            .defaultScrollAnchor(parScrollAnchor)
        }
        .padding(.vertical, SpacingTokens.sm)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Select score for \(playerName)")
        .onAppear { haptic.prepare() }
    }

    /// Scroll anchor that centers the par value in the visible area.
    private var parScrollAnchor: UnitPoint {
        let fraction = Double(par - 1) / Double(scores.count - 1)
        return UnitPoint(x: fraction, y: 0.5)
    }
}
