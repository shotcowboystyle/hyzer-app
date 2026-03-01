import Testing
import SwiftData
import Foundation
import SwiftUI
@testable import HyzerKit
@testable import HyzerApp

/// Tests for PlayerHoleBreakdownViewModel (Story 8.2: Player Hole-by-Hole Breakdown).
@Suite("PlayerHoleBreakdownViewModel")
@MainActor
struct PlayerHoleBreakdownViewModelTests {

    // MARK: - Container setup

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

    // MARK: - Helpers

    private func makeCompletedRound(courseID: UUID, playerIDs: [String], guestNames: [String] = [], holeCount: Int = 9) -> Round {
        let round = Round(
            courseID: courseID,
            organizerID: UUID(),
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: holeCount
        )
        round.start()
        round.awaitFinalization()
        round.complete()
        return round
    }

    private func insertCourseWithHoles(
        context: ModelContext,
        name: String = "Test Course",
        holeCount: Int = 9,
        parPerHole: Int = 3
    ) -> (course: Course, holes: [Hole]) {
        let course = Course(name: name, holeCount: holeCount)
        context.insert(course)
        var holes: [Hole] = []
        for holeNum in 1...holeCount {
            let hole = Hole(courseID: course.id, number: holeNum, par: parPerHole)
            context.insert(hole)
            holes.append(hole)
        }
        return (course, holes)
    }

    // MARK: - Task 5.2: Single player breakdown — correct hole scores, totals, overall

