import Foundation

/// Typed messages exchanged between the iOS and watchOS apps via WatchConnectivity.
///
/// Custom `Codable` implementation serialises the discriminated union as
/// `{ "type": "<case>", "<case>": <payload> }` — safe across app versions.
public enum WatchMessage: Sendable {
    case standingsUpdate(StandingsSnapshot)   // Phone → Watch
    case scoreEvent(WatchScorePayload)         // Watch → Phone
    case voiceRequest(WatchVoiceRequest)       // Watch → Phone
    case voiceResult(WatchVoiceResult)         // Phone → Watch
}

extension WatchMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case standingsUpdate
        case scoreEvent
        case voiceRequest
        case voiceResult
    }

    private enum MessageType: String, Codable {
        case standingsUpdate
        case scoreEvent
        case voiceRequest
        case voiceResult
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
        case .voiceRequest:
            let request = try container.decode(WatchVoiceRequest.self, forKey: .voiceRequest)
            self = .voiceRequest(request)
        case .voiceResult:
            let result = try container.decode(WatchVoiceResult.self, forKey: .voiceResult)
            self = .voiceResult(result)
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
        case .voiceRequest(let request):
            try container.encode(MessageType.voiceRequest, forKey: .type)
            try container.encode(request, forKey: .voiceRequest)
        case .voiceResult(let result):
            try container.encode(MessageType.voiceResult, forKey: .type)
            try container.encode(result, forKey: .voiceResult)
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

// MARK: - WatchVoiceRequest

/// A request from the Watch for the phone to perform voice recognition on its microphone.
///
/// Sent Watch → Phone via `sendMessage` (best-effort instant delivery).
/// Includes the player list so the phone's `VoiceParser` has context to resolve names.
public struct WatchVoiceRequest: Sendable, Codable, Equatable {
    public let roundID: UUID
    public let holeNumber: Int
    /// Players in the current round — sent so the phone can run `VoiceParser` without
    /// needing its own round context at the time of recognition.
    public let playerEntries: [VoicePlayerEntry]

    public init(roundID: UUID, holeNumber: Int, playerEntries: [VoicePlayerEntry]) {
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.playerEntries = playerEntries
    }
}

// MARK: - WatchVoiceResult

/// The result of phone-side voice recognition, sent back to the Watch.
///
/// Sent Phone → Watch via `sendMessage` (best-effort instant delivery).
public struct WatchVoiceResult: Sendable, Codable, Equatable {
    public let result: VoiceParseResult
    public let holeNumber: Int
    public let roundID: UUID

    public init(result: VoiceParseResult, holeNumber: Int, roundID: UUID) {
        self.result = result
        self.holeNumber = holeNumber
        self.roundID = roundID
    }
}

