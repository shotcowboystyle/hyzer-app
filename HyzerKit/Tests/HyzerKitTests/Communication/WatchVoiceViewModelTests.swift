import Testing
import Foundation
@testable import HyzerKit

@Suite("WatchVoiceViewModel")
@MainActor
struct WatchVoiceViewModelTests {

    private let roundID = UUID()
    private let holeNumber = 7

    private let players: [VoicePlayerEntry] = [
        VoicePlayerEntry(playerID: "p1", displayName: "Alice", aliases: []),
        VoicePlayerEntry(playerID: "p2", displayName: "Bob", aliases: [])
    ]

    private func makeVM(reachable: Bool = true) -> (WatchVoiceViewModel, MockWatchConnectivityClient) {
        let client = MockWatchConnectivityClient()
        client.isReachable = reachable
        let vm = WatchVoiceViewModel(
            roundID: roundID,
            holeNumber: holeNumber,
            playerEntries: players,
            connectivityClient: client
        )
        return (vm, client)
    }

    // MARK: - 8.2: startVoiceRequest when reachable

    @Test("startVoiceRequest when reachable sends voiceRequest via sendMessage")
    func test_startVoiceRequest_reachable_sendsVoiceRequest() throws {
        let (vm, client) = makeVM(reachable: true)
        vm.startVoiceRequest()

        #expect(client.sentMessages.count == 1)
        guard case .voiceRequest(let request) = client.sentMessages[0] else {
            Issue.record("Expected voiceRequest message")
            return
        }
        #expect(request.roundID == roundID)
        #expect(request.holeNumber == holeNumber)
        #expect(request.playerEntries.count == 2)
    }

    @Test("startVoiceRequest when reachable sets state to listening")
    func test_startVoiceRequest_reachable_setsListeningState() {
        let (vm, _) = makeVM(reachable: true)
        vm.startVoiceRequest()
        guard case .listening = vm.state else {
            Issue.record("Expected .listening state")
            return
        }
    }

    // MARK: - 8.3: startVoiceRequest when unreachable

    @Test("startVoiceRequest when unreachable sets state to unavailable")
    func test_startVoiceRequest_unreachable_setsUnavailableState() {
        let (vm, _) = makeVM(reachable: false)
        vm.startVoiceRequest()
        guard case .unavailable = vm.state else {
            Issue.record("Expected .unavailable state")
            return
        }
    }

    @Test("startVoiceRequest when unreachable does not send any message")
    func test_startVoiceRequest_unreachable_noMessageSent() {
        let (vm, client) = makeVM(reachable: false)
        vm.startVoiceRequest()
        #expect(client.sentMessages.isEmpty)
    }

    // MARK: - 8.4: handleVoiceResult success

