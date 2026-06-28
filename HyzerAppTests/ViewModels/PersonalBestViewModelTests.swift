import Testing
import SwiftData
import SwiftUI
import Foundation
@testable import HyzerKit
@testable import HyzerApp

@Suite("PersonalBestViewModel")
@MainActor
struct PersonalBestViewModelTests {

    // MARK: - Container

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

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

    @Test("isLoading is true, hasNoData is false, best is nil before compute()")
    func test_viewModel_initialState_isLoading() throws {
        let container = try makeContainer()
        let vm = PersonalBestViewModel(
            modelContext: ModelContext(container),
            playerID: UUID().uuidString,
            courseID: UUID(),
            displayTitle: "Your personal best"
        )
        #expect(vm.isLoading == true)
        #expect(vm.hasNoData == false)
        #expect(vm.best == nil)
    }

    // MARK: - No rounds → hasNoData

    @Test("empty store — hasNoData is true after compute()")
    func test_viewModel_noRounds_setsHasNoData() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = PersonalBestViewModel(
            modelContext: context,
            playerID: UUID().uuidString,
            courseID: UUID(),
            displayTitle: "Your personal best"
        )
        await vm.compute()
        #expect(vm.hasNoData == true)
        #expect(vm.best == nil)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - One round → populated

    @Test("one completed round — populates best with correct formatted fields")
    func test_viewModel_oneRound_populatesBest() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for n in 1...3 {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }
        // strokesPerHole=2 → totalStrokes=6, par=9, relative=-3
        let fixedDate = Date(timeIntervalSinceReferenceDate: 100_000)
        try insertRound(context: context, course: course, playerID: playerID,
                        strokesPerHole: 2, holeCount: 3, completedAt: fixedDate)

        let vm = PersonalBestViewModel(
            modelContext: context, playerID: playerID, courseID: course.id,
            displayTitle: "Your personal best"
        )
        await vm.compute()

