import Foundation
import SwiftData

/// An immutable score entry for one player on one hole of a round.
///
/// CloudKit compatibility constraints (same as Round):
/// - No `@Attribute(.unique)` — CloudKit does not support unique constraints
/// - All properties have defaults so CloudKit can instantiate without all values
/// - No `@Relationship` — round and player referenced via flat foreign keys (Amendment A8)
///
/// Append-only invariant (NFR19): ScoreEvent has NO public update or delete API surface.
/// The model is immutable after creation. Corrections create a new ScoreEvent with a
/// non-nil `supersedesEventID` pointing to the replaced event (Story 3.3).
///
/// Guest players: `playerID` is a Player.id UUID string for registered players,
/// or `"guest:{name}"` for guest players (e.g., `"guest:Dave"`).
@Model
public final class ScoreEvent {
    public var id: UUID = UUID()
    /// Flat FK to Round. Denormalized for CloudKit sync (Amendment A8).
    public var roundID: UUID = UUID()
    /// 1-based hole number.
    public var holeNumber: Int = 1
    /// Player.id.uuidString for registered players; "guest:{name}" for guests.
    public var playerID: String = ""
    /// The stroke count (1-10).
    public var strokeCount: Int = 0
    /// nil for initial scores; points to replaced event for corrections (Story 3.3).
    public var supersedesEventID: UUID?
    /// Player.id of whoever entered this score on their device.
    public var reportedByPlayerID: UUID = UUID()
    /// Originating device ID for conflict detection (Epic 4).
    public var deviceID: String = ""
    public var createdAt: Date = Date()

    public init(
        roundID: UUID,
        holeNumber: Int,
        playerID: String,
        strokeCount: Int,
        reportedByPlayerID: UUID,
        deviceID: String
    ) {
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.playerID = playerID
        self.strokeCount = strokeCount
        self.reportedByPlayerID = reportedByPlayerID
        self.deviceID = deviceID
    }
}
