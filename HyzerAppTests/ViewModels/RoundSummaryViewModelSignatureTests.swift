import Testing
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for `RoundSummaryViewModel.signatureInput` (Story 14.2 — AC #7).
@Suite("RoundSummaryViewModel — signatureInput")
@MainActor
struct RoundSummaryViewModelSignatureTests {

    // MARK: - Fixtures

    private func makeRound(courseID: UUID = UUID()) -> Round {
        let round = Round(
            courseID: courseID,
            organizerID: UUID(),
            playerIDs: ["player-1", "player-2"],
            guestNames: [],
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
            currentPlayerID: standings.first?.playerID ?? "p1"
        )
    }

    // MARK: - Tests

    @Test("signatureInput is deterministic for the same standings")
    func test_signatureInput_isDeterministic_forSameStandings() {
        let courseID = UUID()
        let round = makeRound(courseID: courseID)
        let standings = [
            Standing(playerID: "player-1", playerName: "Alice", position: 1, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: -2),
            Standing(playerID: "player-2", playerName: "Bob",   position: 2, totalStrokes: 31, holesPlayed: 9, scoreRelativeToPar: 2)
        ]

        let vm1 = makeVM(round: round, standings: standings)
        let vm2 = makeVM(round: round, standings: standings)

        #expect(vm1.signatureInput == vm2.signatureInput)
    }

    @Test("signatureInput.playerIDs are sorted ascending")
    func test_signatureInput_playerIDsAreSorted() {
        let round = makeRound()
        let standings = [
            Standing(playerID: "player-Z", playerName: "Zara",  position: 1, totalStrokes: 25, holesPlayed: 9, scoreRelativeToPar: -2),
            Standing(playerID: "player-A", playerName: "Alice", position: 2, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: 0),
            Standing(playerID: "player-M", playerName: "Mike",  position: 3, totalStrokes: 30, holesPlayed: 9, scoreRelativeToPar: 3)
        ]
        let vm = makeVM(round: round, standings: standings)

        let expectedIDs = standings.map(\.playerID).sorted()
        #expect(vm.signatureInput.playerIDs == expectedIDs)
    }

    @Test("signatureInput.playerIDs preserves guest: prefix without stripping it")
    func test_signatureInput_includesGuests_withGuestPrefix() {
        let guestID = GuestIdentifier.makeID()
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: [guestID],
            guestNames: ["Darius"],
            holeCount: 9
        )
        round.start()
        round.awaitFinalization()
        round.complete()

        let standings = [
            Standing(playerID: guestID, playerName: "Darius", position: 1, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: 0)
        ]
        let vm = makeVM(round: round, standings: standings)

        let hasGuestPrefixEntry = vm.signatureInput.playerIDs.contains { $0.hasPrefix(GuestIdentifier.prefix) }
        #expect(hasGuestPrefixEntry, "signatureInput must retain the 'guest:' prefix (AC #7 — do NOT strip it)")
    }

    @Test("signatureInput.sortedTotalStrokes are sorted ascending")
    func test_signatureInput_strokesAreSorted() {
        let round = makeRound()
        let standings = [
            Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: -2),
            Standing(playerID: "p2", playerName: "Bob",   position: 2, totalStrokes: 22, holesPlayed: 9, scoreRelativeToPar: -7),
            Standing(playerID: "p3", playerName: "Carol", position: 3, totalStrokes: 35, holesPlayed: 9, scoreRelativeToPar: 8)
        ]
        let vm = makeVM(round: round, standings: standings)

        #expect(vm.signatureInput.sortedTotalStrokes == [22, 27, 35])
    }
}
