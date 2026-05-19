import Foundation
import SwiftData
import HyzerKit
import os.log

/// Fetches and exposes a player's cross-round scoring trend for `PlayerTrendView`.
///
/// Single-shot: call `compute()` once from `.onAppear`. Matches the shape of
/// `PlayerHoleBreakdownViewModel` — synchronous compute, private logger, `errorMessage` for errors.
@MainActor
@Observable
final class PlayerTrendViewModel {
    let playerID: String
    let playerName: String

    private(set) var trend: TrendSummary?
    private(set) var errorMessage: String?

    var isLoading: Bool { trend == nil && errorMessage == nil }
    var hasEnoughData: Bool { (trend?.points.count ?? 0) >= 3 }

    var bestFormattedScore: String? { trend?.bestScore.map(Standing.formatScore) }
    var worstFormattedScore: String? { trend?.worstScore.map(Standing.formatScore) }
    var averageFormattedScore: String? {
        trend?.averageScore.map { Standing.formatScore(Int($0.rounded())) }
    }

    /// VoiceOver summary for the chart (AC #4).
    var accessibilityChartSummary: String {
        guard let t = trend else {
            return "Score trend for \(playerName): loading."
        }
        guard hasEnoughData else {
            return "Score trend for \(playerName): not enough rounds yet."
        }
        let best = t.bestScore.map { verboseScore(relativeToPar: $0) } ?? "—"
        let worst = t.worstScore.map { verboseScore(relativeToPar: $0) } ?? "—"
        let avg = t.averageScore.map { verboseScore(relativeToPar: Int($0.rounded())) } ?? "—"
        return "Score trend for \(playerName): \(t.points.count) rounds, best \(best), worst \(worst), average \(avg)"
    }

    private let trendService: PlayerTrendService
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "PlayerTrendViewModel")

    init(modelContext: ModelContext, playerID: String, playerName: String) {
        self.playerID = playerID
        self.playerName = playerName
        self.trendService = PlayerTrendService(modelContext: modelContext)
    }

    /// Internal initializer for testing — allows injecting a pre-configured service.
    init(trendService: PlayerTrendService, playerID: String, playerName: String) {
        self.playerID = playerID
        self.playerName = playerName
        self.trendService = trendService
    }

    /// Fetches and computes the trend. Called once from `.task` after the View has
    /// rendered with `isLoading == true`, so the user sees `ProgressView` while the
    /// compute pass runs. The service is `@MainActor` so the work still happens on
    /// the main actor — the async boundary exists to defer it past first paint, not
    /// to move it off-main (that requires a background `ModelContext` and is out of
    /// scope here).
    func compute() async {
        do {
            trend = try trendService.computeTrend(for: playerID)
        } catch {
            logger.error("PlayerTrendViewModel.compute failed: \(error)")
            errorMessage = "Unable to load trend."
        }
    }
}
