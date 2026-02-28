import Foundation
import CloudKit

/// Typed errors that can occur during CloudKit sync operations.
///
/// `Sendable` because it crosses the `SyncEngine` actor boundary when stored
/// in `SyncState.error(_:)`.
public enum SyncError: Error, Sendable {
    /// Device has no network connectivity.
    case networkUnavailable
    /// CloudKit returned an error. Contains the underlying `CKError` for logging/retry decisions.
    case cloudKitFailure(CKError)
    /// Two versions of the same record are in conflict. Contains local and remote copies.
    case recordConflict(local: CKRecord, remote: CKRecord)
    /// iCloud storage quota exceeded; push was rejected.
    case quotaExceeded
}
