import Foundation
import SwiftData
import os.log

/// A player's single best-scoring completed round on a specific course.
///
/// Derived, never persisted. Value-type pattern mirrors `Standing` and `TrendPoint`.
public struct PersonalBest: Sendable, Equatable {
    public let playerID: String
    public let courseID: UUID
    public let roundID: UUID
    public let totalStrokes: Int
    public let scoreRelativeToPar: Int
    public let completedAt: Date
}

/// Derives a player's personal best round on a course from SwiftData.
///
/// Read-only. No CloudKit integration, no model mutations.
/// `@MainActor` matches `StandingsEngine` isolation — both share the main-actor `ModelContext`.
@MainActor
public final class PersonalBestService {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "PersonalBestService")

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Returns the player's best completed round on the given course, or `nil` if none exists.
    ///
    /// "Best" is defined as **lowest `scoreRelativeToPar`**. When two or more rounds tie,
    /// the earliest `completedAt` wins. `totalStrokes` is reported from the same winning
    /// round — note that under a course par change between rounds, "best relative-to-par"
    /// and "best absolute strokes" can diverge; this service reports the round that won on
    /// `scoreRelativeToPar` and surfaces its absolute strokes for display only. Out of scope
    /// for this story: a separate "best absolute" lookup (deferred — not part of PMVP-FR15 ACs).
    ///
    /// Guest players (`playerID` prefixed `"guest:"`) are treated identically to registered
    /// players — `playerID` is an opaque string in both fetch predicates. Because guest IDs
    /// are minted per round (`GuestIdentifier.makeID()`), a guest's personal best will
    /// functionally always be the single round they appeared in. This is expected behavior.
    ///
    /// Uses two bounded fetches to avoid loading every completed round in the store:
    /// 1. ScoreEvents for this player → derive participant round IDs
    /// 2. Completed Rounds on this course in that set, bounded to `maxRounds` most-recent
    ///
    /// - Parameters:
    ///   - playerID: Player.id.uuidString for registered players; opaque `"guest:<uuid>"` for guests.
    ///   - courseID: The course whose rounds are evaluated.
    ///   - maxRounds: Upper bound on rounds evaluated. Default 500 (consistent with PlayerTrendService).
    /// - Returns: The `PersonalBest` for the winning round, or `nil` if no scorable completed rounds exist.
    /// - Throws: Rethrows any SwiftData fetch failure after logging.
    public func computeBest(
        for playerID: String,
        courseID: UUID,
        maxRounds: Int = 500
    ) throws -> PersonalBest? {
        let playerIDLocal = playerID
        let courseIDLocal = courseID

        // (a) ScoreEvents for this player — bounded, newest-first so fetchLimit truncation
        // keeps the most recent events deterministically.
        var eventDescriptor = FetchDescriptor<ScoreEvent>(
            predicate: #Predicate { $0.playerID == playerIDLocal },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        eventDescriptor.fetchLimit = maxRounds * 20  // upper bound: maxRounds rounds × ~18 holes
        let playerEvents: [ScoreEvent]
        do {
            playerEvents = try modelContext.fetch(eventDescriptor)
        } catch {
            logger.error("PersonalBestService: ScoreEvent fetch failed for player \(playerID): \(error)")
            throw error
        }

        let participantRoundIDs = Array(Set(playerEvents.map(\.roundID)))
        guard !participantRoundIDs.isEmpty else { return nil }

        // (b) Completed Rounds on THIS course in that set — bounded, newest-first so
        // fetchLimit truncation keeps the most recent `maxRounds` rounds (AC #3).
        var roundDescriptor = FetchDescriptor<Round>(
            predicate: #Predicate {
                participantRoundIDs.contains($0.id)
                    && $0.status == "completed"
                    && $0.courseID == courseIDLocal
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        roundDescriptor.fetchLimit = maxRounds
        let rounds: [Round]
        do {
            rounds = try modelContext.fetch(roundDescriptor)
        } catch {
            logger.error("PersonalBestService: Round fetch failed for player \(playerID) on course \(courseID): \(error)")
            throw error
        }

        var candidates: [PersonalBest] = []
        for round in rounds {
            guard let completedAt = round.completedAt else { continue }
            // Fresh engine per round. StandingsEngine.recompute catches its own errors and
            // leaves currentStandings holding the PREVIOUS successful round's data — sharing
            // one engine across iterations would bleed those stale standings into rounds
            // whose own recompute failed. A fresh engine starts with currentStandings == [],
            // so .first(where:) returns nil on error and the round is correctly skipped.
            let engine = StandingsEngine(modelContext: modelContext)
            engine.recompute(for: round.id, trigger: .localScore)
            guard let standing = engine.currentStandings.first(where: { $0.playerID == playerIDLocal }),
                  standing.holesPlayed > 0 else {
                // Player participated but produced no resolved score.
                continue
            }
            candidates.append(PersonalBest(
                playerID: playerIDLocal,
                courseID: courseIDLocal,
                roundID: round.id,
                totalStrokes: standing.totalStrokes,
                scoreRelativeToPar: standing.scoreRelativeToPar,
                completedAt: completedAt
            ))
        }

        // Sort by (scoreRelativeToPar ascending, completedAt ascending) and return first (AC #2).
        candidates.sort { lhs, rhs in
            if lhs.scoreRelativeToPar != rhs.scoreRelativeToPar {
                return lhs.scoreRelativeToPar < rhs.scoreRelativeToPar
            }
            return lhs.completedAt < rhs.completedAt
        }
        return candidates.first
    }
}
