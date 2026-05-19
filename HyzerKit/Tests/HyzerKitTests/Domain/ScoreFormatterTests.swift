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
