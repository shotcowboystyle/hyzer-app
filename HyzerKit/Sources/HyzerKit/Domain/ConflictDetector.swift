import Foundation
import SwiftData

/// The result of evaluating a new ScoreEvent against existing events for the same {roundID, playerID, holeNumber}.
///
/// Four mechanically defined cases using `supersedesEventID` and `deviceID`:
/// - `.noConflict` — new event is the only one for this {player, hole}
/// - `.correction` — `supersedesEventID` set, target event has same `deviceID`
/// - `.silentMerge` — different device, same `strokeCount`, both `supersedesEventID == nil`
/// - `.discrepancy` — different device with different `strokeCount`, or cross-device supersession
public enum ConflictResult: Sendable {
    /// No other event exists for this {player, hole} — first score recorded.
    case noConflict
    /// Same-device correction: `newEvent.supersedesEventID` points to an event from the same device.
    case correction
    /// Different device, same `strokeCount`, both initial (no `supersedesEventID`) — merges silently.
    case silentMerge
    /// Conflict requiring resolution: differing scores from different devices, or cross-device supersession.
    /// Carries the IDs of the two conflicting events so `SyncEngine` can create a `Discrepancy` record.
    case discrepancy(existingEventID: UUID, incomingEventID: UUID)
}

/// Pure domain logic for detecting conflicts between ScoreEvents.
///
/// `nonisolated` struct — stateless, no actor isolation required.
/// Called from `SyncEngine.pullRecords()` after inserting new remote events.
/// Never queries SwiftData — operates on `[ScoreEvent]` arrays passed in.
public struct ConflictDetector: Sendable {
    public init() {}

    /// Evaluates `newEvent` against `existingEvents` for the same {roundID, playerID, holeNumber}.
    ///
    /// - Parameters:
    ///   - newEvent: The newly arrived ScoreEvent.
    ///   - existingEvents: All ScoreEvents for the same {roundID, playerID, holeNumber}, including `newEvent`.
    /// - Returns: The `ConflictResult` describing the relationship.
    public func check(newEvent: ScoreEvent, existingEvents: [ScoreEvent]) -> ConflictResult {
        // Filter to same {playerID, holeNumber}, exclude the new event itself
        let others = existingEvents.filter {
            $0.id != newEvent.id &&
            $0.playerID == newEvent.playerID &&
            $0.holeNumber == newEvent.holeNumber &&
            $0.roundID == newEvent.roundID
        }

        // Case 1: No other events exist → no conflict
        guard let other = others.first else {
            return .noConflict
        }

        // Case 2: newEvent has supersedesEventID → correction or cross-device discrepancy
        if let supersedesID = newEvent.supersedesEventID {
            // Find the event being superseded
            let target = existingEvents.first { $0.id == supersedesID }
            let targetDeviceID = target?.deviceID ?? other.deviceID

            if targetDeviceID == newEvent.deviceID {
                // Same-device correction
                return .correction
            } else {
                // Cross-device supersession → discrepancy (Case 4b)
                return .discrepancy(existingEventID: other.id, incomingEventID: newEvent.id)
            }
        }

        // newEvent.supersedesEventID == nil — initial score from a device
        // Find the first other initial event (no supersedesEventID) from a different device
        let otherInitial = others.first {
            $0.supersedesEventID == nil && $0.deviceID != newEvent.deviceID
        }

        guard let conflicting = otherInitial else {
            // No competing initial event from a different device
            return .noConflict
        }

        // Case 3: Same strokeCount → silent merge
        if conflicting.strokeCount == newEvent.strokeCount {
            return .silentMerge
        }

        // Case 4a: Different strokeCount → discrepancy
        return .discrepancy(existingEventID: conflicting.id, incomingEventID: newEvent.id)
    }
}
