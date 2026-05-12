import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for HistoryListViewModel SwiftData integration (Story 8.1: History List & Round Detail).
@Suite("HistoryListViewModel — Queries")
@MainActor
struct HistoryListQueryTests {

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
        round.completedAt = completedAt
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

    // MARK: - Task 4.2: Reverse chronological ordering

    @Test("Completed rounds query returns results in reverse chronological order")
    func test_completedRounds_reverseChronological() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let course = Course(name: "Ordering Course", holeCount: 9)
        context.insert(course)

        let olderDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let newerDate = Date()

        let olderRound = makeRound(courseID: course.id, playerIDs: ["p1"], completedAt: olderDate)
        context.insert(olderRound)
        let newerRound = makeRound(courseID: course.id, playerIDs: ["p1"], completedAt: newerDate)
        context.insert(newerRound)

        try context.save()

        let descriptor = FetchDescriptor<Round>(
            predicate: #Predicate<Round> { $0.status == "completed" },
            sortBy: [SortDescriptor(\Round.completedAt, order: .reverse)]
        )
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
        #expect(results[0].id == newerRound.id)
        #expect(results[1].id == olderRound.id)
    }

    // MARK: - Task 4.2: Non-completed rounds excluded

    @Test("Non-completed rounds are excluded from completed rounds query")
    func test_nonCompletedRounds_excluded() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let course = Course(name: "Filter Course", holeCount: 9)
        context.insert(course)

        let completedRound = makeRound(courseID: course.id, playerIDs: ["p1"])
        context.insert(completedRound)

        let activeRound = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: ["p1"],
            guestNames: [],
            holeCount: 9
        )
        activeRound.start()
        context.insert(activeRound)

        let setupRound = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: ["p1"],
            guestNames: [],
            holeCount: 9
        )
        context.insert(setupRound)

        try context.save()

        let descriptor = FetchDescriptor<Round>(
            predicate: #Predicate<Round> { $0.status == "completed" },
            sortBy: [SortDescriptor(\Round.completedAt, order: .reverse)]
        )
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].id == completedRound.id)
    }
}
