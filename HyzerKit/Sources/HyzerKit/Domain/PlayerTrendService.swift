import Foundation
import SwiftData
import os.log

/// A single round's contribution to a player's scoring trend.
///
/// Derived, never persisted. Mirrors the value-type pattern of `Standing`.
public struct TrendPoint: Identifiable, Sendable, Equatable {
    public let roundID: UUID
    public let completedAt: Date
    public let scoreRelativeToPar: Int
    public var id: UUID { roundID }
}

/// Aggregated trend result for a player across completed rounds.
public struct TrendSummary: Sendable, Equatable {
    public let playerID: String
    /// Data points sorted ascending by `completedAt`.
    public let points: [TrendPoint]
    /// Minimum `scoreRelativeToPar` across all points; nil if no points.
    public let bestScore: Int?
    /// Maximum `scoreRelativeToPar` across all points; nil if no points.
    public let worstScore: Int?
    /// Arithmetic mean of `scoreRelativeToPar`; nil if no points.
    public let averageScore: Double?
}

/// Reads completed rounds from SwiftData and derives a scoring trend for one player.
///
/// Read-only. No CloudKit integration, no model mutations.
/// `@MainActor` matches `StandingsEngine` isolation — both share the main-actor `ModelContext`.
@MainActor
public final class PlayerTrendService {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "PlayerTrendService")

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Computes a scoring trend for the given player across their completed rounds.
    ///
    /// Uses two bounded fetches (player events first, then completed rounds from that set) to
    /// avoid loading every completed round in the store. `StandingsEngine` handles leaf-node
    /// resolution and Amendment A7 score aggregation for each round.
    ///
    /// - Parameters:
    ///   - playerID: Player.id.uuidString for registered players; opaque `"guest:<uuid>"` for guests.
    ///   - maxRounds: Upper bound on rounds returned. Default 500 (per PMVP-NFR4 + safety margin).
    /// - Returns: A `TrendSummary` with points sorted ascending by `completedAt`.
    /// - Throws: Rethrows any SwiftData fetch failure after logging.
    public func computeTrend(for playerID: String, maxRounds: Int = 500) throws -> TrendSummary {
        let playerIDLocal = playerID

        // (a) Fetch ScoreEvents for this player — bounded. Sort newest-first so the fetchLimit
        // truncation (if hit) keeps the most recent events deterministically.
        var eventDescriptor = FetchDescriptor<ScoreEvent>(
            predicate: #Predicate { $0.playerID == playerIDLocal },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        eventDescriptor.fetchLimit = maxRounds * ScoreEvent.maxEventsPerRound  // upper bound: maxRounds rounds × ~18 holes
        let playerEvents: [ScoreEvent]
        do {
            playerEvents = try modelContext.fetch(eventDescriptor)
        } catch {
            logger.error("PlayerTrendService: ScoreEvent fetch failed for player \(playerID): \(error)")
            throw error
        }

        let participantRoundIDs = Array(Set(playerEvents.map(\.roundID)))

        guard !participantRoundIDs.isEmpty else {
            return TrendSummary(playerID: playerID, points: [], bestScore: nil, worstScore: nil, averageScore: nil)
        }

        // (b) Fetch completed Rounds in that set — bounded. Sort newest-first so fetchLimit
        // keeps the most recent `maxRounds` rounds (the trend-view intent), then reverse
        // to ascending order for chart display.
        let completedStatus = RoundStatus.completed
        var roundDescriptor = FetchDescriptor<Round>(
            predicate: #Predicate { participantRoundIDs.contains($0.id) && $0.status == completedStatus },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        roundDescriptor.fetchLimit = maxRounds
        let recentRoundsDesc: [Round]
        do {
            recentRoundsDesc = try modelContext.fetch(roundDescriptor)
        } catch {
            logger.error("PlayerTrendService: Round fetch failed for player \(playerID): \(error)")
            throw error
        }
        let rounds = Array(recentRoundsDesc.reversed())

        var points: [TrendPoint] = []

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
                // Player participated but produced no resolved score (e.g. all events superseded, aborted round).
                continue
            }
            points.append(TrendPoint(
                roundID: round.id,
                completedAt: completedAt,
                scoreRelativeToPar: standing.scoreRelativeToPar
            ))
        }

        let scores = points.map(\.scoreRelativeToPar)
        return TrendSummary(
            playerID: playerID,
            points: points,
            bestScore: scores.min(),
            worstScore: scores.max(),
            averageScore: points.isEmpty ? nil : Double(scores.reduce(0, +)) / Double(points.count)
        )
    }
}
