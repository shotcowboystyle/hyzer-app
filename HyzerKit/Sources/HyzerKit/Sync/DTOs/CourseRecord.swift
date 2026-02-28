import Foundation
import CloudKit

/// Stub DTO for syncing `Course` with CloudKit. Full implementation deferred to Story 4.2.
public struct CourseRecord: Sendable {
    public static let recordType = "Course"
    public let id: UUID

    public func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        return CKRecord(recordType: Self.recordType, recordID: recordID)
    }
}
