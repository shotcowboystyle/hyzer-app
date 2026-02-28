import Foundation
import SwiftUI
import HyzerKit

/// A view-ready row for one player in the round summary.
struct SummaryPlayerRow: Identifiable {
    let id: String  // playerID
    let position: Int
    let playerName: String
    let formattedScore: String
    let totalStrokes: Int
    let scoreColor: Color
    /// True for positions 1, 2, and 3.
    let hasMedal: Bool
}

/// Transforms standings and round data into view-ready rows; handles share snapshot.
///
/// Lightweight wrapper — all standings data is pre-computed by `StandingsEngine`.
/// No SwiftData queries; no model mutations. Receives data via constructor injection.
@MainActor
@Observable
final class RoundSummaryViewModel {

    // MARK: - Exposed properties

    let formattedDate: String
    let playerRows: [SummaryPlayerRow]
    let courseName: String
    let holesPlayed: Int
    let coursePar: Int

    /// Display name of the round organizer, derived from standings.
    var organizerName: String {
        standings.first(where: { $0.playerID == round.organizerID.uuidString })?.playerName
            ?? "Organizer"
    }

    // MARK: - Private

    private let round: Round
    private let standings: [Standing]

    // MARK: - Init

    init(
        round: Round,
        standings: [Standing],
        courseName: String,
        holesPlayed: Int,
        coursePar: Int
    ) {
        self.round = round
        self.standings = standings
        self.courseName = courseName
        self.holesPlayed = holesPlayed
        self.coursePar = coursePar

        let date = round.completedAt ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        self.formattedDate = formatter.string(from: date)

        self.playerRows = standings.map { standing in
            SummaryPlayerRow(
                id: standing.playerID,
                position: standing.position,
                playerName: standing.playerName,
                formattedScore: standing.formattedScore,
                totalStrokes: standing.totalStrokes,
                scoreColor: standing.scoreColor,
                hasMedal: standing.position <= 3
            )
        }
    }

    // MARK: - Share

    /// Renders the summary card to a `UIImage` using `ImageRenderer`.
    func shareSnapshot() -> UIImage? {
        let view = SummaryCardSnapshotView(
            courseName: courseName,
            formattedDate: formattedDate,
            playerRows: playerRows
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