    @Test("handleVoiceResult with success transitions to confirming with correct candidates")
    func test_handleVoiceResult_success_transitionsToConfirming() {
        let (vm, _) = makeVM()
        let candidates = [
            ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3),
            ScoreCandidate(playerID: "p2", displayName: "Bob", strokeCount: 4)
        ]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)

        guard case .confirming(let received) = vm.state else {
            Issue.record("Expected .confirming state")
            return
        }
        #expect(received.count == 2)
        #expect(received[0].playerID == "p1")
        #expect(received[0].strokeCount == 3)
        #expect(received[1].playerID == "p2")
        #expect(received[1].strokeCount == 4)
    }

    // MARK: - 8.5: handleVoiceResult partial

    @Test("handleVoiceResult with partial transitions to partial state")
    func test_handleVoiceResult_partial_transitionsToPartial() {
        let (vm, _) = makeVM()
        let recognized = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3)]
        let unresolved = [UnresolvedCandidate(spokenName: "Charlie", strokeCount: 5)]
        let result = WatchVoiceResult(
            result: .partial(recognized: recognized, unresolved: unresolved),
            holeNumber: holeNumber,
            roundID: roundID
        )
        vm.handleVoiceResult(result)

        guard case .partial(let r, let u) = vm.state else {
            Issue.record("Expected .partial state")
            return
        }
        #expect(r.count == 1)
        #expect(u.count == 1)
        #expect(u[0].spokenName == "Charlie")
    }

    // MARK: - 8.6: handleVoiceResult failed

    @Test("handleVoiceResult with failed transitions to failed state")
    func test_handleVoiceResult_failed_transitionsToFailed() {
        let (vm, _) = makeVM()
        let result = WatchVoiceResult(result: .failed(transcript: "unclear"), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)

        guard case .failed(let transcript) = vm.state else {
            Issue.record("Expected .failed state")
            return
        }
        #expect(transcript == "unclear")
    }

    // MARK: - 8.7: confirmScores sends transferUserInfo for each candidate

    @Test("confirmScores sends scoreEvent via transferUserInfo for each candidate")
    func test_confirmScores_sendsTransferUserInfo_perCandidate() {
        let (vm, client) = makeVM()
        let candidates = [
            ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3),
            ScoreCandidate(playerID: "p2", displayName: "Bob", strokeCount: 5)
        ]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)
        vm.confirmScores()

        #expect(client.transferredMessages.count == 2)
        guard case .scoreEvent(let p1) = client.transferredMessages[0],
              case .scoreEvent(let p2) = client.transferredMessages[1] else {
            Issue.record("Expected scoreEvent messages")
            return
        }
        #expect(p1.playerID == "p1")
        #expect(p1.strokeCount == 3)
        #expect(p1.roundID == roundID)
        #expect(p2.playerID == "p2")
        #expect(p2.strokeCount == 5)
    }

    @Test("confirmScores does not use sendMessage — uses guaranteed transferUserInfo")
    func test_confirmScores_noSendMessage() {
        let (vm, client) = makeVM()
        let candidates = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3)]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)
        vm.confirmScores()
        #expect(client.sentMessages.isEmpty)
    }

    @Test("confirmScores transitions state to committed")
    func test_confirmScores_setsCommittedState() {
        let (vm, _) = makeVM()
        let candidates = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3)]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)
        vm.confirmScores()

        guard case .committed = vm.state else {
            Issue.record("Expected .committed state")
            return
        }
    }

    // MARK: - 8.8: auto-commit timer

    @Test("auto-commit timer fires in confirming state")
    func test_autoCommitTimer_firesAfter1_5s() async throws {
        let (vm, client) = makeVM()
        let candidates = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3)]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)

        // Poll for committed state — allow generous budget for CI scheduling variance.
        var elapsed = 0
        while elapsed < 40 {
            if case .committed = vm.state { break }
            try await Task.sleep(for: .milliseconds(100))
            elapsed += 1
        }

        guard case .committed = vm.state else {
            Issue.record("Expected .committed state after auto-commit timer (4s budget)")
            return
        }
        #expect(client.transferredMessages.count == 1)
    }

    // MARK: - 8.9: cancel

    @Test("cancel resets state to idle")
    func test_cancel_resetsStateToIdle() {
        let (vm, _) = makeVM()
        vm.startVoiceRequest()
        vm.cancel()

        guard case .idle = vm.state else {
            Issue.record("Expected .idle state after cancel")
            return
        }
    }

    @Test("cancel from confirming state does not send score")
    func test_cancel_fromConfirming_noScoreSent() {
        let (vm, client) = makeVM()
        let candidates = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3)]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)
        vm.cancel()

        #expect(client.transferredMessages.isEmpty)
    }

    // MARK: - 8.10: retry

    @Test("retry re-sends voiceRequest when reachable")
    func test_retry_resendsVoiceRequest() throws {
        let (vm, client) = makeVM(reachable: true)
        let failResult = WatchVoiceResult(result: .failed(transcript: ""), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(failResult)
        vm.retry()

        // First sendMessage was from startVoiceRequest in retry
        #expect(client.sentMessages.count == 1)
        guard case .voiceRequest = client.sentMessages[0] else {
            Issue.record("Expected voiceRequest")
            return
        }
        guard case .listening = vm.state else {
            Issue.record("Expected .listening state after retry")
            return
        }
    }

    // MARK: - 8.11: score bounds clamping

    @Test("candidates with strokeCount below 1 are clamped to 1")
    func test_scoreBounds_clampedToMinimum() {
        let (vm, _) = makeVM()
        let candidates = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 0)]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)

        guard case .confirming(let received) = vm.state else {
            Issue.record("Expected .confirming state")
            return
        }
        #expect(received[0].strokeCount == 1)
    }

    @Test("candidates with strokeCount above 10 are clamped to 10")
    func test_scoreBounds_clampedToMaximum() {
        let (vm, _) = makeVM()
        let candidates = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 15)]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)

        guard case .confirming(let received) = vm.state else {
            Issue.record("Expected .confirming state")
            return
        }
        #expect(received[0].strokeCount == 10)
    }

    @Test("candidates within valid range 1...10 are not clamped")
    func test_scoreBounds_validRangeNotClamped() {
        let (vm, _) = makeVM()
        let candidates = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 7)]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: holeNumber, roundID: roundID)
        vm.handleVoiceResult(result)

        guard case .confirming(let received) = vm.state else {
            Issue.record("Expected .confirming state")
            return
        }
        #expect(received[0].strokeCount == 7)
    }
}
