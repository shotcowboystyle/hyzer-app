import Foundation
import Observation

/// Manages leaderboard display state for the Watch app.
///
/// Derives its state from a `WatchStandingsObservable` provider (production: `WatchConnectivityService`).
/// Lives in HyzerKit so the staleness logic can be unit-tested on macOS without importing WatchConnectivity.
@MainActor
@Observable
public final class WatchLeaderboardViewModel {
    private let provider: any WatchStandingsObservable

    // MARK: - Derived state

    /// The current standings snapshot, exposed for navigation destination context (hole, par, roundID).
    public var snapshot: StandingsSnapshot? { provider.currentSnapshot }

    public var standings: [Standing] {
        provider.currentSnapshot?.standings ?? []
    }

    /// True when no live connection and the cached snapshot is older than 30 seconds.
    public var isStale: Bool {
        guard let snapshot = provider.currentSnapshot else { return false }
        return !provider.isPhoneReachable && snapshot.isStale()
    }

    /// Human-readable relative time since the last snapshot (e.g. "30s ago", "2m ago").
    public var staleDurationText: String {
        provider.currentSnapshot?.staleDurationText() ?? ""
    }

    /// Whether the phone is currently reachable via live connection.
    public var isConnected: Bool { provider.isPhoneReachable }

    // MARK: - Init

    public init(provider: any WatchStandingsObservable) {
        self.provider = provider
    }
}
