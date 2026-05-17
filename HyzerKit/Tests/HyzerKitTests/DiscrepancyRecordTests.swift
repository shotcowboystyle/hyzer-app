import Testing
import Foundation
import CloudKit
@testable import HyzerKit

/// Tests for `DiscrepancyRecord` DTO — PII allowlist verification and CKRecord round-trip.
///
/// The PII allowlist test (test_toCKRecord_writesExactKeySet) is the most important test
/// in Story 12.3 — it is the structural guarantee of PMVP-NFR1 for the discrepancy
/// notification path. Treat any regression as a P0 release blocker.
@Suite("DiscrepancyRecord")
struct DiscrepancyRecordTests {

    private func makeRecord() -> DiscrepancyRecord {
        DiscrepancyRecord(
            id: UUID(),
            roundID: UUID(),
            organizerID: UUID(),
            playerID: "player-abc",
            holeNumber: 7,
            createdAt: Date()
        )
    }

    // MARK: - PII allowlist (AC #5, PMVP-NFR1) — P0 release blocker if it regresses

    @Test("toCKRecord writes exactly the allowed key set — no PII fields")
    func test_toCKRecord_writesExactKeySet() {
        let ckRecord = makeRecord().toCKRecord()
        let keys = Set(ckRecord.allKeys())

        let allowedKeys: Set<String> = ["roundID", "organizerID", "playerID", "holeNumber", "createdAt"]
        #expect(keys == allowedKeys, "Exact key set must match PII allowlist")

        // Explicitly assert blocked fields are absent
        #expect(!keys.contains("playerName"))
        #expect(!keys.contains("displayName"))
        #expect(!keys.contains("iCloudRecordName"))
        #expect(!keys.contains("email"))
        #expect(!keys.contains("courseName"))
        #expect(!keys.contains("strokeCount"))
        #expect(!keys.contains("eventID1"))
        #expect(!keys.contains("eventID2"))
        #expect(!keys.contains("resolvedByEventID"))
        #expect(!keys.contains("status"))
    }

    @Test("toCKRecord uses Discrepancy record type")
    func test_toCKRecord_recordType() {
        let ckRecord = makeRecord().toCKRecord()
        #expect(ckRecord.recordType == DiscrepancyRecord.recordType)
        #expect(ckRecord.recordType == "Discrepancy")
    }

    @Test("toCKRecord uses discrepancy UUID as record name")
    func test_toCKRecord_recordName() {
        let dto = makeRecord()
        let ckRecord = dto.toCKRecord()
        #expect(ckRecord.recordID.recordName == dto.id.uuidString)
    }

    // MARK: - CKRecord round-trip

    @Test("init(from:) round-trips all fields correctly")
    func test_init_fromCKRecord_roundTrip() throws {
        let original = makeRecord()
        let ckRecord = original.toCKRecord()

        guard let restored = DiscrepancyRecord(from: ckRecord) else {
            Issue.record("init(from:) returned nil for a valid CKRecord")
            return
        }

        #expect(restored.id == original.id)
        #expect(restored.roundID == original.roundID)
        #expect(restored.organizerID == original.organizerID)
        #expect(restored.playerID == original.playerID)
        #expect(restored.holeNumber == original.holeNumber)
        #expect(abs(restored.createdAt.timeIntervalSince(original.createdAt)) < 1)
    }

    @Test("init(from:) returns nil when roundID is missing")
    func test_init_fromCKRecord_missingRoundID_returnsNil() {
        let ckRecord = makeRecord().toCKRecord()
        ckRecord["roundID"] = nil
        #expect(DiscrepancyRecord(from: ckRecord) == nil)
    }

    @Test("init(from:) returns nil when organizerID is missing")
    func test_init_fromCKRecord_missingOrganizerID_returnsNil() {
        let ckRecord = makeRecord().toCKRecord()
        ckRecord["organizerID"] = nil
        #expect(DiscrepancyRecord(from: ckRecord) == nil)
    }

    @Test("init(from:) returns nil when playerID is missing")
    func test_init_fromCKRecord_missingPlayerID_returnsNil() {
        let ckRecord = makeRecord().toCKRecord()
        ckRecord["playerID"] = nil
        #expect(DiscrepancyRecord(from: ckRecord) == nil)
    }

    @Test("init(from:) returns nil when holeNumber is missing")
    func test_init_fromCKRecord_missingHoleNumber_returnsNil() {
        let ckRecord = makeRecord().toCKRecord()
        ckRecord["holeNumber"] = nil
        #expect(DiscrepancyRecord(from: ckRecord) == nil)
    }

    @Test("init(from:) returns nil when createdAt is missing")
    func test_init_fromCKRecord_missingCreatedAt_returnsNil() {
        let ckRecord = makeRecord().toCKRecord()
        ckRecord["createdAt"] = nil
        #expect(DiscrepancyRecord(from: ckRecord) == nil)
    }

    @Test("init(from:) returns nil for wrong record type")
    func test_init_fromCKRecord_wrongRecordType_returnsNil() {
        let record = CKRecord(recordType: "WrongType", recordID: CKRecord.ID(recordName: UUID().uuidString))
        record["roundID"] = UUID().uuidString as CKRecordValue
        record["organizerID"] = UUID().uuidString as CKRecordValue
        record["playerID"] = "player-abc" as CKRecordValue
        record["holeNumber"] = 3 as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        #expect(DiscrepancyRecord(from: record) == nil)
    }

    @Test("init(from:) returns nil for malformed roundID UUID")
    func test_init_fromCKRecord_malformedRoundID_returnsNil() {
        let ckRecord = makeRecord().toCKRecord()
        ckRecord["roundID"] = "not-a-uuid" as CKRecordValue
        #expect(DiscrepancyRecord(from: ckRecord) == nil)
    }
}
