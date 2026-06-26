import Testing
import SwiftData
import Foundation
@testable import HyzerApp
@testable import HyzerKit
import TestSupport

/// Story 15.11 — Journey 1 (app half): Onboarding → RoundSetup → 18-hole scoring
/// → finalize → summary, end-to-end through the real AppServices composition root.
@Suite("Integration — Full Round Lifecycle (app)")
@MainActor
struct FullRoundLifecycleTests {

    @Test("Onboarding.savePlayer → RoundSetup.startRound persists active Round and triggers CloudKit push")
    func test_onboardingThenRoundSetup_persistsRoundAndPushesViaSyncEngine() async throws {
        let harness = try IntegrationTestHarness.make(seedLocalPlayer: false)
        let context = harness.container.mainContext

        // Onboarding
        let onboarding = OnboardingViewModel()
        onboarding.displayName = "Alice"
        onboarding.savePlayer(in: context)
        let players = try context.fetch(FetchDescriptor<Player>())
        let alice = try #require(players.first)
        #expect(alice.displayName == "Alice")

        // Course needed for RoundSetup
        let course = try harness.seedCourse(name: "Test Course", holeCount: 18, parPerHole: 3)

        // RoundSetup
        let setup = RoundSetupViewModel()
        setup.selectedCourse = course
        #expect(setup.canStartRound)
        try setup.startRound(
            organizer: alice,
            in: context,
            syncEngine: harness.services.syncEngine
        )

        // The Round should now be active.
        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds.count == 1)
        let round = try #require(rounds.first)
        #expect(round.status == RoundStatus.active)
        #expect(round.playerIDs == [alice.id.uuidString])

