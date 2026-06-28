import Testing
import SwiftData
import Foundation
@testable import HyzerApp
@testable import HyzerKit

/// Tests for VoiceOverlayViewModel (Story 5.2) — Partial transcript states.
///
/// Covers: partial transcript recognition, resolving unresolved entries,
/// stroke count retention, and pickable player filtering (5.3).
@Suite("VoiceOverlayViewModel — Partial")
@MainActor
struct VoiceOverlayPartialTests {

    // MARK: - Helpers

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
        await awaitCondition { if case .partial = vm.state { return true } else { return false } }

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
        await awaitCondition { if case .partial = vm.state { return true } else { return false } }
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
        await awaitCondition {
            if case .partial(_, let unresolved) = vm.state { return unresolved.count == 2 } else { return false }
        }
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
        await awaitCondition {
            if case .partial(_, let unresolved) = vm.state { return !unresolved.isEmpty } else { return false }
        }
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

    // MARK: - 5.3: pickablePlayers excludes already-recognized players

    @Test("pickablePlayers_excludesAlreadyRecognizedPlayers")
    func test_pickablePlayers_excludesAlreadyRecognizedPlayers() async throws {
        // Given: "Zork 5 Jake 4" — Jake is recognized, Zork is unresolved
        let mock = MockVoiceRecognitionService()
        mock.transcriptToReturn = "Zork 5 Jake 4"
        let (_, context) = try makeContext()
        let players = samplePlayers()
        let (vm, _) = makeVM(mock: mock, context: context, players: players)

        vm.startListening()
        await awaitCondition { if case .partial = vm.state { return true } else { return false } }
        guard case .partial = vm.state else {
            Issue.record("Setup: expected .partial state")
            return
        }

        // Then: pickablePlayers should not include Jake (already recognized)
        let pickableIDs = vm.pickablePlayers.map(\.playerID)
        #expect(!pickableIDs.contains("player-jake"))
        #expect(pickableIDs.contains("player-mike"))
        #expect(pickableIDs.contains("player-sarah"))
    }
}
