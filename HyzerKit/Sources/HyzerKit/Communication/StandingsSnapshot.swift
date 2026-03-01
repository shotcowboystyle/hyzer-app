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
    /// Par value for the current hole. Used by Watch Crown scoring to set the default score.
    public let currentHolePar: Int
    public let lastUpdatedAt: Date

    public init(
        standings: [Standing],
        roundID: UUID,
        currentHole: Int,
        currentHolePar: Int = 3,
        lastUpdatedAt: Date = Date()
    ) {
        self.standings = standings
        self.roundID = roundID
        self.currentHole = currentHole
        self.currentHolePar = currentHolePar
        self.lastUpdatedAt = lastUpdatedAt
    }

    // MARK: - Codable (custom decoder for backwards-compat with pre-7.2 snapshots)

    private enum CodingKeys: String, CodingKey {
        case standings, roundID, currentHole, currentHolePar, lastUpdatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        standings = try container.decode([Standing].self, forKey: .standings)
        roundID = try container.decode(UUID.self, forKey: .roundID)
        currentHole = try container.decode(Int.self, forKey: .currentHole)
        currentHolePar = try container.decodeIfPresent(Int.self, forKey: .currentHolePar) ?? 3
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
    }

    // MARK: - Staleness helpers

    /// Threshold beyond which a snapshot is considered stale (30 seconds).
    public static let staleThreshold: TimeInterval = 30

    /// Returns `true` when `reference.timeIntervalSince(lastUpdatedAt) > 30`.
    public func isStale(from reference: Date = Date()) -> Bool {
        reference.timeIntervalSince(lastUpdatedAt) > StandingsSnapshot.staleThreshold
    }

    /// Human-readable relative time: "30s ago", "2m ago", "4h ago", etc.
    public func staleDurationText(from reference: Date = Date()) -> String {
        let elapsed = Int(reference.timeIntervalSince(lastUpdatedAt))
        if elapsed < 60 { return "\(elapsed)s ago" }
        if elapsed < 3600 { return "\(elapsed / 60)m ago" }
        return "\(elapsed / 3600)h ago"
    }
}
