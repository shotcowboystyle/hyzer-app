import Foundation
import SwiftData
import os.log

/// Aggregated head-to-head record across all completed rounds two players share.
/// Derived, never persisted. Value-type pattern mirrors `Standing`, `TrendSummary`, `PersonalBest`.
public struct HeadToHeadRecord: Sendable, Equatable {
    public let playerAID: String
    public let playerBID: String
    public let roundsPlayedTogether: Int
    /// Wins counted when `standingA.totalStrokes < standingB.totalStrokes`. Ties contribute to neither side.
    public let winsA: Int
    public let winsB: Int
    public let ties: Int
    /// Mean of `(standingA.scoreRelativeToPar - standingB.scoreRelativeToPar)` across shared rounds where
    /// both players have `holesPlayed > 0`. `nil` when `roundsPlayedTogether == 0`.
    public let averageDifferential: Double?
}

/// A potential opponent for player A in the head-to-head picker.
/// `playerID` is always a registered Player UUID string (never `"guest:<uuid>"`).
public struct HeadToHeadCandidate: Sendable, Equatable, Identifiable, Hashable {
    public let playerID: String
    public let playerName: String
    public let roundsTogether: Int
    public var id: String { playerID }
}

/// Protocol abstraction over `HeadToHeadService` — enables tests to inject a throwing stub
/// without depending on SwiftData failure injection (which is unsupported in-memory).
@MainActor
public protocol HeadToHeadServicing: AnyObject {
    func computeRecord(for playerAID: String, against playerBID: String, maxRounds: Int) throws -> HeadToHeadRecord
    func findOpponentCandidates(for playerAID: String, maxRounds: Int) throws -> [HeadToHeadCandidate]
}

