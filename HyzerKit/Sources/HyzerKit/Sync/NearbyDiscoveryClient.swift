import Foundation

/// A discovered active round on the local network.
///
/// Value type — never persisted. Lifetime is the AsyncStream consumption window.
/// Mirrors the value-type discipline of `StandingsSnapshot`, `StandingsChange`, and
/// `WatchMessage` (all `Sendable` structs in `HyzerKit/Sources/HyzerKit/Communication/`).
public struct DiscoveredRoundPayload: Sendable, Equatable {
    /// The advertised round's UUID.
    public let roundID: UUID
    /// Player IDs from `Round.playerIDs` — UUID strings or `"guest:<uuid>"` strings.
    /// Consumers MUST filter via `playerIDs.contains(localPlayerID.uuidString)` before
    /// taking action (AC #5).
    public let playerIDs: [String]

    public init(roundID: UUID, playerIDs: [String]) {
        self.roundID = roundID
        self.playerIDs = playerIDs
    }
}

/// Abstraction over MultipeerConnectivity Bonjour discovery for active rounds.
///
/// Protocol lives in HyzerKit so `AppServices` and tests can depend on it without
/// importing `MultipeerConnectivity` on macOS test hosts. The live implementation
/// (`LiveNearbyDiscoveryClient`) is in the HyzerApp target — mirrors the
/// `CloudKitClient` / `NetworkMonitor` split.
///
/// Conforming types **must** be `Sendable` because the protocol is consumed from
/// `@MainActor AppServices` and the live impl's delegates fire on private MC queues.
///
/// **Lifecycle invariants:**
/// - All four start/stop methods are idempotent: redundant calls are no-ops.
/// - `startAdvertising(roundID:playerIDs:)` is idempotent only when BOTH `roundID` AND
///   `playerIDs` match the currently-advertised payload. A change in either field
///   replaces the previous advertisement (stops the old `MCNearbyServiceAdvertiser`,
///   creates a new one with the updated TXT record).
/// - `discoveredRounds` is a SINGLE-SUBSCRIBER stream. The underlying continuation is
///   created once at conforming-type init time and is reused across property accesses,
///   so events that arrive before the consumer starts iterating are buffered (default
///   `AsyncStream` buffering). Accessing the property multiple times returns the same
///   stream value; only ONE consumer should iterate it.
public protocol NearbyDiscoveryClient: Sendable {
    /// Begins advertising the local user's organized round on the local network.
    ///
    /// Triggers the iOS local-network permission prompt on first call if permission
    /// has not yet been requested (system-managed; the app does NOT pre-prompt).
    /// Permission denial is reported via the live implementation's internal logger
    /// and leaves the client in an inert state — no error is propagated to the caller.
    ///
    /// - Parameters:
    ///   - roundID: The `Round.id` being advertised.
    ///   - playerIDs: `Round.playerIDs` (UUID strings or `"guest:<uuid>"` strings).
    ///     Encoded into the Bonjour TXT record. See AC #7 for size constraints.
    func startAdvertising(roundID: UUID, playerIDs: [String]) async

    /// Stops the currently-active advertiser, if any. Idempotent.
    func stopAdvertising() async

    /// Begins browsing for nearby advertised rounds. Idempotent — repeat calls are no-ops.
    /// Permission denial behavior mirrors `startAdvertising`.
    func startBrowsing() async

    /// Stops the currently-active browser, if any. Idempotent.
    func stopBrowsing() async

    /// Async stream of discovered round payloads. Each emission represents ONE
    /// `foundPeer` delegate callback from the underlying `MCNearbyServiceBrowser`.
    ///
    /// **Consumer responsibilities** (AC #5, #8, #9):
    /// 1. Filter on `playerIDs.contains(localPlayerID.uuidString)` — drop payloads
    ///    that don't include the local user.
    /// 2. Idempotency: skip payloads whose `roundID` is already locally materialized.
    /// 3. Throttle: enforce a 30s per-`roundID` window between `syncEngine.pullRecords()`
    ///    invocations.
    var discoveredRounds: AsyncStream<DiscoveredRoundPayload> { get }
}
