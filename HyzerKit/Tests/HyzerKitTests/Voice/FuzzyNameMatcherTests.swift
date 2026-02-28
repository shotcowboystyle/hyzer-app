import Testing
import Foundation
@testable import HyzerKit

@Suite("FuzzyNameMatcher")
struct FuzzyNameMatcherTests {

    // MARK: - Alias map lookup

    @Test("alias exact match case-insensitive returns matched")
    func test_match_aliasExact_returnsMatched() {
        // Given: Michael has alias "Mike"
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p1", displayName: "Michael", aliases: ["Mike", "Mikey"])
        ])

        // When
        let result = matcher.match(token: "mike")

        // Then
        if case .matched(let id, let name) = result {
            #expect(id == "p1")
            #expect(name == "Michael")
        } else {
            Issue.record("Expected .matched, got \(result)")
        }
    }

    @Test("alias match is case-insensitive for mixed-case input")
    func test_match_aliasExactMixedCase_returnsMatched() {
        // Given
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p2", displayName: "Sarah", aliases: ["Saz", "Sally"])
        ])

        // When
        let result = matcher.match(token: "SAZ")

        // Then
        if case .matched(let id, _) = result {
            #expect(id == "p2")
        } else {
            Issue.record("Expected .matched for alias SAZ, got \(result)")
        }
    }

    // MARK: - Display name exact match

    @Test("display name exact match returns matched")
    func test_match_displayNameExact_returnsMatched() {
        // Given
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p1", displayName: "Jake", aliases: [])
        ])

        // When
        let result = matcher.match(token: "Jake")

        // Then
        if case .matched(let id, _) = result {
            #expect(id == "p1")
        } else {
            Issue.record("Expected .matched for Jake, got \(result)")
        }
    }

    // MARK: - Display name prefix

    @Test("unique prefix returns matched")
    func test_match_uniquePrefix_returnsMatched() {
        // Given: "Michael" is the only player whose name starts with "Mic"
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p1", displayName: "Michael", aliases: []),
            (playerID: "p2", displayName: "Jake", aliases: [])
        ])

        // When
        let result = matcher.match(token: "Mic")

        // Then: "Mic" uniquely prefixes "Michael"
        if case .matched(let id, _) = result {
            #expect(id == "p1")
        } else {
            Issue.record("Expected .matched for unique prefix Mic, got \(result)")
        }
    }

    @Test("ambiguous prefix returns ambiguous")
    func test_match_ambiguousPrefix_returnsAmbiguous() {
        // Given: Both Mike and Michelle start with "Mi"
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p1", displayName: "Mike", aliases: []),
            (playerID: "p2", displayName: "Michelle", aliases: [])
        ])

        // When
        let result = matcher.match(token: "Mi")

        // Then
        if case .ambiguous = result { } else {
            Issue.record("Expected .ambiguous for shared prefix Mi, got \(result)")
        }
    }

    // MARK: - Levenshtein distance

    @Test("high similarity (>=80%) returns matched")
    func test_match_highSimilarity_returnsMatched() {
        // Given: "Jakee" has similarity 4/5 = 80% to "Jakee" vs "Jake" (1 deletion = 1/5 = 80% sim)
        // Actually "Jakes" vs "Jake": distance=1, maxLen=5, similarity=0.8 → accept
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p1", displayName: "Jake", aliases: [])
        ])

        // When: "Jakes" is 80% similar to "Jake" (1 char diff out of 5)
        let result = matcher.match(token: "Jakes")

        // Then: 1 - 1/5 = 0.8 → accepted
        if case .matched(let id, _) = result {
            #expect(id == "p1")
        } else {
            Issue.record("Expected .matched for Jakes~Jake (80% sim), got \(result)")
        }
    }

    @Test("medium similarity (50-80%) returns ambiguous via Levenshtein")
    func test_match_mediumSimilarity_returnsAmbiguous() {
        // Given: "Jako" vs "Jake" → distance=1, maxLen=4, similarity=0.75 → ambiguous (50-80%)
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p1", displayName: "Jake", aliases: [])
        ])

        // When
        let result = matcher.match(token: "Jako")

        // Then: 75% similarity falls in ambiguous range
        if case .ambiguous(let candidates) = result {
            #expect(candidates.count == 1)
            #expect(candidates[0].playerID == "p1")
        } else {
            Issue.record("Expected .ambiguous for Jako~Jake (75% sim), got \(result)")
        }
    }

    @Test("low similarity (<50%) returns unmatched")
    func test_match_lowSimilarity_returnsUnmatched() {
        // Given
        let matcher = FuzzyNameMatcher(players: [
            (playerID: "p1", displayName: "Jake", aliases: [])
        ])

        // When: completely unrelated token
        let result = matcher.match(token: "xyz")

        // Then
        if case .unmatched = result { } else {
            Issue.record("Expected .unmatched for xyz vs Jake, got \(result)")
        }
    }

    // MARK: - No players

    @Test("empty player list returns unmatched")
    func test_match_emptyPlayerList_returnsUnmatched() {
        // Given
        let matcher = FuzzyNameMatcher(players: [])

        // When
        let result = matcher.match(token: "anyone")

        // Then
        if case .unmatched = result { } else {
            Issue.record("Expected .unmatched for empty player list, got \(result)")
        }
    }
}
