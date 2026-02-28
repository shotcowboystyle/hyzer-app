import CloudKit
import HyzerKit

/// Live implementation of `CloudKitClient` that wraps the CloudKit public database.
///
/// Container: `iCloud.com.shotcowboystyle.hyzerapp`
/// Database: Public (NOT private — SwiftData built-in sync only supports private DB)
/// Zone: Default
///
/// Declared in HyzerApp (not HyzerKit) so HyzerKit remains platform-agnostic and
/// testable without a CloudKit entitlement. Mirrors the split used by
/// `LiveICloudIdentityProvider`.
struct LiveCloudKitClient: CloudKitClient, Sendable {
    private static let container = CKContainer(identifier: "iCloud.com.shotcowboystyle.hyzerapp")
    private static var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - CloudKitClient

    func save(_ records: [CKRecord]) async throws -> [CKRecord] {
        guard !records.isEmpty else { return [] }

        // Use the modern batch-modify API (iOS 16+)
        let (saveResults, _) = try await Self.publicDB.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: false
        )

        // Collect successfully saved records; rethrow the first error if any
        var saved: [CKRecord] = []
        var firstError: Error?
        for (_, result) in saveResults {
            switch result {
            case .success(let record):
                saved.append(record)
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
        }
        if let error = firstError { throw error }
        return saved
    }

    func fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        // Page through all results
        repeat {
            let (results, nextCursor) = cursor == nil
                ? try await Self.publicDB.records(matching: query, inZoneWith: zone)
                : try await Self.publicDB.records(continuingMatchFrom: cursor!)

            for (_, result) in results {
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }
            cursor = nextCursor
        } while cursor != nil

        return allRecords
    }
}
