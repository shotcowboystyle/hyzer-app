import Testing
import HyzerKit

@Suite("verboseScore")
struct VerboseScoreTests {
    @Test func evenPar() { #expect(verboseScore(relativeToPar: 0) == "even par") }
    @Test func oneOver() { #expect(verboseScore(relativeToPar: 1) == "one over par") }
    @Test func oneUnder() { #expect(verboseScore(relativeToPar: -1) == "one under par") }
    @Test func twentyOver() { #expect(verboseScore(relativeToPar: 20) == "twenty over par") }
    @Test func twentyUnder() { #expect(verboseScore(relativeToPar: -20) == "twenty under par") }
    @Test func twentyOneOver_fallsBackToDigits() { #expect(verboseScore(relativeToPar: 21) == "21 over par") }
    @Test func twentyOneUnder_fallsBackToDigits() { #expect(verboseScore(relativeToPar: -21) == "21 under par") }
    @Test func midRangeOver() { #expect(verboseScore(relativeToPar: 7) == "seven over par") }
}

/// Regression suite for Story 15.9 code-review patches: each migrated `accessibilityLabel`
/// call site must compose the verbose phrasing — never the compact `formatScore` form.
@Suite("verboseScore call-site composition")
struct VerboseScoreCallSiteTests {
    // WatchLeaderboardView.StandingRowView.accessibilityLabel(for:)
    @Test func watchLeaderboardRow_evenPar_speaksEvenPar() {
        let label = "Alice, position 1, \(verboseScore(relativeToPar: 0))"
        #expect(label == "Alice, position 1, even par")
    }

    @Test func watchLeaderboardRow_oneUnder_speaksOneUnderPar() {
        let label = "Bob, position 2, \(verboseScore(relativeToPar: -1))"
        #expect(label == "Bob, position 2, one under par")
    }

    // PlayerHoleBreakdownView.HoleScoreRow.accessibilityLabel
    @Test func holeScoreRow_evenPar_dropsCompactForm() {
        let label = "Hole 3, par 3, scored 3, \(verboseScore(relativeToPar: 0))"
        #expect(label == "Hole 3, par 3, scored 3, even par")
    }

    @Test func holeScoreRow_oneUnder_usesCardinalWord() {
        let label = "Hole 5, par 4, scored 3, \(verboseScore(relativeToPar: -1))"
        #expect(label == "Hole 5, par 4, scored 3, one under par")
    }

    // PlayerHoleBreakdownView.SummaryFooterRow.accessibilitySummary
    @Test func summaryFooter_evenPar_speaksEvenPar() {
        let summary = "Total, 54 strokes, par 54, \(verboseScore(relativeToPar: 0))"
        #expect(summary == "Total, 54 strokes, par 54, even par")
    }

    // HistoryRoundCard.accessibilityLabel — winner-is-user branch
    @Test func historyRoundCard_userWonAtEvenPar_usesVerbose() {
        let label = "Pine Hills, May 18 2026. You won at \(verboseScore(relativeToPar: 0))."
        #expect(label == "Pine Hills, May 18 2026. You won at even par.")
    }

    // HistoryRoundCard.accessibilityLabel — other-winner branch
    @Test func historyRoundCard_otherWonAtUnderPar_usesVerbose() {
        let phrase = "Carol won at \(verboseScore(relativeToPar: -2))."
        #expect(phrase == "Carol won at two under par.")
    }
}
