import Foundation
@testable import HyzerKit

// Duplicate of HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift.
// Tech debt: extraction to a shared TestSupport module is tracked alongside
// MockNotificationService and ValueCollector duplications (CLAUDE.md "Known Technical Debt").

/// Controllable test double for `NearbyDiscoveryClient`.
///
/// Exposes `simulateFoundPeer(roundID:playerIDs:)` to inject a discovered payload
/// from test code. Records advertise/browse start-stop call counts and the last
/// advertised roundID for assertions. Thread-safety: `@unchecked Sendable` with
/// all mutations from test code (which controls the call site) — matches the
/// `MockNetworkMonitor` precedent.
///
/// **Idempotency parity with the live client (PROTOCOL CONTRACT):** `startAdvertising`
/// only increments `startAdvertisingCallCount` when `(roundID, playerIDs)` differs from
/// the current advertised pair. Tests that rely on the mock catching real-impl
/// idempotency bugs depend on this behavior.
final class MockNearbyDiscoveryClient: NearbyDiscoveryClient, @unchecked Sendable {
    // Observable state for assertions
    private(set) var startAdvertisingCallCount = 0
    private(set) var stopAdvertisingCallCount = 0
    private(set) var startBrowsingCallCount = 0
    private(set) var stopBrowsingCallCount = 0
    private(set) var lastAdvertisedRoundID: UUID?
    private(set) var lastAdvertisedPlayerIDs: [String] = []

    // AsyncStream + Continuation built once at init time — accessing `discoveredRounds`
    // multiple times returns the same stream; events injected before subscription are
    // buffered (default `.unbounded` AsyncStream buffering).
    private let _discoveredRounds: AsyncStream<DiscoveredRoundPayload>
    private let continuation: AsyncStream<DiscoveredRoundPayload>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: DiscoveredRoundPayload.self)
        self._discoveredRounds = stream
        self.continuation = continuation
    }

    var discoveredRounds: AsyncStream<DiscoveredRoundPayload> { _discoveredRounds }

    func startAdvertising(roundID: UUID, playerIDs: [String]) async {
        // Mirror the live client's idempotency contract: same (roundID, playerIDs) is a no-op.
        if lastAdvertisedRoundID == roundID && lastAdvertisedPlayerIDs == playerIDs {
            return
        }
        startAdvertisingCallCount += 1
        lastAdvertisedRoundID = roundID
        lastAdvertisedPlayerIDs = playerIDs
    }

    func stopAdvertising() async {
        stopAdvertisingCallCount += 1
        lastAdvertisedRoundID = nil
        lastAdvertisedPlayerIDs = []
    }

    func startBrowsing() async { startBrowsingCallCount += 1 }
    func stopBrowsing() async { stopBrowsingCallCount += 1 }

    // MARK: - Test helpers

    /// Injects a discovered payload on the AsyncStream.
    func simulateFoundPeer(roundID: UUID, playerIDs: [String]) {
        continuation.yield(DiscoveredRoundPayload(roundID: roundID, playerIDs: playerIDs))
    }

    func finish() { continuation.finish() }
}
