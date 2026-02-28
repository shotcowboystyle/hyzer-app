import Foundation

/// Classifies individual string tokens from a voice transcript.
///
/// `nonisolated` struct — stateless, `Sendable`, no actor isolation required.
public struct TokenClassifier: Sendable {

    /// Broad number-word map: includes out-of-range words so they can be rejected as noise
    /// rather than incorrectly classified as player names.
    private static let wordToNumber: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
        "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
        "eighty": 80, "ninety": 90, "hundred": 100, "zero": 0
    ]

    public init() {}

    /// Classifies a single string token into `.name`, `.number`, or `.noise`.
    ///
    /// - `.number(Int)`: digit string or word number in range 1–10
    /// - `.name(String)`: purely alphabetic token (not a word number)
    /// - `.noise(String)`: everything else, or out-of-range numbers
    public func classify(raw: String) -> Token {
        let cleaned = raw.trimmingCharacters(in: .punctuationCharacters).lowercased()
        guard !cleaned.isEmpty else { return .noise(raw) }

        // Digit string
        if let int = Int(cleaned) {
            return (1...10).contains(int) ? .number(int) : .noise(raw)
        }

        // Word number — range check: 1–10 valid, outside range → noise (not a player name)
        if let int = Self.wordToNumber[cleaned] {
            return (1...10).contains(int) ? .number(int) : .noise(raw)
        }

        // Purely alphabetic → name candidate
        let isAlphabetic = cleaned.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
        if isAlphabetic {
            return .name(raw.trimmingCharacters(in: .punctuationCharacters))
        }

        return .noise(raw)
    }
}
