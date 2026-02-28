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

    /// Registers a `CKQuerySubscription` on the public database for the given record type.
    ///
    /// Uses `NSPredicate(value: true)` to match all records of the type, with
    /// `shouldSendContentAvailable = true` for silent push notifications.
    /// Returns the saved subscription ID for later cleanup.
    ///
    /// Idempotent when combined with `fetchAllSubscriptionIDs()` — callers should
    /// check existing subscriptions before calling to avoid duplication.
    func subscribe(to recordType: CKRecord.RecordType, predicate: NSPredicate) async throws -> CKSubscription.ID

    /// Removes the subscription with the given ID from the public database.
    func deleteSubscription(_ subscriptionID: CKSubscription.ID) async throws

    /// Returns all existing subscription IDs registered on the public database.
    ///
    /// Used for idempotent subscription setup — check this before calling `subscribe(to:predicate:)`
    /// to avoid accumulating duplicate subscriptions across app launches.
    func fetchAllSubscriptionIDs() async throws -> [CKSubscription.ID]
}
