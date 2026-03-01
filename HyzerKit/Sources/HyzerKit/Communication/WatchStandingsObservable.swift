import Foundation

/// Observable state interface for Watch standings consumption.
///
/// Conformed to by `WatchConnectivityService` (watchOS) and test doubles in `HyzerKitTests`.
/// `WatchLeaderboardViewModel` depends on this protocol instead of the concrete service,
/// enabling macOS-hosted unit tests without importing WatchConnectivity.
@MainActor
public protocol WatchStandingsObservable: AnyObject {
    /// The most recently received (or cached) standings snapshot. `nil` until first update.
    var currentSnapshot: StandingsSnapshot? { get }
    /// Whether the paired iPhone is currently reachable for instant messaging.
    var isPhoneReachable: Bool { get }
}
