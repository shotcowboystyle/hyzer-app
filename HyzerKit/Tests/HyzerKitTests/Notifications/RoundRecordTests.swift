import Testing
import Foundation
import CloudKit
@testable import HyzerKit

/// Tests for `RoundRecord` CKRecord conversion and PII gate enforcement.
///
/// The PII gate test (test_toCKRecord_piiAllowlist) is the most critical test in Story 12.1 —
/// it is the structural guarantee of PMVP-NFR1. Treat its failure as a P0 bug.
@Suite("RoundRecord")
struct RoundRecordTests {

    // MARK: - Round-trip

    @Test("RoundRecord → CKRecord → RoundRecord round-trip preserves all fields")
    func test_roundTrip_preservesAllFields() {
        let id = UUID()
        let organizerID = UUID()
        let createdAt = Date(timeIntervalSinceNow: -60)

        let original = RoundRecord(
            id: id,
            organizerID: organizerID,
            organizerFirstName: "Mike",
            courseName: "Cedar Creek",
            status: "active",
            playerIDs: [organizerID.uuidString, UUID().uuidString],
            createdAt: createdAt
        )

        let ckRecord = original.toCKRecord()
        let reconstructed = RoundRecord(from: ckRecord)

        #expect(reconstructed != nil)
        #expect(reconstructed?.id == id)
        #expect(reconstructed?.organizerID == organizerID)
        #expect(reconstructed?.organizerFirstName == "Mike")
        #expect(reconstructed?.courseName == "Cedar Creek")
        #expect(reconstructed?.status == "active")
        #expect(reconstructed?.playerIDs == original.playerIDs)
        // Date precision: CloudKit stores as Double seconds; allow 1-second tolerance
        #expect(abs((reconstructed?.createdAt ?? Date()).timeIntervalSince(createdAt)) < 1.0)
    }

    // MARK: - PII gate (PMVP-NFR1) — P0

    /// Asserts that `toCKRecord()` writes ONLY the documented allowlist of fields.
    /// No `displayName`, last names, `iCloudRecordName`, email, or score fields.
    @Test("toCKRecord only writes PII-safe allowlist of keys")
    func test_toCKRecord_piiAllowlist() {
        let record = RoundRecord(
            id: UUID(),
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Hawk Ridge",
            status: "active",
            playerIDs: [UUID().uuidString],
            createdAt: Date()
        )

        let ckRecord = record.toCKRecord()
        let actualKeys = Set(ckRecord.allKeys())

        // Exact allowlist — any addition requires an explicit PII review
        let allowedKeys: Set<String> = [
            "organizerID",
            "organizerFirstName",
            "courseName",
            "status",
            "playerIDs",
            "createdAt"
        ]

        // PII fields that must NEVER appear
        let forbiddenKeys: Set<String> = [
            "displayName",
            "iCloudRecordName",
            "email",
            "strokeCount",
            "holeNumber",
            "score",
            "lastName",
            "fullName"
        ]

        #expect(actualKeys == allowedKeys, "CKRecord keys \(actualKeys) must exactly match allowlist \(allowedKeys)")

        for forbidden in forbiddenKeys {
            #expect(!actualKeys.contains(forbidden), "PII field '\(forbidden)' must not appear in Round CKRecord")
        }
    }

    // MARK: - init?(from:) nil cases

    @Test("RoundRecord init?(from:) returns nil for wrong record type")
    func test_init_wrongRecordType_returnsNil() {
        let record = CKRecord(recordType: "ScoreEvent", recordID: CKRecord.ID(recordName: UUID().uuidString))
        #expect(RoundRecord(from: record) == nil)
    }

    @Test("RoundRecord init?(from:) returns nil when organizerID is missing")
    func test_init_missingOrganizerID_returnsNil() {
        let record = makeMinimalRecord()
        record["organizerID"] = nil
        #expect(RoundRecord(from: record) == nil)
    }

    @Test("RoundRecord init?(from:) returns nil when courseName is missing")
    func test_init_missingCourseName_returnsNil() {
        let record = makeMinimalRecord()
        record["courseName"] = nil
        #expect(RoundRecord(from: record) == nil)
    }

    @Test("RoundRecord init?(from:) returns nil when organizerID is malformed UUID")
    func test_init_malformedOrganizerID_returnsNil() {
        let record = makeMinimalRecord()
        record["organizerID"] = "not-a-uuid" as CKRecordValue
        #expect(RoundRecord(from: record) == nil)
    }

    @Test("RoundRecord record type constant is 'Round'")
    func test_recordType_isRound() {
        #expect(RoundRecord.recordType == "Round")
    }

