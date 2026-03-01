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
        let snapshot = StandingsSnapshot(standings: standings, roundID: roundID, currentHole: 5, lastUpdatedAt: date)
        let original = WatchMessage.standingsUpdate(snapshot)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WatchMessage.self, from: data)

        guard case .standingsUpdate(let decodedSnapshot) = decoded else {
            Issue.record("Expected standingsUpdate case")
            return
        }
        #expect(decodedSnapshot.roundID == roundID)
        #expect(decodedSnapshot.currentHole == 5)
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
        let snapshot = StandingsSnapshot(standings: standings, roundID: roundID, currentHole: 9, lastUpdatedAt: date)

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(StandingsSnapshot.self, from: data)

        #expect(decoded.roundID == roundID)
        #expect(decoded.currentHole == 9)
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
        let s1 = StandingsSnapshot(standings: [], roundID: roundID, currentHole: 3, lastUpdatedAt: date)
        let s2 = StandingsSnapshot(standings: [], roundID: roundID, currentHole: 3, lastUpdatedAt: date)
        #expect(s1 == s2)
    }
}
