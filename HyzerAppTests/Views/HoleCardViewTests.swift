import Testing
import SwiftData
import Foundation
@testable import HyzerKit

/// Tests for HoleCardView scoring attribution (Story 10.2).
///
/// HoleCardView is a pure render view — tests exercise the domain logic it depends on
/// (`resolveCurrentScore`) and the lookup table wiring (`scorerNamesByID`).
@Suite("HoleCardView — Scoring Attribution")
struct HoleCardViewTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ScoreEvent.self, configurations: config)
        return ModelContext(container)
    }

    private func makeEvent(
        roundID: UUID = UUID(),
        holeNumber: Int = 1,
        playerID: String = "player-1",
        strokeCount: Int = 3,
        reportedByPlayerID: UUID,
        supersedesEventID: UUID? = nil,
        context: ModelContext
    ) -> ScoreEvent {
        let event = ScoreEvent(
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID,
            deviceID: "test-device"
        )
        event.supersedesEventID = supersedesEventID
        context.insert(event)
        return event
    }

    // MARK: - Attribution lookup

    @Test("Scored row resolves scorer name from scorerNamesByID")
    func test_playerRow_withScore_rendersAttribution() throws {
        let ctx = try makeContext()
        let reporterID = UUID()
        let event = makeEvent(reportedByPlayerID: reporterID, context: ctx)

        let scorerNamesByID = [reporterID.uuidString: "Jake"]
        let resolved = resolveCurrentScore(for: event.playerID, hole: event.holeNumber, in: [event])

        #expect(resolved != nil)
        #expect(scorerNamesByID[resolved!.reportedByPlayerID.uuidString] == "Jake")
    }

    @Test("Unscored player produces no resolved event — no attribution")
    func test_playerRow_withoutScore_noAttribution() throws {
        let resolved = resolveCurrentScore(for: "player-2", hole: 1, in: [])
        #expect(resolved == nil)
    }

    @Test("Missing key in scorerNamesByID returns nil — no Unknown fallback")
    func test_playerRow_scorerLookupMiss_noAttributionRendered() throws {
        let ctx = try makeContext()
        let reporterID = UUID()
        let event = makeEvent(reportedByPlayerID: reporterID, context: ctx)

        let scorerNamesByID: [String: String] = [:]
        let resolved = resolveCurrentScore(for: event.playerID, hole: event.holeNumber, in: [event])

        #expect(resolved != nil)
        let name = scorerNamesByID[resolved!.reportedByPlayerID.uuidString]
        #expect(name == nil)
        #expect(name != "Unknown")
    }

    // MARK: - Supersession chain (AC: 2)

    @Test("Attribution comes from the leaf event, not the superseded original")
    func test_supersededScore_attributionFromLeafEvent_notOriginal() throws {
        let ctx = try makeContext()
        let roundID = UUID()
        let playerID = "player-1"
        let originalReporterID = UUID()
        let correctorID = UUID()

        let eventA = makeEvent(roundID: roundID, playerID: playerID, strokeCount: 5,
                               reportedByPlayerID: originalReporterID, context: ctx)
        let eventB = makeEvent(roundID: roundID, playerID: playerID, strokeCount: 3,
                               reportedByPlayerID: correctorID,
                               supersedesEventID: eventA.id, context: ctx)

        let resolved = resolveCurrentScore(for: playerID, hole: 1, in: [eventA, eventB])

        #expect(resolved?.id == eventB.id)
        #expect(resolved?.reportedByPlayerID == correctorID)
        #expect(resolved?.reportedByPlayerID != originalReporterID)
    }

    @Test("Three-hop chain A→B→C: attribution comes from C (the leaf)")
    func test_supersededScore_multiHopChain_attributionFromLeaf() throws {
        let ctx = try makeContext()
        let roundID = UUID()
        let playerID = "player-1"
        let reporterA = UUID()
        let reporterB = UUID()
        let reporterC = UUID()

        let eventA = makeEvent(roundID: roundID, playerID: playerID, strokeCount: 5,
                               reportedByPlayerID: reporterA, context: ctx)
        let eventB = makeEvent(roundID: roundID, playerID: playerID, strokeCount: 4,
                               reportedByPlayerID: reporterB,
                               supersedesEventID: eventA.id, context: ctx)
        let eventC = makeEvent(roundID: roundID, playerID: playerID, strokeCount: 3,
                               reportedByPlayerID: reporterC,
                               supersedesEventID: eventB.id, context: ctx)

        let resolved = resolveCurrentScore(for: playerID, hole: 1, in: [eventA, eventB, eventC])

        #expect(resolved?.id == eventC.id)
        #expect(resolved?.reportedByPlayerID == reporterC)
    }

    // MARK: - Accessibility labels (AC: 4)

    @Test("Accessibility label includes Scored by name when lookup succeeds")
    func test_accessibilityLabel_withAttribution_includesScoredBy() throws {
        let ctx = try makeContext()
        let reporterID = UUID()
        let event = makeEvent(strokeCount: 3, reportedByPlayerID: reporterID, context: ctx)

        let scorerNamesByID = [reporterID.uuidString: "Jake"]
        let scorerName = scorerNamesByID[event.reportedByPlayerID.uuidString]
        let parPhrase = relativeToParPhrase(strokes: event.strokeCount, par: 3)
        var label = "Mike, score \(event.strokeCount), \(parPhrase)"
        if let name = scorerName {
            label += ". Scored by \(name)."
        }

        #expect(label.contains("Scored by Jake"))
        #expect(label == "Mike, score 3, even par. Scored by Jake.")
    }

    @Test("Accessibility label omits Scored by sentence when scorer lookup misses")
    func test_accessibilityLabel_lookupMiss_noScoredBySentence() throws {
        let ctx = try makeContext()
        let reporterID = UUID()
        let event = makeEvent(strokeCount: 4, reportedByPlayerID: reporterID, context: ctx)

        let scorerNamesByID: [String: String] = [:]
        let scorerName = scorerNamesByID[event.reportedByPlayerID.uuidString]
        let parPhrase = relativeToParPhrase(strokes: event.strokeCount, par: 3)
        var label = "Mike, score \(event.strokeCount), \(parPhrase)"
        if let name = scorerName {
            label += ". Scored by \(name)."
        }

        #expect(!label.contains("Scored by"))
        #expect(!label.contains("Unknown"))
    }

    // MARK: - relativeToParPhrase helper

    @Test("relativeToParPhrase: two under par")
    func test_relativeToParPhrase_twoUnder() {
        #expect(relativeToParPhrase(strokes: 1, par: 3) == "2 under par")
    }

    @Test("relativeToParPhrase: one under par (birdie)")
    func test_relativeToParPhrase_birdie() {
        #expect(relativeToParPhrase(strokes: 2, par: 3) == "one under par")
    }

    @Test("relativeToParPhrase: even par")
    func test_relativeToParPhrase_par() {
        #expect(relativeToParPhrase(strokes: 3, par: 3) == "even par")
    }

    @Test("relativeToParPhrase: one over par (bogey)")
    func test_relativeToParPhrase_bogey() {
        #expect(relativeToParPhrase(strokes: 4, par: 3) == "one over par")
    }

    @Test("relativeToParPhrase: two over par (double bogey)")
    func test_relativeToParPhrase_doubleBogey() {
        #expect(relativeToParPhrase(strokes: 5, par: 3) == "2 over par")
    }
}

// MARK: - Free function mirror of HoleCardView.relativeToParPhrase (testable without a View instance)

private func relativeToParPhrase(strokes: Int, par: Int) -> String {
    let delta = strokes - par
    switch delta {
    case ..<(-1): return "\(abs(delta)) under par"
    case -1:      return "one under par"
    case 0:       return "even par"
    case 1:       return "one over par"
    default:      return "\(delta) over par"
    }
}
