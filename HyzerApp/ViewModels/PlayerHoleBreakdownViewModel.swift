import Foundation
import SwiftUI
import SwiftData
import HyzerKit

/// Fetches and transforms per-hole score data for one player in a completed round.
///
/// Called from `PlayerHoleBreakdownView.onAppear`. Reads SwiftData once; no sync,
/// no mutations. Follows the same pattern as `HistoryListViewModel`.
@MainActor
@Observable
final class PlayerHoleBreakdownViewModel {
    let playerName: String

    private(set) var holeScores: [HoleScore] = []
    private(set) var totalStrokes: Int = 0
    private(set) var totalPar: Int = 0

    var overallRelativeToPar: Int { totalStrokes - totalPar }

    var overallFormattedScore: String {
        if overallRelativeToPar < 0 { return "\(overallRelativeToPar)" }
        if overallRelativeToPar == 0 { return "E" }
        return "+\(overallRelativeToPar)"
    }

    var overallScoreColor: Color {
        if overallRelativeToPar < 0 { return .scoreUnderPar }
        if overallRelativeToPar == 0 { return .scoreAtPar }
        return .scoreOverPar
    }

    private let modelContext: ModelContext
    private let roundID: UUID
    private let playerID: String

    init(modelContext: ModelContext, roundID: UUID, playerID: String, playerName: String) {
        self.modelContext = modelContext
        self.roundID = roundID
        self.playerID = playerID
        self.playerName = playerName
    }

    /// Fetches all ScoreEvents for the round and resolves per-hole scores for this player.
    /// Called once from `.onAppear`.
    func computeBreakdown() {
        let roundIDLocal = roundID

        // Fetch round to get courseID and holeCount
        let roundDescriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == roundIDLocal })
        guard let round = (try? modelContext.fetch(roundDescriptor))?.first else { return }

        // Fetch holes to build par lookup
        let courseIDLocal = round.courseID
        let holeDescriptor = FetchDescriptor<Hole>(predicate: #Predicate { $0.courseID == courseIDLocal })
        let holes = (try? modelContext.fetch(holeDescriptor)) ?? []
        let parByHole = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0.par) })

        // Fetch all ScoreEvents for this round
        let eventDescriptor = FetchDescriptor<ScoreEvent>(predicate: #Predicate { $0.roundID == roundIDLocal })
        let allEvents = (try? modelContext.fetch(eventDescriptor)) ?? []

        // Resolve per-hole scores using Amendment A7 leaf-node resolution
        let playerIDLocal = playerID
        var scores: [HoleScore] = []
        for holeNumber in 1...round.holeCount {
            guard let leaf = resolveCurrentScore(for: playerIDLocal, hole: holeNumber, in: allEvents) else { continue }
            let par = parByHole[holeNumber] ?? 3
            scores.append(HoleScore(holeNumber: holeNumber, par: par, strokeCount: leaf.strokeCount))
        }

        holeScores = scores.sorted { $0.holeNumber < $1.holeNumber }
        totalStrokes = holeScores.reduce(0) { $0 + $1.strokeCount }
        totalPar = holeScores.reduce(0) { $0 + $1.par }
    }
}
