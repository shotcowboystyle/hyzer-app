import Foundation
import CloudKit

/// DTO for syncing `Discrepancy` to CloudKit so the `Discrepancy-creation` subscription
/// can fire and deliver an organizer-only push notification (Story 12.3).
///
/// PII gate (PMVP-NFR1, Story 12.3 AC #5):
/// - NO playerName (we send playerID string only — the organizer's local DB resolves to a display name)
/// - NO course name, no stroke counts, no event IDs
/// - organizerID is denormalized from the parent Round so the subscription predicate
///   `organizerID == <localUserID>` can filter server-side; non-organizers never receive the push
public struct DiscrepancyRecord: Sendable {
    public static let recordType = "Discrepancy"

    public let id: UUID
    public let roundID: UUID
    /// Denormalized from the parent Round.organizerID so the CK subscription predicate
    /// can filter server-side without a join. The only reason this field exists on the DTO.
    public let organizerID: UUID
    /// String form (Player UUID or guest:<uuid>) — matches Discrepancy.playerID storage type.
    public let playerID: String
    public let holeNumber: Int
    public let createdAt: Date

    public init(id: UUID, roundID: UUID, organizerID: UUID, playerID: String, holeNumber: Int, createdAt: Date) {
        self.id = id
        self.roundID = roundID
        self.organizerID = organizerID
        self.playerID = playerID
        self.holeNumber = holeNumber
        self.createdAt = createdAt
    }
}

extension DiscrepancyRecord {
    public func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["roundID"] = roundID.uuidString as CKRecordValue
        record["organizerID"] = organizerID.uuidString as CKRecordValue
        record["playerID"] = playerID as CKRecordValue
        record["holeNumber"] = holeNumber as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        return record
    }

    public init?(from ckRecord: CKRecord) {
        guard ckRecord.recordType == Self.recordType else { return nil }
        let recordName = ckRecord.recordID.recordName
        guard !recordName.isEmpty, let id = UUID(uuidString: recordName) else { return nil }
        guard
            let roundIDString = ckRecord["roundID"] as? String,
            let roundID = UUID(uuidString: roundIDString),
            let organizerIDString = ckRecord["organizerID"] as? String,
            let organizerID = UUID(uuidString: organizerIDString),
            let playerID = ckRecord["playerID"] as? String,
            let holeNumber = ckRecord["holeNumber"] as? Int,
            let createdAt = ckRecord["createdAt"] as? Date
        else { return nil }
        self.id = id
        self.roundID = roundID
        self.organizerID = organizerID
        self.playerID = playerID
        self.holeNumber = holeNumber
        self.createdAt = createdAt
    }
}
