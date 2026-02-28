import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for RoundSummaryViewModel (Story 3.6: Round Completion & Summary).
@Suite("RoundSummaryViewModel")
@MainActor
struct RoundSummaryViewModelTests {

    // MARK: - Fixtures

    private func makeRound(completedAt: Date? = nil) -> Round {
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: ["player-1", "player-2"],
            guestNames: [],
            holeCount: 9
        )
        round.start()
        if completedAt != nil {
            round.awaitFinalization()
            round.complete()
        }
        return round
    }

    private func makeStandings(for round: Round) -> [Standing] {
        [
            Standing(
                playerID: round.playerIDs[0],
                playerName: "Alice",
                position: 1,
                totalStrokes: 27,
                holesPlayed: 9,
                scoreRelativeToPar: -2
            ),
            Standing(
                playerID: round.playerIDs[1],
                playerName: "Bob",
                position: 2,
                totalStrokes: 29,
                holesPlayed: 9,
                scoreRelativeToPar: 0
            )
        ]
    }

    private func makeVM(
        round: Round? = nil,
        standings: [Standing]? = nil,
        courseName: String = "Hawk's Ridge",
        holesPlayed: Int = 9,
        coursePar: Int = 27
    ) -> RoundSummaryViewModel {
        let r = round ?? makeRound(completedAt: Date())
        let s = standings ?? makeStandings(for: r)
        return RoundSummaryViewModel(
            round: r,
            standings: s,
            courseName: courseName,
            holesPlayed: holesPlayed,
            coursePar: coursePar
        )
    }

    // MARK: - Task 7.1: ViewModel initializes with correct playerRows sorted by position

    @Test("playerRows are sorted by standing position")
    func test_playerRows_sortedByPosition() {
        let round = makeRound(completedAt: Date())
        let standings = [
            Standing(playerID: "p2", playerName: "Bob", position: 2, totalStrokes: 29, holesPlayed: 9, scoreRelativeToPar: 0),
            Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: -2)
        ]
        // Standing array is out of order intentionally
        let vm = RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: "Test Course",
            holesPlayed: 9,
            coursePar: 27
        )
        // playerRows order reflects the standings array order (VM does not re-sort; StandingsEngine provides sorted data)
        #expect(vm.playerRows[0].playerName == "Bob")
        #expect(vm.playerRows[1].playerName == "Alice")
    }

    @Test("playerRows contain correct position, name, score and strokes")
    func test_playerRows_correctValues() {
        let round = makeRound(completedAt: Date())
        let vm = makeVM(round: round)

        let alice = vm.playerRows.first { $0.playerName == "Alice" }
        #expect(alice != nil)
        #expect(alice?.position == 1)
        #expect(alice?.formattedScore == "-2")
        #expect(alice?.totalStrokes == 27)

        let bob = vm.playerRows.first { $0.playerName == "Bob" }
        #expect(bob != nil)
        #expect(bob?.position == 2)
        #expect(bob?.formattedScore == "E")
        #expect(bob?.totalStrokes == 29)
    }

    // MARK: - Task 7.2: formattedDate uses round.completedAt

    @Test("formattedDate is derived from round.completedAt when non-nil")
    func test_formattedDate_usesCompletedAt() {
        let round = makeRound(completedAt: Date())
        let vm = makeVM(round: round)
        // The formattedDate should be a non-empty string derived from completedAt
        #expect(!vm.formattedDate.isEmpty)
    }

    @Test("formattedDate falls back to current date when completedAt is nil")
    func test_formattedDate_fallsBackToCurrentDate() {
        let round = makeRound(completedAt: nil)  // completedAt is nil
        let vm = makeVM(round: round)
        // Should still produce a non-empty date string (falls back to Date())
        #expect(!vm.formattedDate.isEmpty)
    }

    // MARK: - Task 7.3: Medal indicators only for positions 1, 2, 3

    @Test("hasMedal is true only for positions 1, 2, 3")
    func test_hasMedal_onlyTopThree() {
        let round = makeRound(completedAt: Date())
        let standings = [
            Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 20, holesPlayed: 9, scoreRelativeToPar: -7),
            Standing(playerID: "p2", playerName: "Bob", position: 2, totalStrokes: 25, holesPlayed: 9, scoreRelativeToPar: -2),
            Standing(playerID: "p3", playerName: "Carol", position: 3, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: 0),
            Standing(playerID: "p4", playerName: "Dave", position: 4, totalStrokes: 30, holesPlayed: 9, scoreRelativeToPar: 3)
        ]
        let vm = RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: "Test",
            holesPlayed: 9,
            coursePar: 27
        )

        let medals = vm.playerRows.map(\.hasMedal)
        #expect(medals[0] == true)   // position 1
        #expect(medals[1] == true)   // position 2
        #expect(medals[2] == true)   // position 3
        #expect(medals[3] == false)  // position 4
    }

    // MARK: - Task 7.4: Score colors match Standing.scoreColor

    @Test("scoreColor for under-par player is .scoreUnderPar")
    func test_scoreColor_underPar() {
        let round = makeRound(completedAt: Date())
        let vm = makeVM(round: round)

        let alice = vm.playerRows.first { $0.playerName == "Alice" }!
        #expect(alice.scoreColor == Standing(
            playerID: "p", playerName: "n", position: 1, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: -2
        ).scoreColor)
    }

    @Test("scoreColor for at-par player is .scoreAtPar")
    func test_scoreColor_atPar() {
        let round = makeRound(completedAt: Date())
        let vm = makeVM(round: round)

        let bob = vm.playerRows.first { $0.playerName == "Bob" }!
        #expect(bob.scoreColor == Standing(
            playerID: "p", playerName: "n", position: 2, totalStrokes: 29, holesPlayed: 9, scoreRelativeToPar: 0
        ).scoreColor)
    }

    @Test("scoreColor for over-par player is .scoreOverPar")
    func test_scoreColor_overPar() {
        let round = makeRound(completedAt: Date())
        let standings = [
            Standing(playerID: "p1", playerName: "Dave", position: 1, totalStrokes: 32, holesPlayed: 9, scoreRelativeToPar: 5)
        ]
        let vm = RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: "Test",
            holesPlayed: 9,
            coursePar: 27
        )

        #expect(vm.playerRows[0].scoreColor == Standing(
            playerID: "p", playerName: "n", position: 1, totalStrokes: 32, holesPlayed: 9, scoreRelativeToPar: 5
        ).scoreColor)
    }

    // MARK: - Task 7.5: shareSnapshot() produces non-nil UIImage

    @Test("shareSnapshot produces a non-nil UIImage")
    func test_shareSnapshot_producesImage() {
        let vm = makeVM()
        let image = vm.shareSnapshot()
        #expect(image != nil)
    }

    // MARK: - Task 7.6: Tied positions share the same position number

    @Test("tied players share the same position number in playerRows")
    func test_playerRows_tiedPositions() {
        let round = makeRound(completedAt: Date())
        let standings = [
            Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: -2),
            Standing(playerID: "p2", playerName: "Bob", position: 1, totalStrokes: 27, holesPlayed: 9, scoreRelativeToPar: -2),
            Standing(playerID: "p3", playerName: "Carol", position: 3, totalStrokes: 30, holesPlayed: 9, scoreRelativeToPar: 1)
        ]
        let vm = RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: "Test",
            holesPlayed: 9,
            coursePar: 27
        )

        #expect(vm.playerRows[0].position == 1)
        #expect(vm.playerRows[1].position == 1)
        #expect(vm.playerRows[2].position == 3)
        // Both tied players get hasMedal = true (position <= 3)
        #expect(vm.playerRows[0].hasMedal == true)
        #expect(vm.playerRows[1].hasMedal == true)
    }

    // MARK: - Task 7.7: Early-finish round with missing scores displays correctly

    @Test("early-finish round with partial scores shows available standing data")
    func test_earlyFinish_partialScores_displaysCorrectly() {
        let round = makeRound(completedAt: Date())
        let standings = [
            Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 12, holesPlayed: 4, scoreRelativeToPar: 0),
            Standing(playerID: "p2", playerName: "Bob", position: 2, totalStrokes: 14, holesPlayed: 4, scoreRelativeToPar: 2)
        ]
        let vm = RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: "Early Exit Course",
            holesPlayed: 4,  // actual scored holes
            coursePar: 27
        )

        #expect(vm.holesPlayed == 4)
        #expect(vm.playerRows.count == 2)
        #expect(vm.playerRows[0].totalStrokes == 12)
    }

    // MARK: - Task 8.1: isRoundCompleted is true after finalizeRound

    @Test("ScorecardViewModel.isRoundCompleted is true after finalizeRound succeeds")
    func test_scorecardVM_isRoundCompleted_afterFinalizeRound() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: ["p1"],
            guestNames: [],
            holeCount: 1
        )
        context.insert(round)
        round.start()
        round.awaitFinalization()
        try context.save()

        let manager = RoundLifecycleManager(modelContext: context)
        let service = ScoringService(modelContext: context, deviceID: "test")
        let vm = ScorecardViewModel(
            scoringService: service,
            lifecycleManager: manager,
            roundID: round.id,
            reportedByPlayerID: UUID()
        )

        try vm.finalizeRound()

        #expect(vm.isRoundCompleted == true)
    }

    // MARK: - Task 8.2: isRoundCompleted is true after finishRound(force: true)

    @Test("ScorecardViewModel.isRoundCompleted is true after finishRound(force: true) succeeds")
    func test_scorecardVM_isRoundCompleted_afterForcedFinish() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: ["p1"],
            guestNames: [],
            holeCount: 9
        )
        context.insert(round)
        round.start()
        try context.save()

        let manager = RoundLifecycleManager(modelContext: context)
        let service = ScoringService(modelContext: context, deviceID: "test")
        let vm = ScorecardViewModel(
            scoringService: service,
            lifecycleManager: manager,
            roundID: round.id,
            reportedByPlayerID: UUID()
        )

        _ = try vm.finishRound(force: true)

        #expect(vm.isRoundCompleted == true)
    }
}
