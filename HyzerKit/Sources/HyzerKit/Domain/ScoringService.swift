import Foundation
import SwiftData

/// Creates immutable ScoreEvents in the domain SwiftData store.
///
/// Constructed by `AppServices` with the main ModelContext and device ID.
/// All callers are `@MainActor`, so this is a plain class (not an actor).
///
/// Story 3.3 will add a correction flow that creates ScoreEvents with a non-nil
/// `supersedesEventID`. For Story 3.2, all events have `supersedesEventID = nil`.
public final class ScoringService {
    private let modelContext: ModelContext
    private let deviceID: String

    public init(modelContext: ModelContext, deviceID: String) {
        self.modelContext = modelContext
        self.deviceID = deviceID
    }

    /// Creates an immutable ScoreEvent and persists it to the domain store.
    ///
    /// - Parameters:
    ///   - roundID: The UUID of the round being scored.
    ///   - holeNumber: 1-based hole number.
    ///   - playerID: Player.id.uuidString or "guest:{name}" for guests.
    ///   - strokeCount: The score (1-10).
    ///   - reportedByPlayerID: The Player.id of whoever is entering this score.
    /// - Returns: The created `ScoreEvent`.
    /// - Throws: Rethrows any SwiftData persistence error. Never uses `try?`.
    @discardableResult
    public func createScoreEvent(
        roundID: UUID,
        holeNumber: Int,
        playerID: String,
        strokeCount: Int,
        reportedByPlayerID: UUID
    ) throws -> ScoreEvent {
        precondition((1...10).contains(strokeCount), "strokeCount must be 1-10, got \(strokeCount)")
        precondition(holeNumber >= 1, "holeNumber must be >= 1, got \(holeNumber)")
        let event = ScoreEvent(
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID,
            deviceID: deviceID
        )
        modelContext.insert(event)
        try modelContext.save()
        return event
    }
}
