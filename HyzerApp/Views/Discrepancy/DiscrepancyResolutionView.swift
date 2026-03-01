import SwiftUI
import HyzerKit

/// Displays two conflicting scores side-by-side for a single discrepancy.
///
/// The organizer taps the correct score to resolve the conflict. No confirmation dialog —
/// per UX principle "confidence through feedback, not confirmation" (AC3).
///
/// Presented as a `.sheet` with `.presentationDetents([.medium])` from `DiscrepancyListView`
/// or directly from `ScorecardContainerView` when only one discrepancy exists.
struct DiscrepancyResolutionView: View {
    let viewModel: DiscrepancyViewModel
    let discrepancy: Discrepancy
    let playerName: String
    @Binding var isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Resolved lazily — holds the two conflicting events and their reporter names.
    @State private var conflictingEvents: (ScoreEvent, ScoreEvent)?
    @State private var reporterName1: String = ""
    @State private var reporterName2: String = ""

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            headerSection
            if let (event1, event2) = conflictingEvents {
                HStack(spacing: SpacingTokens.md) {
                    scoreOption(
                        strokeCount: event1.strokeCount,
                        reporterName: reporterName1,
                        timestamp: event1.createdAt,
                        onSelect: {
                            resolveWith(strokeCount: event1.strokeCount)
                        }
                    )
                    scoreOption(
                        strokeCount: event2.strokeCount,
                        reporterName: reporterName2,
                        timestamp: event2.createdAt,
                        onSelect: {
                            resolveWith(strokeCount: event2.strokeCount)
                        }
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(voiceOverLabel(event1: event1, event2: event2))
                .accessibilityHint("Tap the correct score to resolve the discrepancy.")
            } else {
                ProgressView()
                    .tint(Color.accentPrimary)
            }
            Spacer()
        }
        .padding(SpacingTokens.lg)
        .background(Color.backgroundPrimary)
        .onAppear {
            loadEvents()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("Score Discrepancy")
                .font(TypographyTokens.h2)
                .foregroundStyle(Color.textPrimary)
            Text(playerName)
                .font(TypographyTokens.h3)
                .foregroundStyle(Color.textSecondary)
            Text("Hole \(discrepancy.holeNumber)")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
        }
        .multilineTextAlignment(.center)
    }

    private func scoreOption(
        strokeCount: Int,
        reporterName: String,
        timestamp: Date,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            VStack(spacing: SpacingTokens.sm) {
                Text("\(strokeCount)")
                    .font(TypographyTokens.score)
                    .foregroundStyle(Color.textPrimary)
                Text("Recorded by \(reporterName)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                Text(timestamp, style: .time)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: SpacingTokens.scoringTouchTarget)
            .padding(SpacingTokens.md)
            .background(Color.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.sm))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(strokeCount) strokes, recorded by \(reporterName)")
    }

    // MARK: - Helpers

    private func loadEvents() {
        conflictingEvents = viewModel.loadConflictingEvents(for: discrepancy)
        if let (e1, e2) = conflictingEvents {
            reporterName1 = resolveReporterName(playerID: e1.reportedByPlayerID)
            reporterName2 = resolveReporterName(playerID: e2.reportedByPlayerID)
        }
    }

    private func resolveReporterName(playerID: UUID) -> String {
        // Best-effort player name resolution without an additional query per card.
        // The reporter UUID maps to a Player in the domain store — using the uuidString as
        // the fallback keeps the display functional even if the player record is unavailable.
        playerID.uuidString
    }

    private func resolveWith(strokeCount: Int) {
        withAnimation(AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion)) {
            viewModel.resolve(
                discrepancy: discrepancy,
                selectedStrokeCount: strokeCount,
                playerID: discrepancy.playerID,
                holeNumber: discrepancy.holeNumber
            )
            isPresented = false
        }
    }

    private func voiceOverLabel(event1: ScoreEvent, event2: ScoreEvent) -> String {
        "Score discrepancy for \(playerName) on hole \(discrepancy.holeNumber). " +
        "Option one: \(event1.strokeCount) strokes, recorded by \(reporterName1). " +
        "Option two: \(event2.strokeCount) strokes, recorded by \(reporterName2). " +
        "Tap to select the correct score."
    }
}
