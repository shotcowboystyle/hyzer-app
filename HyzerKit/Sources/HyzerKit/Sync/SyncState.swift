import Foundation

/// Observable state of the sync engine, used to drive `SyncIndicatorView` UI.
///
/// Stored as a property on `SyncEngine` (actor-isolated). Views observe it via
/// the projected @Observable wrapper on AppServices (Story 4.2).
public enum SyncState: Sendable {
    /// No sync operation in progress.
    case idle
    /// A push or pull is currently in flight.
    case syncing
    /// Device has no network; sync is paused.
    case offline
    /// Last sync operation failed. The associated value describes the failure.
    case error(SyncError)
}
