import Foundation
import SwiftData
import HyzerKit

/// View-ready data for one history round card.
struct HistoryRoundCardData {
    let roundID: UUID
    let courseName: String
    let formattedDate: String
    let playerCount: Int
    /// Name of the round winner (first place standing).
    let winnerName: String?
    /// Winner's formatted score relative to par (e.g. "-2", "E", "+1").
    let winnerFormattedScore: String?
    /// Current player's ordinal finishing position (e.g. "1st", "2nd").
    let userPosition: String?
    /// Current player's formatted score.
    let userFormattedScore: String?
}

/// Derives card display data for completed rounds in the history list.
///
/// `@Query` lives in `HistoryListView` (established project pattern). This ViewModel handles
/// data transformation only: course name resolution, standings computation, and card data derivation.
/// Card data is computed on first access per round and cached by round ID for scroll performance.
@MainActor
@Observable
final class HistoryListViewModel {
    private let modelContext: ModelContext
    private let standingsEngine: StandingsEngine
    let currentPlayerID: String

    /// Cached card data keyed by round ID. Populated lazily as cards appear on screen.
    private(set) var cardDataCache: [UUID: HistoryRoundCardData] = [:]

    init(modelContext: ModelContext, currentPlayerID: String) {
        self.modelContext = modelContext
        self.currentPlayerID = currentPlayerID
        self.standingsEngine = StandingsEngine(modelContext: modelContext)
    }

    /// Computes and caches card data for the given round if not already cached.
    func ensureCardData(for round: Round) {
        guard cardDataCache[round.id] == nil else { return }
        computeAndCache(for: round)
    }

    // MARK: - Private

    private func computeAndCache(for round: Round) {
        standingsEngine.recompute(for: round.id, trigger: .localScore)
        let standings = standingsEngine.currentStandings

        let playerCount = round.playerIDs.count + round.guestNames.count
        let winner = standings.first
        let userStanding = standings.first { $0.playerID == currentPlayerID }

        let courseIDLocal = round.courseID
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == courseIDLocal })
        let courseName = (try? modelContext.fetch(descriptor))?.first?.name ?? "Unknown Course"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let formattedDate = formatter.string(from: round.completedAt ?? Date())

        cardDataCache[round.id] = HistoryRoundCardData(
            roundID: round.id,
            courseName: courseName,
            formattedDate: formattedDate,
            playerCount: playerCount,
            winnerName: winner?.playerName,
            winnerFormattedScore: winner?.formattedScore,
            userPosition: userStanding.map { ordinalize($0.position) },
            userFormattedScore: userStanding?.formattedScore
        )
    }

    private func ordinalize(_ position: Int) -> String {
        let suffix: String
        switch position % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch position % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(position)\(suffix)"
    }
}