/// Derives head-to-head records between two players from SwiftData.
///
/// Read-only. No CloudKit integration, no model mutations.
/// `@MainActor` matches `StandingsEngine` isolation — both share the main-actor `ModelContext`.
@MainActor
public final class HeadToHeadService: HeadToHeadServicing {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "HeadToHeadService")

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Computes the head-to-head record between `playerAID` and `playerBID`.
    ///
    /// "Wins for A" are counted when `standingA.totalStrokes < standingB.totalStrokes`.
    /// Tied totalStrokes contribute to `ties` and to neither side's win count, but DO
    /// contribute one round to `roundsPlayedTogether` and one sample to `averageDifferential`.
    /// The differential is signed: a NEGATIVE `averageDifferential` means player A averages a
    /// LOWER (better) score relative to par than player B. Rounds where either player has
    /// `holesPlayed == 0` are skipped entirely (do not affect any output count).
    ///
    /// Returns a record with all-zero counts and `averageDifferential == nil` if they have
    /// no shared completed rounds.
    ///
    /// - Parameters:
    ///   - playerAID: Player identifier for the primary player.
    ///   - playerBID: Player identifier for the opponent.
    ///   - maxRounds: Upper bound on rounds evaluated. Default 500.
    /// - Returns: Aggregated record across shared completed rounds.
    /// - Throws: Rethrows any SwiftData fetch failure after logging.
    public func computeRecord(
        for playerAID: String,
        against playerBID: String,
        maxRounds: Int = 500
    ) throws -> HeadToHeadRecord {
        guard playerAID != playerBID else {
            logger.notice("HeadToHeadService: self-compare attempted for \(playerAID) — returning empty record")
            return HeadToHeadRecord(
                playerAID: playerAID, playerBID: playerBID,
                roundsPlayedTogether: 0, winsA: 0, winsB: 0, ties: 0,
                averageDifferential: nil
            )
        }

        let playerAIDLocal = playerAID
        let playerBIDLocal = playerBID

        var eventsADesc = FetchDescriptor<ScoreEvent>(
            predicate: #Predicate { $0.playerID == playerAIDLocal },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        eventsADesc.fetchLimit = maxRounds * ScoreEvent.maxEventsPerRound
        let eventsA: [ScoreEvent]
        do {
            eventsA = try modelContext.fetch(eventsADesc)
        } catch {
            logger.error("HeadToHeadService: ScoreEvent fetch failed for player A \(playerAID): \(error)")
            throw error
        }

        var eventsBDesc = FetchDescriptor<ScoreEvent>(
            predicate: #Predicate { $0.playerID == playerBIDLocal },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        eventsBDesc.fetchLimit = maxRounds * ScoreEvent.maxEventsPerRound
        let eventsB: [ScoreEvent]
        do {
            eventsB = try modelContext.fetch(eventsBDesc)
        } catch {
            logger.error("HeadToHeadService: ScoreEvent fetch failed for player B \(playerBID): \(error)")
            throw error
        }

        let roundIDsA = Set(eventsA.map(\.roundID))
        let roundIDsB = Set(eventsB.map(\.roundID))
        let sharedRoundIDs = Array(roundIDsA.intersection(roundIDsB))
        guard !sharedRoundIDs.isEmpty else {
            return HeadToHeadRecord(
                playerAID: playerAID,
                playerBID: playerBID,
                roundsPlayedTogether: 0,
                winsA: 0, winsB: 0, ties: 0,
                averageDifferential: nil
            )
        }

        let completedStatus = RoundStatus.completed
        var roundDesc = FetchDescriptor<Round>(
            predicate: #Predicate { sharedRoundIDs.contains($0.id) && $0.status == completedStatus },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        roundDesc.fetchLimit = maxRounds
        let rounds: [Round]
        do {
            rounds = try modelContext.fetch(roundDesc)
        } catch {
            logger.error("HeadToHeadService: Round fetch failed for pair (\(playerAID), \(playerBID)): \(error)")
            throw error
        }

        var winsA = 0
        var winsB = 0
        var ties = 0
        var diffs: [Int] = []
        diffs.reserveCapacity(rounds.count)

        for round in rounds {
            // Fresh engine per round — sharing one engine leaks stale currentStandings on
            // recompute failure. See PlayerTrendService.swift:97-103 and Story 13.2 Dev Notes.
            let engine = StandingsEngine(modelContext: modelContext)
            engine.recompute(for: round.id, trigger: .localScore)

            guard let standingA = engine.currentStandings.first(where: { $0.playerID == playerAIDLocal }),
                  standingA.holesPlayed > 0,
                  let standingB = engine.currentStandings.first(where: { $0.playerID == playerBIDLocal }),
                  standingB.holesPlayed > 0 else {
                logger.notice("HeadToHeadService: round \(round.id) skipped — no resolved score for one or both players")
                continue
            }

            if standingA.totalStrokes < standingB.totalStrokes {
                winsA += 1
            } else if standingB.totalStrokes < standingA.totalStrokes {
                winsB += 1
            } else {
                ties += 1
            }
            diffs.append(standingA.scoreRelativeToPar - standingB.scoreRelativeToPar)
        }

        let roundsPlayedTogether = winsA + winsB + ties
        let average: Double? = diffs.isEmpty ? nil : Double(diffs.reduce(0, +)) / Double(diffs.count)

        return HeadToHeadRecord(
            playerAID: playerAID,
            playerBID: playerBID,
            roundsPlayedTogether: roundsPlayedTogether,
            winsA: winsA,
            winsB: winsB,
            ties: ties,
            averageDifferential: average
        )
    }

    /// Returns every REGISTERED player who has at least one `.completed` round with `playerAID`.
    /// Excludes `playerAID` itself and all guests (`GuestIdentifier.isGuest` filter).
    /// Sorted ascending by `playerName` (case-insensitive). Empty array when no candidates.
    ///
    /// - Parameters:
    ///   - playerAID: The player for whom to find opponents.
    ///   - maxRounds: Upper bound on rounds evaluated. Default 500.
    /// - Returns: Sorted list of candidates with round counts.
    /// - Throws: Rethrows any SwiftData fetch failure after logging.
    public func findOpponentCandidates(
        for playerAID: String,
        maxRounds: Int = 500
    ) throws -> [HeadToHeadCandidate] {
        let playerAIDLocal = playerAID

        var eventsADesc = FetchDescriptor<ScoreEvent>(
            predicate: #Predicate { $0.playerID == playerAIDLocal },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        eventsADesc.fetchLimit = maxRounds * ScoreEvent.maxEventsPerRound
        let eventsA: [ScoreEvent]
        do {
            eventsA = try modelContext.fetch(eventsADesc)
        } catch {
            logger.error("HeadToHeadService: ScoreEvent fetch failed for candidates query (playerA \(playerAID)): \(error)")
            throw error
        }

        let roundIDsA = Array(Set(eventsA.map(\.roundID)))
        guard !roundIDsA.isEmpty else { return [] }

        let completedStatus = RoundStatus.completed
        var roundDesc = FetchDescriptor<Round>(
            predicate: #Predicate { roundIDsA.contains($0.id) && $0.status == completedStatus },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        roundDesc.fetchLimit = maxRounds
        let rounds: [Round]
        do {
            rounds = try modelContext.fetch(roundDesc)
        } catch {
            logger.error("HeadToHeadService: Round fetch failed for candidates query (playerA \(playerAID)): \(error)")
            throw error
        }

        var peerCounts: [String: Int] = [:]
        for round in rounds {
            for peerID in Set(round.playerIDs) where peerID != playerAIDLocal && !GuestIdentifier.isGuest(peerID) {
                peerCounts[peerID, default: 0] += 1
            }
        }
        guard !peerCounts.isEmpty else { return [] }

        let peerIDStrings = Array(peerCounts.keys)
        let peerUUIDs: [UUID] = peerIDStrings.compactMap { id in
            guard let uuid = UUID(uuidString: id) else {
                logger.notice("HeadToHeadService: peerID \(id) is not a valid UUID — skipped")
                return nil
            }
            return uuid
        }
        guard !peerUUIDs.isEmpty else { return [] }
        var playerDesc = FetchDescriptor<Player>(
            predicate: #Predicate { peerUUIDs.contains($0.id) }
        )
        playerDesc.fetchLimit = peerUUIDs.count
        let players: [Player]
        do {
            players = try modelContext.fetch(playerDesc)
        } catch {
            logger.error("HeadToHeadService: Player fetch failed for candidates query (playerA \(playerAID)): \(error)")
            throw error
        }

        // Duplicate Player.id rows are theoretically possible after CloudKit replay even with
        // SwiftData `@Attribute(.unique)` disabled. Take the first displayName encountered.
        let nameByID = Dictionary(
            players.map { ($0.id.uuidString, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )
        var candidates: [HeadToHeadCandidate] = []
        for (peerID, count) in peerCounts {
            guard let name = nameByID[peerID] else {
                logger.notice("HeadToHeadService: peerID \(peerID) has no matching Player row — skipped")
                continue
            }
            candidates.append(HeadToHeadCandidate(playerID: peerID, playerName: name, roundsTogether: count))
        }
        candidates.sort { $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending }
        return candidates
    }
}
