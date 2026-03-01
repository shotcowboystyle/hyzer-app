import Testing
import Foundation
@testable import HyzerKit

@Suite("WatchMessage encode/decode")
struct WatchMessageTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - standingsUpdate roundtrip

    @Test("standingsUpdate roundtrip preserves all fields")
    func test_standingsUpdate_roundtrip() throws {
        let roundID = UUID()
        let standings = [
            Standing(playerID: "player-1", playerName: "Alice", position: 1, totalStrokes: 36, holesPlayed: 9, scoreRelativeToPar: -3),
            Standing(playerID: "player-2", playerName: "Bob", position: 2, totalStrokes: 40, holesPlayed: 9, scoreRelativeToPar: 1)
        ]
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = StandingsSnapshot(standings: standings, roundID: roundID, currentHole: 5, currentHolePar: 4, lastUpdatedAt: date)
        let original = WatchMessage.standingsUpdate(snapshot)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WatchMessage.self, from: data)

        guard case .standingsUpdate(let decodedSnapshot) = decoded else {
            Issue.record("Expected standingsUpdate case")
            return
        }
        #expect(decodedSnapshot.roundID == roundID)
        #expect(decodedSnapshot.currentHole == 5)
        #expect(decodedSnapshot.currentHolePar == 4)
        #expect(decodedSnapshot.lastUpdatedAt == date)
        #expect(decodedSnapshot.standings.count == 2)
        #expect(decodedSnapshot.standings[0].playerID == "player-1")
        #expect(decodedSnapshot.standings[0].playerName == "Alice")
        #expect(decodedSnapshot.standings[0].position == 1)
        #expect(decodedSnapshot.standings[0].scoreRelativeToPar == -3)
        #expect(decodedSnapshot.standings[1].playerID == "player-2")
        #expect(decodedSnapshot.standings[1].scoreRelativeToPar == 1)
    }

    // MARK: - scoreEvent roundtrip

    @Test("scoreEvent roundtrip preserves all fields")
    func test_scoreEvent_roundtrip() throws {
        let roundID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_100)
        let payload = WatchScorePayload(
            roundID: roundID,
            playerID: "player-1",
            holeNumber: 7,
            strokeCount: 4,
            timestamp: timestamp
        )
        let original = WatchMessage.scoreEvent(payload)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WatchMessage.self, from: data)

        guard case .scoreEvent(let decodedPayload) = decoded else {
            Issue.record("Expected scoreEvent case")
            return
        }
        #expect(decodedPayload.roundID == roundID)
        #expect(decodedPayload.playerID == "player-1")
        #expect(decodedPayload.holeNumber == 7)
        #expect(decodedPayload.strokeCount == 4)
        #expect(decodedPayload.timestamp == timestamp)
    }

    // MARK: - JSON type field

    @Test("standingsUpdate encodes correct type discriminator")
    func test_standingsUpdate_typeField() throws {
        let snapshot = StandingsSnapshot(standings: [], roundID: UUID(), currentHole: 1)
        let message = WatchMessage.standingsUpdate(snapshot)
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "standingsUpdate")
    }

    @Test("scoreEvent encodes correct type discriminator")
    func test_scoreEvent_typeField() throws {
        let payload = WatchScorePayload(roundID: UUID(), playerID: "p1", holeNumber: 1, strokeCount: 3)
        let message = WatchMessage.scoreEvent(payload)
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "scoreEvent")
    }

    @Test("decoding unknown type throws")
    func test_unknownType_throws() throws {
        let json = #"{"type":"unknownCase","unknownCase":{}}"#.data(using: .utf8)!
        #expect(throws: Error.self) {
            try decoder.decode(WatchMessage.self, from: json)
        }
    }

    // MARK: - voiceRequest roundtrip

    @Test("voiceRequest roundtrip preserves all fields")
    func test_voiceRequest_roundtrip() throws {
        let roundID = UUID()
        let players = [
            VoicePlayerEntry(playerID: "p1", displayName: "Alice", aliases: ["Al"]),
            VoicePlayerEntry(playerID: "p2", displayName: "Bob", aliases: [])
        ]
        let request = WatchVoiceRequest(roundID: roundID, holeNumber: 9, playerEntries: players)
        let original = WatchMessage.voiceRequest(request)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WatchMessage.self, from: data)

        guard case .voiceRequest(let decodedRequest) = decoded else {
            Issue.record("Expected voiceRequest case")
            return
        }
        #expect(decodedRequest.roundID == roundID)
        #expect(decodedRequest.holeNumber == 9)
        #expect(decodedRequest.playerEntries.count == 2)
        #expect(decodedRequest.playerEntries[0].playerID == "p1")
        #expect(decodedRequest.playerEntries[0].displayName == "Alice")
        #expect(decodedRequest.playerEntries[0].aliases == ["Al"])
        #expect(decodedRequest.playerEntries[1].playerID == "p2")
    }

    @Test("voiceRequest encodes correct type discriminator")
    func test_voiceRequest_typeField() throws {
        let request = WatchVoiceRequest(roundID: UUID(), holeNumber: 1, playerEntries: [])
        let message = WatchMessage.voiceRequest(request)
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "voiceRequest")
    }

    // MARK: - voiceResult roundtrip

    @Test("voiceResult with success roundtrip preserves all fields")
    func test_voiceResult_success_roundtrip() throws {
        let roundID = UUID()
        let candidates = [
            ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 3),
            ScoreCandidate(playerID: "p2", displayName: "Bob", strokeCount: 5)
        ]
        let result = WatchVoiceResult(result: .success(candidates), holeNumber: 7, roundID: roundID)
        let original = WatchMessage.voiceResult(result)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WatchMessage.self, from: data)

        guard case .voiceResult(let decodedResult) = decoded else {
            Issue.record("Expected voiceResult case")
            return
        }
        #expect(decodedResult.holeNumber == 7)
        #expect(decodedResult.roundID == roundID)
        guard case .success(let decodedCandidates) = decodedResult.result else {
            Issue.record("Expected .success parse result")
            return
        }
        #expect(decodedCandidates.count == 2)
        #expect(decodedCandidates[0].playerID == "p1")
        #expect(decodedCandidates[0].strokeCount == 3)
    }

    @Test("voiceResult with partial roundtrip preserves all fields")
    func test_voiceResult_partial_roundtrip() throws {
        let roundID = UUID()
        let recognized = [ScoreCandidate(playerID: "p1", displayName: "Alice", strokeCount: 4)]
        let unresolved = [UnresolvedCandidate(spokenName: "Charlie", strokeCount: 6)]
        let result = WatchVoiceResult(
            result: .partial(recognized: recognized, unresolved: unresolved),
            holeNumber: 3,
            roundID: roundID
        )
        let original = WatchMessage.voiceResult(result)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WatchMessage.self, from: data)

        guard case .voiceResult(let decodedResult) = decoded else {
            Issue.record("Expected voiceResult case")
            return
        }
        guard case .partial(let r, let u) = decodedResult.result else {
            Issue.record("Expected .partial parse result")
            return
        }
        #expect(r.count == 1)
        #expect(u.count == 1)
        #expect(u[0].spokenName == "Charlie")
        #expect(u[0].strokeCount == 6)
    }

    @Test("voiceResult with failed roundtrip preserves transcript")
    func test_voiceResult_failed_roundtrip() throws {
        let result = WatchVoiceResult(
            result: .failed(transcript: "could not understand"),
            holeNumber: 1,
            roundID: UUID()
        )
        let original = WatchMessage.voiceResult(result)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WatchMessage.self, from: data)

        guard case .voiceResult(let decodedResult) = decoded else {
            Issue.record("Expected voiceResult case")
            return
        }
        guard case .failed(let transcript) = decodedResult.result else {
            Issue.record("Expected .failed parse result")
            return
        }
        #expect(transcript == "could not understand")
    }

    @Test("voiceResult encodes correct type discriminator")
    func test_voiceResult_typeField() throws {
        let result = WatchVoiceResult(result: .failed(transcript: ""), holeNumber: 1, roundID: UUID())
        let message = WatchMessage.voiceResult(result)
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["type"] as? String == "voiceResult")
    }
}

