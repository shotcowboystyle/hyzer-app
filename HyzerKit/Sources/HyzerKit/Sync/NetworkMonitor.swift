import Foundation

/// Abstraction over the device's network reachability state.
///
/// Protocol lives in HyzerKit so `SyncScheduler` and tests can depend on it without
/// importing `Network.framework` on macOS test hosts. The live implementation
/// (`LiveNetworkMonitor`) is in the HyzerApp target.
///
/// Conforming types **must** be `Sendable` because the protocol is consumed from
/// the `SyncScheduler` actor.
public protocol NetworkMonitor: Sendable {
    /// Synchronous check of the current connectivity state.
    ///
    /// `true` when the path status is `.satisfied` (any interface).
    var isConnected: Bool { get }

    /// Async stream that emits `true` when connectivity is restored and
    /// `false` when connectivity is lost.
    ///
    /// Starts emitting immediately with the current state on subscription.
    var pathUpdates: AsyncStream<Bool> { get }
}
