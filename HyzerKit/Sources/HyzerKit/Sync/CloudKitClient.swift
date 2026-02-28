import CloudKit

/// Abstraction over the CloudKit public database.
///
/// Protocol lives in HyzerKit so `SyncEngine` and tests can depend on it without importing
/// the full CloudKit framework in every test host. The live implementation
/// (`LiveCloudKitClient`) is in the HyzerApp target.
///
/// Conforming types **must** be `Sendable` because the protocol is used from
/// the `SyncEngine` actor.
public protocol CloudKitClient: Sendable {
    /// Saves records to CloudKit and returns the saved copies (with system fields populated).
    func save(_ records: [CKRecord]) async throws -> [CKRecord]

    /// Fetches records matching `query` from the given record zone (nil → default zone).
    func fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord]
}
