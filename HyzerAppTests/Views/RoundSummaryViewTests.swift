import Testing
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for RoundSummaryView visual-state correctness (Story 11.2).
///
/// The view layer (`PlayerSummaryRow`) is private. These tests assert through
/// `SummaryPlayerRow` data, which drives all rendering decisions.
/// Visual snapshot testing is not set up in this project; 6.3 is covered by
/// the no-emoji assertion below. For pixel-level review, inspect the
/// `SummaryCardSnapshotView` preview at default and iPhone SE (375 pt) widths.
@Suite("RoundSummaryView — Story 11.2 Visual State")
@MainActor
struct RoundSummaryViewTests {

    // MARK: - Helpers

    private func makeRound() -> Round {
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: ["p1", "p2", "p3", "p4", "p5", "p6"],
            guestNames: ["Darius"],
            holeCount: 9
        )
        round.start()
        round.awaitFinalization()
        round.complete()
        return round
    }

    private func makeVM(round: Round, standings: [Standing]) -> RoundSummaryViewModel {
        RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: "Hawk's Ridge",
            holesPlayed: 9,
            coursePar: 27,
            currentPlayerID: "p1"
        )
    }

    // MARK: - Test 6.2: Position 1 uses medal treatment (hasMedal=true → h1 weight)

    @Test("Position 1 row has hasMedal=true — drives h1-weight rendering in view")
    func test_position1_hasMedal_drivesH1Weight() {
        let round = makeRound()
        let standings = [
            Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 20, holesPlayed: 9, scoreRelativeToPar: -7)
        ]
        let vm = makeVM(round: round, standings: standings)
        let row = vm.playerRows.first { $0.position == 1 }
        #expect(row?.hasMedal == true)
        // Rendering note: hasMedal=true causes PlayerSummaryRow.positionLabel
        // to apply TypographyTokens.h1 (title/bold) — verified by view inspection.
    }

    // MARK: - Test 6.3 / 6.4: Six-player + 1-guest round — all position labels are text-only

    @Test("6-player + 1-guest round: all position labels are ASCII-only (no emoji glyphs)")
    func test_sixPlayerWithGuest_allPositionLabels_textOnly() {
        let guestID = GuestIdentifier.makeID()
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: ["p1", "p2", "p3", "p4", "p5", "p6", guestID],
            guestNames: ["Darius"],
            holeCount: 9
        )
        round.start()
        round.awaitFinalization()
        round.complete()

        let standings: [Standing] = [
            Standing(playerID: "p1",    playerName: "Alice",  position: 1, totalStrokes: 20, holesPlayed: 9, scoreRelativeToPar: -7),
            Standing(playerID: "p2",    playerName: "Bob",    position: 2, totalStrokes: 23, holesPlayed: 9, scoreRelativeToPar: -4),
            Standing(playerID: "p3",    playerName: "Carol",  position: 3, totalStrokes: 25, holesPlayed: 9, scoreRelativeToPar: -2),
            Standing(playerID: "p4",    playerName: "Dave",   position: 4, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar:  0),
            Standing(playerID: "p5",    playerName: "Eve",    position: 5, totalStrokes: 29, holesPlayed: 9, scoreRelativeToPar:  2),
            Standing(playerID: "p6",    playerName: "Frank",  position: 6, totalStrokes: 31, holesPlayed: 9, scoreRelativeToPar:  4),
            Standing(playerID: guestID, playerName: "Darius", position: 7, totalStrokes: 33, holesPlayed: 9, scoreRelativeToPar:  6)
        ]
        let vm = RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: "Hawk's Ridge",
            holesPlayed: 9,
            coursePar: 27,
            currentPlayerID: "p1"
        )

        for row in vm.playerRows {
            let label = row.positionLabelText
            #expect(
                label.unicodeScalars.allSatisfy { $0.isASCII },
                "positionLabelText '\(label)' for position \(row.position) must be ASCII-only (no emoji)"
            )
            // Guest player check
            if row.id == guestID {
                #expect(row.playerName == "Darius")
            }
        }

        // Medal rows (1-3) must all be hasMedal=true
        let medalRows = vm.playerRows.filter { $0.position <= 3 }
        #expect(medalRows.count == 3)
        #expect(medalRows.allSatisfy(\.hasMedal))
    }
}
