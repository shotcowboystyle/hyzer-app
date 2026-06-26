import Testing
import SwiftData
import Foundation
@testable import HyzerKit
import TestSupport

/// Story 15.11 — Journey 1 (kit half): full-round domain mechanics.
///
/// Exercises the event-sourcing pipeline end-to-end without any HyzerApp layer:
/// ScoringService → ScoreEvent persistence → RoundLifecycleManager.checkCompletion
/// → StandingsEngine.recompute → RoundLifecycleManager.finalizeRound.
///
/// Runs via `swift test --package-path HyzerKit` — no iOS Simulator required.
@Suite("Integration — Full Round Lifecycle (kit)")
@MainActor
struct FullRoundLifecycleKitTests {

    @Test("18 holes × 4 players, mixed scores: checkCompletion returns .nowAwaitingFinalization on event 72; standings sorted ascending")
    func test_fullRound_eighteenHolesFourPlayers_checkCompletionFlipsOnEvent72() throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 18, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let bob = try harness.seedPlayer(displayName: "Bob")
        let carol = try harness.seedPlayer(displayName: "Carol")
        let dave = try harness.seedPlayer(displayName: "Dave")
        let playerIDs = [alice, bob, carol, dave].map(\.id.uuidString)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: playerIDs,
            holeCount: 18
        )

        // Per-player stroke-per-hole (constant for simplicity, but differentiated across players):
        // Alice: par (3) → 54  | Bob: bogey (4) → 72  | Carol: birdie (2) → 36  | Dave: double (5) → 90
        let perPlayerScore: [String: Int] = [
            alice.id.uuidString: 3,
            bob.id.uuidString: 4,
            carol.id.uuidString: 2,
            dave.id.uuidString: 5
        ]

        var eventCount = 0
        for hole in 1...18 {
            for pid in playerIDs {
                _ = try harness.scoringService.createScoreEvent(
                    roundID: round.id,
                    holeNumber: hole,
                    playerID: pid,
                    strokeCount: perPlayerScore[pid]!,
                    reportedByPlayerID: alice.id
                )
                eventCount += 1

                let result = try harness.roundLifecycleManager.checkCompletion(roundID: round.id)
                if eventCount < 18 * 4 {
                    // Until the final event, we should be incomplete.
                    if case .incomplete = result {
                        // ok
                    } else {
                        Issue.record("checkCompletion returned .nowAwaitingFinalization before event 72 (event #\(eventCount))")
                    }
                } else {
                    // Event 72: the final score arrives — transition fires.
                    #expect(
                        isNowAwaitingFinalization(result),
                        "event 72 (the final score) must flip checkCompletion to .nowAwaitingFinalization"
                    )
                }
            }
        }

        // Round was transitioned to awaitingFinalization by checkCompletion.
        let refreshed = try #require(fetchRound(id: round.id, in: harness.container.mainContext))
        #expect(refreshed.status == RoundStatus.awaitingFinalization)

        // Standings: ascending by totalStrokes — Carol (36) → Alice (54) → Bob (72) → Dave (90).
        harness.standingsEngine.recompute(for: round.id, trigger: .localScore)
        let standings = harness.standingsEngine.currentStandings
        #expect(standings.count == 4)
        #expect(standings.map(\.playerID) == [
            carol.id.uuidString,
            alice.id.uuidString,
            bob.id.uuidString,
            dave.id.uuidString
        ])
        #expect(standings.map(\.totalStrokes) == [36, 54, 72, 90])
        #expect(standings.map(\.position) == [1, 2, 3, 4])
    }

    @Test("finalizeRound transitions Round.status from awaitingFinalization → completed and sets completedAt")
    func test_finalizeRound_transitionsToCompletedAndSetsCompletedAt() throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        for hole in 1...3 {
            _ = try harness.scoringService.createScoreEvent(
                roundID: round.id,
                holeNumber: hole,
                playerID: alice.id.uuidString,
                strokeCount: 3,
                reportedByPlayerID: alice.id
            )
        }
        // Flip to awaitingFinalization.
        let preFinalize = try harness.roundLifecycleManager.checkCompletion(roundID: round.id)
        #expect(isNowAwaitingFinalization(preFinalize))

        let beforeFinalize = Date()
        try harness.roundLifecycleManager.finalizeRound(roundID: round.id)
        let afterFinalize = Date()

        let refreshed = try #require(fetchRound(id: round.id, in: harness.container.mainContext))
        #expect(refreshed.status == RoundStatus.completed)
        let completedAt = try #require(refreshed.completedAt)
        #expect(completedAt >= beforeFinalize && completedAt <= afterFinalize,
                "completedAt must be set during finalizeRound — got \(completedAt)")
    }

    @Test("finalizeRound on non-awaitingFinalization round throws invalidStateForTransition")
    func test_finalizeRound_onActiveRound_throwsInvalidState() throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        // Active (no checkCompletion yet) — finalize should refuse.
        #expect(throws: RoundLifecycleError.self) {
            try harness.roundLifecycleManager.finalizeRound(roundID: round.id)
        }
    }

    @Test("StandingsEngine.recompute returns trigger = .localScore when invoked by per-entry pipeline")
    func test_standingsRecompute_localScoreTrigger() throws {
        let harness = try IntegrationKitHarness.make()
        let course = try harness.seedCourse(holeCount: 1, parPerHole: 3)
        let alice = try harness.seedPlayer(displayName: "Alice")
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 1
        )

        _ = try harness.scoringService.createScoreEvent(
            roundID: round.id,
            holeNumber: 1,
            playerID: alice.id.uuidString,
            strokeCount: 3,
            reportedByPlayerID: alice.id
        )
        let change = harness.standingsEngine.recompute(for: round.id, trigger: .localScore)

        if case .localScore = change.trigger {
            // ok — exact case match
        } else {
            Issue.record("recompute should return the trigger it was passed; got \(change.trigger)")
        }
        #expect(change.newStandings.count == 1)
        #expect(change.newStandings.first?.totalStrokes == 3)
    }

    // MARK: - Local helpers

    private func isNowAwaitingFinalization(_ result: CompletionCheckResult) -> Bool {
        if case .nowAwaitingFinalization = result { return true }
        return false
    }

    private func fetchRound(id: UUID, in context: ModelContext) -> Round? {
        let idLocal = id
        var descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == idLocal })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
