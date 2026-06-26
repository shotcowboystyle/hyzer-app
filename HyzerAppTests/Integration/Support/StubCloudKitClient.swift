import CloudKit
import Foundation
@testable import HyzerKit

/// Shared `CloudKitClient` stub used across `HyzerAppTests/Integration/` and the
/// legacy unit tests (`AppServicesTests`, `AppServicesNearbyDiscoveryTests`,
/// `ICloudIdentityResolutionTests`).
///
/// Behaviour:
/// - `fetch(matching:in:)` returns `recordsToReturn` if non-empty (drained once),
///   otherwise `[]`. The drain-once semantic lets a test script a single remote
///   pull without re-emitting the same records on retry/subsequent fetches.
/// - `save(_:)` and `save(_:savePolicy:)` capture submitted records in
///   `savedRecords` and echo them back (the real CloudKit contract returns the
///   server-modified versions; for tests the echo is sufficient).
/// - All counters (`fetchCallCount`, `saveCallCount`, `subscribeCallCount`) are
///   safe to read from the main actor after `await`-ing whatever triggered them.
///
/// To replace the pre-Story-15.11 per-file stubs (`StubCloudKitClientApp`,
/// `CountingCloudKitClient`, `StubCloudKitClient`), use this single type and pass
/// it directly to `AppServices.init(cloudKitClient:)`.
final class StubCloudKitClient: CloudKitClient, @unchecked Sendable {

    // MARK: Scripting

    /// Records returned by the next call to `fetch(matching:in:)`.
    ///
    /// Drained on first read so tests can simulate "single remote pull materializes
    /// these records" without leaking into a subsequent retry. Set this BEFORE the
    /// action under test (e.g., before injecting a nearby payload that triggers a
    /// pull). To return the same payload on every fetch, set
    /// `recordsToReturnPersist = true`.
    var recordsToReturn: [CKRecord] = []

    /// When true, `recordsToReturn` is NOT drained on read — every fetch returns
    /// the same array. Useful for tests that need many fetches to see the same
    /// stable remote state.
    var recordsToReturnPersist: Bool = false

    /// Throwable error injected into the next `fetch(matching:in:)` call.
    /// Cleared after one fetch.
    var fetchErrorToThrow: Error?

    /// Throwable error injected into the next `save(_:)` call.
    /// Cleared after one save.
    var saveErrorToThrow: Error?

    // MARK: Counters

    private(set) var fetchCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var subscribeCallCount = 0
    private(set) var deleteSubscriptionCallCount = 0

    // MARK: Captured arguments

    /// Records submitted to `save(_:)` / `save(_:savePolicy:)`, in call order.
    /// Each entry is the slice passed to a single save call.
    private(set) var savedRecords: [[CKRecord]] = []

    /// Queries submitted to `fetch(matching:in:)`, in call order.
    private(set) var fetchedQueries: [CKQuery] = []

    // MARK: CloudKitClient

    func save(_ records: [CKRecord]) async throws -> [CKRecord] {
        saveCallCount += 1
        savedRecords.append(records)
        if let error = saveErrorToThrow {
            saveErrorToThrow = nil
            throw error
        }
        return records
    }

    func save(
        _ records: [CKRecord],
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy
    ) async throws -> [CKRecord] {
        try await save(records)
    }

    func fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord] {
        fetchCallCount += 1
        fetchedQueries.append(query)
        if let error = fetchErrorToThrow {
            fetchErrorToThrow = nil
            throw error
        }
        if recordsToReturnPersist {
            return recordsToReturn
        }
        let drained = recordsToReturn
        recordsToReturn = []
        return drained
    }

    func subscribe(to recordType: CKRecord.RecordType, predicate: NSPredicate) async throws -> CKSubscription.ID {
        subscribeCallCount += 1
        return ""
    }

    func deleteSubscription(_ subscriptionID: CKSubscription.ID) async throws {
        deleteSubscriptionCallCount += 1
    }

    func fetchAllSubscriptionIDs() async throws -> [CKSubscription.ID] { [] }

    func subscribeWithAlert(
        to recordType: CKRecord.RecordType,
        predicate: NSPredicate,
        subscriptionID: CKSubscription.ID,
        notificationInfo: CKSubscription.NotificationInfo
    ) async throws -> CKSubscription.ID {
        subscribeCallCount += 1
        return subscriptionID
    }
}
