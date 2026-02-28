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
