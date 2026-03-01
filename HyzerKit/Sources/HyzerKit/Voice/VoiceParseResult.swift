import Foundation

/// A successfully resolved player–score pair produced by `VoiceParser`.
public struct ScoreCandidate: Sendable, Equatable, Codable {
    public let playerID: String
    public let displayName: String
    public let strokeCount: Int

    public init(playerID: String, displayName: String, strokeCount: Int) {
        self.playerID = playerID
        self.displayName = displayName
        self.strokeCount = strokeCount
    }
}

/// A player name that was heard but could not be matched to a known player.
/// Carries the stroke count paired with the spoken name so the user only needs
/// to resolve the identity — the stroke count is retained on resolution.
public struct UnresolvedCandidate: Sendable, Equatable, Codable {
    public let spokenName: String
    public let strokeCount: Int

    public init(spokenName: String, strokeCount: Int) {
        self.spokenName = spokenName
        self.strokeCount = strokeCount
    }
}

/// The result of parsing a voice transcript against a known player list.
public enum VoiceParseResult: Sendable {
    /// All player names in the transcript were resolved and paired with stroke counts.
    case success([ScoreCandidate])
    /// Some names were resolved; others could not be matched to known players.
    case partial(recognized: [ScoreCandidate], unresolved: [UnresolvedCandidate])
    /// No names could be resolved from the transcript.
    case failed(transcript: String)
}

// MARK: - VoiceParseResult Codable

extension VoiceParseResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case success
        case partial
        case failed
    }

    private enum ResultType: String, Codable {
        case success
        case partial
        case failed
    }

    private struct PartialPayload: Codable {
        let recognized: [ScoreCandidate]
        let unresolved: [UnresolvedCandidate]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ResultType.self, forKey: .type)
        switch type {
        case .success:
            let candidates = try container.decode([ScoreCandidate].self, forKey: .success)
            self = .success(candidates)
        case .partial:
            let payload = try container.decode(PartialPayload.self, forKey: .partial)
            self = .partial(recognized: payload.recognized, unresolved: payload.unresolved)
        case .failed:
            let transcript = try container.decode(String.self, forKey: .failed)
            self = .failed(transcript: transcript)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let candidates):
            try container.encode(ResultType.success, forKey: .type)
            try container.encode(candidates, forKey: .success)
        case .partial(let recognized, let unresolved):
            try container.encode(ResultType.partial, forKey: .type)
            try container.encode(PartialPayload(recognized: recognized, unresolved: unresolved), forKey: .partial)
        case .failed(let transcript):
            try container.encode(ResultType.failed, forKey: .type)
            try container.encode(transcript, forKey: .failed)
        }
    }
}

/// A classified token from a voice transcript.
public enum Token: Sendable, Equatable {
    /// A token classified as a player name fragment.
    case name(String)
    /// A token classified as a stroke count (1–10).
    case number(Int)
    /// A token that could not be meaningfully classified.
    case noise(String)
}
