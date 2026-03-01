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
}
