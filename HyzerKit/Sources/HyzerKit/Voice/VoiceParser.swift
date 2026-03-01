import Foundation

/// Input type for `VoiceParser` — minimal player representation with no SwiftData dependency.
public struct VoicePlayerEntry: Sendable, Codable, Equatable {
    public let playerID: String
    public let displayName: String
    public let aliases: [String]

    public init(playerID: String, displayName: String, aliases: [String]) {
        self.playerID = playerID
        self.displayName = displayName
        self.aliases = aliases
    }
}

/// Parses a voice transcript into player–score pairs via a tokenize → classify → assemble pipeline.
///
/// `nonisolated` struct — stateless, `Sendable`, no platform imports (no Speech framework dependency).
/// Callable from any isolation context without `await`.
public struct VoiceParser: Sendable {

    private let classifier = TokenClassifier()

    public init() {}

    /// Parses a spoken transcript into a `VoiceParseResult`.
    ///
    /// Pipeline:
    /// 1. Tokenize: split by whitespace and commas → `[String]`
    /// 2. Classify: each token → `.name`, `.number`, or `.noise`
    /// 3. Assemble: pair each `.name` with the next `.number` in sequence
    /// 4. Match: resolve name fragments to known players via `FuzzyNameMatcher`
    ///
    /// Subset scoring is valid — "Jake 4" alone is accepted even in a multi-player round.
    ///
    /// - Parameters:
    ///   - transcript: The raw string from speech recognition.
    ///   - players: The known player list for this round.
    /// - Returns: `.success`, `.partial`, or `.failed`.
    public func parse(transcript: String, players: [VoicePlayerEntry]) -> VoiceParseResult {
        let matcher = FuzzyNameMatcher(players: players.map { ($0.playerID, $0.displayName, $0.aliases) })
        let rawTokens = tokenize(transcript)
        let classified = rawTokens.map { classifier.classify(raw: $0) }
        let pairs = assemble(classified: classified)

        guard !pairs.isEmpty else { return .failed(transcript: transcript) }

        var recognized: [ScoreCandidate] = []
        var unresolved: [UnresolvedCandidate] = []

        for (nameToken, strokeCount) in pairs {
            switch matcher.match(token: nameToken) {
            case .matched(let playerID, let displayName):
                recognized.append(ScoreCandidate(playerID: playerID, displayName: displayName, strokeCount: strokeCount))
            case .ambiguous, .unmatched:
                unresolved.append(UnresolvedCandidate(spokenName: nameToken, strokeCount: strokeCount))
            }
        }

        if recognized.isEmpty { return .failed(transcript: transcript) }
        if unresolved.isEmpty { return .success(recognized) }
        return .partial(recognized: recognized, unresolved: unresolved)
    }

    // MARK: - Pipeline: Tokenize

    private func tokenize(_ transcript: String) -> [String] {
        let separators = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ","))
        return transcript
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Pipeline: Assemble name-number pairs

    /// Pairs each `.name` token with the next `.number` token that follows it.
    /// Names with no following number are silently skipped.
    private func assemble(classified: [Token]) -> [(name: String, strokeCount: Int)] {
        var pairs: [(name: String, strokeCount: Int)] = []
        var i = 0

        while i < classified.count {
            guard case .name(let nameToken) = classified[i] else { i += 1; continue }

            var j = i + 1
            while j < classified.count {
                if case .number(let count) = classified[j] {
                    pairs.append((name: nameToken, strokeCount: count))
                    i = j + 1
                    break
                } else if case .noise = classified[j] {
                    j += 1
                } else {
                    // Another name token — no number found for current name
                    i = j
                    break
                }
            }
            if j >= classified.count { i = j }
        }

        return pairs
    }
}
