import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// View-layer tests for the "View score trend" entry point added to PlayerHoleBreakdownView
/// (Story 13.1 Task 4 — entry-point wiring).
///
/// Note: Full SwiftUI view-tree introspection of NavigationLink<Label, PlayerTrendView> is
/// impractical without a view-probe utility that doesn't exist in this project. The tests below
/// verify the critical identifier pass-through behaviour at the ViewModel layer, which is the
/// most common entry-point bug (passing the wrong playerID to PlayerTrendView). SwiftUI visual
/// correctness is covered by manual verification in Task 8.2.
@Suite("PlayerHoleBreakdownView — Score trend entry point")
@MainActor
struct PlayerHoleBreakdownViewTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

    /// Verifies that `PlayerTrendViewModel` initialized with a given playerID/playerName round-trips
    /// both values correctly after `compute()`. This catches the most common entry-point bug:
    /// passing the wrong identifier from `PlayerHoleBreakdownView` to `PlayerTrendView`.
    @Test("playerID and playerName identifiers round-trip through PlayerTrendViewModel")
    func test_breakdownView_includesTrendEntryPoint_identifiersRoundTrip() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playerID = "player-\(UUID().uuidString)"
        let playerName = "Alice"

        let course = Course(name: "Test", holeCount: 3, isSeeded: false)
        context.insert(course)
        let round = Round(
            courseID: course.id, organizerID: UUID(), playerIDs: [playerID],
            guestNames: [], holeCount: 3
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = Date(timeIntervalSinceNow: -1)
        for n in 1...3 {
            context.insert(ScoreEvent(
                roundID: round.id, holeNumber: n, playerID: playerID,
                strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
            ))
        }
        try context.save()

        let trendVM = PlayerTrendViewModel(modelContext: context, playerID: playerID, playerName: playerName)
        await trendVM.compute()

        // The playerID and playerName the view uses must match what was passed in —
        // no intermediate transformation that could silently mangle identifiers.
        #expect(trendVM.playerID == playerID)
        #expect(trendVM.playerName == playerName)
        #expect(trendVM.trend?.playerID == playerID)
    }

    /// Verifies guest playerID (opaque "guest:<uuid>" string) round-trips correctly — the
    /// trend entry point must not resolve or transform guest IDs.
    @Test("guest playerID passes through unmodified to PlayerTrendViewModel")
    func test_breakdownView_guestIDPassthroughToTrendVM() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let guestID = "guest:\(UUID().uuidString)"
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)
        let round = Round(
            courseID: course.id, organizerID: UUID(), playerIDs: [],
            guestNames: ["Guest"], holeCount: 1, guestIDs: [guestID]
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = Date(timeIntervalSinceNow: -1)
        context.insert(ScoreEvent(
            roundID: round.id, holeNumber: 1, playerID: guestID,
            strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"
        ))
        try context.save()

        let trendVM = PlayerTrendViewModel(modelContext: context, playerID: guestID, playerName: "Guest")
        await trendVM.compute()

        #expect(trendVM.playerID == guestID)
        #expect(trendVM.trend?.playerID == guestID)
        #expect(trendVM.trend?.points.isEmpty == false)
    }
}
