import Testing
import Foundation
@testable import HyzerKit

@Suite("TokenClassifier")
struct TokenClassifierTests {

    let classifier = TokenClassifier()

    // MARK: - Digit strings in range 1–10

    @Test("digit string in range 1-10 returns number")
    func test_classify_digitInRange_returnsNumber() {
        // Given/When/Then
        for n in 1...10 {
            let result = classifier.classify(raw: "\(n)")
            if case .number(let val) = result {
                #expect(val == n)
            } else {
                Issue.record("Expected .number(\(n)) for '\(n)', got \(result)")
            }
        }
    }

    @Test("digit string zero returns noise")
    func test_classify_digitZero_returnsNoise() {
        // Given
        let result = classifier.classify(raw: "0")
        // Then
        if case .noise = result { } else {
            Issue.record("Expected .noise for 0, got \(result)")
        }
    }

    @Test("digit string above 10 returns noise")
    func test_classify_digitAboveTen_returnsNoise() {
        // Given/When/Then
        for n in [11, 15, 100] {
            let result = classifier.classify(raw: "\(n)")
            if case .noise = result { } else {
                Issue.record("Expected .noise for \(n), got \(result)")
            }
        }
    }

    // MARK: - Word numbers

    @Test("word numbers one through ten return correct number")
    func test_classify_wordNumbers_returnNumber() {
        // Given
        let words: [(String, Int)] = [
            ("one", 1), ("two", 2), ("three", 3), ("four", 4), ("five", 5),
            ("six", 6), ("seven", 7), ("eight", 8), ("nine", 9), ("ten", 10)
        ]

        // When/Then
        for (word, expected) in words {
            let result = classifier.classify(raw: word)
            if case .number(let val) = result {
                #expect(val == expected, "Expected \(expected) for '\(word)'")
            } else {
                Issue.record("Expected .number(\(expected)) for '\(word)', got \(result)")
            }
        }
    }

    @Test("word number with uppercase is classified as number")
    func test_classify_wordNumberUppercase_returnsNumber() {
        // Given: classifier lowercases before lookup
        let result = classifier.classify(raw: "Three")
        // Then
        if case .number(let val) = result {
            #expect(val == 3)
        } else {
            Issue.record("Expected .number(3) for 'Three', got \(result)")
        }
    }

    @Test("out-of-range word number returns noise")
    func test_classify_wordNumberOutOfRange_returnsNoise() {
        // Given: "thirty" is not in the valid number map
        let result = classifier.classify(raw: "thirty")
        // Then
        if case .noise = result { } else {
            Issue.record("Expected .noise for 'thirty', got \(result)")
        }
    }

    // MARK: - Name tokens

    @Test("alphabetic token returns name")
    func test_classify_alphabeticToken_returnsName() {
        // Given
        let result = classifier.classify(raw: "Mike")
        // Then
        if case .name(let s) = result {
            #expect(s == "Mike")
        } else {
            Issue.record("Expected .name(Mike), got \(result)")
        }
    }

    @Test("token with punctuation returns name after trimming")
    func test_classify_tokenWithTrailingPunctuation_returnsNameTrimmed() {
        // Given: speech recognizer sometimes appends punctuation
        let result = classifier.classify(raw: "Jake,")
        // Then
        if case .name(let s) = result {
            #expect(s == "Jake")
        } else {
            Issue.record("Expected .name(Jake) for 'Jake,', got \(result)")
        }
    }

    // MARK: - Noise tokens

    @Test("alphanumeric mixed token returns noise")
    func test_classify_mixedAlphanumeric_returnsNoise() {
        // Given
        let result = classifier.classify(raw: "4a")
        // Then
        if case .noise = result { } else {
            Issue.record("Expected .noise for '4a', got \(result)")
        }
    }

    @Test("empty string returns noise")
    func test_classify_emptyString_returnsNoise() {
        // Given
        let result = classifier.classify(raw: "")
        // Then
        if case .noise = result { } else {
            Issue.record("Expected .noise for empty string, got \(result)")
        }
    }
}