    @Test("toCKRecord record ID uses round UUID as recordName")
    func test_toCKRecord_recordIDMatchesUUID() {
        let id = UUID()
        let record = RoundRecord(
            id: id,
            organizerID: UUID(),
            organizerFirstName: "Bob",
            courseName: "Pines",
            status: "active",
            playerIDs: [],
            createdAt: Date()
        )
        let ckRecord = record.toCKRecord()
        #expect(ckRecord.recordID.recordName == id.uuidString)
    }

    // MARK: - Story 12.2: Winner fields (Task 8.3)

    @Test("toCKRecord omits winnerFirstName and winnerScoreDisplay when nil")
    func test_toCKRecord_winnerFields_omittedWhenNil() {
        let record = RoundRecord(
            id: UUID(),
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Hawk Ridge",
            status: "active",
            playerIDs: [UUID().uuidString],
            createdAt: Date(),
            winnerFirstName: nil,
            winnerScoreDisplay: nil
        )

        let ckRecord = record.toCKRecord()
        let actualKeys = Set(ckRecord.allKeys())

        #expect(!actualKeys.contains("winnerFirstName"), "winnerFirstName must be omitted when nil — Story 12.1 active-state push backwards-compat")
        #expect(!actualKeys.contains("winnerScoreDisplay"), "winnerScoreDisplay must be omitted when nil")
    }

    @Test("toCKRecord writes winnerFirstName and winnerScoreDisplay when non-nil")
    func test_toCKRecord_winnerFields_writtenWhenNonNil() {
        let record = RoundRecord(
            id: UUID(),
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Hawk Ridge",
            status: "completed",
            playerIDs: [UUID().uuidString],
            createdAt: Date(),
            winnerFirstName: "Bob",
            winnerScoreDisplay: "-2"
        )

        let ckRecord = record.toCKRecord()

        #expect(ckRecord["winnerFirstName"] as? String == "Bob")
        #expect(ckRecord["winnerScoreDisplay"] as? String == "-2")
    }

    @Test("toCKRecord PII allowlist includes winner fields when set (extended)")
    func test_toCKRecord_piiAllowlist_withWinnerFields() {
        let record = RoundRecord(
            id: UUID(),
            organizerID: UUID(),
            organizerFirstName: "Alice",
            courseName: "Hawk Ridge",
            status: "completed",
            playerIDs: [UUID().uuidString],
            createdAt: Date(),
            winnerFirstName: "Bob",
            winnerScoreDisplay: "+2"
        )

        let ckRecord = record.toCKRecord()
        let actualKeys = Set(ckRecord.allKeys())

        // Extended allowlist for completed rounds
        let allowedKeys: Set<String> = [
            "organizerID",
            "organizerFirstName",
            "courseName",
            "status",
            "playerIDs",
            "createdAt",
            "winnerFirstName",
            "winnerScoreDisplay"
        ]

        // PII blocklist — unchanged from Story 12.1
        let forbiddenKeys: Set<String> = [
            "displayName",
            "iCloudRecordName",
            "email",
            "strokeCount",
            "holeNumber",
            "score",
            "lastName",
            "fullName"
        ]

        #expect(actualKeys == allowedKeys,
                "CKRecord keys \(actualKeys) must exactly match completed-state allowlist \(allowedKeys) — stricter than `isSubset` per Task 8.3")

        for forbidden in forbiddenKeys {
            #expect(!actualKeys.contains(forbidden), "PII field '\(forbidden)' must not appear in Round CKRecord")
        }
    }

    @Test("init?(from:) succeeds and winner fields are nil when absent from CKRecord")
    func test_init_fromCKRecord_winnerFieldsOptional_absentMeansNil() {
        let record = makeMinimalRecord()
        // No winner keys set — simulates an in-flight active-round record

        let dto = RoundRecord(from: record)

        #expect(dto != nil)
        #expect(dto?.winnerFirstName == nil)
        #expect(dto?.winnerScoreDisplay == nil)
    }

    @Test("init?(from:) round-trips winner fields when present in CKRecord")
    func test_init_fromCKRecord_winnerFieldsRoundTrip() {
        let record = makeMinimalRecord()
        record["status"] = "completed" as CKRecordValue
        record["winnerFirstName"] = "Carol" as CKRecordValue
        record["winnerScoreDisplay"] = "E" as CKRecordValue

        let dto = RoundRecord(from: record)

        #expect(dto?.winnerFirstName == "Carol")
        #expect(dto?.winnerScoreDisplay == "E")
    }

    // MARK: - Helpers

    private func makeMinimalRecord() -> CKRecord {
        let record = CKRecord(recordType: "Round", recordID: CKRecord.ID(recordName: UUID().uuidString))
        record["organizerID"] = UUID().uuidString as CKRecordValue
        record["organizerFirstName"] = "Test" as CKRecordValue
        record["courseName"] = "Test Course" as CKRecordValue
        record["status"] = "active" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["playerIDs"] = [UUID().uuidString] as CKRecordValue
        return record
    }
}
