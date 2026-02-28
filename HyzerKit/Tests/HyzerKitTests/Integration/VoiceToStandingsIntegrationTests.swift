import Testing
import SwiftData
import Foundation
@testable import HyzerKit

/// Integration test: voice transcript string → VoiceParser → ScoreEvents → StandingsEngine standings.
///
/// No SFSpeechRecognizer used — tests the parser-to-standings pipeline only (AC2, AC4).
@Suite("VoiceToStandings Integration")
@MainActor
struct VoiceToStandingsIntegrationTests {

    // MARK: - Setup helpers

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeRound(
        in context: ModelContext,
        playerIDs: [String],
        holeCount: Int = 9,
        parPerHole: Int = 3
    ) throws -> Round {
        let course = Course(name: "Test Course", holeCount: holeCount, isSeeded: false)
        context.insert(course)

        for n in 1...holeCount {
            context.insert(Hole(courseID: course.id, number: n, par: parPerHole))
        }

        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: playerIDs,
            guestNames: [],
            holeCount: holeCount
        )
        context.insert(round)
        try context.save()
        return round
    }

    // MARK: - AC2, AC4: Full voice-to-standings pipeline

    @Test("transcript Mike 3 Jake 4 Sarah 2 produces correct standings")
    func test_voiceToStandings_threePlayerTranscript_correctStandings() throws {
        // Given: three players in the round
        let container = try makeContainer()
        let context = ModelContext(container)

        let p1ID = UUID()
        let p2ID = UUID()
        let p3ID = UUID()

        let michael = Player(displayName: "Michael")
        michael.id = p1ID
        michael.aliases = ["Mike"]
        let jake = Player(displayName: "Jake")
        jake.id = p2ID
        let sarah = Player(displayName: "Sarah")
        sarah.id = p3ID

        context.insert(michael)
        context.insert(jake)
        context.insert(sarah)

        let playerIDStrs = [p1ID.uuidString, p2ID.uuidString, p3ID.uuidString]
        let round = try makeRound(in: context, playerIDs: playerIDStrs, holeCount: 9, parPerHole: 3)

        // When: voice transcript is parsed (no SFSpeechRecognizer — pure pipeline test)
        let parser = VoiceParser()
        let voicePlayers = [
            VoicePlayerEntry(playerID: p1ID.uuidString, displayName: "Michael", aliases: ["Mike"]),
            VoicePlayerEntry(playerID: p2ID.uuidString, displayName: "Jake", aliases: []),
            VoicePlayerEntry(playerID: p3ID.uuidString, displayName: "Sarah", aliases: [])
        ]
        let result = parser.parse(transcript: "Mike 3, Jake 4, Sarah 2", players: voicePlayers)

        // Assert parse result
        guard case .success(let candidates) = result else {
            Issue.record("Expected .success from VoiceParser, got \(result)")
            return
        }
        #expect(candidates.count == 3)

        // Create ScoreEvents via ScoringService (same path as tap scoring)
        let scoringService = ScoringService(modelContext: context, deviceID: "voice-device")
        let reporterID = p1ID
        for candidate in candidates {
            try scoringService.createScoreEvent(
                roundID: round.id,
                holeNumber: 1,
                playerID: candidate.playerID,
                strokeCount: candidate.strokeCount,
                reportedByPlayerID: reporterID
            )
        }

        // Trigger standings recomputation
        let engine = StandingsEngine(modelContext: context)
        engine.recompute(for: round.id, trigger: .localScore)
        let standings = engine.currentStandings

        // Then: three players have standings
        #expect(standings.count == 3)

        let byID = Dictionary(uniqueKeysWithValues: standings.map { ($0.playerID, $0) })

        // Mike (Michael) scored 3 on par-3 → E (0)
        #expect(byID[p1ID.uuidString]?.totalStrokes == 3)
        #expect(byID[p1ID.uuidString]?.scoreRelativeToPar == 0)

        // Jake scored 4 on par-3 → +1
        #expect(byID[p2ID.uuidString]?.totalStrokes == 4)
        #expect(byID[p2ID.uuidString]?.scoreRelativeToPar == 1)

        // Sarah scored 2 on par-3 → -1 (best)
        #expect(byID[p3ID.uuidString]?.totalStrokes == 2)
        #expect(byID[p3ID.uuidString]?.scoreRelativeToPar == -1)

        // Sarah should be ranked first (lowest score)
        #expect(byID[p3ID.uuidString]?.position == 1)
    }

    @Test("subset voice scoring Jake 4 only updates Jake standings")
    func test_voiceToStandings_subsetScoring_onlyJakeUpdated() throws {
        // Given: two players
        let container = try makeContainer()
        let context = ModelContext(container)

        let p1ID = UUID()
        let p2ID = UUID()

        let jake = Player(displayName: "Jake")
        jake.id = p1ID
        let sarah = Player(displayName: "Sarah")
        sarah.id = p2ID

        context.insert(jake)
        context.insert(sarah)

        let round = try makeRound(
            in: context,
            playerIDs: [p1ID.uuidString, p2ID.uuidString],
            holeCount: 9,
            parPerHole: 3
        )

        // When: only Jake speaks his score
        let parser = VoiceParser()
        let voicePlayers = [
            VoicePlayerEntry(playerID: p1ID.uuidString, displayName: "Jake", aliases: []),
            VoicePlayerEntry(playerID: p2ID.uuidString, displayName: "Sarah", aliases: [])
        ]
        let result = parser.parse(transcript: "Jake 4", players: voicePlayers)

        guard case .success(let candidates) = result else {
            Issue.record("Expected .success for subset scoring, got \(result)")
            return
        }
        #expect(candidates.count == 1)
        #expect(candidates[0].playerID == p1ID.uuidString)

        let service = ScoringService(modelContext: context, deviceID: "voice-device")
        try service.createScoreEvent(
            roundID: round.id,
            holeNumber: 1,
            playerID: candidates[0].playerID,
            strokeCount: candidates[0].strokeCount,
            reportedByPlayerID: p1ID
        )

        let engine = StandingsEngine(modelContext: context)
        engine.recompute(for: round.id, trigger: .localScore)
        let standings = engine.currentStandings

        // Then: only Jake has holesPlayed > 0
        let byID = Dictionary(uniqueKeysWithValues: standings.map { ($0.playerID, $0) })
        #expect(byID[p1ID.uuidString]?.holesPlayed == 1)
        #expect(byID[p1ID.uuidString]?.totalStrokes == 4)
        #expect(byID[p2ID.uuidString]?.holesPlayed == 0)
    }
}
