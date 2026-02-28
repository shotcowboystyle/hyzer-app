import Foundation
import CloudKit

/// Data Transfer Object for syncing `ScoreEvent` with CloudKit.
///
/// `Sendable` (value type struct) — safe to pass across actor isolation boundaries
/// between `SyncEngine` and CloudKit async operations.
///
/// Field mapping mirrors `ScoreEvent` model properties.
/// Optional `supersedesEventID` maps to a nullable CKRecord field.
public struct ScoreEventRecord: Sendable {
    public static let recordType = "ScoreEvent"

    public let id: UUID
    public let roundID: UUID
    public let holeNumber: Int
    public let playerID: String
    public let strokeCount: Int
    /// nil for initial scores; UUID of the superseded event for corrections.
    public let supersedesEventID: UUID?
    public let reportedByPlayerID: UUID
    public let deviceID: String
    public let createdAt: Date

    public init(
        id: UUID,
        roundID: UUID,
        holeNumber: Int,
        playerID: String,
        strokeCount: Int,
        supersedesEventID: UUID?,
        reportedByPlayerID: UUID,
        deviceID: String,
        createdAt: Date
    ) {
        self.id = id
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.playerID = playerID
        self.strokeCount = strokeCount
        self.supersedesEventID = supersedesEventID
        self.reportedByPlayerID = reportedByPlayerID
        self.deviceID = deviceID
        self.createdAt = createdAt
    }

    /// Convenience initialiser that copies all fields from a `ScoreEvent` domain model.
    public init(from event: ScoreEvent) {
        self.id = event.id
        self.roundID = event.roundID
        self.holeNumber = event.holeNumber
        self.playerID = event.playerID
        self.strokeCount = event.strokeCount
        self.supersedesEventID = event.supersedesEventID
        self.reportedByPlayerID = event.reportedByPlayerID
        self.deviceID = event.deviceID
        self.createdAt = event.createdAt
    }
}

// MARK: - CKRecord conversion

extension ScoreEventRecord {
    // MARK: DTO → CKRecord

    /// Converts this DTO to a `CKRecord` suitable for saving to CloudKit.
    ///
    /// Record ID is the UUID string of the original `ScoreEvent.id`, ensuring
    /// idempotent upserts — saving the same event twice yields one CloudKit record.
    public func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["roundID"] = roundID.uuidString as CKRecordValue
        record["holeNumber"] = holeNumber as CKRecordValue
        record["playerID"] = playerID as CKRecordValue
        record["strokeCount"] = strokeCount as CKRecordValue
        record["reportedByPlayerID"] = reportedByPlayerID.uuidString as CKRecordValue
        record["deviceID"] = deviceID as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        if let supersedesEventID {
            record["supersedesEventID"] = supersedesEventID.uuidString as CKRecordValue
        }
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
            let roundIDString = ckRecord["roundID"] as? String,
            let roundID = UUID(uuidString: roundIDString),
            let holeNumber = ckRecord["holeNumber"] as? Int,
            let playerID = ckRecord["playerID"] as? String,
            let strokeCount = ckRecord["strokeCount"] as? Int,
            let reportedByPlayerIDString = ckRecord["reportedByPlayerID"] as? String,
            let reportedByPlayerID = UUID(uuidString: reportedByPlayerIDString),
            let deviceID = ckRecord["deviceID"] as? String,
            let createdAt = ckRecord["createdAt"] as? Date
        else { return nil }

        self.id = id
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.playerID = playerID
        self.strokeCount = strokeCount
        self.reportedByPlayerID = reportedByPlayerID
        self.deviceID = deviceID
        self.createdAt = createdAt
        self.supersedesEventID = (ckRecord["supersedesEventID"] as? String).flatMap { UUID(uuidString: $0) }
    }
}
