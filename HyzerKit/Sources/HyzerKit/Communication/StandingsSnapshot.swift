import Foundation

/// A serialisable snapshot of leaderboard standings transmitted from Phone to Watch.
///
/// Written by `PhoneConnectivityService` (via `sendMessage` and `WatchCacheManager`) and
/// read by `WatchConnectivityService` (live) or `WatchCacheManager` (offline fallback).
public struct StandingsSnapshot: Sendable, Codable, Equatable {
    public let standings: [Standing]
    public let roundID: UUID
    /// 1-based hole number currently being played.
    public let currentHole: Int
    public let lastUpdatedAt: Date

    public init(
        standings: [Standing],
        roundID: UUID,
        currentHole: Int,
        lastUpdatedAt: Date = Date()
    ) {
        self.standings = standings
        self.roundID = roundID
        self.currentHole = currentHole
        self.lastUpdatedAt = lastUpdatedAt
    }

    // MARK: - Staleness helpers

    /// Threshold beyond which a snapshot is considered stale (30 seconds).
    public static let staleThreshold: TimeInterval = 30

    /// Returns `true` when `reference.timeIntervalSince(lastUpdatedAt) > 30`.
    public func isStale(from reference: Date = Date()) -> Bool {
        reference.timeIntervalSince(lastUpdatedAt) > StandingsSnapshot.staleThreshold
    }

    /// Human-readable relative time: "30s ago", "2m ago", etc.
    public func staleDurationText(from reference: Date = Date()) -> String {
        let elapsed = Int(reference.timeIntervalSince(lastUpdatedAt))
        if elapsed < 60 { return "\(elapsed)s ago" }
        return "\(elapsed / 60)m ago"
    }
}
