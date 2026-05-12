import Testing
import SwiftData
import Foundation
@testable import HyzerApp
@testable import HyzerKit

/// Tests for VoiceOverlayViewModel (Story 5.2) — Failed, error, cancel, and retry states.
///
/// Covers: failed transcript detection, retry flow, cancel from partial/failed states,
/// and recognition errors surfaced as .error state (5.3, 6.9).
@Suite("VoiceOverlayViewModel — Errors")
@MainActor
struct VoiceOverlayErrorTests {

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
        await awaitCondition { if case .failed = vm.state { return true } else { return false } }

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
        await awaitCondition { if case .failed = vm.state { return true } else { return false } }
        guard case .failed = vm.state else {
            Issue.record("Setup: expected .failed state")
            return
        }

        // Reconfigure mock so second attempt succeeds
        mock.transcriptToReturn = "Jake 4"

        // When
        vm.retry()
        await awaitCondition { if case .confirming = vm.state { return true } else { return false } }

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
        await awaitCondition { if case .partial = vm.state { return true } else { return false } }
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
        await awaitCondition { if case .failed = vm.state { return true } else { return false } }
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
        await awaitCondition { if case .error = vm.state { return true } else { return false } }

        // Then — use pattern matching (VoiceParseError is not Equatable)
        if case .error(.microphonePermissionDenied) = vm.state {
            // Expected — correct error case
        } else {
            Issue.record("Expected .error(.microphonePermissionDenied) state, got \(vm.state)")
        }
        #expect(vm.isTerminated == true)
    }
}
