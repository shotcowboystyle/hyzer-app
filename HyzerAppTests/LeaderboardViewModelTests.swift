import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for LeaderboardViewModel (Story 3.4: Live Leaderboard).
@Suite("LeaderboardViewModel")
@MainActor
struct LeaderboardViewModelTests {

    // MARK: - Setup

    private func makeContextAndEngine() throws -> (ModelContext, StandingsEngine) {
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let engine = StandingsEngine(modelContext: context)
        return (context, engine)
    }

    /// Inserts a round with a course and holes and saves. Returns the round.
    private func makeRound(
        in context: ModelContext,
        playerIDs: [String],
        holeCount: Int = 9
    ) throws -> Round {
        let course = Course(name: "Test Course", holeCount: holeCount, isSeeded: false)
        context.insert(course)
        for number in 1...holeCount {
            context.insert(Hole(courseID: course.id, number: number, par: 3))
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

    // MARK: - AC 1: Standings updated after handleScoreEntered

    @Test("handleScoreEntered calls standingsEngine.recompute with .localScore trigger")
    func test_handleScoreEntered_recomputesWithLocalScoreTrigger() throws {
        let (context, engine) = try makeContextAndEngine()

        let playerID = UUID()
        let p = Player(displayName: "Alice")
        p.id = playerID
        context.insert(p)

        let round = try makeRound(in: context, playerIDs: [playerID.uuidString])

        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: playerID.uuidString,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let vm = LeaderboardViewModel(
            standingsEngine: engine,
            roundID: round.id,
            currentPlayerID: playerID.uuidString
        )

        // Before handleScoreEntered, standings are empty (no recompute yet)
        #expect(vm.currentStandings.isEmpty)

        vm.handleScoreEntered()

        // After handleScoreEntered, standings should be populated via recompute
        #expect(vm.currentStandings.count == 1)
        #expect(vm.currentStandings[0].playerName == "Alice")
        // Trigger is .localScore — verified indirectly via latestChange
        #expect(engine.latestChange?.trigger == .localScore)
    }

    // MARK: - AC 4: showPulse lifecycle

    @Test("showPulse becomes true immediately after handleScoreEntered")
    func test_showPulse_becomesTrueAfterHandleScoreEntered() throws {
        let (context, engine) = try makeContextAndEngine()

        let playerID = UUID()
        let p = Player(displayName: "Player")
        p.id = playerID
        context.insert(p)

        let round = try makeRound(in: context, playerIDs: [playerID.uuidString])

        let vm = LeaderboardViewModel(
            standingsEngine: engine,
            roundID: round.id,
            currentPlayerID: playerID.uuidString
        )

        #expect(vm.showPulse == false)
        vm.handleScoreEntered()
        #expect(vm.showPulse == true)
    }

    // MARK: - AC 4: positionChanges populated

    @Test("positionChanges populated from StandingsChange after standings shift")
    func test_positionChanges_populatedAfterStandingsShift() throws {
        let (context, engine) = try makeContextAndEngine()

        let aliceID = UUID()
        let bobID = UUID()

        for (id, name) in [(aliceID, "Alice"), (bobID, "Bob")] {
            let p = Player(displayName: name)
            p.id = id
            context.insert(p)
        }

        let playerIDs = [aliceID.uuidString, bobID.uuidString]
        let round = try makeRound(in: context, playerIDs: playerIDs)

        // First score: both at par (tied at position 1)
        for playerID in playerIDs {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: 1, playerID: playerID,
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let vm = LeaderboardViewModel(
            standingsEngine: engine,
            roundID: round.id,
            currentPlayerID: aliceID.uuidString
        )

        // First recompute: no position changes (no previous standings)
        vm.handleScoreEntered()
        #expect(vm.positionChanges.isEmpty)

        // Alice gets a birdie on hole 2 — she should move up, Bob moves down
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 2, playerID: aliceID.uuidString,
            strokeCount: 2, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        vm.handleScoreEntered()

        // Bob should have a position change (1 → 2)
        let bobChange = vm.positionChanges[bobID.uuidString]
        #expect(bobChange != nil)
        #expect(bobChange?.from == 1)
        #expect(bobChange?.to == 2)
    }

    // MARK: - currentPlayerStandingIndex

    @Test("currentPlayerStandingIndex returns correct index for current player")
    func test_currentPlayerStandingIndex_correctIndex() throws {
        let (context, engine) = try makeContextAndEngine()

        let aliceID = UUID()
        let bobID = UUID()

        for (id, name) in [(aliceID, "Alice"), (bobID, "Bob")] {
            let p = Player(displayName: name)
            p.id = id
            context.insert(p)
        }

        let playerIDs = [aliceID.uuidString, bobID.uuidString]
        let round = try makeRound(in: context, playerIDs: playerIDs)

        // Bob better score (birdie), Alice par — Bob leads
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: bobID.uuidString,
            strokeCount: 2, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: aliceID.uuidString,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let vm = LeaderboardViewModel(
            standingsEngine: engine,
            roundID: round.id,
            currentPlayerID: aliceID.uuidString
        )
        vm.handleScoreEntered()

        // Standings: [Bob (-1), Alice (E)] — Alice is at index 1
        let index = vm.currentPlayerStandingIndex
        #expect(index == 1)
    }

    @Test("currentPlayerStandingIndex returns nil when no standings")
    func test_currentPlayerStandingIndex_nilWhenEmpty() throws {
        let (context, engine) = try makeContextAndEngine()
        let playerID = UUID()
        let p = Player(displayName: "Player")
        p.id = playerID
        context.insert(p)
        let round = try makeRound(in: context, playerIDs: [playerID.uuidString])

        let vm = LeaderboardViewModel(
            standingsEngine: engine,
            roundID: round.id,
            currentPlayerID: playerID.uuidString
        )
        // No recompute called — standings empty
        #expect(vm.currentPlayerStandingIndex == nil)
    }
}
