import SwiftUI
import HyzerKit

/// Lists all unresolved discrepancies for a round, allowing the organizer to resolve each one.
///
/// When only a single discrepancy exists, this view skips the list and presents
/// `DiscrepancyResolutionView` directly (AC5, task 3.4).
///
/// Presented as a `.sheet` with `.presentationDetents([.medium])` from `ScorecardContainerView`.
struct DiscrepancyListView: View {
    let viewModel: DiscrepancyViewModel
    let playerNamesByID: [String: String]
    @Binding var isPresented: Bool

    @State private var selectedDiscrepancy: Discrepancy?
    @State private var isShowingResolution: Bool = false

    var body: some View {
        let discrepancies = viewModel.unresolvedDiscrepancies

        Group {
            if discrepancies.count == 1, let only = discrepancies.first {
                // Single discrepancy: go directly to resolution
                DiscrepancyResolutionView(
                    viewModel: viewModel,
                    discrepancy: only,
                    playerName: playerNamesByID[only.playerID] ?? only.playerID,
                    isPresented: $isPresented
                )
            } else {
                listContent(discrepancies: discrepancies)
            }
        }
        .sheet(isPresented: $isShowingResolution) {
            if let discrepancy = selectedDiscrepancy {
                DiscrepancyResolutionView(
                    viewModel: viewModel,
                    discrepancy: discrepancy,
                    playerName: playerNamesByID[discrepancy.playerID] ?? discrepancy.playerID,
                    isPresented: $isShowingResolution
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - List content

    private func listContent(discrepancies: [Discrepancy]) -> some View {
        NavigationStack {
            List(discrepancies, id: \.id) { discrepancy in
                Button {
                    selectedDiscrepancy = discrepancy
                    isShowingResolution = true
                } label: {
                    discrepancyRow(discrepancy: discrepancy)
                }
                .accessibilityLabel(rowAccessibilityLabel(discrepancy: discrepancy))
                .accessibilityHint("Double tap to resolve this score discrepancy.")
            }
            .listStyle(.plain)
            .background(Color.backgroundPrimary)
            .navigationTitle("Score Discrepancies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(Color.accentPrimary)
                }
            }
        }
    }

    private func discrepancyRow(discrepancy: Discrepancy) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text(playerNamesByID[discrepancy.playerID] ?? discrepancy.playerID)
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textPrimary)
                Text("Hole \(discrepancy.holeNumber)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textSecondary)
        }
        .frame(minHeight: SpacingTokens.minimumTouchTarget)
        .contentShape(Rectangle())
    }

    private func rowAccessibilityLabel(discrepancy: Discrepancy) -> String {
        let name = playerNamesByID[discrepancy.playerID] ?? discrepancy.playerID
        return "Score discrepancy for \(name), hole \(discrepancy.holeNumber)"
    }
}
