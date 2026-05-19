import Foundation
import HyzerKit

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
public final class MockNearbyDiscoveryClient: NearbyDiscoveryClient, @unchecked Sendable {
    // Observable state for assertions
    public private(set) var startAdvertisingCallCount = 0
    public private(set) var stopAdvertisingCallCount = 0
    public private(set) var startBrowsingCallCount = 0
    public private(set) var stopBrowsingCallCount = 0
    public private(set) var lastAdvertisedRoundID: UUID?
    public private(set) var lastAdvertisedPlayerIDs: [String] = []

    // AsyncStream + Continuation built once at init time — accessing `discoveredRounds`
    // multiple times returns the same stream; events injected before subscription are
    // buffered (default `.unbounded` AsyncStream buffering).
    private let _discoveredRounds: AsyncStream<DiscoveredRoundPayload>
    private let continuation: AsyncStream<DiscoveredRoundPayload>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: DiscoveredRoundPayload.self)
        self._discoveredRounds = stream
        self.continuation = continuation
    }

    public var discoveredRounds: AsyncStream<DiscoveredRoundPayload> { _discoveredRounds }

    public func startAdvertising(roundID: UUID, playerIDs: [String]) async {
        // Mirror the live client's idempotency contract: same (roundID, playerIDs) is a no-op.
        if lastAdvertisedRoundID == roundID && lastAdvertisedPlayerIDs == playerIDs {
            return
        }
        startAdvertisingCallCount += 1
        lastAdvertisedRoundID = roundID
        lastAdvertisedPlayerIDs = playerIDs
    }

    public func stopAdvertising() async {
        stopAdvertisingCallCount += 1
        lastAdvertisedRoundID = nil
        lastAdvertisedPlayerIDs = []
    }

    public func startBrowsing() async { startBrowsingCallCount += 1 }
    public func stopBrowsing() async { stopBrowsingCallCount += 1 }

    // MARK: - Test helpers

    /// Injects a discovered payload on the AsyncStream.
    public func simulateFoundPeer(roundID: UUID, playerIDs: [String]) {
        continuation.yield(DiscoveredRoundPayload(roundID: roundID, playerIDs: playerIDs))
    }

    public func finish() { continuation.finish() }
}
