import Foundation
import SwiftData
import Observation
import os.log

/// Computes live standings from ScoreEvent data for an active round.
///
/// All mutation and access must occur on the MainActor (same isolation as SwiftUI views).
/// NOT a Swift actor — uses @MainActor @Observable per the architecture spec.
///
/// Concurrency note: `recompute(for:trigger:)` is synchronous and uses the `@MainActor`-isolated
/// `ModelContext` to fetch SwiftData records. All callers must be `@MainActor`.
@MainActor
@Observable
public final class StandingsEngine {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "StandingsEngine")

    /// The most recently computed standings, ordered by rank ascending.
    public private(set) var currentStandings: [Standing] = []
    /// The most recent standings change, used by views for animation triggers.
    public private(set) var latestChange: StandingsChange?

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Recomputes standings for the given round and returns the change result.
    ///
    /// Uses Amendment A7 leaf-node resolution via `resolveCurrentScore(for:hole:in:)`.
    /// On any SwiftData fetch failure, logs the error and returns unchanged standings.
    ///
    /// - Parameters:
    ///   - roundID: The round to compute standings for.
    ///   - trigger: What caused this recomputation (used for animation differentiation).
    /// - Returns: A `StandingsChange` describing the transition from previous to new standings.
    @discardableResult
    public func recompute(for roundID: UUID, trigger: StandingsChangeTrigger) -> StandingsChange {
        let previous = currentStandings
        do {
            let newStandings = try computeStandings(for: roundID)
            let positionChanges = buildPositionChanges(previous: previous, new: newStandings)
            let change = StandingsChange(
                previousStandings: previous,
                newStandings: newStandings,
                trigger: trigger,
                positionChanges: positionChanges
            )
            currentStandings = newStandings
            latestChange = change
            return change
        } catch {
            logger.error("StandingsEngine.recompute failed for round \(roundID): \(error)")
            return StandingsChange(
                previousStandings: previous,
                newStandings: previous,
                trigger: trigger,
                positionChanges: [:]
            )
        }
    }

    // MARK: - Private

    private func computeStandings(for roundID: UUID) throws -> [Standing] {
        // Fetch the round to get courseID and player list
        let roundIDLocal = roundID
        let roundDescriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == roundIDLocal })
        guard let round = try modelContext.fetch(roundDescriptor).first else {
            return []
        }

        // Fetch all ScoreEvents for this round
        let eventDescriptor = FetchDescriptor<ScoreEvent>(predicate: #Predicate { $0.roundID == roundIDLocal })
        let allEvents = try modelContext.fetch(eventDescriptor)

        // Fetch holes for par values
        let courseIDLocal = round.courseID
        let holeDescriptor = FetchDescriptor<Hole>(predicate: #Predicate { $0.courseID == courseIDLocal })
        let holes = try modelContext.fetch(holeDescriptor)
        let parByHole = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0.par) })

        // Fetch all registered players for name resolution (small dataset)
        let allPlayers = try modelContext.fetch(FetchDescriptor<Player>())
        let playersByIDString = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id.uuidString, $0) })

        // Build unified player list: registered + guests
        let allPlayerIDs = round.playerIDs + round.guestNames.map { "guest:\($0)" }

        // Compute raw totals per player
        var unsortedStandings: [Standing] = allPlayerIDs.compactMap { playerID in
            let playerName = resolvePlayerName(playerID: playerID, playersByIDString: playersByIDString)
            let scoredHoles = Set(allEvents.filter { $0.playerID == playerID }.map(\.holeNumber))
            var totalStrokes = 0
            var totalPar = 0
            var holesPlayed = 0
            for holeNumber in scoredHoles {
                guard let leaf = resolveCurrentScore(for: playerID, hole: holeNumber, in: allEvents) else { continue }
                totalStrokes += leaf.strokeCount
                totalPar += parByHole[holeNumber] ?? 3
                holesPlayed += 1
            }
            return Standing(
                playerID: playerID,
                playerName: playerName,
                position: 0, // Assigned below after sorting
                totalStrokes: totalStrokes,
                holesPlayed: holesPlayed,
                scoreRelativeToPar: totalStrokes - totalPar
            )
        }

        // Sort: ascending by scoreRelativeToPar, then alphabetical by playerName (tiebreak)
        unsortedStandings.sort { a, b in
            if a.scoreRelativeToPar != b.scoreRelativeToPar { return a.scoreRelativeToPar < b.scoreRelativeToPar }
            return a.playerName < b.playerName
        }

        // Assign 1-based positions (tied players share the same position)
        var result: [Standing] = []
        for (index, standing) in unsortedStandings.enumerated() {
            let position: Int
            if index == 0 {
                position = 1
            } else if standing.scoreRelativeToPar == unsortedStandings[index - 1].scoreRelativeToPar {
                position = result[index - 1].position
            } else {
                position = index + 1
            }
            result.append(Standing(
                playerID: standing.playerID,
                playerName: standing.playerName,
                position: position,
                totalStrokes: standing.totalStrokes,
                holesPlayed: standing.holesPlayed,
                scoreRelativeToPar: standing.scoreRelativeToPar
            ))
        }
        return result
    }

    private func resolvePlayerName(playerID: String, playersByIDString: [String: Player]) -> String {
        if playerID.hasPrefix("guest:") {
            return String(playerID.dropFirst(6))
        }
        return playersByIDString[playerID]?.displayName ?? playerID
    }

    private func buildPositionChanges(
        previous: [Standing],
        new: [Standing]
    ) -> [String: StandingsChange.PositionChange] {
        var changes: [String: StandingsChange.PositionChange] = [:]
        for standing in new {
            guard let prev = previous.first(where: { $0.playerID == standing.playerID }),
                  prev.position != standing.position else { continue }
            changes[standing.playerID] = StandingsChange.PositionChange(from: prev.position, to: standing.position)
        }
        return changes
    }
}
