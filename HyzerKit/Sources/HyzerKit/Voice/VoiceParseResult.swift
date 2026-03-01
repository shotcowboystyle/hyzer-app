import Foundation

/// A successfully resolved player–score pair produced by `VoiceParser`.
public struct ScoreCandidate: Sendable, Equatable {
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
public struct UnresolvedCandidate: Sendable, Equatable {
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

/// A classified token from a voice transcript.
public enum Token: Sendable, Equatable {
    /// A token classified as a player name fragment.
    case name(String)
    /// A token classified as a stroke count (1–10).
    case number(Int)
    /// A token that could not be meaningfully classified.
    case noise(String)
}
