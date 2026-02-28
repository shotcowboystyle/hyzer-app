/// Identifies what event triggered a standings recomputation.
///
/// Used in `StandingsChange` to allow views to apply different animations
/// depending on the origin of the change (e.g., local score vs. remote sync).
public enum StandingsChangeTrigger: Sendable {
    /// A score was entered or corrected on this device.
    case localScore
    /// Standings changed due to a CloudKit sync receive (Epic 4).
    case remoteSync
    /// A conflicting score was resolved by the conflict engine (Epic 4).
    case conflictResolution
}
