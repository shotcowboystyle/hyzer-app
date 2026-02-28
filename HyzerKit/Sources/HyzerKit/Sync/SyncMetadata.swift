import Foundation
import SwiftData

/// Tracks the push/pull state of a local record with respect to CloudKit.
///
/// Stored in the **operational** `ModelConfiguration` — local-only, never synced to CloudKit.
/// One entry per outbound push attempt or inbound pull. Forms a simple state machine:
///   `.pending` → `.inFlight` → `.synced`
///                           ↘ `.failed`  (eligible for retry)
///
/// All properties have defaults so the operational store can be deleted and
/// rebuilt from scratch without data loss (CloudKit has the authoritative copy).
@Model
public final class SyncMetadata {
    /// Primary key — matches `CKRecord.ID.recordName`.
    public var id: UUID = UUID()
    /// The CloudKit record ID string (UUID form) this entry tracks.
    public var recordID: String = ""
    /// The CloudKit record type name (e.g. `"ScoreEvent"`).
    public var recordType: String = ""
    /// Current position in the sync pipeline.
    public var syncStatus: SyncStatus = SyncStatus.pending
    /// Set to `Date()` when a push attempt begins; nil until first attempt.
    public var lastAttempt: Date? = nil
    public var createdAt: Date = Date()

    public init(recordID: String, recordType: String) {
        self.recordID = recordID
        self.recordType = recordType
    }
}

/// The sync pipeline state for a `SyncMetadata` entry.
///
/// Raw `String` so SwiftData can store and query it without a transformer.
public enum SyncStatus: String, Codable, Sendable, CaseIterable {
    /// Written locally; not yet pushed to CloudKit.
    case pending
    /// Push has been dispatched; CloudKit `save()` is in flight.
    /// Guard against actor reentrancy — entries already `.inFlight` are skipped
    /// by subsequent `pushPending()` calls (Amendment A1).
    case inFlight
    /// Successfully round-tripped with CloudKit.
    case synced
    /// Last push attempt failed; eligible for retry.
    case failed
}
