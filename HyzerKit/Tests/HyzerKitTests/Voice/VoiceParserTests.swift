import Testing
import Foundation
@testable import HyzerKit

@Suite("VoiceParser")
struct VoiceParserTests {

    let parser = VoiceParser()

    // Standard three-player roster used across tests
    let players: [VoicePlayerEntry] = [
        VoicePlayerEntry(playerID: "p1", displayName: "Michael", aliases: ["Mike"]),
        VoicePlayerEntry(playerID: "p2", displayName: "Jake", aliases: []),
        VoicePlayerEntry(playerID: "p3", displayName: "Sarah", aliases: [])
    ]

    // MARK: - AC2: Full transcript tokenize-classify-assemble

    @Test("three-player transcript returns success with all scores")
    func test_parse_threePlayerTranscript_returnsSuccess() {
        // Given
        let transcript = "Mike 3, Jake 4, Sarah 2"

        // When
        let result = parser.parse(transcript: transcript, players: players)

        // Then
        if case .success(let candidates) = result {
            #expect(candidates.count == 3)
            let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.playerID, $0) })
            #expect(byID["p1"]?.strokeCount == 3)
            #expect(byID["p2"]?.strokeCount == 4)
            #expect(byID["p3"]?.strokeCount == 2)
        } else {
            Issue.record("Expected .success, got \(result)")
        }
    }

    // MARK: - AC4: Subset scoring valid

    @Test("single-player subset transcript returns success")
    func test_parse_subsetOnePlayer_returnsSuccess() {
        // Given: only Jake scored
        let transcript = "Jake 4"

        // When
        let result = parser.parse(transcript: transcript, players: players)

        // Then: subset scoring is valid
        if case .success(let candidates) = result {
            #expect(candidates.count == 1)
            #expect(candidates[0].playerID == "p2")
            #expect(candidates[0].strokeCount == 4)
        } else {
            Issue.record("Expected .success for subset scoring Jake 4, got \(result)")
        }
    }

    // MARK: - AC2: Partial result when some names unresolved

    @Test("unresolvable name returns partial with recognized and unresolved")
    func test_parse_unknownName_returnsPartial() {
        // Given: "Zork" is not a known player
        let transcript = "Jake 3, Zork 5"

        // When
        let result = parser.parse(transcript: transcript, players: players)

        // Then
        if case .partial(let recognized, let unresolved) = result {
            #expect(recognized.count == 1)
            #expect(recognized[0].playerID == "p2")
            #expect(unresolved.contains("Zork"))
        } else {
            Issue.record("Expected .partial for unknown name Zork, got \(result)")
        }
    }

    // MARK: - AC2: Failed result when no names resolved

    @Test("no recognizable content returns failed")
    func test_parse_noRecognizableContent_returnsFailed() {
        // Given
        let transcript = "blah blah blah"

        // When
        let result = parser.parse(transcript: transcript, players: players)

        // Then
        if case .failed(let t) = result {
            #expect(t == transcript)
        } else {
            Issue.record("Expected .failed for unrecognizable transcript, got \(result)")
        }
    }

    @Test("empty transcript returns failed")
    func test_parse_emptyTranscript_returnsFailed() {
        // Given
        let result = parser.parse(transcript: "", players: players)
        // Then
        if case .failed = result { } else {
            Issue.record("Expected .failed for empty transcript, got \(result)")
        }
    }

    // MARK: - AC3: Alias matching

    @Test("alias in transcript matches correct player")
    func test_parse_alias_matchesCorrectPlayer() {
        // Given: "Mike" is an alias for Michael (p1)
        let transcript = "Mike 3"

        // When
        let result = parser.parse(transcript: transcript, players: players)

        // Then
        if case .success(let candidates) = result {
            #expect(candidates[0].playerID == "p1")
            #expect(candidates[0].displayName == "Michael")
            #expect(candidates[0].strokeCount == 3)
        } else {
            Issue.record("Expected .success with Michael matched via Mike alias, got \(result)")
        }
    }

    // MARK: - Word numbers

    @Test("word number in transcript is parsed correctly")
    func test_parse_wordNumber_parsedCorrectly() {
        // Given
        let transcript = "Jake three"

        // When
        let result = parser.parse(transcript: transcript, players: players)

        // Then
        if case .success(let candidates) = result {
            #expect(candidates[0].strokeCount == 3)
        } else {
            Issue.record("Expected .success with strokeCount=3 for 'three', got \(result)")
        }
    }

    // MARK: - Name without following number is skipped

    @Test("name with no following number is skipped, paired name succeeds")
    func test_parse_nameWithNoNumber_skipped() {
        // Given: Mike has no number, Jake does
        let transcript = "Mike Jake 4"

        // When
        let result = parser.parse(transcript: transcript, players: players)

        // Then: Mike is dropped, Jake 4 succeeds
        if case .success(let candidates) = result {
            #expect(candidates.count == 1)
            #expect(candidates[0].playerID == "p2")
            #expect(candidates[0].strokeCount == 4)
        } else {
            Issue.record("Expected .success with only Jake 4, got \(result)")
        }
    }

    // MARK: - AC6: VoiceParseResult conforms to Sendable

    @Test("VoiceParseResult is Sendable")
    func test_voiceParseResult_isSendable() {
        // Given: Compile-time check that VoiceParseResult conforms to Sendable
        let result: any Sendable = VoiceParseResult.success([])
        // Then: assignment compiles → Sendable conformance verified
        _ = result
    }
}
