import Testing
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for the winner-computation logic used by `ScorecardContainerView.handleRoundCompleted`
/// when building the `pushRoundCompletion` arguments.
///
/// `SyncEngine` is a concrete actor with no injectable protocol, so these tests validate
/// the winner-derivation logic in isolation — the same logic executes inside `handleRoundCompleted`.
@Suite("RoundCompletionPush")
struct RoundCompletionPushTests {

    // MARK: - Winner derivation helpers (mirrors ScorecardContainerView.handleRoundCompleted)

    /// Computes the push winner from standings using the same logic as the call site.
    private func computeWinner(from standings: [Standing]) -> Standing? {
        let leaders = standings.filter { $0.position == 1 }
        return leaders.sorted {
            $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending
        }.first
    }

    private func firstNameOf(_ playerName: String) -> String {
        playerName
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? playerName
    }

    // MARK: - Single-winner case

    @Test("Single winner: correct first name and score display are derived")
    func test_singleWinner_correctNameAndScore() {
        let standings = [
            Standing(playerID: "p1", playerName: "Alice Smith", position: 1, totalStrokes: 58, holesPlayed: 18, scoreRelativeToPar: -4),
            Standing(playerID: "p2", playerName: "Bob Jones", position: 2, totalStrokes: 62, holesPlayed: 18, scoreRelativeToPar: 0)
        ]

        let winner = computeWinner(from: standings)
        let winnerFirstName = firstNameOf(winner?.playerName ?? "")

        #expect(winnerFirstName == "Alice")
        #expect(winner?.formattedScore == "-4")
    }

    @Test("Single winner: even-par score displays as 'E'")
    func test_singleWinner_evenPar_displaysE() {
        let standings = [
            Standing(playerID: "p1", playerName: "Carol Davis", position: 1, totalStrokes: 62, holesPlayed: 18, scoreRelativeToPar: 0)
        ]

        let winner = computeWinner(from: standings)

        #expect(winner?.formattedScore == "E")
        #expect(firstNameOf(winner?.playerName ?? "") == "Carol")
    }

    @Test("Single winner: over-par score displays with + prefix")
    func test_singleWinner_overPar_displaysPlusPrefix() {
        let standings = [
            Standing(playerID: "p1", playerName: "Dave Wilson", position: 1, totalStrokes: 66, holesPlayed: 18, scoreRelativeToPar: 4)
        ]

        let winner = computeWinner(from: standings)

        #expect(winner?.formattedScore == "+4")
    }

    // MARK: - Tie-break case (AC #6)

    @Test("Tie: alphabetically-first winner name is selected (case-insensitive)")
    func test_tie_alphabeticallyFirstWinnerSelected() {
        // "carlos" < "Alice" alphabetically (case-insensitive: "alice" < "carlos")
        // "Alice" should win the tie-break
        let standings = [
            Standing(playerID: "p1", playerName: "Carlos Lopez", position: 1, totalStrokes: 58, holesPlayed: 18, scoreRelativeToPar: -4),
            Standing(playerID: "p2", playerName: "Alice Martin", position: 1, totalStrokes: 58, holesPlayed: 18, scoreRelativeToPar: -4),
            Standing(playerID: "p3", playerName: "Zoe Park", position: 3, totalStrokes: 65, holesPlayed: 18, scoreRelativeToPar: 3)
        ]

        let winner = computeWinner(from: standings)
        let winnerFirstName = firstNameOf(winner?.playerName ?? "")

        #expect(winnerFirstName == "Alice", "Alphabetically-first name (case-insensitive) must be selected (AC #6)")
    }

    @Test("Tie: single-word player name returns full name as first name")
    func test_tie_singleWordName_returnsFullName() {
        let standings = [
            Standing(playerID: "p1", playerName: "Ziggy", position: 1, totalStrokes: 58, holesPlayed: 18, scoreRelativeToPar: -4),
            Standing(playerID: "p2", playerName: "Aaron", position: 1, totalStrokes: 58, holesPlayed: 18, scoreRelativeToPar: -4)
        ]

        let winner = computeWinner(from: standings)
        let winnerFirstName = firstNameOf(winner?.playerName ?? "")

        #expect(winnerFirstName == "Aaron", "Alphabetically-first single-word name selected")
    }

    @Test("Tie: case-insensitive — 'alice' and 'Bob' → 'alice' wins tie-break")
    func test_tie_caseInsensitive() {
        let standings = [
            Standing(playerID: "p1", playerName: "Bob Chen", position: 1, totalStrokes: 60, holesPlayed: 18, scoreRelativeToPar: -2),
            Standing(playerID: "p2", playerName: "alice Kim", position: 1, totalStrokes: 60, holesPlayed: 18, scoreRelativeToPar: -2)
        ]

        let winner = computeWinner(from: standings)

        // "alice" < "bob" case-insensitively
        #expect(winner?.playerName == "alice Kim")
    }

    // MARK: - Empty standings guard

    @Test("Empty standings: computeWinner returns nil (no crash)")
    func test_emptyStandings_returnsNil() {
        let winner = computeWinner(from: [])
        #expect(winner == nil)
    }

    @Test("No position-1 players: computeWinner returns nil")
    func test_noPosition1_returnsNil() {
        let standings = [
            Standing(playerID: "p1", playerName: "Alice", position: 2, totalStrokes: 62, holesPlayed: 18, scoreRelativeToPar: 0),
            Standing(playerID: "p2", playerName: "Bob", position: 3, totalStrokes: 65, holesPlayed: 18, scoreRelativeToPar: 3)
        ]

        let winner = computeWinner(from: standings)
        #expect(winner == nil)
    }

    // MARK: - First-name extraction

    @Test("First-name split: compound name extracts first token")
    func test_firstName_compoundName() {
        #expect(firstNameOf("Alice Smith") == "Alice")
        #expect(firstNameOf("Bob James Jones") == "Bob")
        #expect(firstNameOf("Carol") == "Carol")
    }

    @Test("First-name split: empty string returns empty string (defensive)")
    func test_firstName_emptyString() {
        #expect(firstNameOf("") == "")
    }
}
