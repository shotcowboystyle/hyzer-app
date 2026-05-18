import Testing
import SwiftData
import Foundation
@testable import HyzerKit

@Suite("PersonalBestService")
@MainActor
struct PersonalBestServiceTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        try TestContainerFactory.makeSyncContainer()
    }

    /// Inserts a completed round with the given per-hole stroke counts (all holes par 3).
    @discardableResult
    private func insertRound(
        context: ModelContext,
        course: Course,
        playerID: String,
        holeStrokes: [Int],
        completedAt: Date = Date(timeIntervalSinceNow: -1),
        guestIDs: [String] = [],
        guestNames: [String] = []
    ) throws -> Round {
        let isGuest = guestIDs.contains(playerID)
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: isGuest ? [] : [playerID],
            guestNames: guestNames,
            holeCount: holeStrokes.count,
            guestIDs: guestIDs.isEmpty ? nil : guestIDs
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = completedAt

        for (index, strokes) in holeStrokes.enumerated() {
            context.insert(ScoreEvent(
                roundID: round.id,
                holeNumber: index + 1,
                playerID: playerID,
                strokeCount: strokes,
                reportedByPlayerID: UUID(),
                deviceID: "test"
            ))
        }
        try context.save()
        return round
    }

    // MARK: - Empty store

    @Test("empty store returns nil")
    func test_computeBest_emptyStore_returnsNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let service = PersonalBestService(modelContext: context)

        let result = try service.computeBest(for: UUID().uuidString, courseID: UUID())

        #expect(result == nil)
    }

    // MARK: - No rounds for player on queried course

    @Test("player has rounds on different course only — returns nil for queried course")
    func test_computeBest_noRoundsForPlayerOnCourse_returnsNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let courseA = Course(name: "A", holeCount: 1, isSeeded: false)
        let courseB = Course(name: "B", holeCount: 1, isSeeded: false)
        context.insert(courseA)
        context.insert(courseB)

        try insertRound(context: context, course: courseA, playerID: playerID, holeStrokes: [3])

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: courseB.id)

        #expect(result == nil)
    }

    // MARK: - Completed-only filter (AC #1)

    @Test("excludes non-completed rounds; returns only completed round even if active is better")
    func test_computeBest_excludesNonCompletedRounds() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)
        context.insert(Hole(courseID: course.id, number: 1, par: 3))

        // Active round with a better score — should be excluded
        let activeRound = Round(
            courseID: course.id, organizerID: UUID(), playerIDs: [playerID],
            guestNames: [], holeCount: 1
        )
        context.insert(activeRound)
        activeRound.start()  // not completed
        context.insert(ScoreEvent(
            roundID: activeRound.id, holeNumber: 1, playerID: playerID,
            strokeCount: 1, reportedByPlayerID: UUID(), deviceID: "test"
        ))

        // Completed round with a worse score — should be returned
        let completedRound = try insertRound(
            context: context, course: course, playerID: playerID,
            holeStrokes: [5]  // +2 relative to par 3
        )

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: course.id)

        #expect(result?.roundID == completedRound.id)
    }

    // MARK: - Cross-course filter (AC #1)

    @Test("excludes rounds from other courses")
    func test_computeBest_excludesOtherCourses() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let courseA = Course(name: "A", holeCount: 3, isSeeded: false)
        let courseB = Course(name: "B", holeCount: 3, isSeeded: false)
        context.insert(courseA)
        context.insert(courseB)
        for n in 1...3 {
            context.insert(Hole(courseID: courseA.id, number: n, par: 3))
            context.insert(Hole(courseID: courseB.id, number: n, par: 3))
        }

        // -5 on course A
        try insertRound(context: context, course: courseA, playerID: playerID, holeStrokes: [1, 1, 1])
        // +2 on course B
        let courseBRound = try insertRound(context: context, course: courseB, playerID: playerID, holeStrokes: [4, 4, 3])

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: courseB.id)

        #expect(result?.roundID == courseBRound.id)
        #expect(result?.courseID == courseB.id)
    }

    // MARK: - Single round (AC #1)

    @Test("single completed round — returns that round's fields exactly")
    func test_computeBest_singleRound_returnsThatRound() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for n in 1...3 {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }
        let fixedDate = Date(timeIntervalSinceReferenceDate: 100_000)
        let round = try insertRound(
            context: context, course: course, playerID: playerID,
            holeStrokes: [3, 3, 2],  // totalStrokes=8, par=9, relative=-1
            completedAt: fixedDate
        )

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: course.id)

        #expect(result?.roundID == round.id)
        #expect(result?.playerID == playerID)
        #expect(result?.courseID == course.id)
        #expect(result?.totalStrokes == 8)
        #expect(result?.scoreRelativeToPar == -1)
        #expect(result?.completedAt == fixedDate)
    }

    // MARK: - Best score selection (AC #1)

    @Test("multiple rounds — returns the lowest scoreRelativeToPar round")
    func test_computeBest_multipleRounds_returnsLowestScore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for n in 1...3 {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }

        // Scores relative to par: +2, -1, +3
        try insertRound(context: context, course: course, playerID: playerID,
                        holeStrokes: [4, 4, 3],  // +2
                        completedAt: Date(timeIntervalSinceReferenceDate: 1000))
        let bestRound = try insertRound(context: context, course: course, playerID: playerID,
                        holeStrokes: [3, 3, 2],  // -1
                        completedAt: Date(timeIntervalSinceReferenceDate: 2000))
        try insertRound(context: context, course: course, playerID: playerID,
                        holeStrokes: [4, 4, 4],  // +3
                        completedAt: Date(timeIntervalSinceReferenceDate: 3000))

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: course.id)

        #expect(result?.roundID == bestRound.id)
        #expect(result?.scoreRelativeToPar == -1)
    }

    // MARK: - Tiebreak: earliest date wins (AC #2)

    @Test("tied scores — returns earliest completedAt (AC #2 critical tiebreak)")
    func test_computeBest_tiedScores_returnsEarliestDate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for n in 1...3 {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }

        let t1 = Date(timeIntervalSinceReferenceDate: 1000)
        let t2 = Date(timeIntervalSinceReferenceDate: 2000)
        let t3 = Date(timeIntervalSinceReferenceDate: 3000)

        // All three rounds tie at -1; insert in non-chronological order
        try insertRound(context: context, course: course, playerID: playerID,
                        holeStrokes: [3, 3, 2], completedAt: t2)
        let earliestRound = try insertRound(context: context, course: course, playerID: playerID,
                        holeStrokes: [3, 3, 2], completedAt: t1)
        try insertRound(context: context, course: course, playerID: playerID,
                        holeStrokes: [3, 3, 2], completedAt: t3)

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: course.id)

        #expect(result?.roundID == earliestRound.id)
        #expect(result?.completedAt == t1)
    }

    // MARK: - Guest player (AC #6)

    @Test("guest player queried by guestID — returns that round; different guestID returns nil")
    func test_computeBest_includesGuestPlayerByGuestID() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let guestID = "guest:\(UUID().uuidString)"
        let otherGuestID = "guest:\(UUID().uuidString)"
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        let guestRound = try insertRound(
            context: context,
            course: course,
            playerID: guestID,
            holeStrokes: [3],
            guestIDs: [guestID],
            guestNames: ["Guest Player"]
        )

        let service = PersonalBestService(modelContext: context)

        // Correct guest ID → returns the round
        let result = try service.computeBest(for: guestID, courseID: course.id)
        #expect(result?.roundID == guestRound.id)
        #expect(result?.playerID == guestID)

        // Different guest ID → no matching events, returns nil (documents round-scoped guest semantics)
        let otherResult = try service.computeBest(for: otherGuestID, courseID: course.id)
        #expect(otherResult == nil)
    }

    // MARK: - Fetch limit (AC #3)

    @Test("respects maxRounds fetch limit — drops rounds older than the most-recent maxRounds window")
    func test_computeBest_respectsFetchLimit() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)
        context.insert(Hole(courseID: course.id, number: 1, par: 3))

        // Insert 600 rounds to exceed maxRounds=500. The all-time best (-2, strokes=1)
        // is placed at index 0 (OLDEST) — outside the most-recent 500 window, so it
        // MUST be dropped. The best-in-window (-1, strokes=2) is placed at index 100,
        // the very first index inside the most-recent 500 window. All other rounds
        // are E (strokes=3). If the test asserts -1, fetchLimit truncation is correct.
        // If it returned -2, the limit failed to drop the oldest 100 rounds.
        for i in 0..<600 {
            let strokes: Int
            if i == 0 {
                strokes = 1  // -2, all-time best (oldest — outside window)
            } else if i == 100 {
                strokes = 2  // -1, best within most-recent 500 window
            } else {
                strokes = 3  // E
            }
            let round = Round(
                courseID: course.id, organizerID: UUID(),
                playerIDs: [playerID], guestNames: [], holeCount: 1
            )
            context.insert(round)
            round.start()
            round.complete()
            round.completedAt = Date(timeIntervalSinceReferenceDate: Double(i) * 60)
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: 1, playerID: playerID,
                strokeCount: strokes, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: course.id, maxRounds: 500)

        #expect(result != nil)
        // The all-time best (-2) is OUTSIDE the most-recent 500 window and must be dropped.
        // The result must be the in-window best (-1), NOT -2.
        #expect(result?.scoreRelativeToPar == -1)
    }

    // MARK: - Skip rounds where player has no score

    @Test("skips rounds where player has no ScoreEvents; returns round with valid score")
    func test_computeBest_skipsRoundsWherePlayerHasNoScore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let otherPlayerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)
        context.insert(Hole(courseID: course.id, number: 1, par: 3))

        // Two rounds: player is in playerIDs but has zero ScoreEvents
        for i in 0..<2 {
            let round = Round(
                courseID: course.id, organizerID: UUID(),
                playerIDs: [playerID, otherPlayerID], guestNames: [], holeCount: 1
            )
            context.insert(round)
            round.start()
            round.complete()
            round.completedAt = Date(timeIntervalSinceReferenceDate: Double(i) * 1000)
            // Only score the OTHER player
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: 1, playerID: otherPlayerID,
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }

        // One round with a valid score for our player
        let validRound = try insertRound(
            context: context, course: course, playerID: playerID,
            holeStrokes: [3],
            completedAt: Date(timeIntervalSinceReferenceDate: 9000)
        )

        let service = PersonalBestService(modelContext: context)
        let result = try service.computeBest(for: playerID, courseID: course.id)

        #expect(result?.roundID == validRound.id)
    }

    // MARK: - Fresh engine prevents stale state leak (regression guard for Story 13.1 patch P2)

    @Test("source-level guard: StandingsEngine is constructed inside the for-round loop, not above it")
    func test_computeBest_freshEngineConstructedPerIteration() throws {
        // The stale-state leak guarded here is intra-call: if `StandingsEngine` were
        // constructed ONCE above the for loop and reused, internal `recompute` failures
        // would leave `currentStandings` holding the previous round's values, bleeding
        // them into subsequent iterations (Story 13.1 review patch P2).
        //
        // The failure mode can only be triggered by an internal SwiftData exception
        // inside StandingsEngine.recompute — too fragile to reliably stage in a CI
        // test. Per spec Task 6.3 fallback, this is a source-level guard: assert that
        // PersonalBestService.swift declares a fresh engine inside the round loop.
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Domain/
            .deletingLastPathComponent()  // HyzerKitTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // HyzerKit/
            .appendingPathComponent("Sources/HyzerKit/Domain/PersonalBestService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let lines = source.components(separatedBy: "\n")
        guard let loopIndex = lines.firstIndex(where: { $0.contains("for round in rounds") }) else {
            Issue.record("expected `for round in rounds` loop in PersonalBestService.swift")
            return
        }
        let loopBody = lines[loopIndex..<lines.endIndex]
        let constructorLine = loopBody.first(where: { $0.contains("let engine = StandingsEngine(") })
        #expect(constructorLine != nil,
                "StandingsEngine must be constructed fresh inside `for round in rounds` — see Story 13.1 review patch P2")
    }
}
