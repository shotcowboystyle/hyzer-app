import Testing
import Foundation
@testable import HyzerKit

@Suite("VoiceParseResult Codable roundtrip")
struct VoiceParseResultCodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - ScoreCandidate

    @Test("ScoreCandidate encode/decode roundtrip preserves all fields")
    func test_scoreCandidate_roundtrip() throws {
        let original = ScoreCandidate(playerID: "player-42", displayName: "Alice", strokeCount: 3)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ScoreCandidate.self, from: data)
        #expect(decoded.playerID == "player-42")
        #expect(decoded.displayName == "Alice")
        #expect(decoded.strokeCount == 3)
    }

    // MARK: - UnresolvedCandidate

    @Test("UnresolvedCandidate encode/decode roundtrip preserves all fields")
    func test_unresolvedCandidate_roundtrip() throws {
        let original = UnresolvedCandidate(spokenName: "Jake", strokeCount: 5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(UnresolvedCandidate.self, from: data)
        #expect(decoded.spokenName == "Jake")
        #expect(decoded.strokeCount == 5)
    }

    // MARK: - VoiceParseResult.success

    @Test("VoiceParseResult.success roundtrip preserves candidates")
    func test_voiceParseResult_success_roundtrip() throws {
        let candidates = [
            ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3),
            ScoreCandidate(playerID: "p2", displayName: "Bob", strokeCount: 4)
        ]
        let original = VoiceParseResult.success(candidates)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoiceParseResult.self, from: data)

        guard case .success(let decodedCandidates) = decoded else {
            Issue.record("Expected .success case")
            return
        }
        #expect(decodedCandidates.count == 2)
        #expect(decodedCandidates[0].playerID == "p1")
        #expect(decodedCandidates[0].strokeCount == 3)
        #expect(decodedCandidates[1].displayName == "Bob")
    }

    @Test("VoiceParseResult.success encodes correct type field")
    func test_voiceParseResult_success_typeField() throws {
        let original = VoiceParseResult.success([])
        let data = try encoder.encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "success")
    }

    // MARK: - VoiceParseResult.partial

    @Test("VoiceParseResult.partial roundtrip preserves recognized and unresolved")
    func test_voiceParseResult_partial_roundtrip() throws {
        let recognized = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 4)]
        let unresolved = [UnresolvedCandidate(spokenName: "Unknown", strokeCount: 6)]
        let original = VoiceParseResult.partial(recognized: recognized, unresolved: unresolved)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoiceParseResult.self, from: data)

        guard case .partial(let r, let u) = decoded else {
            Issue.record("Expected .partial case")
            return
        }
        #expect(r.count == 1)
        #expect(r[0].playerID == "p1")
        #expect(u.count == 1)
        #expect(u[0].spokenName == "Unknown")
        #expect(u[0].strokeCount == 6)
    }

    @Test("VoiceParseResult.partial encodes correct type field")
    func test_voiceParseResult_partial_typeField() throws {
        let original = VoiceParseResult.partial(recognized: [], unresolved: [])
        let data = try encoder.encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "partial")
    }

    // MARK: - VoiceParseResult.failed

    @Test("VoiceParseResult.failed roundtrip preserves transcript")
    func test_voiceParseResult_failed_roundtrip() throws {
        let original = VoiceParseResult.failed(transcript: "I didn't catch that")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoiceParseResult.self, from: data)

        guard case .failed(let transcript) = decoded else {
            Issue.record("Expected .failed case")
            return
        }
        #expect(transcript == "I didn't catch that")
    }

    @Test("VoiceParseResult.failed encodes correct type field")
    func test_voiceParseResult_failed_typeField() throws {
        let original = VoiceParseResult.failed(transcript: "")
        let data = try encoder.encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "failed")
    }

    // MARK: - VoiceParseError

    @Test("VoiceParseError microphonePermissionDenied roundtrip")
    func test_voiceParseError_microphonePermissionDenied_roundtrip() throws {
        let original = VoiceParseError.microphonePermissionDenied
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoiceParseError.self, from: data)
        #expect(decoded == .microphonePermissionDenied)
    }

    @Test("VoiceParseError recognitionUnavailable roundtrip")
    func test_voiceParseError_recognitionUnavailable_roundtrip() throws {
        let original = VoiceParseError.recognitionUnavailable
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoiceParseError.self, from: data)
        #expect(decoded == .recognitionUnavailable)
    }

    @Test("VoiceParseError noSpeechDetected roundtrip")
    func test_voiceParseError_noSpeechDetected_roundtrip() throws {
        let original = VoiceParseError.noSpeechDetected
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoiceParseError.self, from: data)
        #expect(decoded == .noSpeechDetected)
    }

    // MARK: - VoicePlayerEntry

    @Test("VoicePlayerEntry encode/decode roundtrip preserves all fields including aliases")
    func test_voicePlayerEntry_roundtrip() throws {
        let original = VoicePlayerEntry(playerID: "p99", displayName: "Charlie", aliases: ["Chuck", "C"])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoicePlayerEntry.self, from: data)
        #expect(decoded.playerID == "p99")
        #expect(decoded.displayName == "Charlie")
        #expect(decoded.aliases == ["Chuck", "C"])
    }

    @Test("VoicePlayerEntry with empty aliases roundtrip")
    func test_voicePlayerEntry_emptyAliases_roundtrip() throws {
        let original = VoicePlayerEntry(playerID: "p1", displayName: "Alice", aliases: [])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(VoicePlayerEntry.self, from: data)
        #expect(decoded.aliases.isEmpty)
    }
}
