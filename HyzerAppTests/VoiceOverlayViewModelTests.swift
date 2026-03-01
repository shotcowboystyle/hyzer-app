import Testing
import SwiftData
import Foundation
@testable import HyzerApp
@testable import HyzerKit

/// Tests for VoiceOverlayViewModel (Story 5.2).
///
/// Framework: Swift Testing (`@Suite`, `@Test`, `#expect`).
/// All tests are `@MainActor` matching the ViewModel's isolation.
@Suite("VoiceOverlayViewModel")
@MainActor
struct VoiceOverlayViewModelTests {

    // MARK: - Helpers

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
        return (container, ModelContext(container))
    }

    private func makeVM(
        mock: MockVoiceRecognitionService = MockVoiceRecognitionService(),
        context: ModelContext,
        players: [VoicePlayerEntry] = []
    ) -> (VoiceOverlayViewModel, ScoringService) {
        let service = ScoringService(modelContext: context, deviceID: "test-device")
        let vm = VoiceOverlayViewModel(
            voiceRecognitionService: mock,
            scoringService: service,
            parser: VoiceParser(),
            roundID: UUID(),
            holeNumber: 1,
            reportedByPlayerID: UUID(),
            players: players
        )
        return (vm, service)
    }

    private func samplePlayers() -> [VoicePlayerEntry] {
        [
            VoicePlayerEntry(playerID: "player-mike", displayName: "Mike", aliases: []),
            VoicePlayerEntry(playerID: "player-jake", displayName: "Jake", aliases: []),
            VoicePlayerEntry(playerID: "player-sarah", displayName: "Sarah", aliases: [])
        ]
    }

    // MARK: - 6.3: startListening with successful transcript → .confirming with correct candidates

    @Test("startListening_successfulTranscript_setsConfirmingWithCandidates")
    func test_startListening_successfulTranscript_setsConfirmingWithCandidates() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Mike 3 Jake 4"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        // When
        vm.startListening()
        // Allow async recognition to propagate
        try await Task.sleep(for: .milliseconds(100))

        // Then
        if case .confirming(let candidates) = vm.state {
            #expect(candidates.count == 2)
            #expect(candidates.first?.displayName == "Mike")
            #expect(candidates.first?.strokeCount == 3)
            #expect(candidates.last?.displayName == "Jake")
            #expect(candidates.last?.strokeCount == 4)
        } else {
            Issue.record("Expected .confirming state, got \(vm.state)")
        }
    }

    // MARK: - 6.4: commitScores creates one ScoreEvent per candidate

    @Test("commitScores_createsOneScoreEventPerCandidate")
    func test_commitScores_createsOneScoreEventPerCandidate() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Mike 3 Jake 4"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .confirming = vm.state else {
            Issue.record("Setup: expected .confirming state")
            return
        }

        // When
        vm.commitScores()

        // Then
        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 2)
        let strokes = Set(fetched.map(\.strokeCount))
        #expect(strokes.contains(3))
        #expect(strokes.contains(4))
        if case .committed = vm.state { } else {
            Issue.record("Expected .committed state, got \(vm.state)")
        }
        #expect(vm.isCommitted == true)
        #expect(vm.isTerminated == true)
    }

    // MARK: - 6.5: correctScore updates candidate and resets timer

    @Test("correctScore_updatesStrokeCount")
    func test_correctScore_updatesStrokeCount() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Mike 3"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .confirming = vm.state else {
            Issue.record("Setup: expected .confirming state")
            return
        }

        // When
        vm.correctScore(at: 0, newStrokeCount: 5)

        // Then
        if case .confirming(let candidates) = vm.state {
            #expect(candidates[0].strokeCount == 5)
        } else {
            Issue.record("Expected .confirming state after correction")
        }
    }

    // MARK: - 6.6: cancel → .dismissed, no ScoreEvents

    @Test("cancel_setsDismissedState_createsNoScoreEvents")
    func test_cancel_setsDismissedState_createsNoScoreEvents() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Mike 3 Jake 4"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))

        // When
        vm.cancel()

        // Then
        if case .dismissed = vm.state { } else {
            Issue.record("Expected .dismissed state, got \(vm.state)")
        }
        #expect(vm.isTerminated == true)
        #expect(vm.isCommitted == false)
        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.isEmpty)
        #expect(mock.stopListeningCallCount == 1)
    }

    // MARK: - 6.7: subset scoring — single player transcript commits only that player's score

    @Test("startListening_singlePlayerTranscript_commitsOnlyThatPlayer")
    func test_startListening_singlePlayerTranscript_commitsOnlyThatPlayer() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Jake 4"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))

        // When
        vm.commitScores()

        // Then
        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 1)
        #expect(fetched[0].playerID == "player-jake")
        #expect(fetched[0].strokeCount == 4)
    }

    // MARK: - 6.8: VoiceOver focus pauses timer

    @Test("voiceOverFocus_pausesAutoCommitTimer")
    func test_voiceOverFocus_pausesAutoCommitTimer() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Mike 3"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .confirming = vm.state else {
            Issue.record("Setup: expected .confirming state")
            return
        }

        // When — VoiceOver focuses on overlay
        vm.isVoiceOverFocused = true
        // Wait longer than 1.5s auto-commit window
        try await Task.sleep(for: .seconds(2))

        // Then — timer should have been cancelled; state is still .confirming, no scores committed
        if case .confirming = vm.state { } else {
            Issue.record("Expected .confirming (timer paused), got \(vm.state)")
        }
        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.isEmpty)
    }

    // MARK: - Auto-commit timer fires after 1.5s

    @Test("autoCommitTimer_firesAfterDelay_commitsScores")
    func test_autoCommitTimer_firesAfterDelay_commitsScores() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Mike 3 Jake 4"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .confirming = vm.state else {
            Issue.record("Setup: expected .confirming state")
            return
        }

        // When — wait for auto-commit timer (1.5s) plus buffer
        try await Task.sleep(for: .seconds(2))

        // Then — timer should have fired and committed scores
        if case .committed = vm.state { } else {
            Issue.record("Expected .committed state after auto-commit timer, got \(vm.state)")
        }
        #expect(vm.isCommitted == true)
        #expect(vm.isTerminated == true)
        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.count == 2)
    }

    // MARK: - 5.3: partial transcript sets .partial state

    @Test("startListening_partialTranscript_setsPartialState")
    func test_startListening_partialTranscript_setsPartialState() async throws {
        // Given: "Zork" is unknown, "Jake" is known
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Zork 5 Jake 4"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        // When
        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))

        // Then
        if case .partial(let recognized, let unresolved) = vm.state {
            #expect(recognized.count == 1)
            #expect(recognized[0].displayName == "Jake")
            #expect(recognized[0].strokeCount == 4)
            #expect(unresolved.count == 1)
            #expect(unresolved[0].spokenName == "Zork")
            #expect(unresolved[0].strokeCount == 5)
        } else {
            Issue.record("Expected .partial state, got \(vm.state)")
        }
        #expect(vm.isTerminated == false)
    }

    // MARK: - 5.3: resolveUnresolved last entry transitions to .confirming

    @Test("resolveUnresolved_lastEntry_transitionsToConfirming")
    func test_resolveUnresolved_lastEntry_transitionsToConfirming() async throws {
        // Given: partial state with 1 unresolved
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Zork 5 Jake 4"
        let (_, context) = try makeContext()
        let players = samplePlayers()
        let (vm, _) = makeVM(mock: mock, context: context, players: players)

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .partial = vm.state else {
            Issue.record("Setup: expected .partial state")
            return
        }

        let sarahEntry = players.first { $0.displayName == "Sarah" }!
        let timerCountBefore = vm.timerResetCount

        // When
        vm.resolveUnresolved(at: 0, player: sarahEntry)

        // Then
        if case .confirming(let candidates) = vm.state {
            #expect(candidates.count == 2)
            let byName = Dictionary(uniqueKeysWithValues: candidates.map { ($0.displayName, $0) })
            #expect(byName["Jake"]?.strokeCount == 4)
            #expect(byName["Sarah"]?.strokeCount == 5)
        } else {
            Issue.record("Expected .confirming state after resolving last unresolved, got \(vm.state)")
        }
        #expect(vm.timerResetCount > timerCountBefore)
    }

    // MARK: - 5.3: resolveUnresolved non-last entry stays .partial

    @Test("resolveUnresolved_notLast_remainsPartial")
    func test_resolveUnresolved_notLast_remainsPartial() async throws {
        // Given: partial state with 2 unresolved (Zork + Ghost, Jake known)
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Zork 5 Ghost 3 Jake 4"
        let (_, context) = try makeContext()
        let players = samplePlayers()
        let (vm, _) = makeVM(mock: mock, context: context, players: players)

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .partial(_, let unresolved) = vm.state, unresolved.count == 2 else {
            Issue.record("Setup: expected .partial state with 2 unresolved")
            return
        }

        let sarahEntry = players.first { $0.displayName == "Sarah" }!

        // When: resolve only index 0 (still 1 unresolved remaining)
        vm.resolveUnresolved(at: 0, player: sarahEntry)

        // Then: stays .partial with 1 remaining
        if case .partial(let recognized, let remaining) = vm.state {
            #expect(remaining.count == 1)
            _ = recognized // recognized count increases
        } else {
            Issue.record("Expected .partial state with 1 remaining, got \(vm.state)")
        }
    }

    // MARK: - 5.3: resolveUnresolved retains stroke count from parser

    @Test("resolveUnresolved_retainsStrokeCountFromParser")
    func test_resolveUnresolved_retainsStrokeCountFromParser() async throws {
        // Given: "Zork 7 Jake 4" — Zork unresolved with stroke count 7, Jake recognized
        // The stroke count 7 must be retained when resolving Zork to a known player.
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Zork 7 Jake 4"
        let (_, context) = try makeContext()
        let players = samplePlayers()
        let (vm, _) = makeVM(mock: mock, context: context, players: players)

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .partial(_, let unresolved) = vm.state, !unresolved.isEmpty else {
            Issue.record("Setup: expected .partial state with unresolved entries, got \(vm.state)")
            return
        }
        #expect(unresolved[0].strokeCount == 7)

        let mikeEntry = players.first { $0.displayName == "Mike" }!

        // When
        vm.resolveUnresolved(at: 0, player: mikeEntry)

        // Then: the resolved ScoreCandidate must keep stroke count 7 (not 0 or par)
        if case .confirming(let candidates) = vm.state {
            let mike = candidates.first { $0.displayName == "Mike" }
            #expect(mike?.strokeCount == 7)
        } else {
            Issue.record("Expected .confirming state after resolution, got \(vm.state)")
        }
    }

    // MARK: - 5.3: failed transcript sets .failed state, isTerminated stays false

    @Test("startListening_failedTranscript_setsFailedState")
    func test_startListening_failedTranscript_setsFailedState() async throws {
        // Given: "blah blah blah" matches no players
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "blah blah blah"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        // When
        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))

        // Then: .failed state and NOT terminated (retry must be available)
        if case .failed = vm.state { } else {
            Issue.record("Expected .failed state, got \(vm.state)")
        }
        #expect(vm.isTerminated == false)
    }

    // MARK: - 5.3: retry from failed state resets and recognizes again

    @Test("retry_fromFailedState_resetsToListeningAndRecognizes")
    func test_retry_fromFailedState_resetsToListeningAndRecognizes() async throws {
        // Given: first attempt fails, second succeeds
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "blah blah blah"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .failed = vm.state else {
            Issue.record("Setup: expected .failed state")
            return
        }

        // Reconfigure mock so second attempt succeeds
        mock.transcriptToReturn = "Jake 4"

        // When
        vm.retry()
        try await Task.sleep(for: .milliseconds(100))

        // Then: recognizeCallCount is 2 and state is .confirming
        #expect(mock.recognizeCallCount == 2)
        if case .confirming(let candidates) = vm.state {
            #expect(candidates.count == 1)
            #expect(candidates[0].displayName == "Jake")
        } else {
            Issue.record("Expected .confirming state after retry, got \(vm.state)")
        }
    }

    // MARK: - 5.3: cancel from .partial creates no ScoreEvents

    @Test("cancel_fromPartialState_createsNoScoreEvents")
    func test_cancel_fromPartialState_createsNoScoreEvents() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Zork 5 Jake 4"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .partial = vm.state else {
            Issue.record("Setup: expected .partial state")
            return
        }

        // When
        vm.cancel()

        // Then
        if case .dismissed = vm.state { } else {
            Issue.record("Expected .dismissed state, got \(vm.state)")
        }
        #expect(vm.isTerminated == true)
        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.isEmpty)
    }

    // MARK: - 5.3: cancel from .failed creates no ScoreEvents

    @Test("cancel_fromFailedState_createsNoScoreEvents")
    func test_cancel_fromFailedState_createsNoScoreEvents() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "blah blah blah"
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))
        guard case .failed = vm.state else {
            Issue.record("Setup: expected .failed state")
            return
        }

        // When
        vm.cancel()

        // Then
        if case .dismissed = vm.state { } else {
            Issue.record("Expected .dismissed state, got \(vm.state)")
        }
        #expect(vm.isTerminated == true)
        let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(fetched.isEmpty)
    }

    // MARK: - 6.9: recognition error → .error state

    @Test("startListening_recognitionError_setsErrorState")
    func test_startListening_recognitionError_setsErrorState() async throws {
        // Given
        let mock = MockVoiceRecognitionService()
        mock.errorToThrow = .microphonePermissionDenied
        let (_, context) = try makeContext()
        let (vm, _) = makeVM(mock: mock, context: context, players: samplePlayers())

        // When
        vm.startListening()
        try await Task.sleep(for: .milliseconds(100))

        // Then — use pattern matching (VoiceParseError is not Equatable)
        if case .error(.microphonePermissionDenied) = vm.state {
            // Expected — correct error case
        } else {
            Issue.record("Expected .error(.microphonePermissionDenied) state, got \(vm.state)")
        }
        #expect(vm.isTerminated == true)
    }
}
