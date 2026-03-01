import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for HistoryListViewModel (Story 8.1: History List & Round Detail).
@Suite("HistoryListViewModel")
@MainActor
struct HistoryListViewModelTests {

    // MARK: - Container setup

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

    // MARK: - Helpers

    private func makeRound(
        courseID: UUID,
        playerIDs: [String],
        guestNames: [String] = [],
        completedAt: Date = Date()
    ) -> Round {
        let round = Round(
            courseID: courseID,
            organizerID: UUID(),
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: 9
        )
        round.start()
        round.awaitFinalization()
        round.complete()
        return round
    }

    private func insertCompletedRoundWithScores(
        context: ModelContext,
        playerID: String,
        strokesPerHole: Int = 3,
        parPerHole: Int = 3
    ) throws -> (round: Round, course: Course) {
        let course = Course(name: "Test Course", holeCount: 9)
        context.insert(course)

        let round = makeRound(courseID: course.id, playerIDs: [playerID])
        context.insert(round)

        for holeNum in 1...9 {
            let hole = Hole(courseID: course.id, number: holeNum, par: parPerHole)
            context.insert(hole)
            let event = ScoreEvent(
                roundID: round.id,
                holeNumber: holeNum,
                playerID: playerID,
                strokeCount: strokesPerHole,
                reportedByPlayerID: UUID(),
                deviceID: "test"
            )
            context.insert(event)
        }
        try context.save()
        return (round, course)
    }

    // MARK: - Task 4.1: Card data derivation

