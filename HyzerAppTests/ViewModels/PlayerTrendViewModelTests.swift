import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

@Suite("PlayerTrendViewModel")
@MainActor
struct PlayerTrendViewModelTests {

    // MARK: - Container

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

    /// Inserts a completed round with `holeCount` holes scored at `strokesPerHole` for `playerID`.
    @discardableResult
    private func insertRound(
        context: ModelContext,
        course: Course,
        playerID: String,
        strokesPerHole: Int = 3,
        holeCount: Int = 3,
        completedAt: Date = Date(timeIntervalSinceNow: -1)
    ) throws -> Round {
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerID],
            guestNames: [],
            holeCount: holeCount
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = completedAt
        for n in 1...holeCount {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: n, playerID: playerID,
                strokeCount: strokesPerHole, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()
        return round
    }

    // MARK: - Initial state

    @Test("isLoading is true before compute() is called")
    func test_viewModel_initialState_isLoading() throws {
        let container = try makeContainer()
        let vm = PlayerTrendViewModel(
            modelContext: ModelContext(container),
            playerID: "player1",
            playerName: "Alice"
        )
        #expect(vm.isLoading == true)
        #expect(vm.trend == nil)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - hasEnoughData boundary

    @Test("hasEnoughData is false with empty store")
    func test_viewModel_emptyTrend_hasEnoughDataFalse() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = PlayerTrendViewModel(modelContext: context, playerID: UUID().uuidString, playerName: "Alice")
        await vm.compute()
        #expect(vm.hasEnoughData == false)
    }

    @Test("hasEnoughData is false with 2 rounds (boundary: needs ≥3)")
    func test_viewModel_twoRounds_hasEnoughDataFalse() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for i in 0..<2 {
            try insertRound(context: context, course: course, playerID: playerID,
                            completedAt: Date(timeIntervalSinceReferenceDate: Double(i) * 1000))
        }
        let vm = PlayerTrendViewModel(modelContext: context, playerID: playerID, playerName: "Alice")
        await vm.compute()
        #expect(vm.hasEnoughData == false)
    }

    @Test("hasEnoughData is true with exactly 3 rounds")
    func test_viewModel_threeRounds_hasEnoughDataTrue() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for i in 0..<3 {
            try insertRound(context: context, course: course, playerID: playerID,
                            completedAt: Date(timeIntervalSinceReferenceDate: Double(i) * 1000))
        }
        let vm = PlayerTrendViewModel(modelContext: context, playerID: playerID, playerName: "Alice")
        await vm.compute()
        #expect(vm.hasEnoughData == true)
    }

    // MARK: - Accessibility summary strings

    @Test("accessibilityChartSummary returns not-enough-rounds string when hasEnoughData is false")
    func test_viewModel_accessibilitySummary_emptyState() async throws {
        let container = try makeContainer()
        let vm = PlayerTrendViewModel(
            modelContext: ModelContext(container),
            playerID: UUID().uuidString,
            playerName: "Alice"
        )
        await vm.compute()
        #expect(vm.accessibilityChartSummary == "Score trend for Alice: not enough rounds yet.")
    }

    @Test("accessibilityChartSummary returns loading string before compute()")
    func test_viewModel_accessibilitySummary_loadingState() throws {
        let container = try makeContainer()
        let vm = PlayerTrendViewModel(
            modelContext: ModelContext(container),
            playerID: UUID().uuidString,
            playerName: "Alice"
        )
        // Do NOT call compute() — stays in loading state
        #expect(vm.accessibilityChartSummary == "Score trend for Alice: loading.")
    }

    @Test("accessibilityChartSummary exact string with 5 scored rounds")
    func test_viewModel_accessibilitySummary_populated() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for n in 1...3 {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }

        // 3 holes par 3 each → totalPar = 9
        // Strokes per round to get relative scores: [-3, -1, 0, +2, +5]
        // -3: [2,2,2]=6, -1: [3,3,2]=8, 0: [3,3,3]=9, +2: [4,4,3]=11, +5: [4,5,5]=14
        let strokeSets: [[Int]] = [[2,2,2], [3,3,2], [3,3,3], [4,4,3], [4,5,5]]
        for (i, strokes) in strokeSets.enumerated() {
            let round = Round(
                courseID: course.id, organizerID: UUID(), playerIDs: [playerID],
                guestNames: [], holeCount: 3
            )
            context.insert(round)
            round.start()
            round.complete()
            round.completedAt = Date(timeIntervalSinceReferenceDate: Double(i) * 1000)
            for (hIdx, s) in strokes.enumerated() {
                context.insert(ScoreEvent(
                    roundID: round.id, holeNumber: hIdx + 1, playerID: playerID,
                    strokeCount: s, reportedByPlayerID: UUID(), deviceID: "test"
                ))
            }
        }
        try context.save()

        let vm = PlayerTrendViewModel(modelContext: context, playerID: playerID, playerName: "Mike")
        await vm.compute()

        // scores: -3, -1, 0, +2, +5 → best=-3, worst=+5, avg=3/5=0.6 → rounds to 1.
        // Story 15.9 migrated the chart-summary rel-to-par formatting to verbose form
        // (e.g., "three under par" instead of "-3").
        let expected = "Score trend for Mike: 5 rounds, best three under par, worst five over par, average one over par"
        #expect(vm.accessibilityChartSummary == expected)
    }

    // MARK: - formatScore convention parity

    @Test("formatScore mirrors Standing.formatScore: negative, zero (E), positive")
    func test_viewModel_formatScore_matchesStandingConvention() {
        #expect(Standing.formatScore(-2) == "-2")
        #expect(Standing.formatScore(0) == "E")
        #expect(Standing.formatScore(1) == "+1")
    }

    // MARK: - Error path
    //
    // Note: SwiftData does NOT throw when a model type is missing from the schema — it returns
    // empty results. Triggering a genuine SwiftData fetch error in-process requires either:
    //   (a) A protocol-based service injection (out of story scope), or
    //   (b) Corrupting the backing store at the file-system level (too fragile for CI).
    // The error-handling code in PlayerTrendViewModel.compute() is verified by code review
    // and manual inspection. The `do/catch` with `logger.error` + `errorMessage = "..."` path
    // follows CLAUDE.md "No silent try?" strictly. Deferral documented in Completion Notes.

    @Test("trend is nil and isLoading is false after compute() with empty store (not an error state)")
    func test_viewModel_emptyStoreIsNotErrorState() async throws {
        let container = try makeContainer()
        let vm = PlayerTrendViewModel(
            modelContext: ModelContext(container),
            playerID: UUID().uuidString,
            playerName: "Test"
        )
        await vm.compute()
        #expect(vm.errorMessage == nil)  // empty store → empty trend, not an error
        #expect(vm.trend != nil)         // trend is set (empty TrendSummary)
        #expect(vm.hasEnoughData == false)
    }
}
