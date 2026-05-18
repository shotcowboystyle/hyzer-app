import SwiftUI
import SwiftData
import HyzerKit

/// Shared card component that renders a player's personal best on a course.
///
/// Used by both `CourseDetailView` (title: "Your personal best") and
/// `PlayerHoleBreakdownView` (title: "<playerName>'s personal best").
/// Off-course warm register (UX-PMVP-DR5): backgroundElevated card, no animations.
struct PersonalBestCardView: View {
    let playerID: String
    let courseID: UUID
    let displayTitle: String

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PersonalBestViewModel?

    var body: some View {
        content
            .background(Color.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
            .padding(.horizontal, SpacingTokens.lg)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel?.accessibilityLabel ?? "\(displayTitle) loading.")
            // Keyed on (playerID, courseID) so SwiftUI re-runs compute when the parent
            // pushes a different player or course onto the same view identity (e.g.,
            // navigating between two players' breakdowns reuses PersonalBestCardView).
            .task(id: "\(playerID)|\(courseID)") {
                let vm = PersonalBestViewModel(
                    modelContext: modelContext,
                    playerID: playerID,
                    courseID: courseID,
                    displayTitle: displayTitle
                )
                viewModel = vm
                await vm.compute()
            }
    }

    @ViewBuilder private var content: some View {
        if let vm = viewModel {
            if vm.errorMessage != nil {
                noDataState
            } else if vm.isLoading {
                loadingState
            } else if vm.hasNoData {
                noDataState
            } else {
                populatedState(vm: vm)
            }
        } else {
            loadingState
        }
    }

    private func populatedState(vm: PersonalBestViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text(vm.displayTitle)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.md) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(vm.formattedStrokes ?? "—")
                        .font(TypographyTokens.score)
                        .foregroundStyle(Color.textPrimary)
                    Text("strokes")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                    Text(vm.formattedScore ?? "—")
                        .font(TypographyTokens.score)
                        .foregroundStyle(vm.scoreColor)
                    Text(vm.formattedDate ?? "—")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(SpacingTokens.lg)
    }

    private var noDataState: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text(displayTitle)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
            Text("No rounds yet on this course")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text(displayTitle)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity)
    }
}
