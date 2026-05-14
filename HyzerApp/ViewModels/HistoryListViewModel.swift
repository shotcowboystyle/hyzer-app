import Foundation
import SwiftUI
import SwiftData
import os.log
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
    /// Winner's score color derived from Standing.scoreColor.
    let winnerScoreColor: Color?
    /// Current player's ordinal finishing position (e.g. "1st", "2nd").
    let userPosition: String?
    /// Current player's formatted score.
    let userFormattedScore: String?
    /// Current player's score color derived from Standing.scoreColor.
    let userScoreColor: Color?
    /// True when the current player is the round winner. Collapses winner + user lines in the card.
    let userIsWinner: Bool
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
    private let dateFormatter: DateFormatter
    private let ordinalFormatter: NumberFormatter
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "HistoryListViewModel")
    let currentPlayerID: String

    /// Cached card data keyed by round ID. Populated lazily as cards appear on screen.
    private(set) var cardDataCache: [UUID: HistoryRoundCardData] = [:]

    init(modelContext: ModelContext, currentPlayerID: String) {
        self.modelContext = modelContext
        self.currentPlayerID = currentPlayerID
        self.standingsEngine = StandingsEngine(modelContext: modelContext)
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .none
        self.dateFormatter = dateFmt
        let ordFmt = NumberFormatter()
        ordFmt.numberStyle = .ordinal
        ordFmt.locale = .autoupdatingCurrent
        self.ordinalFormatter = ordFmt
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
        let userIsWinner = userStanding?.position == 1

        let isTieForFirst = standings.filter { $0.position == 1 }.count > 1
        let winnerName: String? = (isTieForFirst && !userIsWinner) ? "Tie for 1st" : winner?.playerName

        let courseIDLocal = round.courseID
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == courseIDLocal })
        let courseName: String
        do {
            courseName = try modelContext.fetch(descriptor).first?.name ?? "Unknown Course"
        } catch {
            logger.error("HistoryListViewModel: course fetch failed for round \(round.id): \(error)")
            courseName = "Unknown Course"
        }

        let formattedDate = dateFormatter.string(from: round.completedAt ?? Date())

        cardDataCache[round.id] = HistoryRoundCardData(
            roundID: round.id,
            courseName: courseName,
            formattedDate: formattedDate,
            playerCount: playerCount,
            winnerName: winnerName,
            winnerFormattedScore: winner?.formattedScore,
            winnerScoreColor: winner?.scoreColor,
            userPosition: userStanding.map { ordinal($0.position) },
            userFormattedScore: userStanding?.formattedScore,
            userScoreColor: userStanding?.scoreColor,
            userIsWinner: userIsWinner
        )
    }

    func ordinal(_ n: Int) -> String {
        ordinalFormatter.string(from: NSNumber(value: n)) ?? String(n)
    }
}
