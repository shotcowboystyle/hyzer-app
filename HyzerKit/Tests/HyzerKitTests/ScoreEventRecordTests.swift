import Testing
import Foundation
import CloudKit
@testable import HyzerKit

@Suite("ScoreEventRecord DTO")
struct ScoreEventRecordTests {

    // MARK: - init(from: ScoreEvent)

    @Test("init(from:ScoreEvent) copies all fields correctly")
    func test_initFromScoreEvent_copiesAllFields() {
        let roundID = UUID()
        let reporterID = UUID()
        let supersedesID = UUID()
        let event = ScoreEvent(
            roundID: roundID,
            holeNumber: 7,
            playerID: "player-abc",
            strokeCount: 4,
            reportedByPlayerID: reporterID,
            deviceID: "device-xyz"
        )
        event.supersedesEventID = supersedesID

        let dto = ScoreEventRecord(from: event)

        #expect(dto.id == event.id)
        #expect(dto.roundID == roundID)
        #expect(dto.holeNumber == 7)
        #expect(dto.playerID == "player-abc")
        #expect(dto.strokeCount == 4)
        #expect(dto.supersedesEventID == supersedesID)
        #expect(dto.reportedByPlayerID == reporterID)
        #expect(dto.deviceID == "device-xyz")
        #expect(dto.createdAt == event.createdAt)
    }

    // MARK: - CKRecord round-trip

    @Test("toCKRecord produces CKRecord with correct record type and record ID")
    func test_toCKRecord_recordTypeAndID() {
        let event = ScoreEvent.fixture()
        let dto = ScoreEventRecord(from: event)
        let record = dto.toCKRecord()

        #expect(record.recordType == "ScoreEvent")
        #expect(record.recordID.recordName == event.id.uuidString)
    }

    @Test("CKRecord round-trip preserves all required fields")
    func test_ckRecord_roundTrip_preservesAllFields() {
        let roundID = UUID()
        let reporterID = UUID()
        let event = ScoreEvent(
            roundID: roundID,
            holeNumber: 3,
            playerID: "guest:Alice",
            strokeCount: 2,
            reportedByPlayerID: reporterID,
            deviceID: "dev-001"
        )

        let dto = ScoreEventRecord(from: event)
        let ckRecord = dto.toCKRecord()
        guard let restored = ScoreEventRecord(from: ckRecord) else {
            Issue.record("ScoreEventRecord(from:) returned nil")
            return
        }

        #expect(restored.id == event.id)
        #expect(restored.roundID == roundID)
        #expect(restored.holeNumber == 3)
        #expect(restored.playerID == "guest:Alice")
        #expect(restored.strokeCount == 2)
        #expect(restored.supersedesEventID == nil)
        #expect(restored.reportedByPlayerID == reporterID)
        #expect(restored.deviceID == "dev-001")
    }

    @Test("CKRecord round-trip preserves non-nil supersedesEventID")
    func test_ckRecord_roundTrip_preservesSupersedesEventID() {
        let event = ScoreEvent.fixture()
        let supersedesID = UUID()
        event.supersedesEventID = supersedesID

        let ckRecord = ScoreEventRecord(from: event).toCKRecord()
        guard let restored = ScoreEventRecord(from: ckRecord) else {
            Issue.record("ScoreEventRecord(from:) returned nil")
            return
        }

        #expect(restored.supersedesEventID == supersedesID)
    }

    @Test("init(from:CKRecord) returns nil for wrong record type")
    func test_initFromCKRecord_wrongType_returnsNil() {
        let record = CKRecord(recordType: "Round")
        let dto = ScoreEventRecord(from: record)
        #expect(dto == nil)
    }

    @Test("init(from:CKRecord) returns nil when required fields are missing")
    func test_initFromCKRecord_missingFields_returnsNil() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "ScoreEvent", recordID: recordID)
        // Do NOT set any fields — all required fields missing
        let dto = ScoreEventRecord(from: record)
        #expect(dto == nil)
    }

    // MARK: - Sendable conformance

    @Test("ScoreEventRecord is Sendable and can be passed across concurrency boundaries")
    func test_scoreEventRecord_isSendable() async {
        let event = ScoreEvent.fixture()
        let dto = ScoreEventRecord(from: event)
        // Just verify it can be captured in an async context
        let captured = await Task.detached { dto }.value
        #expect(captured.id == dto.id)
    }
}