    @Test("ensureCardData returns no data for empty cache without calling it")
    func test_emptyCache_beforeEnsureCardData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: "player-1")

        let fakeID = UUID()
        #expect(vm.cardDataCache[fakeID] == nil)
    }

    @Test("ensureCardData populates card data for a completed round with correct course name")
    func test_ensureCardData_populatesCourseName() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (round, course) = try insertCompletedRoundWithScores(context: context, playerID: playerID)

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: playerID)
        vm.ensureCardData(for: round)

        let data = vm.cardDataCache[round.id]
        #expect(data != nil)
        #expect(data?.courseName == course.name)
    }

    @Test("ensureCardData derives correct player count for registered players")
    func test_ensureCardData_playerCount_registeredOnly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let p1 = UUID().uuidString
        let p2 = UUID().uuidString
        let course = Course(name: "Eagle Ridge", holeCount: 9)
        context.insert(course)
        let round = makeRound(courseID: course.id, playerIDs: [p1, p2])
        context.insert(round)
        try context.save()

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: p1)
        vm.ensureCardData(for: round)

        #expect(vm.cardDataCache[round.id]?.playerCount == 2)
    }

    @Test("ensureCardData derives correct player count including guests")
    func test_ensureCardData_playerCount_withGuests() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let p1 = UUID().uuidString
        let course = Course(name: "Hawk's Ridge", holeCount: 9)
        context.insert(course)
        let round = makeRound(courseID: course.id, playerIDs: [p1], guestNames: ["Alice", "Bob"])
        context.insert(round)
        try context.save()

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: p1)
        vm.ensureCardData(for: round)

        #expect(vm.cardDataCache[round.id]?.playerCount == 3)
    }

    @Test("ensureCardData derives winner name and score from standings")
    func test_ensureCardData_winnerNameAndScore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerWinner = Player(displayName: "Alice")
        let playerLoser = Player(displayName: "Bob")
        context.insert(playerWinner)
        context.insert(playerLoser)

        // Use the UUID strings that match the player IDs
        let course = Course(name: "Pine Valley", holeCount: 9)
        context.insert(course)

        let round = Round(
            courseID: course.id,
            organizerID: playerWinner.id,
            playerIDs: [playerWinner.id.uuidString, playerLoser.id.uuidString],
            guestNames: [],
            holeCount: 9
        )
        context.insert(round)
        round.start()
        round.awaitFinalization()
        round.complete()

        for holeNum in 1...9 {
            let hole = Hole(courseID: course.id, number: holeNum, par: 3)
            context.insert(hole)
            // Winner: 2 strokes per hole (under par)
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerWinner.id.uuidString, strokeCount: 2,
                reportedByPlayerID: playerWinner.id, deviceID: "test"
            ))
            // Loser: 4 strokes per hole (over par)
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerLoser.id.uuidString, strokeCount: 4,
                reportedByPlayerID: playerLoser.id, deviceID: "test"
            ))
        }
        try context.save()

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: playerWinner.id.uuidString)
        vm.ensureCardData(for: round)

        let data = vm.cardDataCache[round.id]
        #expect(data?.winnerName == "Alice")
        #expect(data?.winnerFormattedScore == "-9")  // 18 strokes, 27 par → -9
    }

    @Test("ensureCardData derives user position as ordinal string")
    func test_ensureCardData_userPosition_ordinal() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let p1 = Player(displayName: "Player1")
        context.insert(p1)
        let course = Course(name: "Course", holeCount: 9)
        context.insert(course)
        let round = Round(
            courseID: course.id,
            organizerID: p1.id,
            playerIDs: [p1.id.uuidString],
            guestNames: [],
            holeCount: 9
        )
        context.insert(round)
        round.start()
        round.awaitFinalization()
        round.complete()

        for holeNum in 1...9 {
            context.insert(Hole(courseID: course.id, number: holeNum, par: 3))
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: p1.id.uuidString, strokeCount: 3,
                reportedByPlayerID: p1.id, deviceID: "test"
            ))
        }
        try context.save()

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: p1.id.uuidString)
        vm.ensureCardData(for: round)

        let data = vm.cardDataCache[round.id]
        #expect(data?.userPosition == "1st")
        #expect(data?.userFormattedScore == "E")  // 27 strokes at par 27
    }

    @Test("ensureCardData returns nil for user position when currentPlayerID not in round")
    func test_ensureCardData_userPosition_nilWhenNotInRound() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let p1 = UUID().uuidString
        let (round, _) = try insertCompletedRoundWithScores(context: context, playerID: p1)

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: "different-player-id")
        vm.ensureCardData(for: round)

        let data = vm.cardDataCache[round.id]
        #expect(data?.userPosition == nil)
        #expect(data?.userFormattedScore == nil)
    }

    @Test("ensureCardData handles guest players correctly in standings")
    func test_ensureCardData_guestPlayers() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let registeredID = UUID().uuidString
        let guestName = "Charlie"
        let guestPlayerID = "guest:\(guestName)"

        let course = Course(name: "Guest Course", holeCount: 9)
        context.insert(course)
        let round = makeRound(courseID: course.id, playerIDs: [registeredID], guestNames: [guestName])
        context.insert(round)

        for holeNum in 1...9 {
            let hole = Hole(courseID: course.id, number: holeNum, par: 3)
            context.insert(hole)
            // Guest wins with 2 strokes per hole
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: guestPlayerID, strokeCount: 2,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
            // Registered player gets 4
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: registeredID, strokeCount: 4,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: registeredID)
        vm.ensureCardData(for: round)

        let data = vm.cardDataCache[round.id]
        #expect(data?.winnerName == guestName)   // guest name without "guest:" prefix
        #expect(data?.playerCount == 2)
    }

    @Test("ensureCardData caches result and does not recompute on second call")
    func test_ensureCardData_cachesPreventsRecompute() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (round, _) = try insertCompletedRoundWithScores(context: context, playerID: playerID)

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: playerID)
        vm.ensureCardData(for: round)
        let firstData = vm.cardDataCache[round.id]

        // Call again — should hit cache, not recompute
        vm.ensureCardData(for: round)
        let secondData = vm.cardDataCache[round.id]

        #expect(firstData?.courseName == secondData?.courseName)
        #expect(firstData?.roundID == secondData?.roundID)
    }

    @Test("ensureCardData formats date from round.completedAt")
    func test_ensureCardData_formattedDate_isNonEmpty() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (round, _) = try insertCompletedRoundWithScores(context: context, playerID: playerID)

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: playerID)
        vm.ensureCardData(for: round)

        #expect(vm.cardDataCache[round.id]?.formattedDate.isEmpty == false)
    }

    // MARK: - Task 4.2: SwiftData integration — only completed rounds

    @Test("ensureCardData only used with completed rounds — non-completed rounds are excluded by @Query")
    func test_cardDataForCompletedRound_hasAllFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (round, course) = try insertCompletedRoundWithScores(context: context, playerID: playerID)

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: playerID)
        vm.ensureCardData(for: round)

        let data = vm.cardDataCache[round.id]
        #expect(data != nil)
        #expect(data?.courseName == course.name)
        #expect(data?.playerCount == 1)
        #expect(data?.formattedDate.isEmpty == false)
    }
}
