import Foundation
import SwiftData

/// Represents a detected conflict between two ScoreEvents from different devices for the same {player, hole}.
///
/// Stored in the **domain store** — syncs to CloudKit so all devices can see and resolve conflicts.
/// Created by `SyncEngine.pullRecords()` via `ConflictDetector` when a discrepancy is detected.
/// Resolution UI (Epic 6, Story 6.1) reads these records to present `DiscrepancyAlertView`.
///
/// CloudKit compatibility constraints:
/// - No `@Attribute(.unique)` — CloudKit does not support unique constraints
/// - All properties have defaults so CloudKit can instantiate without all values
@Model
public final class Discrepancy {
    public var id: UUID = UUID()
    /// Flat FK to Round containing both conflicting events.
    public var roundID: UUID = UUID()
    /// Player whose score is in conflict.
    public var playerID: String = ""
    /// 1-based hole number where the conflict occurred.
    public var holeNumber: Int = 1
    /// ID of the first conflicting ScoreEvent.
    public var eventID1: UUID = UUID()
    /// ID of the second conflicting ScoreEvent.
    public var eventID2: UUID = UUID()
    /// Current resolution state.
    public var status: DiscrepancyStatus = DiscrepancyStatus.unresolved
    /// ID of the authoritative ScoreEvent created by Epic 6 resolution (nil until resolved).
    public var resolvedByEventID: UUID? = nil
    public var createdAt: Date = Date()

    public init(
        roundID: UUID,
        playerID: String,
        holeNumber: Int,
        eventID1: UUID,
        eventID2: UUID
    ) {
        self.roundID = roundID
        self.playerID = playerID
        self.holeNumber = holeNumber
        self.eventID1 = eventID1
        self.eventID2 = eventID2
    }
}

/// Resolution state for a `Discrepancy` record.
///
/// Raw `String` so SwiftData can store and query it without a transformer (same pattern as `SyncStatus`).
public enum DiscrepancyStatus: String, Codable, Sendable, CaseIterable {
    /// Conflict detected; awaiting organizer resolution (Epic 6).
    case unresolved
    /// Organizer has resolved the conflict via `DiscrepancyResolutionView` (Epic 6).
    case resolved
}
