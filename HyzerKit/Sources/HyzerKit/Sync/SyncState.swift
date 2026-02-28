import Foundation

/// Observable state of the sync engine, used to drive future `SyncIndicatorView` UI.
///
/// Stored as a property on `SyncEngine` (actor-isolated). Future views observe it via
/// a projected @Observable wrapper on AppServices (Story 4.2).
///
/// `@unchecked Sendable` because the `.error(Error)` associated value captures a
/// non-Sendable `Error`; in practice this is always a `SyncError` (which is Sendable)
/// written and read only from within the `SyncEngine` actor.
public enum SyncState: @unchecked Sendable {
    /// No sync operation in progress.
    case idle
    /// A push or pull is currently in flight.
    case syncing
    /// Device has no network; sync is paused.
    case offline
    /// Last sync operation failed. The associated value describes the failure.
    case error(Error)
}
