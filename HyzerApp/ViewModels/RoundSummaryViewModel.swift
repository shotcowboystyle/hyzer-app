import Foundation
import SwiftUI
import HyzerKit

/// A view-ready row for one player in the round summary.
struct SummaryPlayerRow: Identifiable {
    let id: String  // playerID
    let position: Int
    let playerName: String
    let formattedScore: String
    let scoreRelativeToPar: Int
    let totalStrokes: Int
    let scoreColor: Color
    /// True for positions 1, 2, and 3.
    let hasMedal: Bool

    /// Text shown in the position column — always an ASCII digit string (no emoji).
    var positionLabelText: String { "\(position)" }
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
    let currentPlayerID: String

    /// Display name of the round organizer, derived from standings.
    var organizerName: String {
        standings.first(where: { $0.playerID == round.organizerID.uuidString })?.playerName
            ?? "Organizer"
    }

    /// Deterministic input for the `RoundSignature` visual.
    ///
    /// Computed (not stored) so any future change to `standings` or `round` is reflected.
    /// In practice `standings` is final at viewmodel construction time, so reading
    /// `signatureInput` is O(n log n) once per render where n = standings.count.
    var signatureInput: RoundSignatureInput {
        RoundSignatureInput(
            courseID: round.courseID,
            playerIDs: standings.map(\.playerID).sorted(),
            sortedTotalStrokes: standings.map(\.totalStrokes).sorted()
        )
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
        coursePar: Int,
        currentPlayerID: String
    ) {
        self.round = round
        self.standings = standings
        self.courseName = courseName
        self.holesPlayed = holesPlayed
        self.coursePar = coursePar
        self.currentPlayerID = currentPlayerID

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
                scoreRelativeToPar: standing.scoreRelativeToPar,
                totalStrokes: standing.totalStrokes,
                scoreColor: standing.scoreColor,
                hasMedal: standing.position <= 3
            )
        }
    }

    // MARK: - Share

    /// Text caption attached to the share sheet alongside the PNG render.
    ///
    /// Format: "Round at [course] — [winner(s)] won at [score]"
    /// Falls back to course-only if standings data is inconsistent.
    var shareText: String {
        let sanitizedCourse = courseName.replacingOccurrences(of: "\n", with: " ")
        let winners = playerRows.filter { $0.position == 1 }
        
        guard !winners.isEmpty, let score = winners.first?.formattedScore else {
            return "Round at \(sanitizedCourse)"
        }
        
        let sanitizedWinnerNames = winners.map { $0.playerName.replacingOccurrences(of: "\n", with: " ") }
        
        let winnerClause: String
        if sanitizedWinnerNames.count == 1 {
            winnerClause = sanitizedWinnerNames[0]
        } else if sanitizedWinnerNames.count == 2 {
            winnerClause = "\(sanitizedWinnerNames[0]) and \(sanitizedWinnerNames[1])"
        } else if sanitizedWinnerNames.count == 3 {
            winnerClause = "\(sanitizedWinnerNames[0]), \(sanitizedWinnerNames[1]), and \(sanitizedWinnerNames[2])"
        } else {
            let othersCount = sanitizedWinnerNames.count - 3
            winnerClause = "\(sanitizedWinnerNames[0]), \(sanitizedWinnerNames[1]), \(sanitizedWinnerNames[2]), and \(othersCount) others"
        }
        
        return "Round at \(sanitizedCourse) \u{2014} \(winnerClause) won at \(score)"
    }

    /// Renders the summary card to a `UIImage` using `ImageRenderer`.
    func shareSnapshot(displayScale: CGFloat) -> UIImage? {
        let view = SummaryCardSnapshotView(
            courseName: courseName,
            formattedDate: formattedDate,
            playerRows: playerRows,
            holesPlayed: holesPlayed,
            organizerName: organizerName,
            signatureInput: signatureInput
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = displayScale
        return renderer.uiImage
    }
}
