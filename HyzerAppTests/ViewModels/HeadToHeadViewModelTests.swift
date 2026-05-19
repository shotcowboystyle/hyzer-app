import Testing
import SwiftData
import SwiftUI
import Foundation
@testable import HyzerKit
@testable import HyzerApp

// MARK: - HeadToHeadViewModel Tests

@Suite("HeadToHeadViewModel")
@MainActor
struct HeadToHeadViewModelTests {

    // MARK: - Container

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

    /// Inserts a completed round with per-hole strokes for two players (all holes par 3 via fallback).
    @discardableResult
    private func insertRound(
        context: ModelContext,
        course: Course,
        playerAID: String,
        playerBID: String,
        strokesA: [Int],
        strokesB: [Int],
        completedAt: Date = Date(timeIntervalSinceNow: -1)
    ) throws -> Round {
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerAID, playerBID],
            guestNames: [],
            holeCount: strokesA.count
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = completedAt
        for (i, s) in strokesA.enumerated() {
            context.insert(ScoreEvent(roundID: round.id, holeNumber: i + 1, playerID: playerAID,
                                      strokeCount: s, reportedByPlayerID: UUID(), deviceID: "test"))
        }
        for (i, s) in strokesB.enumerated() {
            context.insert(ScoreEvent(roundID: round.id, holeNumber: i + 1, playerID: playerBID,
                                      strokeCount: s, reportedByPlayerID: UUID(), deviceID: "test"))
        }
        try context.save()
        return round
    }

    // MARK: - Initial state

    @Test("isLoading true, hasData false, hasNoData false before compute()")
    func test_viewModel_initialState_isLoading() throws {
        let container = try makeContainer()
        let vm = HeadToHeadViewModel(
            modelContext: ModelContext(container),
            playerAID: UUID().uuidString, playerAName: "Alice",
            playerBID: UUID().uuidString, playerBName: "Bob"
        )
        #expect(vm.isLoading == true)
        #expect(vm.hasData == false)
        #expect(vm.hasNoData == false)
    }

    // MARK: - Empty / no shared rounds

    @Test("empty store → hasNoData true after compute()")
    func test_viewModel_noSharedRounds_setsHasNoData() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = HeadToHeadViewModel(
            modelContext: context,
            playerAID: UUID().uuidString, playerAName: "Alice",
            playerBID: UUID().uuidString, playerBName: "Bob"
        )
        await vm.compute()

        #expect(vm.hasNoData == true)
        #expect(vm.hasData == false)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Populated state (AC #1)

    @Test("one shared round where A wins by 2 — populates all formatted properties correctly")
    func test_viewModel_oneSharedRound_populates() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // A=[3,3] (relToPar=0), B=[4,4] (relToPar=2) → A wins, diff=-2
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [4, 4])

        let vm = HeadToHeadViewModel(
            modelContext: context,
            playerAID: playerA, playerAName: "Alice",
            playerBID: playerB, playerBName: "Bob"
        )
        await vm.compute()

        #expect(vm.hasData == true)
        #expect(vm.roundsPlayedFormatted == "1 round")
        #expect(vm.winsAFormatted == "1")
        #expect(vm.winsBFormatted == "0")
        #expect(vm.winsAPercentFormatted == "100%")
        #expect(vm.winsBPercentFormatted == "0%")
        #expect(vm.averageDifferentialFormatted == "-2")
    }

    // MARK: - Singular/plural copy

    @Test("roundsPlayedFormatted uses singular '1 round' and plural '<n> rounds'")
    func test_viewModel_roundsPlayedFormatted_singularVsPlural() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // One round → "1 round"
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3], strokesB: [3],
                        completedAt: Date(timeIntervalSinceReferenceDate: 1000))

        let vm1 = HeadToHeadViewModel(
            modelContext: context,
            playerAID: playerA, playerAName: "Alice",
            playerBID: playerB, playerBName: "Bob"
        )
        await vm1.compute()
        #expect(vm1.roundsPlayedFormatted == "1 round")

        // Two rounds → "2 rounds"
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3], strokesB: [3],
                        completedAt: Date(timeIntervalSinceReferenceDate: 2000))

        let vm2 = HeadToHeadViewModel(
            modelContext: context,
            playerAID: playerA, playerAName: "Alice",
            playerBID: playerB, playerBName: "Bob"
        )
        await vm2.compute()
        #expect(vm2.roundsPlayedFormatted == "2 rounds")
    }

    // MARK: - Percent edge case

    @Test("percentString with zero denominator returns nil — guard prevents division by zero")
    func test_viewModel_percentString_zeroDenominator_returnsNil() throws {
        let container = try makeContainer()
        let vm = HeadToHeadViewModel(
            modelContext: ModelContext(container),
            playerAID: UUID().uuidString, playerAName: "Alice",
            playerBID: UUID().uuidString, playerBName: "Bob"
        )
        // Before compute, record is nil → denominator is nil → percent returns nil
        #expect(vm.winsAPercentFormatted == nil)
        #expect(vm.winsBPercentFormatted == nil)
    }

    // MARK: - Standing.formatScore convention pin (AC #1)

    @Test("averageDifferentialFormatted follows Standing.formatScore: -2, E, +1")
    func test_viewModel_averageDifferentialFormatted_matchesStandingConvention() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // Under par differential
        let pA1 = UUID().uuidString
        let pB1 = UUID().uuidString
        try insertRound(context: context, course: course, playerAID: pA1, playerBID: pB1,
                        strokesA: [3, 3], strokesB: [4, 4])  // diff = -2
        let vmUnder = HeadToHeadViewModel(
            modelContext: context, playerAID: pA1, playerAName: "A", playerBID: pB1, playerBName: "B"
        )
        await vmUnder.compute()
        #expect(vmUnder.averageDifferentialFormatted == "-2")

        // Even differential
        let pA2 = UUID().uuidString
        let pB2 = UUID().uuidString
        try insertRound(context: context, course: course, playerAID: pA2, playerBID: pB2,
                        strokesA: [3, 3], strokesB: [3, 3])  // diff = 0
        let vmEven = HeadToHeadViewModel(
            modelContext: context, playerAID: pA2, playerAName: "A", playerBID: pB2, playerBName: "B"
        )
        await vmEven.compute()
        #expect(vmEven.averageDifferentialFormatted == "E")

        // Over par differential
        let pA3 = UUID().uuidString
        let pB3 = UUID().uuidString
        try insertRound(context: context, course: course, playerAID: pA3, playerBID: pB3,
                        strokesA: [4, 3], strokesB: [3, 3])  // A: relToPar=1, B: relToPar=0 → diff=+1
        let vmOver = HeadToHeadViewModel(
            modelContext: context, playerAID: pA3, playerAName: "A", playerBID: pB3, playerBName: "B"
        )
        await vmOver.compute()
        #expect(vmOver.averageDifferentialFormatted == "+1")
    }

    // MARK: - Accessibility (AC #9)

    @Test("accessibilityLabel returns loading string before compute()")
    func test_viewModel_accessibilityLabel_loadingState() throws {
        let container = try makeContainer()
        let vm = HeadToHeadViewModel(
            modelContext: ModelContext(container),
            playerAID: UUID().uuidString, playerAName: "Alice",
            playerBID: UUID().uuidString, playerBName: "Bob"
        )
        #expect(vm.accessibilityLabel == "Head-to-head loading.")
    }

    @Test("accessibilityLabel empty state matches AC #3 copy verbatim (AC #3 + AC #9)")
    func test_viewModel_accessibilityLabel_emptyState() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = HeadToHeadViewModel(
            modelContext: context,
            playerAID: UUID().uuidString, playerAName: "Alice",
            playerBID: UUID().uuidString, playerBName: "Bob"
        )
        await vm.compute()

        #expect(vm.accessibilityLabel == "Alice and Bob haven't played a round together yet.")
    }

    @Test("accessibilityLabel populated state matches full sentence (AC #9)")
    func test_viewModel_accessibilityLabel_populated() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // A=[3,3], B=[4,4] → 1 round, A wins 1, diff=-2
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [4, 4])

        let vm = HeadToHeadViewModel(
            modelContext: context,
            playerAID: playerA, playerAName: "Alice",
            playerBID: playerB, playerBName: "Bob"
        )
        await vm.compute()

        // AC #9: "Head-to-head, <A> versus <B>. <n> rounds played. <A> wins <winsA>, <pctA>. <B> wins <winsB>, <pctB>. Average differential <diff>."
        // Story 15.9 migrated rel-to-par formatting to verbose form (e.g., "two under par" instead of "-2").
        #expect(vm.accessibilityLabel == "Head-to-head, Alice versus Bob. 1 round played. Alice wins 1, 100%. Bob wins 0, 0%. Average differential two under par.")
    }

    // MARK: - Error path collapses to no-data (AC #8)
    //
    // SwiftData does not reliably throw on in-memory fetch failures, so per spec Task 7.2
    // the fallback is a stub `HeadToHeadServicing` that throws synchronously. This actually
    // exercises the `catch` branch in `compute()` (errorMessage assignment, hasComputed = true,
    // accessibility label matching empty state — UX-PMVP-DR5 reflective register).

    @Test("compute() catch path sets errorMessage, hasNoData, and empty-state accessibility label (AC #8)")
    func test_viewModel_serviceErrorPath_collapsesToNoData() async throws {
        let throwingService = ThrowingHeadToHeadServiceStub()
        let vm = HeadToHeadViewModel(
            service: throwingService,
            playerAID: UUID().uuidString, playerAName: "Alice",
            playerBID: UUID().uuidString, playerBName: "Bob"
        )
        await vm.compute()

        // Catch branch exercised: errorMessage is set AND hasNoData collapses to true.
        #expect(vm.errorMessage == "Unable to load head-to-head record.")
        #expect(vm.hasNoData == true)
        #expect(vm.hasData == false)
        // Accessibility label matches empty-state copy — sighted/VoiceOver coherence (AC #8).
        #expect(vm.accessibilityLabel == "Alice and Bob haven't played a round together yet.")
    }
}

