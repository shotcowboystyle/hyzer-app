import Foundation
@testable import HyzerKit

public extension SyncMetadata {
    /// Creates a SyncMetadata with test defaults. Use in tests only.
    static func fixture(
        recordID: String = UUID().uuidString,
        recordType: String = "ScoreEvent",
        syncStatus: SyncStatus = .pending
    ) -> SyncMetadata {
        let meta = SyncMetadata(recordID: recordID, recordType: recordType)
        meta.syncStatus = syncStatus
        return meta
    }
}
