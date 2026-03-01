import SwiftUI
import SwiftData
import HyzerKit

/// History tab root view: reverse-chronological list of completed rounds (Epic 8, Story 8.1).
///
/// `@Query` lives here per the established project pattern (see `ScoringTabView`).
/// `HistoryListViewModel` handles data transformation. Card data is computed lazily
/// per card via `onAppear` for smooth scroll performance with large history lists.
struct HistoryListView: View {
    let currentPlayerID: String

    @Query(
        filter: #Predicate<Round> { $0.status == "completed" },
        sort: \Round.completedAt,
        order: .reverse
    ) private var completedRounds: [Round]

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryListViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if completedRounds.isEmpty {
                    emptyState
                } else if let vm = viewModel {
                    roundList(vm: vm)
                } else {
                    Color.backgroundPrimary
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("History")
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = HistoryListViewModel(modelContext: modelContext, currentPlayerID: currentPlayerID)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.lg) {
            Text("Your round history will appear here after your first completed round.")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
    }

    private func roundList(vm: HistoryListViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.md) {
                ForEach(completedRounds) { round in
                    NavigationLink {
                        HistoryRoundDetailView(round: round, currentPlayerID: currentPlayerID)
                    } label: {
                        HistoryRoundCard(round: round, viewModel: vm)
                    }
                    .onAppear {
                        vm.ensureCardData(for: round)
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)
        }
    }
}

// MARK: - HistoryRoundCard

private struct HistoryRoundCard: View {
    let round: Round
    let viewModel: HistoryListViewModel

    private var data: HistoryRoundCardData? {
        viewModel.cardDataCache[round.id]
    }

    var body: some View {
        if let data = data {
            cardContent(data: data)
        } else {
            RoundedRectangle(cornerRadius: SpacingTokens.md)
                .fill(Color.backgroundElevated)
                .frame(height: SpacingTokens.xxl * 2)
        }
    }

    private func cardContent(data: HistoryRoundCardData) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text(data.courseName)
                    .font(TypographyTokens.h3)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            HStack(spacing: SpacingTokens.xs) {
                Text(data.formattedDate)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Text("·")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Text("\(data.playerCount) players")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if let winnerName = data.winnerName, let winnerScore = data.winnerFormattedScore {
                HStack(spacing: SpacingTokens.xs) {
                    Text("\(winnerName) won at")
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                    Text(winnerScore)
                        .font(TypographyTokens.body)
                        .foregroundStyle(data.winnerScoreColor ?? Color.textPrimary)
                }
            }

            if let userPosition = data.userPosition, let userScore = data.userFormattedScore {
                HStack(spacing: SpacingTokens.xs) {
                    Text("You finished \(userPosition) at")
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                    Text(userScore)
                        .font(TypographyTokens.body)
                        .foregroundStyle(data.userScoreColor ?? Color.textPrimary)
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(data: data))
    }

    private func accessibilityLabel(data: HistoryRoundCardData) -> String {
        var parts: [String] = ["\(data.courseName), \(data.formattedDate)."]
        if let name = data.winnerName, let score = data.winnerFormattedScore {
            parts.append("\(name) won at \(score).")
        }
        if let position = data.userPosition, let score = data.userFormattedScore {
            parts.append("You finished \(position) at \(score).")
        }
        return parts.joined(separator: " ")
    }
}