        // startRound's CloudKit push is fire-and-forget on a background Task. Wait for it.
        try await waitUntil(
            { harness.cloudKit.saveCallCount > 0 },
            conditionDescription: "syncEngine.pushRound triggers a cloudKit.save"
        )
    }

    @Test("18-hole 2-player round: LeaderboardViewModel.currentStandings updates after every score")
    func test_eighteenHoleTwoPlayer_leaderboardUpdatesOnEveryScore() throws {
        let harness = try IntegrationTestHarness.make()
        let context = harness.container.mainContext
        let alice = try #require(harness.localPlayer)
        let bob = try harness.seedPlayer(displayName: "Bob")
        let course = try harness.seedCourse(holeCount: 18, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString, bob.id.uuidString],
            holeCount: 18
        )

        let scorecard = ScorecardViewModel(
            scoringService: harness.services.scoringService,
            lifecycleManager: harness.services.roundLifecycleManager,
            roundID: round.id,
            reportedByPlayerID: alice.id
        )
        let leaderboard = LeaderboardViewModel(
            standingsEngine: harness.services.standingsEngine,
            roundID: round.id,
            currentPlayerID: alice.id.uuidString
        )

        // Alice scores 3 (par), Bob scores 4 (bogey) on every hole — Alice stays #1.
        for hole in 1...18 {
            try scorecard.enterScore(
                playerID: alice.id.uuidString,
                holeNumber: hole,
                strokeCount: 3,
                isRoundFinished: false
            )
            leaderboard.handleScoreEntered()
            try scorecard.enterScore(
                playerID: bob.id.uuidString,
                holeNumber: hole,
                strokeCount: 4,
                isRoundFinished: false
            )
            leaderboard.handleScoreEntered()

            // After each pair of scores, both players should appear in standings
            // with Alice ranked first.
            #expect(leaderboard.currentStandings.count == 2)
            #expect(leaderboard.currentStandings[0].playerID == alice.id.uuidString)
        }

        // Final state: Alice 54 (E), Bob 72 (+18); 18 holes played each.
        let standings = leaderboard.currentStandings
        #expect(standings[0].totalStrokes == 54)
        #expect(standings[0].scoreRelativeToPar == 0)
        #expect(standings[1].totalStrokes == 72)
        #expect(standings[1].scoreRelativeToPar == 18)
    }

    @Test("LeaderboardViewModel.handleScoreEntered: positionChanges populated when ranks swap")
    func test_leaderboard_positionChanges_nonEmptyOnRankSwap() throws {
        let harness = try IntegrationTestHarness.make()
        let context = harness.container.mainContext
        let alice = try #require(harness.localPlayer)
        let bob = try harness.seedPlayer(displayName: "Bob")
        let course = try harness.seedCourse(holeCount: 18, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString, bob.id.uuidString],
            holeCount: 18
        )

        let scorecard = ScorecardViewModel(
            scoringService: harness.services.scoringService,
            lifecycleManager: harness.services.roundLifecycleManager,
            roundID: round.id,
            reportedByPlayerID: alice.id
        )
        let leaderboard = LeaderboardViewModel(
            standingsEngine: harness.services.standingsEngine,
            roundID: round.id,
            currentPlayerID: alice.id.uuidString
        )

        // Hole 1: Bob birdies (2 strokes), Alice bogeys (4 strokes). After: Bob #1, Alice #2.
        try scorecard.enterScore(playerID: bob.id.uuidString, holeNumber: 1, strokeCount: 2, isRoundFinished: false)
        leaderboard.handleScoreEntered()
        try scorecard.enterScore(playerID: alice.id.uuidString, holeNumber: 1, strokeCount: 4, isRoundFinished: false)
        leaderboard.handleScoreEntered()
        #expect(leaderboard.currentStandings[0].playerID == bob.id.uuidString,
                "after hole 1 only: Bob (2) leads Alice (4)")

        // Hole 2: Bob doubles (5 strokes), Alice birdies (2 strokes).
        // Cumulative — Bob 7 strokes / 2 holes (+1 to par 6), Alice 6 strokes / 2 holes (E).
        try scorecard.enterScore(playerID: bob.id.uuidString, holeNumber: 2, strokeCount: 5, isRoundFinished: false)
        leaderboard.handleScoreEntered()
        try scorecard.enterScore(playerID: alice.id.uuidString, holeNumber: 2, strokeCount: 2, isRoundFinished: false)
        leaderboard.handleScoreEntered()

        // After the swap, positionChanges must be populated for at least one of the
        // affected players (the recompute that produced the new #1/#2 ordering).
        #expect(!leaderboard.positionChanges.isEmpty,
                "rank swap between Alice and Bob must produce positionChanges entries")
        #expect(leaderboard.currentStandings[0].playerID == alice.id.uuidString,
                "after Alice's hole 2 birdie: Alice (6 strokes, E) leads Bob (7 strokes, +1)")
    }

    @Test("Final score flips isAwaitingFinalization → finalizeRound completes the round")
    func test_finalScore_flipsIsAwaitingFinalization_thenFinalize() throws {
        let harness = try IntegrationTestHarness.make()
        let context = harness.container.mainContext
        let alice = try #require(harness.localPlayer)
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        let scorecard = ScorecardViewModel(
            scoringService: harness.services.scoringService,
            lifecycleManager: harness.services.roundLifecycleManager,
            roundID: round.id,
            reportedByPlayerID: alice.id
        )

        for hole in 1...2 {
            try scorecard.enterScore(
                playerID: alice.id.uuidString,
                holeNumber: hole,
                strokeCount: 3,
                isRoundFinished: false
            )
            #expect(!scorecard.isAwaitingFinalization, "not yet on hole \(hole)")
        }

        // Final score — flips the flag.
        try scorecard.enterScore(
            playerID: alice.id.uuidString,
            holeNumber: 3,
            strokeCount: 3,
            isRoundFinished: false
        )
        #expect(scorecard.isAwaitingFinalization, "all-scored final hole must flip isAwaitingFinalization")
        #expect(!scorecard.isRoundCompleted)

        // Finalize.
        try scorecard.finalizeRound()
        #expect(scorecard.isRoundCompleted)

        // Round should now be completed in SwiftData.
        let roundID = round.id
        let refreshedDescriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == roundID })
        let fetched = try context.fetch(refreshedDescriptor)
        let refreshed = try #require(fetched.first)
        #expect(refreshed.status == RoundStatus.completed)
        #expect(refreshed.completedAt != nil)
    }

    @Test("RoundSummaryViewModel rows match StandingsEngine output post-finalization")
    func test_roundSummary_rowsMatchStandings() throws {
        let harness = try IntegrationTestHarness.make()
        let context = harness.container.mainContext
        let alice = try #require(harness.localPlayer)
        let bob = try harness.seedPlayer(displayName: "Bob")
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString, bob.id.uuidString],
            holeCount: 3
        )

        let scorecard = ScorecardViewModel(
            scoringService: harness.services.scoringService,
            lifecycleManager: harness.services.roundLifecycleManager,
            roundID: round.id,
            reportedByPlayerID: alice.id
        )
        for hole in 1...3 {
            try scorecard.enterScore(playerID: alice.id.uuidString, holeNumber: hole, strokeCount: 2, isRoundFinished: false)
            try scorecard.enterScore(playerID: bob.id.uuidString, holeNumber: hole, strokeCount: 4, isRoundFinished: false)
        }
        try scorecard.finalizeRound()

        harness.services.standingsEngine.recompute(for: round.id, trigger: .localScore)
        let standings = harness.services.standingsEngine.currentStandings

        let summary = RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: course.name,
            holesPlayed: 3,
            coursePar: 9,
            currentPlayerID: alice.id.uuidString
        )
        #expect(summary.playerRows.count == standings.count)
        #expect(summary.playerRows.map(\.position) == standings.map(\.position))
        #expect(summary.playerRows.map(\.playerName) == standings.map(\.playerName))
        // Top-3 medals: 2 players, both in top 3, so both should have medals.
        let allHaveMedal = summary.playerRows.allSatisfy { $0.hasMedal }
        #expect(allHaveMedal)
    }

    @Test("AppServices.roundDidStart: organizer advertises; roundDidEnd: stops advertising")
    func test_appServices_roundDidStart_advertises_roundDidEnd_stops() async throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id, // organizer == local player
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        await harness.services.roundDidStart()
        #expect(harness.nearby.startAdvertisingCallCount == 1, "organizer round should advertise")
        #expect(harness.nearby.lastAdvertisedRoundID == round.id)

        await harness.services.roundDidEnd()
        #expect(harness.nearby.stopAdvertisingCallCount >= 1, "roundDidEnd should stop advertising")
        #expect(harness.nearby.lastAdvertisedRoundID == nil)
    }
}
