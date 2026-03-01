import SwiftUI
import SwiftData
import HyzerKit

/// Hole-by-hole score breakdown for one player in a completed round (Epic 8, Story 8.2).
///
/// Terminal view of the 4-level progressive disclosure:
/// History list → Round detail → Player breakdown → Hole-by-hole scores.
/// Read-only. No editing, no sync.
struct PlayerHoleBreakdownView: View {
    let roundID: UUID
    let playerID: String
    let playerName: String

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: PlayerHoleBreakdownViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                breakdownContent(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
            }
        }
        .navigationTitle(playerName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard viewModel == nil else { return }
            let vm = PlayerHoleBreakdownViewModel(
                modelContext: modelContext,
                roundID: roundID,
                playerID: playerID,
                playerName: playerName
            )
            vm.computeBreakdown()
            viewModel = vm
        }
    }

    // MARK: - Content

    private func breakdownContent(vm: PlayerHoleBreakdownViewModel) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(vm.holeScores) { hole in
                    HoleScoreRow(hole: hole)
                    Divider()
                        .overlay(Color.backgroundElevated)
                        .padding(.leading, SpacingTokens.lg)
                }

                SummaryFooterRow(
                    totalStrokes: vm.totalStrokes,
                    totalPar: vm.totalPar,
                    formattedScore: vm.overallFormattedScore,
                    scoreColor: vm.overallScoreColor
                )
            }
            .padding(.top, SpacingTokens.md)
        }
        .background(Color.backgroundPrimary)
    }
}

// MARK: - HoleScoreRow

private struct HoleScoreRow: View {
    let hole: HoleScore

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Hole \(hole.holeNumber)")
                    .font(TypographyTokens.h3)
                    .foregroundStyle(Color.textPrimary)
                Text("Par \(hole.par)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                Text("\(hole.strokeCount)")
                    .font(TypographyTokens.score)
                    .foregroundStyle(hole.scoreColor)
                Text(hole.formattedRelativeToPar)
                    .font(TypographyTokens.body)
                    .foregroundStyle(hole.scoreColor)
            }
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hole \(hole.holeNumber), par \(hole.par), scored \(hole.strokeCount), \(accessibilityRelativeToPar(hole.relativeToPar)) par")
    }

    private func accessibilityRelativeToPar(_ relative: Int) -> String {
        if relative < 0 { return "\(abs(relative)) under" }
        if relative == 0 { return "even with" }
        return "\(relative) over"
    }
}

// MARK: - SummaryFooterRow

private struct SummaryFooterRow: View {
    let totalStrokes: Int
    let totalPar: Int
    let formattedScore: String
    let scoreColor: Color

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Divider()
                .overlay(Color.backgroundTertiary)

            HStack(spacing: SpacingTokens.md) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("Total")
                        .font(TypographyTokens.h3)
                        .foregroundStyle(Color.textPrimary)
                    Text("Par \(totalPar)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                    Text("\(totalStrokes)")
                        .font(TypographyTokens.score)
                        .foregroundStyle(scoreColor)
                    Text(formattedScore)
                        .font(TypographyTokens.body)
                        .foregroundStyle(scoreColor)
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)
        }
        .background(Color.backgroundElevated)
    }
}
