import SwiftUI
import SwiftData
import HyzerKit

/// Navigation-pushed detail view for a completed round (Epic 8, Story 8.1).
///
/// Reuses `RoundSummaryViewModel` for final standings data. Computes standings via
/// `StandingsEngine` on appear, then presents full player rankings, round metadata,
/// and a share button using the existing snapshot infrastructure.
struct HistoryRoundDetailView: View {
    let round: Round
    let currentPlayerID: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    @State private var viewModel: RoundSummaryViewModel?
    @State private var isShareSheetPresented = false
    @State private var shareImage: UIImage?

    var body: some View {
        Group {
            if let vm = viewModel {
                detailContent(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
            }
        }
        .navigationTitle("Round Summary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShareSheetPresented) {
            if let image = shareImage {
                ShareSheetRepresentable(items: [image, shareText(vm: viewModel)])
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = buildViewModel()
        }
    }

    // MARK: - Content

    private func detailContent(vm: RoundSummaryViewModel) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xl) {
                headerSection(vm: vm)
                Divider().overlay(Color.backgroundElevated)
                standingsSection(vm: vm)
                Divider().overlay(Color.backgroundElevated)
                metadataSection(vm: vm)
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.xl)
        }
        .background(Color.backgroundPrimary)
        .safeAreaInset(edge: .bottom) {
            shareButton(vm: vm)
        }
    }

    private func headerSection(vm: RoundSummaryViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(vm.courseName)
                .font(TypographyTokens.h1)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text(vm.formattedDate)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private func standingsSection(vm: RoundSummaryViewModel) -> some View {
        VStack(spacing: SpacingTokens.md) {
            ForEach(vm.playerRows) { row in
                NavigationLink {
                    PlayerHoleBreakdownView(
                        roundID: round.id,
                        playerID: row.id,
                        playerName: row.playerName
                    )
                } label: {
                    HStack {
                        HistoryPlayerRow(row: row)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func metadataSection(vm: RoundSummaryViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            HStack {
                Text("Holes played")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(vm.holesPlayed)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            HStack {
                Text("Organizer")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(vm.organizerName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func shareButton(vm: RoundSummaryViewModel) -> some View {
        Button {
            shareImage = vm.shareSnapshot(displayScale: displayScale)
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

    private func shareText(vm: RoundSummaryViewModel?) -> String {
        guard let vm = vm else { return "" }
        let winner = vm.playerRows.first(where: { $0.position == 1 })
        return "Round at \(vm.courseName) -- \(winner?.playerName ?? "") wins at \(winner?.formattedScore ?? "")!"
    }

    // MARK: - ViewModel builder

    private func buildViewModel() -> RoundSummaryViewModel? {
        let engine = StandingsEngine(modelContext: modelContext)
        engine.recompute(for: round.id, trigger: .localScore)
        let standings = engine.currentStandings

        let courseIDLocal = round.courseID
        let courseDescriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == courseIDLocal })
        let courseName = (try? modelContext.fetch(courseDescriptor))?.first?.name ?? "Unknown Course"

        let holeDescriptor = FetchDescriptor<Hole>(predicate: #Predicate { $0.courseID == courseIDLocal })
        let holes = (try? modelContext.fetch(holeDescriptor)) ?? []
        let coursePar = holes.reduce(0) { $0 + $1.par }

        return RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: courseName,
            holesPlayed: round.holeCount,
            coursePar: coursePar,
            currentPlayerID: currentPlayerID
        )
    }
}

// MARK: - HistoryPlayerRow

private struct HistoryPlayerRow: View {
    let row: SummaryPlayerRow

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            positionLabel
                .frame(width: SpacingTokens.xl, alignment: .center)

            Text(row.playerName)
                .font(TypographyTokens.h2)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

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
                Text(medalEmoji(for: row.position))
                    .font(TypographyTokens.h2)
            } else {
                Text("\(row.position)")
                    .font(TypographyTokens.h2)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func medalEmoji(for position: Int) -> String {
        switch position {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(position)"
        }
    }
}

// MARK: - ShareSheetRepresentable

private struct ShareSheetRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