// MARK: - StandingsSnapshot serialisation tests

@Suite("StandingsSnapshot serialisation")
struct StandingsSnapshotTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("serialisation roundtrip preserves all fields")
    func test_snapshotRoundtrip_preservesAllFields() throws {
        let roundID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let standings = [
            Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 30, holesPlayed: 9, scoreRelativeToPar: -3)
        ]
        let snapshot = StandingsSnapshot(standings: standings, roundID: roundID, currentHole: 9, currentHolePar: 5, lastUpdatedAt: date)

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(StandingsSnapshot.self, from: data)

        #expect(decoded.roundID == roundID)
        #expect(decoded.currentHole == 9)
        #expect(decoded.currentHolePar == 5)
        #expect(decoded.lastUpdatedAt == date)
        #expect(decoded.standings.count == 1)
        #expect(decoded.standings[0].playerName == "Alice")
        #expect(decoded.standings[0].scoreRelativeToPar == -3)
    }

    @Test("empty standings serialises and deserialises")
    func test_emptyStandings_roundtrip() throws {
        let snapshot = StandingsSnapshot(standings: [], roundID: UUID(), currentHole: 1)
        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(StandingsSnapshot.self, from: data)
        #expect(decoded.standings.isEmpty)
    }

    @Test("equatable: two snapshots with same data are equal")
    func test_equatable_sameData() {
        let roundID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let s1 = StandingsSnapshot(standings: [], roundID: roundID, currentHole: 3, currentHolePar: 4, lastUpdatedAt: date)
        let s2 = StandingsSnapshot(standings: [], roundID: roundID, currentHole: 3, currentHolePar: 4, lastUpdatedAt: date)
        #expect(s1 == s2)
    }

    @Test("decoding JSON without currentHolePar falls back to par 3")
    func test_decode_missingCurrentHolePar_defaultsToThree() throws {
        let json = """
        {
          "standings": [],
          "roundID": "12345678-1234-1234-1234-123456789012",
          "currentHole": 7,
          "lastUpdatedAt": 1700000000.0
        }
        """.data(using: .utf8)!
        let decoded = try decoder.decode(StandingsSnapshot.self, from: json)
        #expect(decoded.currentHolePar == 3)
        #expect(decoded.currentHole == 7)
    }
}
