import SwiftUI
import HyzerKit

/// Displays the final standings when a round is completed.
///
/// Presented as a `.fullScreenCover` from `ScorecardContainerView` when `isRoundCompleted` becomes true.
/// Designed for screenshot readability: no animated content, generous spacing, warm off-course typography.
struct RoundSummaryView: View {
    let viewModel: RoundSummaryViewModel
    let onDismiss: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var isShareSheetPresented = false
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.xl) {
                    headerSection
                    Divider()
                        .overlay(Color.backgroundElevated)
                    standingsSection
                    Divider()
                        .overlay(Color.backgroundElevated)
                    metadataSection
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.xl)
            }
            .background(Color.backgroundPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.accentPrimary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                shareButton
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let image = shareImage {
                ShareSheetRepresentable(items: [image, viewModel.shareText])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(viewModel.courseName)
                .font(TypographyTokens.h1)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(viewModel.formattedDate)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var standingsSection: some View {
        VStack(spacing: SpacingTokens.md) {
            ForEach(viewModel.playerRows) { row in
                PlayerSummaryRow(row: row)
            }
        }
    }

    private var metadataSection: some View {
        VStack(spacing: SpacingTokens.xs) {
            HStack {
                Text("Holes played")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(viewModel.holesPlayed)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            HStack {
                Text("Organizer")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(viewModel.organizerName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var shareButton: some View {
        Button {
            shareImage = viewModel.shareSnapshot(displayScale: displayScale)
            if shareImage != nil {
                isShareSheetPresented = true
            }
        } label: {
            Text("Share Results")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.backgroundPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.md)
                .background(Color.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.sm))
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.bottom, SpacingTokens.lg)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let winners = viewModel.playerRows.filter { $0.position == 1 }
        let winnerNames = winners.map(\.playerName).joined(separator: ", ")
        let winnerScore = winners.first?.formattedScore ?? ""
        let currentPlayer = viewModel.playerRows.first(where: { $0.id == viewModel.currentPlayerID })
        let myPosition = currentPlayer?.position ?? 0
        let myScore = currentPlayer?.formattedScore ?? ""

        let winnersText = winners.count > 1 ? "\(winnerNames) tied for first" : "\(winnerNames) finished first"
        return "Round complete at \(viewModel.courseName). \(winnersText) at \(winnerScore). You finished \(myPosition) at \(myScore)."
    }

}

// MARK: - PlayerSummaryRow

private struct PlayerSummaryRow: View {
    let row: SummaryPlayerRow

    private let goldOpacity: Double = 1.0
    private let silverOpacity: Double = 0.85
    private let bronzeOpacity: Double = 0.80

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            positionLabel
                .frame(width: SpacingTokens.xl, alignment: .center)

            Text(row.playerName)
                .font(TypographyTokens.h2)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                Text(row.formattedScore)
                    .font(TypographyTokens.score)
                    .foregroundStyle(row.scoreColor)

                Text("\(row.totalStrokes) strokes")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var positionLabel: some View {
        Group {
            if row.hasMedal {
                Text(row.positionLabelText)
                    .font(TypographyTokens.h1)
                    .foregroundStyle(medalColor(for: row.position))
            } else {
                Text(row.positionLabelText)
                    .font(TypographyTokens.h2)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func medalColor(for position: Int) -> Color {
        switch position {
        case 1: return Color.textPrimary.opacity(goldOpacity)
        case 2: return Color.textPrimary.opacity(silverOpacity)
        case 3: return Color.textPrimary.opacity(bronzeOpacity)
        default: return Color.textPrimary
        }
    }
}

// MARK: - SummaryCardSnapshotView
//
// Non-interactive snapshot version of the summary, optimized for `ImageRenderer` output.
// Internal access allows `RoundSummaryViewModel.shareSnapshot()` to reference it directly.

struct SummaryCardSnapshotView: View {
    let courseName: String
    let formattedDate: String
    let playerRows: [SummaryPlayerRow]
    let holesPlayed: Int
    let organizerName: String

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            VStack(spacing: SpacingTokens.xs) {
                Text(courseName)
                    .font(TypographyTokens.h1)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(formattedDate)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Divider()
                .overlay(Color.backgroundElevated)

            VStack(spacing: SpacingTokens.md) {
                ForEach(playerRows) { row in
                    PlayerSummaryRow(row: row)
                }
            }

            Divider()
                .overlay(Color.backgroundElevated)

            VStack(spacing: SpacingTokens.xs) {
                HStack {
                    Text("Holes played")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("\(holesPlayed)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                HStack {
                    Text("Organizer")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(organizerName)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(SpacingTokens.xl)
        .frame(width: 390)
        .background(Color.backgroundPrimary)
    }
}
