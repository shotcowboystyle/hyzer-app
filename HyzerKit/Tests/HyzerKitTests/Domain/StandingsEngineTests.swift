import Testing
import SwiftData
import Foundation
@testable import HyzerKit

/// Tests for StandingsEngine (Story 3.4: Live Leaderboard).
@Suite("StandingsEngine")
@MainActor
struct StandingsEngineTests {

    // MARK: - Test Setup

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Creates a round with holes and inserts everything into the context.
    private func makeRound(
        in context: ModelContext,
        playerIDs: [String] = [],
        guestNames: [String] = [],
        holeCount: Int = 9,
        parValues: [Int: Int] = [:]  // holeNumber: par
    ) throws -> (round: Round, courseID: UUID) {
        let course = Course(name: "Test Course", holeCount: holeCount, isSeeded: false)
        context.insert(course)

        for number in 1...holeCount {
            let par = parValues[number] ?? 3
            context.insert(Hole(courseID: course.id, number: number, par: par))
        }

        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: holeCount
        )
        context.insert(round)
        try context.save()
        return (round, course.id)
    }

    private func makeEngine(context: ModelContext) -> StandingsEngine {
        StandingsEngine(modelContext: context)
    }

    // MARK: - AC 1: Real-time standings ranked by relative score to par

    @Test("single player, single hole: standings show correct relative-to-par score")
    func test_singlePlayerSingleHole_correctRelativeToPar() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerUUID = UUID()
        let playerIDStr = playerUUID.uuidString

        let player = Player(displayName: "Alice")
        player.id = playerUUID
        context.insert(player)

        let (round, _) = try makeRound(in: context, playerIDs: [playerIDStr], parValues: [1: 3])

        // Score of 4 on par-3 = +1
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: playerIDStr,
            strokeCount: 4, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let engine = makeEngine(context: context)
        engine.recompute(for: round.id, trigger: .localScore)

        let standings = engine.currentStandings
        #expect(standings.count == 1)
        #expect(standings[0].playerName == "Alice")
        #expect(standings[0].scoreRelativeToPar == 1)
        #expect(standings[0].totalStrokes == 4)
        #expect(standings[0].holesPlayed == 1)
        #expect(standings[0].position == 1)
    }

    @Test("multiple players ranked correctly: lower relative-to-par first")
    func test_multiplePlayers_rankedByRelativeToPar() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let aliceID = UUID()
        let bobID = UUID()
        let charlieID = UUID()

        for (id, name) in [(aliceID, "Alice"), (bobID, "Bob"), (charlieID, "Charlie")] {
            let p = Player(displayName: name)
            p.id = id
            context.insert(p)
        }

        let playerIDs = [aliceID.uuidString, bobID.uuidString, charlieID.uuidString]
        let (round, _) = try makeRound(in: context, playerIDs: playerIDs, parValues: [1: 3])

        // Alice: 2 strokes (par 3, -1), Bob: 3 strokes (par 3, E), Charlie: 5 strokes (par 3, +2)
        for (playerID, strokes) in [(aliceID.uuidString, 2), (bobID.uuidString, 3), (charlieID.uuidString, 5)] {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: 1, playerID: playerID,
                strokeCount: strokes, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let engine = makeEngine(context: context)
        engine.recompute(for: round.id, trigger: .localScore)

        let standings = engine.currentStandings
        #expect(standings.count == 3)
        #expect(standings[0].playerName == "Alice")
        #expect(standings[0].position == 1)
        #expect(standings[0].scoreRelativeToPar == -1)
        #expect(standings[1].playerName == "Bob")
        #expect(standings[1].position == 2)
        #expect(standings[1].scoreRelativeToPar == 0)
        #expect(standings[2].playerName == "Charlie")
        #expect(standings[2].position == 3)
        #expect(standings[2].scoreRelativeToPar == 2)
    }

    @Test("alphabetical tiebreak when scores are equal")
    func test_tiedScores_alphabeticalTiebreak() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let zebraID = UUID()
        let appleID = UUID()

        for (id, name) in [(zebraID, "Zebra"), (appleID, "Apple")] {
            let p = Player(displayName: name)
            p.id = id
            context.insert(p)
        }

        let playerIDs = [zebraID.uuidString, appleID.uuidString]
        let (round, _) = try makeRound(in: context, playerIDs: playerIDs, parValues: [1: 3])

        // Both shoot par 3 = E
        for playerID in [zebraID.uuidString, appleID.uuidString] {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: 1, playerID: playerID,
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let engine = makeEngine(context: context)
        engine.recompute(for: round.id, trigger: .localScore)

        let standings = engine.currentStandings
        #expect(standings.count == 2)
        // Tied, so both position 1; Apple sorts before Zebra alphabetically
        #expect(standings[0].playerName == "Apple")
        #expect(standings[0].position == 1)
        #expect(standings[1].playerName == "Zebra")
        #expect(standings[1].position == 1)
    }

    @Test("partial round: holesPlayed reflects only holes with scores")
    func test_partialRound_holesPlayedCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID()
        let p = Player(displayName: "Player")
        p.id = playerID
        context.insert(p)

        let (round, _) = try makeRound(in: context, playerIDs: [playerID.uuidString], holeCount: 9)

        // Only score holes 1-3
        for holeNum in 1...3 {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum, playerID: playerID.uuidString,
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let engine = makeEngine(context: context)
        engine.recompute(for: round.id, trigger: .localScore)

        let standings = engine.currentStandings
        #expect(standings.count == 1)
        #expect(standings[0].holesPlayed == 3)
        #expect(standings[0].totalStrokes == 9)
    }

    @Test("supersession chain: only leaf-node scores used for corrected holes")
    func test_supersessionChain_leafNodeOnly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID()
        let p = Player(displayName: "Player")
        p.id = playerID
        context.insert(p)

        let (round, _) = try makeRound(in: context, playerIDs: [playerID.uuidString], parValues: [1: 3])

        // Original score: 5 (superseded)
        let original = ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: playerID.uuidString,
            strokeCount: 5, reportedByPlayerID: UUID(), deviceID: "test"
        )
        context.insert(original)
        try context.save()

        // Correction: 2 (supersedes original)
        let correction = ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: playerID.uuidString,
            strokeCount: 2, reportedByPlayerID: UUID(), deviceID: "test"
        )
        correction.supersedesEventID = original.id
        context.insert(correction)
        try context.save()

        let engine = makeEngine(context: context)
        engine.recompute(for: round.id, trigger: .localScore)

        let standings = engine.currentStandings
        #expect(standings.count == 1)
        // Only the leaf-node score (2) should count, not the superseded (5)
        #expect(standings[0].totalStrokes == 2)
        #expect(standings[0].scoreRelativeToPar == -1) // 2 - 3 = -1
    }

    // MARK: - AC 5: StandingsChange includes animation context

    @Test("StandingsChange.positionChanges correctly detects position shifts")
    func test_positionChanges_detectedCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let aliceID = UUID()
        let bobID = UUID()

        for (id, name) in [(aliceID, "Alice"), (bobID, "Bob")] {
            let p = Player(displayName: name)
            p.id = id
            context.insert(p)
        }

        let playerIDs = [aliceID.uuidString, bobID.uuidString]
        let (round, _) = try makeRound(in: context, playerIDs: playerIDs, parValues: [1: 3, 2: 3])

        // Hole 1: Alice 3 (E), Bob 3 (E) — tied at pos 1
        for playerID in [aliceID.uuidString, bobID.uuidString] {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: 1, playerID: playerID,
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let engine = makeEngine(context: context)
        let firstChange = engine.recompute(for: round.id, trigger: .localScore)
        // After first compute, both at position 1 — no previous, so no changes
        #expect(firstChange.positionChanges.isEmpty)

        // Hole 2: Alice 2 (birdie), Bob stays — Alice moves to 1st alone
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 2, playerID: aliceID.uuidString,
            strokeCount: 2, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let secondChange = engine.recompute(for: round.id, trigger: .localScore)
        // Bob should have moved from 1 to 2
        let bobChange = secondChange.positionChanges[bobID.uuidString]
        #expect(bobChange != nil)
        #expect(bobChange?.from == 1)
        #expect(bobChange?.to == 2)
    }

    @Test("mixed registered and guest players resolve names correctly")
    func test_mixedPlayers_namesResolvedCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID()
        let p = Player(displayName: "Alice")
        p.id = playerID
        context.insert(p)

        let (round, _) = try makeRound(
            in: context,
            playerIDs: [playerID.uuidString],
            guestNames: ["Dave"],
            parValues: [1: 3]
        )

        // Score for registered player
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: playerID.uuidString,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        // Score for guest player
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: "guest:Dave",
            strokeCount: 4, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let engine = makeEngine(context: context)
        engine.recompute(for: round.id, trigger: .localScore)

        let standings = engine.currentStandings
        #expect(standings.count == 2)
        let names = standings.map(\.playerName)
        #expect(names.contains("Alice"))
        #expect(names.contains("Dave"))
    }

    @Test("trigger type is preserved in StandingsChange")
    func test_triggerType_preserved() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID()
        let p = Player(displayName: "Player")
        p.id = playerID
        context.insert(p)

        let (round, _) = try makeRound(in: context, playerIDs: [playerID.uuidString])

        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: playerID.uuidString,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let engine = makeEngine(context: context)

        let localChange = engine.recompute(for: round.id, trigger: .localScore)
        #expect(localChange.trigger == .localScore)

        let remoteChange = engine.recompute(for: round.id, trigger: .remoteSync)
        #expect(remoteChange.trigger == .remoteSync)
    }

    @Test("no scores yet: returns empty standings")
    func test_noScores_returnsEmptyStandings() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID()
        let p = Player(displayName: "Player")
        p.id = playerID
        context.insert(p)

        let (round, _) = try makeRound(in: context, playerIDs: [playerID.uuidString])
        // No ScoreEvents inserted

        let engine = makeEngine(context: context)
        engine.recompute(for: round.id, trigger: .localScore)

        // Player is in the round but has no scores — should appear with 0 strokes, 0 holes played
        let standings = engine.currentStandings
        #expect(standings.count == 1)
        #expect(standings[0].holesPlayed == 0)
        #expect(standings[0].totalStrokes == 0)
        #expect(standings[0].scoreRelativeToPar == 0)
    }
}
