import Foundation
import SwiftData

/// Typed error for ScoringService operations.
public enum ScoringServiceError: Error, Sendable, Equatable {
    case previousEventNotFound(UUID)
    case roundNotFound(UUID)
    case playerNotInRound(playerID: String, roundID: UUID)
    case holeOutOfRange(hole: Int, holeCount: Int)
    case roundNotActive(status: String)
}

/// Creates immutable ScoreEvents in the domain SwiftData store.
///
/// Constructed by `AppServices` with the main ModelContext and device ID.
/// All callers are `@MainActor`, so this is a plain class (not an actor).
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
    ///   - playerID: Player.id.uuidString or opaque `"guest:<uuid>"` for guests.
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

    /// Creates a correction ScoreEvent that supersedes a previous event.
    ///
    /// The original event is never mutated or deleted (NFR19, append-only).
    /// `HoleCardView.resolveCurrentScore()` (Amendment A7) finds the new leaf node automatically.
    ///
    /// - Parameters:
    ///   - previousEventID: The UUID of the event being corrected.
    ///   - roundID: The UUID of the round being scored.
    ///   - holeNumber: 1-based hole number.
    ///   - playerID: Player.id.uuidString or opaque `"guest:<uuid>"` for guests.
    ///   - strokeCount: The corrected score (1-10).
    ///   - reportedByPlayerID: The Player.id of whoever is entering this correction.
    /// - Returns: The created correction `ScoreEvent`.
    /// - Throws: `ScoringServiceError.previousEventNotFound` if the previous event does not exist.
    ///           Rethrows any SwiftData persistence error. Never uses `try?`.
    @discardableResult
    public func correctScore(
        previousEventID: UUID,
        roundID: UUID,
        holeNumber: Int,
        playerID: String,
        strokeCount: Int,
        reportedByPlayerID: UUID
    ) throws -> ScoreEvent {
        precondition((1...10).contains(strokeCount), "strokeCount must be 1-10, got \(strokeCount)")
        precondition(holeNumber >= 1, "holeNumber must be >= 1, got \(holeNumber)")

        // Captured local required for #Predicate macro
        let id = previousEventID
        let descriptor = FetchDescriptor<ScoreEvent>(predicate: #Predicate { $0.id == id })
        let results = try modelContext.fetch(descriptor)
        guard !results.isEmpty else {
            throw ScoringServiceError.previousEventNotFound(previousEventID)
        }

        let event = ScoreEvent(
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID,
            deviceID: deviceID
        )
        event.supersedesEventID = previousEventID
        modelContext.insert(event)
        try modelContext.save()
        return event
    }

    /// Validates that a cross-device score payload (typically from the paired Watch)
    /// refers to a known active round, a player who is actually in that round, and a
    /// hole within the course's hole count. Use this before persisting any score that
    /// originated outside the phone process.
    ///
    /// - Throws: `ScoringServiceError.roundNotFound` if the round does not exist locally.
    ///           `ScoringServiceError.roundNotActive` if the round is finished.
    ///           `ScoringServiceError.playerNotInRound` if the playerID is not a member.
    ///           `ScoringServiceError.holeOutOfRange` if the hole is outside `[1, holeCount]`.
    public func validateExternalScore(
        roundID: UUID,
        playerID: String,
        holeNumber: Int
    ) throws {
        let id = roundID
        var descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let round = try modelContext.fetch(descriptor).first else {
            throw ScoringServiceError.roundNotFound(roundID)
        }
        guard !round.isFinished else {
            throw ScoringServiceError.roundNotActive(status: round.status)
        }
        guard holeNumber >= 1, holeNumber <= round.holeCount else {
            throw ScoringServiceError.holeOutOfRange(hole: holeNumber, holeCount: round.holeCount)
        }
        let isMember = round.playerIDs.contains(playerID) || round.guestIDs.contains(playerID)
        guard isMember else {
            throw ScoringServiceError.playerNotInRound(playerID: playerID, roundID: roundID)
        }
    }
}
