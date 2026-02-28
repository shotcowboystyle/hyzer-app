import Foundation
import HyzerKit

/// Manages leaderboard state for an active round: standings, pill animation, and expanded sheet.
///
/// Created in `ScorecardContainerView` alongside `ScorecardViewModel`.
/// Receives `StandingsEngine` via constructor injection — never `AppServices` directly.
@MainActor
@Observable
final class LeaderboardViewModel {
    private let standingsEngine: StandingsEngine
    let roundID: UUID
    let currentPlayerID: String

    // MARK: - Published state

    /// Current standings in rank order (delegated from StandingsEngine).
    var currentStandings: [Standing] { standingsEngine.currentStandings }

    /// Whether the expanded leaderboard sheet is presented.
    var isExpanded: Bool = false

    /// True while the pill pulse animation is active.
    var showPulse: Bool = false

    /// Position changes from the most recent recompute, used for arrow indicators.
    /// Cleared automatically after the arrow animation completes (~2 seconds).
    var positionChanges: [String: StandingsChange.PositionChange] = [:]

    // MARK: - Init

    init(standingsEngine: StandingsEngine, roundID: UUID, currentPlayerID: String) {
        self.standingsEngine = standingsEngine
        self.roundID = roundID
        self.currentPlayerID = currentPlayerID
    }

    // MARK: - Actions

    /// Called after each score entry or correction to update standings and trigger animations.
    func handleScoreEntered() {
        let change = standingsEngine.recompute(for: roundID, trigger: .localScore)
        positionChanges = change.positionChanges

        // Trigger pill pulse: scale 1.0 → 1.03 → 1.0 over 0.3s
        showPulse = true
        Task { @MainActor [weak self] in
            // CancellationError is not expected here; if it occurs the pulse simply doesn't reset
            try? await Task.sleep(for: .milliseconds(300))
            self?.showPulse = false
        }

        // Clear position-change arrows after their animation completes (~2s total: 0.2 + 1.5 + 0.3)
        Task { @MainActor [weak self] in
            // CancellationError is not expected; if it occurs arrows remain until next recompute
            try? await Task.sleep(for: .seconds(2))
            self?.positionChanges = [:]
        }
    }

    // MARK: - Scroll helpers

    /// Index of the current player in `currentStandings`, used for auto-scroll in the pill.
    var currentPlayerStandingIndex: Int? {
        currentStandings.firstIndex(where: { $0.playerID == currentPlayerID })
    }
}
