import Foundation

/// Typed messages exchanged between the iOS and watchOS apps via WatchConnectivity.
///
/// Custom `Codable` implementation serialises the discriminated union as
/// `{ "type": "<case>", "<case>": <payload> }` — safe across app versions.
public enum WatchMessage: Sendable {
    case standingsUpdate(StandingsSnapshot)
    case scoreEvent(WatchScorePayload)
}

extension WatchMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case standingsUpdate
        case scoreEvent
    }

    private enum MessageType: String, Codable {
        case standingsUpdate
        case scoreEvent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .standingsUpdate:
            let snapshot = try container.decode(StandingsSnapshot.self, forKey: .standingsUpdate)
            self = .standingsUpdate(snapshot)
        case .scoreEvent:
            let payload = try container.decode(WatchScorePayload.self, forKey: .scoreEvent)
            self = .scoreEvent(payload)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .standingsUpdate(let snapshot):
            try container.encode(MessageType.standingsUpdate, forKey: .type)
            try container.encode(snapshot, forKey: .standingsUpdate)
        case .scoreEvent(let payload):
            try container.encode(MessageType.scoreEvent, forKey: .type)
            try container.encode(payload, forKey: .scoreEvent)
        }
    }
}

// MARK: - WatchScorePayload

/// A score event submitted by the Watch user, delivered to the phone for `ScoreEvent` creation.
///
/// Story 7.2 scope: the Phone's `PhoneConnectivityService` wires this to `ScoringService`.
public struct WatchScorePayload: Sendable, Codable, Equatable {
    public let roundID: UUID
    public let playerID: String
    public let holeNumber: Int
    public let strokeCount: Int
    public let timestamp: Date

    public init(
        roundID: UUID,
        playerID: String,
        holeNumber: Int,
        strokeCount: Int,
        timestamp: Date = Date()
    ) {
        self.roundID = roundID
        self.playerID = playerID
        self.holeNumber = holeNumber
        self.strokeCount = strokeCount
        self.timestamp = timestamp
    }
}
