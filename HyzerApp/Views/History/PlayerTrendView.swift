import SwiftUI
import Charts
import SwiftData
import HyzerKit

/// Line-chart view of a player's `scoreRelativeToPar` across completed rounds (Story 13.1).
///
/// Off-course warm register (UX-PMVP-DR5): `Color.backgroundPrimary` background, no floating
/// leaderboard pill, no score-state-colored background tint, no animation beyond springGentle.
/// Entry point: `PlayerHoleBreakdownView` → "View score trend" row.
struct PlayerTrendView: View {
    let playerID: String
    let playerName: String

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlayerTrendViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                if let error = vm.errorMessage {
                    errorState(message: error)
                } else if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !vm.hasEnoughData {
                    emptyState
                } else if let trend = vm.trend {
                    chartContent(trend: trend, vm: vm)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(playerName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil else { return }
            // Assign VM first so the body re-renders with vm.isLoading == true (ProgressView)
            // before the compute call begins — otherwise the user sees a frozen view during
            // the synchronous fetch+aggregation pass.
            let vm = PlayerTrendViewModel(
                modelContext: modelContext,
                playerID: playerID,
                playerName: playerName
            )
            viewModel = vm
            await vm.compute()
        }
    }

    // MARK: - Empty state (AC #2)

    private var emptyState: some View {
        Text("Not enough rounds yet. Trends appear after 3 rounds.")
            .font(TypographyTokens.body)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error state

    private func errorState(message: String) -> some View {
        Text(message)
            .font(TypographyTokens.body)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chart content (AC #1, #3, #4, #5)

    private func chartContent(trend: TrendSummary, vm: PlayerTrendViewModel) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                trendChart(trend: trend, vm: vm)
                statStrip(vm: vm)
            }
        }
    }

    private func trendChart(trend: TrendSummary, vm: PlayerTrendViewModel) -> some View {
        Chart(trend.points) { point in
            LineMark(
                x: .value("Date", point.completedAt),
                y: .value("Score", point.scoreRelativeToPar)
            )
            .foregroundStyle(Color.textSecondary)
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Date", point.completedAt),
                y: .value("Score", point.scoreRelativeToPar)
            )
            .foregroundStyle(by: .value("ScoreState", scoreStateLabel(point.scoreRelativeToPar)))
            .symbolSize(60)
        }
        .chartForegroundStyleScale([
            "Under par": Color.scoreUnderPar,
            "At par":    Color.scoreAtPar,
            "Over par":  Color.scoreOverPar
        ])
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 240)
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.xl)
        // Suppress per-point a11y so VoiceOver speaks only the verbose chart summary.
        // Each `PointMark` would otherwise surface `Standing.formatScore` ("E"/"+3"), the
        // compact form this story exists to keep out of accessibility labels.
        .accessibilityElement(children: .ignore)
        .accessibilityChartDescriptor(TrendChartDescriptor(trend: trend, playerName: playerName))
        .accessibilityLabel(vm.accessibilityChartSummary)
    }

    // MARK: - Summary strip (AC #4 mirror)

    private func statStrip(vm: PlayerTrendViewModel) -> some View {
        HStack(spacing: SpacingTokens.xl) {
            statColumn(label: "Best",    value: vm.bestFormattedScore ?? "—",    color: Color.scoreUnderPar)
            statColumn(label: "Average", value: vm.averageFormattedScore ?? "—", color: Color.textPrimary)
            statColumn(label: "Worst",   value: vm.worstFormattedScore ?? "—",   color: Color.scoreOverPar)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.xl)
    }

    private func statColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(label)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(TypographyTokens.score)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    /// 3-tier score-state label for chart categorical colour scale (AC #1, Dev Notes).
    ///
    /// Intentionally collapses `scoreWayOver` into "Over par" — the trend is a cross-round
    /// aggregate using the same 3-tier palette as `Standing.scoreColor` (not the 4-tier
    /// per-hole palette from `ColorTokens.scoreColor(strokes:par:)`).
    private func scoreStateLabel(_ score: Int) -> String {
        if score < 0 { return "Under par" }
        if score == 0 { return "At par" }
        return "Over par"
    }
}

// MARK: - AXChartDescriptorRepresentable (AC #4)

private struct TrendChartDescriptor: AXChartDescriptorRepresentable {
    let trend: TrendSummary
    let playerName: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Date",
            categoryOrder: trend.points.map { dateFormatter.string(from: $0.completedAt) }
        )

        let minScore = trend.points.map(\.scoreRelativeToPar).min().map(Double.init) ?? 0
        let maxScore = trend.points.map(\.scoreRelativeToPar).max().map(Double.init) ?? 0

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Score relative to par",
            range: min(minScore - 1, -1)...max(maxScore + 1, 1),
            gridlinePositions: []
        ) { value in Standing.formatScore(Int(value)) }

        let series = AXDataSeriesDescriptor(
            name: playerName,
            isContinuous: true,
            dataPoints: trend.points.map { point in
                AXDataPoint(
                    x: dateFormatter.string(from: point.completedAt),
                    y: Double(point.scoreRelativeToPar),
                    additionalValues: [],
                    label: Standing.formatScore(point.scoreRelativeToPar)
                )
            }
        )

        let bestScore = trend.bestScore.map(Standing.formatScore) ?? "—"
        let worstScore = trend.worstScore.map(Standing.formatScore) ?? "—"
        let avgScore = trend.averageScore.map { Standing.formatScore(Int($0.rounded())) } ?? "—"

        return AXChartDescriptor(
            title: "Score trend for \(playerName)",
            summary: "Score trend for \(playerName): \(trend.points.count) rounds, best \(bestScore), worst \(worstScore), average \(avgScore)",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