    @Test("computeBreakdown produces correct hole scores for 3-hole round")
    func test_computeBreakdown_singlePlayer_correctHoleScores() throws {
        // Given: 3-hole round with known strokes per hole
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, name: "Cedar Creek", holeCount: 3, parPerHole: 4)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID], holeCount: 3)
        context.insert(round)

        // Par 4 holes — Hole 1: birdie (3), Hole 2: par (4), Hole 3: bogey (5)
        let strokesByHole = [1: 3, 2: 4, 3: 5]
        for (holeNum, strokes) in strokesByHole {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerID, strokeCount: strokes,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        // When
        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Alice"
        )
        vm.computeBreakdown()

        // Then: 3 hole scores, sorted by hole number, with correct par and strokes
        #expect(vm.holeScores.count == 3)
        #expect(vm.holeScores[0].holeNumber == 1)
        #expect(vm.holeScores[0].par == 4)
        #expect(vm.holeScores[0].strokeCount == 3)
        #expect(vm.holeScores[1].holeNumber == 2)
        #expect(vm.holeScores[1].par == 4)
        #expect(vm.holeScores[1].strokeCount == 4)
        #expect(vm.holeScores[2].holeNumber == 3)
        #expect(vm.holeScores[2].par == 4)
        #expect(vm.holeScores[2].strokeCount == 5)
    }

    @Test("computeBreakdown produces correct totals")
    func test_computeBreakdown_singlePlayer_correctTotals() throws {
        // Given: 9-hole round, 3 strokes each, par 3
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 9, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID])
        context.insert(round)

        for holeNum in 1...9 {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerID, strokeCount: 3,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        // When
        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Bob"
        )
        vm.computeBreakdown()

        // Then: 27 total strokes, 27 par, even
        #expect(vm.totalStrokes == 27)
        #expect(vm.totalPar == 27)
        #expect(vm.overallRelativeToPar == 0)
        #expect(vm.overallFormattedScore == "E")
    }

    @Test("computeBreakdown summary totals match sum of individual hole scores")
    func test_computeBreakdown_summaryTotals_matchHoleScoreSum() throws {
        // Given: varied strokes per hole
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 9, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID])
        context.insert(round)

        let strokes = [2, 3, 4, 3, 2, 5, 3, 4, 3] // sum = 29
        for (index, holeNum) in (1...9).enumerated() {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerID, strokeCount: strokes[index],
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Charlie"
        )
        vm.computeBreakdown()

        // When: summing hole scores manually
        let summedStrokes = vm.holeScores.reduce(0) { $0 + $1.strokeCount }
        let summedPar = vm.holeScores.reduce(0) { $0 + $1.par }

        // Then: totals match
        #expect(vm.totalStrokes == summedStrokes)
        #expect(vm.totalPar == summedPar)
        #expect(vm.overallRelativeToPar == summedStrokes - summedPar)
    }

    @Test("computeBreakdown with corrected score uses leaf ScoreEvent")
    func test_computeBreakdown_correctedScore_usesLeafNode() throws {
        // Given: player has an original score and a correction (supersedesEventID)
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 1, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID], holeCount: 1)
        context.insert(round)

        let original = ScoreEvent(
            roundID: round.id, holeNumber: 1,
            playerID: playerID, strokeCount: 5,
            reportedByPlayerID: UUID(), deviceID: "test"
        )
        context.insert(original)
        try context.save()

        let correction = ScoreEvent(
            roundID: round.id, holeNumber: 1,
            playerID: playerID, strokeCount: 3,
            reportedByPlayerID: UUID(), deviceID: "test"
        )
        correction.supersedesEventID = original.id
        context.insert(correction)
        try context.save()

        // When
        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Dave"
        )
        vm.computeBreakdown()

        // Then: uses leaf (correction = 3 strokes), not original (5 strokes)
        #expect(vm.holeScores.count == 1)
        #expect(vm.holeScores[0].strokeCount == 3)
        #expect(vm.totalStrokes == 3)
    }

    @Test("computeBreakdown works for guest players")
    func test_computeBreakdown_guestPlayer_worksIdentically() throws {
        // Given: a round with a guest player
        let container = try makeContainer()
        let context = ModelContext(container)

        let guestName = "Eve"
        let guestPlayerID = "guest:\(guestName)"

        let (course, _) = insertCourseWithHoles(context: context, holeCount: 3, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [], guestNames: [guestName], holeCount: 3)
        context.insert(round)

        for holeNum in 1...3 {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: guestPlayerID, strokeCount: 4,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        // When
        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: guestPlayerID, playerName: guestName
        )
        vm.computeBreakdown()

        // Then: guest data resolved identically to registered players
        #expect(vm.holeScores.count == 3)
        #expect(vm.totalStrokes == 12)
        #expect(vm.totalPar == 9)
        #expect(vm.overallRelativeToPar == 3)
        #expect(vm.overallFormattedScore == "+3")
    }

    @Test("computeBreakdown returns holes sorted ascending by hole number")
    func test_computeBreakdown_holesSortedAscending() throws {
        // Given: events inserted out of order
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 5, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID], holeCount: 5)
        context.insert(round)

        // Insert in reverse order
        for holeNum in stride(from: 5, through: 1, by: -1) {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerID, strokeCount: holeNum, // strokeCount == holeNum for easy verification
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        // When
        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Frank"
        )
        vm.computeBreakdown()

        // Then: sorted 1,2,3,4,5 regardless of insertion order
        #expect(vm.holeScores.map(\.holeNumber) == [1, 2, 3, 4, 5])
        #expect(vm.holeScores.map(\.strokeCount) == [1, 2, 3, 4, 5])
    }

    @Test("computeBreakdown overall score color uses 3-tier (under/at/over) for aggregate")
    func test_computeBreakdown_overallScoreColor_underParIsGreen() throws {
        // Given: all birdies → under par overall
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 3, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID], holeCount: 3)
        context.insert(round)

        for holeNum in 1...3 {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerID, strokeCount: 2,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Grace"
        )
        vm.computeBreakdown()

        #expect(vm.overallScoreColor == Color.scoreUnderPar)
    }

    @Test("computeBreakdown overall score color is scoreAtPar when even")
    func test_computeBreakdown_overallScoreColor_atPar_isScoreAtPar() throws {
        // Given: all pars → even overall
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 3, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID], holeCount: 3)
        context.insert(round)

        for holeNum in 1...3 {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerID, strokeCount: 3,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Ivy"
        )
        vm.computeBreakdown()

        #expect(vm.overallScoreColor == Color.scoreAtPar)
    }

    @Test("computeBreakdown overall score color is scoreOverPar when over par")
    func test_computeBreakdown_overallScoreColor_overPar_isScoreOverPar() throws {
        // Given: all bogeys → over par overall
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 3, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID], holeCount: 3)
        context.insert(round)

        for holeNum in 1...3 {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: holeNum,
                playerID: playerID, strokeCount: 4,
                reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Jake"
        )
        vm.computeBreakdown()

        #expect(vm.overallScoreColor == Color.scoreOverPar)
    }

    @Test("computeBreakdown individual hole uses 4-tier scoreColor including scoreWayOver")
    func test_computeBreakdown_individualHole_doubleBogeyIsWayOver() throws {
        // Given: one hole with double bogey
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = UUID().uuidString
        let (course, _) = insertCourseWithHoles(context: context, holeCount: 1, parPerHole: 3)
        let round = makeCompletedRound(courseID: course.id, playerIDs: [playerID], holeCount: 1)
        context.insert(round)

        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1,
            playerID: playerID, strokeCount: 5, // par 3, double bogey
            reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let vm = PlayerHoleBreakdownViewModel(
            modelContext: context, roundID: round.id,
            playerID: playerID, playerName: "Hank"
        )
        vm.computeBreakdown()

        #expect(vm.holeScores.count == 1)
        #expect(vm.holeScores[0].scoreColor == Color.scoreWayOver)
    }
}
