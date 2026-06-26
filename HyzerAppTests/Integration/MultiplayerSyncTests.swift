import Testing
import SwiftData
import CloudKit
import Foundation
@testable import HyzerApp
@testable import HyzerKit
import TestSupport

/// Story 15.11 — Journey 3 (app half): nearby discovery → CloudKit pull
/// trigger semantics. Extends `AppServicesNearbyDiscoveryTests` without
/// modifying it.
///
/// **Scope note:** the materialize-and-show-on-leaderboard chain is split
/// across two pre-existing mechanisms in production:
///   1. Round records arrive via the Round CKQuerySubscription push (handled by
///      `AppServices.handleRoundStartedNotification` + a fresh pull there).
///   2. `SyncEngine.pullRecords` only pulls **ScoreEvent** records — it never
///      pulls Round records (see `SyncEngine.swift:304-314`).
/// Nearby discovery only triggers (2), not (1). So a meaningful "round
/// materializes via nearby" end-to-end test isn't representative of how the
/// system actually works — it would test a flow that production doesn't run.
/// The kit-level `RemoteScoreEventArrivalTests` covers ScoreEvent materialization
/// once the Round exists; this suite focuses on the discovery trigger and
/// throttle invariants at the AppServices integration boundary.
@Suite("Integration — Multiplayer Sync (app)")
@MainActor
struct MultiplayerSyncTests {

    @Test("Nearby discovery for a NEW round → pullRecords triggers; same round again <30s → throttled")
    func test_nearbyDiscovery_throttle() async throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)
        let bobID = UUID()
        let roundID = UUID()

        // Empty remote payload — we only care about the trigger count, not the
        // materialized state.
        harness.cloudKit.recordsToReturn = []

        let syncTask = try await harness.startSyncAndAwaitInitialPull()
        defer { syncTask.cancel() }

        let baseline = harness.cloudKit.fetchCallCount

        // First discovery — should trigger a pull (round not in SwiftData).
        harness.nearby.simulateFoundPeer(
            roundID: roundID,
            playerIDs: [alice.id.uuidString, bobID.uuidString]
        )
        try await waitUntil(
            { harness.cloudKit.fetchCallCount > baseline },
            conditionDescription: "first peer discovery triggers pull"
        )
        let afterFirst = harness.cloudKit.fetchCallCount

        // Second discovery within the throttle window — should NOT trigger.
        harness.nearby.simulateFoundPeer(
            roundID: roundID,
            playerIDs: [alice.id.uuidString, bobID.uuidString]
        )
        do {
            try await waitUntil(
                { harness.cloudKit.fetchCallCount > afterFirst },
                timeout: .milliseconds(200),
                conditionDescription: "throttled second discovery must NOT trigger pull"
            )
        } catch is WaitUntilError {
            // Expected — throttle held.
        }
        #expect(
            harness.cloudKit.fetchCallCount == afterFirst,
            "30s throttle should suppress the second pull for the same roundID"
        )
    }

    @Test("After roundDidEnd, the throttle stamp is cleared so re-discovery re-triggers pull")
    func test_lastPullByRoundIDClearedOnRoundDidEnd() async throws {
        let harness = try IntegrationTestHarness.make()
        let alice = try #require(harness.localPlayer)
        let bobID = UUID()
        let roundID = UUID()
        harness.cloudKit.recordsToReturn = []

        let syncTask = try await harness.startSyncAndAwaitInitialPull()
        defer { syncTask.cancel() }

        let baseline = harness.cloudKit.fetchCallCount

        harness.nearby.simulateFoundPeer(
            roundID: roundID,
            playerIDs: [alice.id.uuidString, bobID.uuidString]
        )
        try await waitUntil(
            { harness.cloudKit.fetchCallCount > baseline },
            conditionDescription: "first discovery triggers pull"
        )
        let afterFirst = harness.cloudKit.fetchCallCount

        await harness.services.roundDidEnd()

        harness.nearby.simulateFoundPeer(
            roundID: roundID,
            playerIDs: [alice.id.uuidString, bobID.uuidString]
        )
        try await waitUntil(
            { harness.cloudKit.fetchCallCount > afterFirst },
            conditionDescription: "after roundDidEnd, re-discovery must re-trigger pull"
        )
        #expect(harness.cloudKit.fetchCallCount > afterFirst,
                "lastPullByRoundID must be cleared on roundDidEnd")
    }
}
