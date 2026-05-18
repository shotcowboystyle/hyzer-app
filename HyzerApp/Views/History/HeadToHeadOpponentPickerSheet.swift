import SwiftUI
import SwiftData
import HyzerKit

/// Sheet presenting registered opponent candidates for the head-to-head comparison picker.
///
/// Presented as `.sheet` from `PlayerHoleBreakdownView`. On row selection the sheet
/// dismisses and the parent's `selectedOpponent` state drives a `NavigationLink` push
/// to `HeadToHeadView`. (AC #5)
struct HeadToHeadOpponentPickerSheet: View {
    let playerAID: String
    let playerAName: String
    let onSelect: (HeadToHeadCandidate) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HeadToHeadOpponentPickerViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.hasError {
                        emptyState
                    } else if vm.hasNoCandidates {
                        emptyState
                    } else {
                        candidatesList(vm: vm)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Compare \(playerAName) with…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .task(id: playerAID) {
            let vm = HeadToHeadOpponentPickerViewModel(modelContext: modelContext, playerAID: playerAID)
            viewModel = vm
            await vm.loadCandidates()
        }
    }

    private var emptyState: some View {
        Text("No one to compare with yet. Play a round with someone else first.")
            .font(TypographyTokens.body)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func candidatesList(vm: HeadToHeadOpponentPickerViewModel) -> some View {
        List(vm.candidates) { candidate in
            Button {
                onSelect(candidate)
            } label: {
                HStack(spacing: SpacingTokens.md) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        Text(candidate.playerName)
                            .font(TypographyTokens.body)
                            .foregroundStyle(Color.textPrimary)
                        Text(HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(candidate.roundsTogether))
                            .font(TypographyTokens.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(minHeight: SpacingTokens.minimumTouchTarget)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Compare with \(candidate.playerName), \(HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(candidate.roundsTogether))"
                )
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}
