import Testing
import Foundation
@testable import HyzerKit

// MARK: - WatchScoringViewModel tests

@Suite("WatchScoringViewModel")
@MainActor
struct WatchScoringViewModelTests {

    private let roundID = UUID()

    private func makeVM(
        playerName: String = "Alice",
        playerID: String = "player-1",
        holeNumber: Int = 7,
        parValue: Int = 3
    ) -> (WatchScoringViewModel, MockWatchConnectivityClient) {
        let client = MockWatchConnectivityClient()
        let vm = WatchScoringViewModel(
            playerName: playerName,
            playerID: playerID,
            holeNumber: holeNumber,
            parValue: parValue,
            roundID: roundID,
            connectivityClient: client
        )
        return (vm, client)
    }

    // MARK: - 6.2: Initial score equals par value

    @Test("initial score equals par value")
    func test_initialScore_equalsParValue() {
        let (vm, _) = makeVM(parValue: 4)
        #expect(vm.currentScore == 4)
    }

    @Test("initial score equals par value of 3")
    func test_initialScore_equalsParValue3() {
        let (vm, _) = makeVM(parValue: 3)
        #expect(vm.currentScore == 3)
    }

    // MARK: - 6.3: Score color changes correctly

    @Test("scoreColor is scoreAtPar when at par")
    func test_scoreColor_atPar() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 3
        #expect(vm.scoreColor == .scoreAtPar)
    }

    @Test("scoreColor is scoreUnderPar when under par")
    func test_scoreColor_underPar() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 2
        #expect(vm.scoreColor == .scoreUnderPar)
    }

    @Test("scoreColor is scoreOverPar when over par")
    func test_scoreColor_overPar() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 5
        #expect(vm.scoreColor == .scoreOverPar)
    }

    // MARK: - 6.4: confirmScore calls transferUserInfo with correct payload

    @Test("confirmScore sends WatchScorePayload via transferUserInfo")
    func test_confirmScore_sendsPayload() {
        let (vm, client) = makeVM(playerName: "Bob", playerID: "player-2", holeNumber: 9, parValue: 3)
        vm.currentScore = 4
        vm.confirmScore()

        #expect(client.transferredMessages.count == 1)
        guard case .scoreEvent(let payload) = client.transferredMessages[0] else {
            Issue.record("Expected scoreEvent message")
            return
        }
        #expect(payload.roundID == roundID)
        #expect(payload.playerID == "player-2")
        #expect(payload.holeNumber == 9)
        #expect(payload.strokeCount == 4)
    }

    @Test("confirmScore does not use sendMessage (uses guaranteed transferUserInfo)")
    func test_confirmScore_noSendMessage() {
        let (vm, client) = makeVM()
        vm.confirmScore()
        #expect(client.sentMessages.isEmpty)
    }

    // MARK: - 6.5: Score clamped within valid range

    @Test("score clamped to minimum 1")
    func test_scoreClamped_minimum() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 0
        #expect(vm.currentScore == 1)
    }

    @Test("score clamped to maximum 10")
    func test_scoreClamped_maximum() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 11
        #expect(vm.currentScore == 10)
    }

    @Test("score within range is not clamped")
    func test_scoreNotClamped_withinRange() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 8
        #expect(vm.currentScore == 8)
    }

    // MARK: - 6.6: formattedScoreRelativeToPar

    @Test("formattedScoreRelativeToPar returns E at par")
    func test_formatted_atPar() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 3
        #expect(vm.formattedScoreRelativeToPar == "E")
    }

    @Test("formattedScoreRelativeToPar returns negative for birdie")
    func test_formatted_birdie() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 2
        #expect(vm.formattedScoreRelativeToPar == "-1")
    }

    @Test("formattedScoreRelativeToPar returns positive for bogey")
    func test_formatted_bogey() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 4
        #expect(vm.formattedScoreRelativeToPar == "+1")
    }

    @Test("formattedScoreRelativeToPar returns +2 for double bogey")
    func test_formatted_doubleBogey() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 5
        #expect(vm.formattedScoreRelativeToPar == "+2")
    }

    @Test("formattedScoreRelativeToPar handles ace (hole-in-one)")
    func test_formatted_ace() {
        let (vm, _) = makeVM(parValue: 3)
        vm.currentScore = 1
        #expect(vm.formattedScoreRelativeToPar == "-2")
    }

    // MARK: - 6.7: isConfirmed

    @Test("isConfirmed is false initially")
    func test_isConfirmed_initiallyFalse() {
        let (vm, _) = makeVM()
        #expect(vm.isConfirmed == false)
    }

    @Test("isConfirmed is true after confirmScore")
    func test_isConfirmed_trueAfterConfirm() {
        let (vm, _) = makeVM()
        vm.confirmScore()
        #expect(vm.isConfirmed == true)
    }
}
