import Foundation

/// A computed standing for one player in an active round.
///
/// Produced by `StandingsEngine.recompute(for:trigger:)` and consumed by leaderboard views.
/// Immutable value type — never persisted; always derived from `ScoreEvent` data.
public struct Standing: Identifiable, Sendable, Equatable, Codable {
    /// Player.id.uuidString for registered players; "guest:{name}" for guests.
    public let playerID: String
    public let playerName: String
    /// 1-based ranking position (ties share the same position).
    public let position: Int
    /// Sum of stroke counts across all resolved leaf-node ScoreEvents.
    public let totalStrokes: Int
    /// Number of distinct holes with at least one resolved score.
    public let holesPlayed: Int
    /// `totalStrokes` minus the total par for all holes played. Negative = under par.
    public let scoreRelativeToPar: Int

    public var id: String { playerID }

    public init(
        playerID: String,
        playerName: String,
        position: Int,
        totalStrokes: Int,
        holesPlayed: Int,
        scoreRelativeToPar: Int
    ) {
        self.playerID = playerID
        self.playerName = playerName
        self.position = position
        self.totalStrokes = totalStrokes
        self.holesPlayed = holesPlayed
        self.scoreRelativeToPar = scoreRelativeToPar
    }
}
