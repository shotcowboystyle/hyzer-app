import Foundation

/// Resolves name tokens against a known player list using deterministic matching strategies.
///
/// `nonisolated` struct — stateless after init, `Sendable`, no actor isolation required.
/// Takes a flattened player representation to avoid any SwiftData dependency.
public struct FuzzyNameMatcher: Sendable {

    /// The result of attempting to match a name token against the player list.
    public enum MatchResult: Sendable {
        /// Exactly one player matched the token.
        case matched(playerID: String, displayName: String)
        /// Multiple players are plausible matches (similarity 50–80%).
        case ambiguous(candidates: [(playerID: String, displayName: String)])
        /// No player matched above the minimum threshold (<50% similarity).
        case unmatched
    }

    private struct Entry: Sendable {
        let playerID: String
        let displayName: String
        let aliases: [String]
    }

    private let players: [Entry]

    /// Initializer takes a flattened player list — no SwiftData dependency.
    public init(players: [(playerID: String, displayName: String, aliases: [String])]) {
        self.players = players.map { Entry(playerID: $0.playerID, displayName: $0.displayName, aliases: $0.aliases) }
    }

    /// Resolves a name token to a known player.
    ///
    /// Matching priority:
    /// 1. Alias exact match (case-insensitive)
    /// 2. Display name exact match (case-insensitive)
    /// 3. Display name prefix (unique prefix among all players)
    /// 4. Levenshtein similarity: ≥0.8 → accept; 0.5–0.8 → ambiguous; <0.5 → unmatched
    public func match(token: String) -> MatchResult {
        let lower = token.lowercased()

        // 1. Alias exact match
        let aliasMatches = players.filter { $0.aliases.contains { $0.lowercased() == lower } }
        if aliasMatches.count == 1 { return .matched(playerID: aliasMatches[0].playerID, displayName: aliasMatches[0].displayName) }
        if aliasMatches.count > 1 { return .ambiguous(candidates: aliasMatches.map { ($0.playerID, $0.displayName) }) }

        // 2. Display name exact match
        let displayMatches = players.filter { $0.displayName.lowercased() == lower }
        if displayMatches.count == 1 { return .matched(playerID: displayMatches[0].playerID, displayName: displayMatches[0].displayName) }
        if displayMatches.count > 1 { return .ambiguous(candidates: displayMatches.map { ($0.playerID, $0.displayName) }) }

        // 3. Display name unique prefix
        let prefixMatches = players.filter { $0.displayName.lowercased().hasPrefix(lower) }
        if prefixMatches.count == 1 { return .matched(playerID: prefixMatches[0].playerID, displayName: prefixMatches[0].displayName) }
        if prefixMatches.count > 1 { return .ambiguous(candidates: prefixMatches.map { ($0.playerID, $0.displayName) }) }

        // 4. Levenshtein distance fallback
        return levenshteinMatch(lower: lower)
    }

    // MARK: - Levenshtein Fallback

    private func levenshteinMatch(lower: String) -> MatchResult {
        var acceptMatches: [(playerID: String, displayName: String, similarity: Double)] = []
        var ambiguousMatches: [(playerID: String, displayName: String)] = []

        for player in players {
            let name = player.displayName.lowercased()
            let dist = levenshteinDistance(lower, name)
            let maxLen = max(lower.count, name.count)
            guard maxLen > 0 else { continue }
            let similarity = 1.0 - Double(dist) / Double(maxLen)

            if similarity >= 0.8 {
                acceptMatches.append((player.playerID, player.displayName, similarity))
            } else if similarity >= 0.5 {
                ambiguousMatches.append((player.playerID, player.displayName))
            }
        }

        if acceptMatches.count == 1 { return .matched(playerID: acceptMatches[0].playerID, displayName: acceptMatches[0].displayName) }
        if acceptMatches.count > 1 { return .ambiguous(candidates: acceptMatches.map { ($0.playerID, $0.displayName) }) }
        if !ambiguousMatches.isEmpty { return .ambiguous(candidates: ambiguousMatches) }

        return .unmatched
    }

    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count
        if aLen == 0 { return bLen }
        if bLen == 0 { return aLen }

        var prev = Array(0...bLen)
        for i in 1...aLen {
            var curr = [Int](repeating: 0, count: bLen + 1)
            curr[0] = i
            for j in 1...bLen {
                curr[j] = aChars[i - 1] == bChars[j - 1] ? prev[j - 1] : 1 + min(prev[j - 1], prev[j], curr[j - 1])
            }
            prev = curr
        }
        return prev[bLen]
    }
}
