import Testing
import SwiftData
import Foundation
import SwiftUI
@testable import HyzerKit
@testable import HyzerApp

/// Tests for PlayerHoleBreakdownViewModel score color logic (3-tier overall, 4-tier individual)
/// (Story 8.2: Player Hole-by-Hole Breakdown).
@Suite("PlayerHoleBreakdownViewModel — Colors")
@MainActor
struct PlayerHoleBreakdownColorTests {

    // MARK: - Container setup

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

    // MARK: - Score color tests

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