// MARK: - Throwing Stub

/// Stub `HeadToHeadServicing` that throws synchronously on both methods.
/// Per Story 13.3 spec Task 7.2 fallback: SwiftData failure injection is unsupported
/// in-memory, so a protocol-backed stub is used to verify the `catch` branch in
/// `HeadToHeadViewModel.compute()` and `HeadToHeadOpponentPickerViewModel.loadCandidates()`.
@MainActor
private final class ThrowingHeadToHeadServiceStub: HeadToHeadServicing {
    enum StubError: Error { case forced }
    func computeRecord(for playerAID: String, against playerBID: String, maxRounds: Int) throws -> HeadToHeadRecord {
        throw StubError.forced
    }
    func findOpponentCandidates(for playerAID: String, maxRounds: Int) throws -> [HeadToHeadCandidate] {
        throw StubError.forced
    }
}

// MARK: - HeadToHeadOpponentPickerViewModel Tests

@Suite("HeadToHeadOpponentPickerViewModel")
@MainActor
struct HeadToHeadOpponentPickerViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

    @discardableResult
    private func insertRegisteredPlayer(context: ModelContext, displayName: String) throws -> String {
        let player = Player(displayName: displayName)
        context.insert(player)
        try context.save()
        return player.id.uuidString
    }

    @discardableResult
    private func insertRound(
        context: ModelContext,
        course: Course,
        playerAID: String,
        playerBID: String,
        completedAt: Date = Date(timeIntervalSinceNow: -1)
    ) throws -> Round {
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerAID, playerBID],
            guestNames: [],
            holeCount: 1
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = completedAt
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: playerAID,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: playerBID,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()
        return round
    }

    // MARK: - Initial state

    @Test("isLoading true, hasNoCandidates false before loadCandidates()")
    func test_pickerVM_initialState_isLoading() throws {
        let container = try makeContainer()
        let vm = HeadToHeadOpponentPickerViewModel(
            modelContext: ModelContext(container),
            playerAID: UUID().uuidString
        )
        #expect(vm.isLoading == true)
        #expect(vm.hasNoCandidates == false)
    }

    // MARK: - Empty store

    @Test("empty store → hasNoCandidates true after loadCandidates()")
    func test_pickerVM_emptyStore_setsHasNoCandidates() async throws {
        let container = try makeContainer()
        let vm = HeadToHeadOpponentPickerViewModel(
            modelContext: ModelContext(container),
            playerAID: UUID().uuidString
        )
        await vm.loadCandidates()

        #expect(vm.hasNoCandidates == true)
        #expect(vm.candidates.isEmpty)
    }

    // MARK: - Populated

    @Test("one shared round with registered opponent → candidate appears with correct count")
    func test_pickerVM_populatesCandidates() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        let playerB = try insertRegisteredPlayer(context: context, displayName: "Bob")
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB)

        let vm = HeadToHeadOpponentPickerViewModel(modelContext: context, playerAID: playerA)
        await vm.loadCandidates()

        #expect(vm.candidates.count == 1)
        #expect(vm.candidates[0].playerID == playerB)
        #expect(vm.candidates[0].roundsTogether == 1)
    }

    // MARK: - Guest exclusion (AC #5)

    @Test("guest playerIDs excluded from candidate list (AC #5)")
    func test_pickerVM_excludesGuests() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        let guestID = GuestIdentifier.makeID()
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        let guestRound = Round(courseID: course.id, organizerID: UUID(),
                               playerIDs: [playerA], guestNames: ["Guest"], holeCount: 1,
                               guestIDs: [guestID])
        context.insert(guestRound)
        guestRound.start()
        guestRound.complete()
        guestRound.completedAt = Date(timeIntervalSinceReferenceDate: 1000)
        context.insert(ScoreEvent(roundID: guestRound.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: guestRound.id, holeNumber: 1, playerID: guestID,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        let vm = HeadToHeadOpponentPickerViewModel(modelContext: context, playerAID: playerA)
        await vm.loadCandidates()

        #expect(vm.candidates.isEmpty)
    }

    // MARK: - roundsTogetherCopy (AC #5 singular/plural)

    @Test("roundsTogetherCopy returns singular for count == 1")
    func test_pickerVM_roundsTogetherCopy_singular() {
        #expect(HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(1) == "1 round together")
    }

    @Test("roundsTogetherCopy returns plural for count > 1")
    func test_pickerVM_roundsTogetherCopy_plural() {
        #expect(HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(2) == "2 rounds together")
        #expect(HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(7) == "7 rounds together")
    }
}
