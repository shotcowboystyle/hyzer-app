import Foundation
import CloudKit
@testable import HyzerKit

/// In-memory test double for `CloudKitClient`.
///
/// Stores records in a dictionary keyed by `CKRecord.ID`. Supports:
/// - Inspection of saved records via `savedRecords`
/// - Error simulation via `shouldSimulateError`
/// - Latency simulation via `simulatedLatency` (for `.inFlight` timing tests)
final class MockCloudKitClient: CloudKitClient, @unchecked Sendable {
    /// All records that have been saved through this client, in insertion order.
    private(set) var savedRecords: [CKRecord] = []

    /// When set, all operations throw this error instead of succeeding.
    var shouldSimulateError: CKError?

    /// When set, operations sleep for this duration before executing (simulates latency).
    var simulatedLatency: Duration?

    /// Internal store keyed by record ID.
    private var store: [CKRecord.ID: CKRecord] = [:]

    // MARK: - CloudKitClient

    func save(_ records: [CKRecord]) async throws -> [CKRecord] {
        if let latency = simulatedLatency {
            try await Task.sleep(for: latency)
        }
        if let error = shouldSimulateError {
            throw error
        }
        for record in records {
            store[record.recordID] = record
            savedRecords.append(record)
        }
        return records
    }

    func fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord] {
        if let latency = simulatedLatency {
            try await Task.sleep(for: latency)
        }
        if let error = shouldSimulateError {
            throw error
        }
        return store.values.filter { $0.recordType == query.recordType }
    }

    // MARK: - Test helpers

    /// Seeds the in-memory store with the given records (simulates remote state).
    func seed(_ records: [CKRecord]) {
        for record in records {
            store[record.recordID] = record
        }
    }

    /// Clears all stored records and saved-records history.
    func reset() {
        store.removeAll()
        savedRecords.removeAll()
    }
}
