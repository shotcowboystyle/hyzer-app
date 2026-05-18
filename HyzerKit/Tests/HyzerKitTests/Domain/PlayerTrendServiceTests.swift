import Testing
import SwiftData
import Foundation
@testable import HyzerKit

@Suite("PlayerTrendService")
@MainActor
struct PlayerTrendServiceTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        try TestContainerFactory.makeSyncContainer()
    }

    /// Inserts a completed round with the given per-hole stroke counts (all holes par 3).
    /// Pass `completedAt` to control sort order. Default is 1 second before now.
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

    @Test("empty store returns empty TrendSummary with nil statistics")
    func test_computeTrend_emptyStore_returnsEmptySummary() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let service = PlayerTrendService(modelContext: context)

        let summary = try service.computeTrend(for: UUID().uuidString)

        #expect(summary.points.isEmpty)
        #expect(summary.bestScore == nil)
        #expect(summary.worstScore == nil)
        #expect(summary.averageScore == nil)
    }

    // MARK: - Completed-only filter

    @Test("excludes non-completed rounds; includes only completed ones")
    func test_computeTrend_excludesNonCompletedRounds() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // Active round (not completed)
        let activeRound = Round(
            courseID: course.id, organizerID: UUID(), playerIDs: [playerID],
            guestNames: [], holeCount: 1
        )
        context.insert(activeRound)
        activeRound.start()
        context.insert(ScoreEvent(
            roundID: activeRound.id, holeNumber: 1, playerID: playerID,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        ))

        // Completed round
        try insertRound(context: context, course: course, playerID: playerID, holeStrokes: [3])
        try context.save()

        let service = PlayerTrendService(modelContext: context)
        let summary = try service.computeTrend(for: playerID)

        #expect(summary.points.count == 1)
    }

    // MARK: - Sort order

    @Test("points are sorted ascending by completedAt")
    func test_computeTrend_sortsPointsByCompletedAtAscending() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        let t1 = Date(timeIntervalSinceReferenceDate: 1_000)
        let t2 = Date(timeIntervalSinceReferenceDate: 2_000)
        let t3 = Date(timeIntervalSinceReferenceDate: 3_000)

        // Insert in non-chronological order
        try insertRound(context: context, course: course, playerID: playerID, holeStrokes: [4], completedAt: t3)
        try insertRound(context: context, course: course, playerID: playerID, holeStrokes: [2], completedAt: t1)
        try insertRound(context: context, course: course, playerID: playerID, holeStrokes: [3], completedAt: t2)

        let service = PlayerTrendService(modelContext: context)
        let summary = try service.computeTrend(for: playerID)

        #expect(summary.points.count == 3)
        #expect(summary.points[0].completedAt == t1)
        #expect(summary.points[1].completedAt == t2)
        #expect(summary.points[2].completedAt == t3)
    }

    // MARK: - Player with no events

    @Test("excludes rounds where the player has no ScoreEvents")
    func test_computeTrend_excludesRoundsWherePlayerHasNoScore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let otherPlayerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // Round with only OTHER player scored — our playerID is in playerIDs but has no events
        let round = Round(
            courseID: course.id, organizerID: UUID(),
            playerIDs: [playerID, otherPlayerID], guestNames: [], holeCount: 1
        )
        context.insert(round)
        round.start()
        round.complete()
        // Only insert ScoreEvent for the OTHER player
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: otherPlayerID,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let service = PlayerTrendService(modelContext: context)
        let summary = try service.computeTrend(for: playerID)

        #expect(summary.points.isEmpty)
    }

    // MARK: - Guest player

    @Test("includes guest player rounds when queried by guestID")
    func test_computeTrend_includesGuestPlayerByGuestID() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let guestID = "guest:\(UUID().uuidString)"
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        try insertRound(
            context: context,
            course: course,
            playerID: guestID,
            holeStrokes: [3],
            guestIDs: [guestID],
            guestNames: ["Guest Player"]
        )

        let service = PlayerTrendService(modelContext: context)
        let summary = try service.computeTrend(for: guestID)

        #expect(summary.points.count == 1)
        #expect(summary.playerID == guestID)
    }

    // MARK: - Statistics

    @Test("computes bestScore, worstScore, averageScore correctly")
    func test_computeTrend_summaryStatistics_correct() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for n in 1...3 {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }

        // 3 holes each, par 3 each → totalPar = 9
        // -3: strokes=[2,2,2] → totalStrokes=6 → 6-9=-3
        // -1: strokes=[3,3,2] → totalStrokes=8 → 8-9=-1
        //  0: strokes=[3,3,3] → totalStrokes=9 → 9-9=0
        // +2: strokes=[4,4,3] → totalStrokes=11 → 11-9=2
        // +5: strokes=[4,5,5] → totalStrokes=14 → 14-9=5
        let scores: [[Int]] = [[2,2,2], [3,3,2], [3,3,3], [4,4,3], [4,5,5]]
        for (i, strokes) in scores.enumerated() {
            try insertRound(
                context: context, course: course, playerID: playerID, holeStrokes: strokes,
                completedAt: Date(timeIntervalSinceReferenceDate: Double(i) * 1000)
            )
        }

        let service = PlayerTrendService(modelContext: context)
        let summary = try service.computeTrend(for: playerID)

        #expect(summary.points.count == 5)
        #expect(summary.bestScore == -3)
        #expect(summary.worstScore == 5)
        // average = (-3 + -1 + 0 + 2 + 5) / 5 = 3/5 = 0.6
        if let avg = summary.averageScore {
            #expect(abs(avg - 0.6) < 0.001)
        } else {
            Issue.record("averageScore should not be nil")
        }
    }

    // MARK: - Fetch limit

    @Test("respects maxRounds fetch limit — returns exactly maxRounds points")
    func test_computeTrend_respectsFetchLimit() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // Insert 600 rounds cheaply (1 hole, 1 event each)
        for i in 0..<600 {
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
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let service = PlayerTrendService(modelContext: context)
        let summary = try service.computeTrend(for: playerID, maxRounds: 500)

        #expect(summary.points.count == 500)
    }

    // MARK: - Superseded events (unresolvable score)

    @Test("skips round where all player events are self-superseding (no resolved score)")
    func test_computeTrend_unscoredHoleSkipsRound() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        let round = Round(
            courseID: course.id, organizerID: UUID(), playerIDs: [playerID],
            guestNames: [], holeCount: 1
        )
        context.insert(round)
        round.start()
        round.complete()

        // Self-superseding event: resolveCurrentScore returns nil because the event's own
        // ID is in the supersededIDs set.
        let eventID = UUID()
        let event = ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: playerID,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        )
        event.id = eventID
        event.supersedesEventID = eventID  // points to itself → no leaf
        context.insert(event)
        try context.save()

        let service = PlayerTrendService(modelContext: context)
        let summary = try service.computeTrend(for: playerID)

        #expect(summary.points.isEmpty)
    }

    // MARK: - Correctness smoke test at scale (AC #3 device measurement deferred)

    // AC #3's 500ms budget is measured from view appear to first paint on a real iOS device.
    // The macOS x86_64 test runner is ~5x slower than an M-series device; asserting any
    // fixed wall-clock threshold here would either falsely pass at multiples of the budget
    // (3s) or falsely fail on slow CI. This test asserts CORRECTNESS at the 250-round
    // scale only — the AC #3 perf gate is verified on-device per Task 8.3 / Completion Note #8.
    // For local diagnostics, run with `swift test -c release` and inspect the test duration
    // log; for CI, treat regressions in this test's wall-clock time as a signal, not a gate.
    @Test("250 completed rounds compute correctly (perf budget verified on device per AC #3)")
    func test_computeTrend_250Rounds_correctnessAtScale() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        for i in 0..<250 {
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
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let service = PlayerTrendService(modelContext: context)
        let result = try service.computeTrend(for: playerID)

        // Correctness gate: all 250 rounds returned, sorted ascending, scores well-formed.
        #expect(result.points.count == 250)
        #expect(result.bestScore != nil)
        #expect(result.worstScore != nil)
        let timestamps = result.points.map(\.completedAt)
        #expect(timestamps == timestamps.sorted())
    }
}