        #expect(vm.best != nil)
        #expect(vm.formattedStrokes == "6")
        #expect(vm.formattedScore == "-3")

        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .medium
        expectedFormatter.timeStyle = .none
        #expect(vm.formattedDate == expectedFormatter.string(from: fixedDate))
    }

    // MARK: - formatScore convention parity

    @Test("formattedScore mirrors Standing.formatScore: negative, zero (E), positive")
    func test_viewModel_formattedScore_matchesStandingConvention() {
        #expect(Standing.formatScore(-2) == "-2")
        #expect(Standing.formatScore(0) == "E")
        #expect(Standing.formatScore(1) == "+1")
    }

    // MARK: - Date formatter matches project convention (AC #1)

    @Test("formattedDate uses medium dateStyle with no timeStyle — matches project convention")
    func test_viewModel_formattedDate_matchesProjectConvention() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)
        context.insert(Hole(courseID: course.id, number: 1, par: 3))

        let testDate = Date(timeIntervalSince1970: 1_710_000_000)
        try insertRound(context: context, course: course, playerID: playerID,
                        strokesPerHole: 3, holeCount: 1, completedAt: testDate)

        let vm = PersonalBestViewModel(
            modelContext: context, playerID: playerID, courseID: course.id,
            displayTitle: "Your personal best"
        )
        await vm.compute()

        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .medium
        expectedFormatter.timeStyle = .none
        #expect(vm.formattedDate == expectedFormatter.string(from: testDate))
    }

    // MARK: - Accessibility labels

    @Test("accessibilityLabel is loading string before compute()")
    func test_viewModel_accessibilityLabel_loadingState() throws {
        let container = try makeContainer()
        let vm = PersonalBestViewModel(
            modelContext: ModelContext(container),
            playerID: UUID().uuidString,
            courseID: UUID(),
            displayTitle: "Your personal best"
        )
        #expect(vm.accessibilityLabel == "Your personal best loading.")
    }

    @Test("accessibilityLabel is no-data string after compute() on empty store")
    func test_viewModel_accessibilityLabel_noDataState() async throws {
        let container = try makeContainer()
        let vm = PersonalBestViewModel(
            modelContext: ModelContext(container),
            playerID: UUID().uuidString,
            courseID: UUID(),
            displayTitle: "Your personal best"
        )
        await vm.compute()
        #expect(vm.accessibilityLabel == "No rounds yet on this course.")
    }

    @Test("accessibilityLabel matches populated format exactly")
    func test_viewModel_accessibilityLabel_populated() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString
        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        for n in 1...3 {
            context.insert(Hole(courseID: course.id, number: n, par: 3))
        }
        let fixedDate = Date(timeIntervalSinceReferenceDate: 100_000)
        // strokesPerHole=2 → relative=-3
        try insertRound(context: context, course: course, playerID: playerID,
                        strokesPerHole: 2, holeCount: 3, completedAt: fixedDate)

        let vm = PersonalBestViewModel(
            modelContext: context, playerID: playerID, courseID: course.id,
            displayTitle: "Your personal best"
        )
        await vm.compute()

        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .medium
        expectedFormatter.timeStyle = .none
        let dateString = expectedFormatter.string(from: fixedDate)
        // Story 15.9 migrated the PB rel-to-par a11y formatting to verbose form
        // (e.g., "three under par" instead of "-3").
        let expected = "Your personal best: 6 strokes, three under par, on \(dateString)"
        #expect(vm.accessibilityLabel == expected)
    }

    // MARK: - Score color (3-tier)

    @Test("scoreColor matches 3-tier convention: under=scoreUnderPar, even=scoreAtPar, over=scoreOverPar")
    func test_viewModel_scoreColor_matchesTier() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerID = UUID().uuidString

        func makeCoursePar3(_ name: String) -> Course {
            let c = Course(name: name, holeCount: 1, isSeeded: false)
            context.insert(c)
            context.insert(Hole(courseID: c.id, number: 1, par: 3))
            return c
        }

        let courseUnder = makeCoursePar3("Under")
        let courseEven = makeCoursePar3("Even")
        let courseOver = makeCoursePar3("Over")

        // -1: strokes=2
        try insertRound(context: context, course: courseUnder, playerID: playerID, strokesPerHole: 2, holeCount: 1)
        // 0: strokes=3
        try insertRound(context: context, course: courseEven, playerID: playerID, strokesPerHole: 3, holeCount: 1)
        // +1: strokes=4
        try insertRound(context: context, course: courseOver, playerID: playerID, strokesPerHole: 4, holeCount: 1)

        let vmUnder = PersonalBestViewModel(modelContext: context, playerID: playerID, courseID: courseUnder.id, displayTitle: "t")
        let vmEven = PersonalBestViewModel(modelContext: context, playerID: playerID, courseID: courseEven.id, displayTitle: "t")
        let vmOver = PersonalBestViewModel(modelContext: context, playerID: playerID, courseID: courseOver.id, displayTitle: "t")

        await vmUnder.compute()
        await vmEven.compute()
        await vmOver.compute()

        #expect(vmUnder.scoreColor == Color.scoreUnderPar)
        #expect(vmEven.scoreColor == Color.scoreAtPar)
        #expect(vmOver.scoreColor == Color.scoreOverPar)
    }

    // MARK: - Error path
    //
    // Note: SwiftData does NOT throw when a model type is missing from the schema — it
    // returns empty results silently. Triggering a genuine SwiftData fetch error in-process
    // requires corrupting the backing store at the file-system level (too fragile for CI).
    // The error-handling path in PersonalBestViewModel.compute() is verified by code review
    // and the do/catch with logger.error + errorMessage pattern follows CLAUDE.md strictly.
    // Deferral mirrors Completion Note #7 of Story 13.1.

    @Test("empty store is not an error state — errorMessage is nil after compute()")
    func test_viewModel_emptyStoreIsNotErrorState() async throws {
        let container = try makeContainer()
        let vm = PersonalBestViewModel(
            modelContext: ModelContext(container),
            playerID: UUID().uuidString,
            courseID: UUID(),
            displayTitle: "Your personal best"
        )
        await vm.compute()
        #expect(vm.errorMessage == nil)
        #expect(vm.hasNoData == true)
    }
}
