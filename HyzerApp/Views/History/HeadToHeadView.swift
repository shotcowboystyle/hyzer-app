import SwiftUI
import SwiftData
import HyzerKit

/// Head-to-head record view between two registered players (Story 13.3).
///
/// Off-course warm register (UX-PMVP-DR5): `Color.backgroundPrimary` background, neutral
/// color treatment for both players, no animations beyond springGentle.
/// Entry point: `PlayerHoleBreakdownView` → "Compare" → `HeadToHeadOpponentPickerSheet` → row tap.
struct HeadToHeadView: View {
    let playerAID: String
    let playerAName: String
    let playerBID: String
    let playerBName: String

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HeadToHeadViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.hasNoData {
                    emptyState
                } else {
                    populatedContent(vm: vm)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Head-to-Head")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(playerAID)|\(playerBID)") {
            let vm = HeadToHeadViewModel(
                modelContext: modelContext,
                playerAID: playerAID, playerAName: playerAName,
                playerBID: playerBID, playerBName: playerBName
            )
            viewModel = vm
            await vm.compute()
        }
    }

    private var emptyState: some View {
        Text("\(playerAName) and \(playerBName) haven't played a round together yet.")
            .font(TypographyTokens.body)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel?.accessibilityLabel ?? "")
    }

    private func populatedContent(vm: HeadToHeadViewModel) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xl) {
                headerSection(vm: vm)
                roundsCountSection(vm: vm)
                winsRowSection(vm: vm)
                differentialSection(vm: vm)
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(vm.accessibilityLabel)
    }

    private func headerSection(vm: HeadToHeadViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("\(vm.playerAName) vs \(vm.playerBName)")
                .font(TypographyTokens.h1)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
        }
        .accessibilityHidden(true)
    }

    private func roundsCountSection(vm: HeadToHeadViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(vm.roundsPlayedFormatted ?? "—")
                .font(TypographyTokens.score)
                .foregroundStyle(Color.textPrimary)
            Text("played together")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .accessibilityHidden(true)
    }

    private func winsRowSection(vm: HeadToHeadViewModel) -> some View {
        HStack(spacing: SpacingTokens.md) {
            winsColumn(
                name: vm.playerAName,
                wins: vm.winsAFormatted ?? "—",
                percent: vm.winsAPercentFormatted ?? "—"
            )
            winsColumn(
                name: vm.playerBName,
                wins: vm.winsBFormatted ?? "—",
                percent: vm.winsBPercentFormatted ?? "—"
            )
        }
        .accessibilityHidden(true)
    }

    private func winsColumn(name: String, wins: String, percent: String) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(name)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
            Text(wins)
                .font(TypographyTokens.score)
                .foregroundStyle(Color.textPrimary)
            Text(percent)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
    }

    private func differentialSection(vm: HeadToHeadViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(vm.averageDifferentialFormatted ?? "—")
                .font(TypographyTokens.score)
                .foregroundStyle(Color.textPrimary)
            Text("average differential")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .accessibilityHidden(true)
    }
}
