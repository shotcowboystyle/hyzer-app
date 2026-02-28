import Foundation
import CloudKit

/// Stub DTO for syncing `Round` with CloudKit. Full implementation deferred to Story 4.2.
public struct RoundRecord: Sendable {
    public static let recordType = "Round"
    public let id: UUID

    public func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        return CKRecord(recordType: Self.recordType, recordID: recordID)
    }
}
