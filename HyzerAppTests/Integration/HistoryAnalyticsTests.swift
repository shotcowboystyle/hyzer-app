import Testing
import SwiftData
import Foundation
@testable import HyzerApp
@testable import HyzerKit

/// Story 15.11 — Journey 4b: History & Analytics VM coverage gaps.
///
/// Coverage audit (2026-06-22) found that `HistoryListViewModel`,
/// `PlayerHoleBreakdownViewModel`, `HeadToHeadViewModel`, and
/// `PlayerTrendViewModel` already have unit-test files in `HyzerAppTests/ViewModels/`
/// (the Story 15.11 plan's "zero coverage" claim was based on stale recon).
///
/// This file adds only the genuine gaps the existing tests miss:
///   1. The `isTieForFirst && !userIsWinner` branch at `HistoryListViewModel.swift:84-85`
///      — covers the "Tie for 1st" label shown when the user is NOT one of the
///      tied players.
///   2. `PlayerTrendViewModel.compute` chronological ordering of `trend.points`
///      — the existing tests verify `hasEnoughData` / loading states but never
///      assert that the points come back oldest-first.
@Suite("Integration — History & Analytics (gap coverage)")
@MainActor
struct HistoryAnalyticsTests {

    // MARK: - Setup helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self,
            ScoreEvent.self, SyncMetadata.self, Discrepancy.self,
            configurations: config
        )
    }

    @discardableResult
    private func insertCourse(in context: ModelContext, holeCount: Int = 18) throws -> Course {
        let course = Course(name: "Test Course", holeCount: holeCount)
        context.insert(course)
        for n in 1...holeCount {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }
        try context.save()
        return course
    }

    private func insertPlayer(in context: ModelContext, displayName: String) throws -> Player {
        let player = Player(displayName: displayName)
        context.insert(player)
        try context.save()
        return player
    }

    @discardableResult
    private func insertCompletedRound(
        context: ModelContext,
        course: Course,
        playerStrokes: [(playerID: String, strokes: [Int])],
        completedAt: Date = Date(timeIntervalSinceNow: -3600)
    ) throws -> Round {
        let holeCount = playerStrokes[0].strokes.count
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: playerStrokes.map(\.playerID),
            guestNames: [],
            holeCount: holeCount
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = completedAt
        for entry in playerStrokes {
            for (index, strokes) in entry.strokes.enumerated() {
                context.insert(ScoreEvent(
                    roundID: round.id,
                    holeNumber: index + 1,
                    playerID: entry.playerID,
                    strokeCount: strokes,
                    reportedByPlayerID: UUID(),
                    deviceID: "test"
                ))
            }
        }
        try context.save()
        return round
    }

    // MARK: - Gap 1: HistoryListViewModel tie-for-first branch

    @Test("HistoryListViewModel: tie for first when user is NOT in the tie shows 'Tie for 1st'")
    func test_historyList_tieForFirstWhenUserNotInTie_showsTieLabel() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let course = try insertCourse(in: context)
        let alice = try insertPlayer(in: context, displayName: "Alice")
        let bob = try insertPlayer(in: context, displayName: "Bob")
        let carol = try insertPlayer(in: context, displayName: "Carol")

        // Alice + Bob tie at E (54 strokes). Carol scores +18 — third place.
        let round = try insertCompletedRound(
            context: context,
            course: course,
            playerStrokes: [
                (alice.id.uuidString, Array(repeating: 3, count: 18)),
                (bob.id.uuidString, Array(repeating: 3, count: 18)),
                (carol.id.uuidString, Array(repeating: 4, count: 18))
            ]
        )

        // currentPlayer = Carol — definitively NOT in the tie.
        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: carol.id.uuidString)
        vm.ensureCardData(for: round)

        let card = try #require(vm.cardDataCache[round.id])
        #expect(
            card.winnerName == "Tie for 1st",
            "HistoryListViewModel:84-85 should label the tied result 'Tie for 1st' when the user is not in the tie"
        )
        #expect(card.userIsWinner == false)
    }

    @Test("HistoryListViewModel: tie for first when user IS in the tie shows the user's own name")
    func test_historyList_tieForFirstWhenUserInTie_showsWinnerName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let course = try insertCourse(in: context)
        let alice = try insertPlayer(in: context, displayName: "Alice")
        let bob = try insertPlayer(in: context, displayName: "Bob")

        // Alice + Bob both tie at E.
        let round = try insertCompletedRound(
            context: context,
            course: course,
            playerStrokes: [
                (alice.id.uuidString, Array(repeating: 3, count: 18)),
                (bob.id.uuidString, Array(repeating: 3, count: 18))
            ]
        )

        // currentPlayer = Alice — IS in the tie. The conditional at
        // HistoryListViewModel:84-85 requires the user NOT to be the winner
        // to flip to "Tie for 1st" — otherwise the winner.playerName is used.
        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: alice.id.uuidString)
        vm.ensureCardData(for: round)

        let card = try #require(vm.cardDataCache[round.id])
        #expect(
            card.winnerName != "Tie for 1st",
            "user in the tie should see their own name (or co-winner's name), not the 'Tie for 1st' label"
        )
        #expect(card.userIsWinner == true)
    }

    // MARK: - Gap 2: PlayerTrendViewModel chronological ordering

    @Test("PlayerTrendViewModel.compute returns trend points sorted chronologically (oldest first)")
    func test_playerTrend_compute_returnsPointsSortedChronologically() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let course = try insertCourse(in: context)
        let alice = try insertPlayer(in: context, displayName: "Alice")
        let aliceID = alice.id.uuidString

        // 4 completed rounds inserted in non-chronological order so we prove
        // the sort happens inside the service, not just by lucky insertion order.
        let dayInSeconds: TimeInterval = 86400
        try insertCompletedRound(
            context: context, course: course,
            playerStrokes: [(aliceID, Array(repeating: 4, count: 18))],
            completedAt: Date(timeIntervalSinceNow: -2 * dayInSeconds)
        )
        try insertCompletedRound(
            context: context, course: course,
            playerStrokes: [(aliceID, Array(repeating: 3, count: 18))],
            completedAt: Date(timeIntervalSinceNow: -4 * dayInSeconds)
        )
        try insertCompletedRound(
            context: context, course: course,
            playerStrokes: [(aliceID, Array(repeating: 5, count: 18))],
            completedAt: Date(timeIntervalSinceNow: -1 * dayInSeconds)
        )
        try insertCompletedRound(
            context: context, course: course,
            playerStrokes: [(aliceID, Array(repeating: 2, count: 18))],
            completedAt: Date(timeIntervalSinceNow: -3 * dayInSeconds)
        )

        let vm = PlayerTrendViewModel(
            modelContext: context,
            playerID: aliceID,
            playerName: "Alice"
        )
        await vm.compute()

        let trend = try #require(vm.trend)
        #expect(trend.points.count == 4)
        for i in 1..<trend.points.count {
            #expect(
                trend.points[i].completedAt > trend.points[i - 1].completedAt,
                "trend points must be in strict chronological order (oldest first)"
            )
        }
    }
}
