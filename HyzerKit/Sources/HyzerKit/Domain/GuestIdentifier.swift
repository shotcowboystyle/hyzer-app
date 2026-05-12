import Foundation

/// Centralizes the rules for guest player identifiers in `ScoreEvent.playerID`,
/// `Round.guestIDs`, and any UI key that needs to refer to a guest.
///
/// Format:
///   `"guest:<uuid>"` — a stable, opaque identifier with no human-readable PII.
///
/// The previous format `"guest:<name>"` (e.g. `"guest:Dave"`) leaked names through
/// `ScoreEvent.playerID` to the CloudKit public database, where any installed app
/// could enumerate them via `NSPredicate(value: true)`. Names now live only in
/// `Round.guestNames` (local-only model field), indexed by `Round.guestIDs`.
///
/// Backward compatibility: legacy ScoreEvents already on disk may carry
/// `"guest:<name>"` playerIDs. `displayName(for:in:)` falls back to extracting the
/// raw name when no UUID match is found in the round.
public enum GuestIdentifier {
    /// Constant prefix used for guest playerIDs. Never write a name after this prefix.
    public static let prefix = "guest:"

    /// Returns true if the given player ID refers to a guest (registered Player IDs
    /// are plain UUID strings with no prefix).
    public static func isGuest(_ playerID: String) -> Bool {
        playerID.hasPrefix(prefix)
    }

    /// Generates a new opaque guest playerID. Used at round-setup time when a new
    /// guest is added — paired index-aligned with `Round.guestNames`.
    public static func makeID() -> String {
        prefix + UUID().uuidString
    }

    /// Resolves a guest display name for a `ScoreEvent.playerID`, given the parallel
    /// `guestIDs`/`guestNames` arrays from the owning `Round`.
    ///
    /// - For UUID-form playerIDs (`"guest:<uuid>"`), returns the matching name or `nil`
    ///   if the guest is not part of this round.
    /// - For legacy name-form playerIDs (`"guest:<name>"`), returns the raw name.
    /// - For non-guest IDs, returns `nil` (caller should resolve from registered players).
    public static func displayName(
        for playerID: String,
        guestIDs: [String],
        guestNames: [String]
    ) -> String? {
        guard isGuest(playerID) else { return nil }
        if let index = guestIDs.firstIndex(of: playerID), index < guestNames.count {
            return guestNames[index]
        }
        // Legacy ScoreEvents may carry `"guest:<name>"` directly. Surface the raw name
        // so existing rounds still render correctly; this branch is unreachable for
        // newly-created rounds.
        return String(playerID.dropFirst(prefix.count))
    }
}
