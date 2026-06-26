import Testing
import SwiftData
import Foundation
@testable import HyzerApp
@testable import HyzerKit
import TestSupport

/// Story 15.11 — Journey 4a: Watch → Phone score-arrival pipeline.
///
/// Exercises `PhoneConnectivityService.handleWatchScoreEvent` via the test seam
/// `_testInjectIncomingMessage(_:)` (added in Story 15.11) without going through
/// `WCSession`. Asserts the full chain: WatchMessage → ScoringService.createScoreEvent
/// → SwiftData persistence → StandingsEngine recompute.
@Suite("Integration — Watch → Phone Score Sync")
@MainActor
struct WatchPhoneSyncTests {

    @Test("Watch score payload → ScoreEvent persisted with correct fields → standings recompute")
    func test_watchPayload_happyPath_persistsScoreEventAndRecomputesStandings() throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)
        let bob = try harness.seedPlayer(displayName: "Bob")
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString, bob.id.uuidString],
            holeCount: 3
        )

        // PhoneConnectivityService needs the StandingsEngine wired in for the
        // recompute trigger to fire. AppServices.init does NOT do this — only
        // startSync() does — so wire it directly to keep the test fast.
        harness.services.phoneConnectivityService.startObservingStandings(harness.services.standingsEngine)

        let payload = WatchScorePayload(
            roundID: round.id,
            playerID: bob.id.uuidString,
            holeNumber: 1,
            strokeCount: 2
        )
        harness.services.phoneConnectivityService._testInjectIncomingMessage(.scoreEvent(payload))

        // A ScoreEvent should now be present for (round, bob, hole 1).
        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        let bobEvent = try #require(events.first { $0.playerID == bob.id.uuidString && $0.holeNumber == 1 })
        #expect(bobEvent.roundID == round.id)
        #expect(bobEvent.strokeCount == 2)
        // The reporter is the LOCAL player (Alice), not the player being scored —
        // PhoneConnectivityService.localPlayerID is the reporter for Watch payloads.
        #expect(bobEvent.reportedByPlayerID == alice.id)

        // Standings recompute on demand and verify Bob shows up at totalStrokes=2.
        harness.services.standingsEngine.recompute(for: round.id, trigger: .localScore)
        let bobStanding = try #require(harness.services.standingsEngine.currentStandings.first { $0.playerID == bob.id.uuidString })
        #expect(bobStanding.totalStrokes == 2)
        #expect(bobStanding.holesPlayed == 1)
    }

    @Test("Watch payload with strokeCount > 10 is rejected (no ScoreEvent created)")
    func test_watchPayload_strokeCountOutOfRange_isRejected() throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        let payload = WatchScorePayload(
            roundID: round.id,
            playerID: alice.id.uuidString,
            holeNumber: 1,
            strokeCount: 11 // out of range
        )
        harness.services.phoneConnectivityService._testInjectIncomingMessage(.scoreEvent(payload))

        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.isEmpty,
                "strokeCount=11 must be rejected by the strokeCount range guard in PhoneConnectivityService")
    }

    @Test("Watch payload for a finished round is rejected via validateExternalScore")
    func test_watchPayload_finishedRound_isRejected() throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )
        // Force the round to completed so validateExternalScore throws roundNotActive.
        round.complete()
        try harness.container.mainContext.save()

        let payload = WatchScorePayload(
            roundID: round.id,
            playerID: alice.id.uuidString,
            holeNumber: 1,
            strokeCount: 3
        )
        harness.services.phoneConnectivityService._testInjectIncomingMessage(.scoreEvent(payload))

        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.isEmpty,
                "finished round must be rejected by ScoringService.validateExternalScore (.roundNotActive)")
    }

    @Test("Watch payload for a player not in the round is rejected via validateExternalScore")
    func test_watchPayload_playerNotInRound_isRejected() throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)
        let course = try harness.seedCourse(holeCount: 3, parPerHole: 3)
        let round = try harness.seedActiveRound(
            courseID: course.id,
            organizerID: alice.id,
            playerIDs: [alice.id.uuidString],
            holeCount: 3
        )

        let strangerID = UUID().uuidString
        let payload = WatchScorePayload(
            roundID: round.id,
            playerID: strangerID,
            holeNumber: 1,
            strokeCount: 3
        )
        harness.services.phoneConnectivityService._testInjectIncomingMessage(.scoreEvent(payload))

        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.isEmpty,
                "non-member playerID must be rejected by ScoringService.validateExternalScore (.playerNotInRound)")
    }

    @Test("Watch payload for a non-existent round is rejected (no crash)")
    func test_watchPayload_unknownRound_isRejectedSafely() throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)

        let payload = WatchScorePayload(
            roundID: UUID(), // no such round
            playerID: alice.id.uuidString,
            holeNumber: 1,
            strokeCount: 3
        )
        harness.services.phoneConnectivityService._testInjectIncomingMessage(.scoreEvent(payload))

        let events = try harness.container.mainContext.fetch(FetchDescriptor<ScoreEvent>())
        #expect(events.isEmpty)
    }
}
