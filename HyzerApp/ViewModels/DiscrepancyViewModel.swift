import Foundation
import SwiftData
import HyzerKit
import os.log

/// Manages discrepancy resolution state for the round organizer.
///
/// Created by `ScorecardContainerView` when unresolved discrepancies exist for the current round.
/// Receives individual services via constructor injection — never the full `AppServices` container.
///
/// Only the round organizer interacts with this ViewModel. Non-organizer participants
/// never receive an instance of this class (PRD FR49).
@MainActor
@Observable
final class DiscrepancyViewModel {
    private let scoringService: ScoringService
    private let standingsEngine: StandingsEngine
    private let modelContext: ModelContext
    let roundID: UUID
    let organizerID: UUID
    let currentPlayerID: UUID

    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "DiscrepancyViewModel")

    // MARK: - Published state

    /// All unresolved discrepancies for this round. Populated by `loadUnresolved()`.
    var unresolvedDiscrepancies: [Discrepancy] = []

    /// The discrepancy currently selected for resolution (drives sheet presentation).
    var selectedDiscrepancy: Discrepancy?

    /// Non-nil when a resolution operation fails.
    var resolveError: Error?

    // MARK: - Init

    init(
        scoringService: ScoringService,
        standingsEngine: StandingsEngine,
        modelContext: ModelContext,
        roundID: UUID,
        organizerID: UUID,
        currentPlayerID: UUID
    ) {
        self.scoringService = scoringService
        self.standingsEngine = standingsEngine
        self.modelContext = modelContext
        self.roundID = roundID
        self.organizerID = organizerID
        self.currentPlayerID = currentPlayerID
    }

    // MARK: - Computed properties

    /// True when the current player is the round organizer.
    var isOrganizer: Bool {
        currentPlayerID == organizerID
    }

    /// Number of unresolved discrepancies — used as the badge count on `LeaderboardPillView`.
    var badgeCount: Int {
        unresolvedDiscrepancies.count
    }

    // MARK: - Actions

    /// Fetches all unresolved `Discrepancy` records for the current round from SwiftData.
    ///
    /// Stores results in `unresolvedDiscrepancies`. Errors are logged; the state remains
    /// empty on failure (organizer simply sees no badge rather than a crash).
    func loadUnresolved() {
        let roundIDLocal = roundID
        let descriptor = FetchDescriptor<Discrepancy>(
            predicate: #Predicate { $0.roundID == roundIDLocal }
        )
        do {
            let all = try modelContext.fetch(descriptor)
            unresolvedDiscrepancies = all.filter { $0.status == .unresolved }
        } catch {
            logger.error("DiscrepancyViewModel.loadUnresolved failed: \(error)")
            unresolvedDiscrepancies = []
        }
    }

    /// Returns the two conflicting `ScoreEvent` instances referenced by a discrepancy.
    ///
    /// Returns `nil` if either event cannot be found in the local SwiftData store.
    func loadConflictingEvents(for discrepancy: Discrepancy) -> (ScoreEvent, ScoreEvent)? {
        let id1 = discrepancy.eventID1
        let id2 = discrepancy.eventID2

        let descriptor1 = FetchDescriptor<ScoreEvent>(predicate: #Predicate { $0.id == id1 })
        let descriptor2 = FetchDescriptor<ScoreEvent>(predicate: #Predicate { $0.id == id2 })

        guard
            let event1 = (try? modelContext.fetch(descriptor1))?.first,
            let event2 = (try? modelContext.fetch(descriptor2))?.first
        else {
            logger.error("DiscrepancyViewModel.loadConflictingEvents: could not find events for discrepancy \(discrepancy.id)")
            return nil
        }
        return (event1, event2)
    }

    /// Resolves a discrepancy by creating an authoritative ScoreEvent and updating the Discrepancy status.
    ///
    /// Creates a new `ScoreEvent` with `supersedesEventID = nil` (authoritative resolution, not a
    /// correction chain). Sets `reportedByPlayerID` to the organizer's ID for audit trail.
    /// Updates `Discrepancy.status` to `.resolved` and sets `resolvedByEventID`.
    /// Calls `StandingsEngine.recompute(for:trigger:.conflictResolution)` to update standings.
    ///
    /// - Parameters:
    ///   - discrepancy: The `Discrepancy` to resolve.
    ///   - selectedStrokeCount: The authoritative stroke count chosen by the organizer.
    ///   - playerID: The player whose score is being resolved.
    ///   - holeNumber: The hole number for the resolved score.
    /// - Throws: Rethrows any `ScoringService` or SwiftData error. Sets `resolveError` on failure.
    func resolve(
        discrepancy: Discrepancy,
        selectedStrokeCount: Int,
        playerID: String,
        holeNumber: Int
    ) {
        do {
            let resolutionEvent = try scoringService.createScoreEvent(
                roundID: roundID,
                holeNumber: holeNumber,
                playerID: playerID,
                strokeCount: selectedStrokeCount,
                reportedByPlayerID: currentPlayerID
            )

            discrepancy.status = .resolved
            discrepancy.resolvedByEventID = resolutionEvent.id
            try modelContext.save()

            standingsEngine.recompute(for: roundID, trigger: .conflictResolution)
            loadUnresolved()
        } catch {
            logger.error("DiscrepancyViewModel.resolve failed: \(error)")
            resolveError = error
        }
    }
}
