import Foundation
import CloudKit

/// Data Transfer Object for syncing `Round` with CloudKit.
///
/// Promoted from identity-only stub in Story 12.1 to support the Round-started
/// CKQuerySubscription that drives push notifications.
///
/// PII gate (PMVP-NFR1): Only the precomputed organizer first-name token is stored.
/// No `displayName`, last names, `iCloudRecordName`, email, or scores.
/// The allowlist of stored keys is enforced by the `toCKRecord()` implementation and
/// verified by `RoundRecordTests.test_toCKRecord_piiAllowlist`.
public struct RoundRecord: Sendable {
    public static let recordType = "Round"

    public let id: UUID
    public let organizerID: UUID
    /// Precomputed first-name token of the organizer's `displayName`. Never the full name.
    public let organizerFirstName: String
    public let courseName: String
    /// `"active"` / `"completed"` / etc. Matches `RoundStatus` constants.
    public let status: String
    public let playerIDs: [String]
    public let createdAt: Date

    public init(
        id: UUID,
        organizerID: UUID,
        organizerFirstName: String,
        courseName: String,
        status: String,
        playerIDs: [String],
        createdAt: Date
    ) {
        self.id = id
        self.organizerID = organizerID
        self.organizerFirstName = organizerFirstName
        self.courseName = courseName
        self.status = status
        self.playerIDs = playerIDs
        self.createdAt = createdAt
    }
}

// MARK: - CKRecord conversion

extension RoundRecord {
    // MARK: DTO → CKRecord

    /// Converts this DTO to a `CKRecord` suitable for saving to CloudKit.
    ///
    /// Record ID is the UUID string of `Round.id` — ensures idempotent upserts.
    /// PII gate: the only string field from `Player` is the precomputed `organizerFirstName` token.
    public func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["organizerID"] = organizerID.uuidString as CKRecordValue
        record["organizerFirstName"] = organizerFirstName as CKRecordValue
        record["courseName"] = courseName as CKRecordValue
        record["status"] = status as CKRecordValue
        record["playerIDs"] = playerIDs as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        return record
    }

    // MARK: CKRecord → DTO

    /// Creates a DTO from a `CKRecord` received from CloudKit.
    ///
    /// Returns `nil` if the record type doesn't match or required fields are missing/malformed.
    public init?(from ckRecord: CKRecord) {
        guard ckRecord.recordType == Self.recordType else { return nil }

        let recordName = ckRecord.recordID.recordName
        guard !recordName.isEmpty, let id = UUID(uuidString: recordName) else { return nil }

        guard
            let organizerIDString = ckRecord["organizerID"] as? String,
            let organizerID = UUID(uuidString: organizerIDString),
            let organizerFirstName = ckRecord["organizerFirstName"] as? String,
            let courseName = ckRecord["courseName"] as? String,
            let status = ckRecord["status"] as? String,
            let createdAt = ckRecord["createdAt"] as? Date,
            // playerIDs is a required, non-optional field on the record. Reject malformed
            // records outright rather than silently degrading to [] which would mask buggy peers.
            let playerIDs = ckRecord["playerIDs"] as? [String]
        else { return nil }

        self.id = id
        self.organizerID = organizerID
        self.organizerFirstName = organizerFirstName
        self.courseName = courseName
        self.status = status
        self.playerIDs = playerIDs
        self.createdAt = createdAt
    }
}
