import Testing
import SwiftUI
@testable import HyzerKit

@Suite("HoleScore")
struct HoleScoreTests {

    // MARK: - formattedRelativeToPar

    @Test("formattedRelativeToPar returns negative string for birdie")
    func test_formattedRelativeToPar_birdie_returnsNegativeString() {
        // Given: player gets 2 on a par-3 hole
        let hole = HoleScore(holeNumber: 1, par: 3, strokeCount: 2)

        // Then: displays as "-1"
        #expect(hole.formattedRelativeToPar == "-1")
    }

    @Test("formattedRelativeToPar returns E for par")
    func test_formattedRelativeToPar_par_returnsE() {
        // Given: player matches par on a par-4 hole
        let hole = HoleScore(holeNumber: 2, par: 4, strokeCount: 4)

        // Then: displays as "E"
        #expect(hole.formattedRelativeToPar == "E")
    }

    @Test("formattedRelativeToPar returns plus string for bogey")
    func test_formattedRelativeToPar_bogey_returnsPlusOne() {
        // Given: player shoots bogey on a par-3 hole
        let hole = HoleScore(holeNumber: 3, par: 3, strokeCount: 4)

        // Then: displays as "+1"
        #expect(hole.formattedRelativeToPar == "+1")
    }

    @Test("formattedRelativeToPar returns plus string for double bogey")
    func test_formattedRelativeToPar_doubleBogey_returnsPlusTwo() {
        // Given: player shoots double bogey on a par-3 hole
        let hole = HoleScore(holeNumber: 4, par: 3, strokeCount: 5)

        // Then: displays as "+2"
        #expect(hole.formattedRelativeToPar == "+2")
    }

    @Test("formattedRelativeToPar returns negative string for eagle")
    func test_formattedRelativeToPar_eagle_returnsMinus2() {
        // Given: player shoots eagle (2 under par) on a par-4 hole
        let hole = HoleScore(holeNumber: 5, par: 4, strokeCount: 2)

        // Then: displays as "-2"
        #expect(hole.formattedRelativeToPar == "-2")
    }

    // MARK: - scoreColor (4-tier)

    @Test("scoreColor returns scoreUnderPar for under par")
    func test_scoreColor_underPar_returnsScoreUnderPar() {
        // Given: birdie (2 strokes on par 3)
        let hole = HoleScore(holeNumber: 1, par: 3, strokeCount: 2)

        // Then: green color
        #expect(hole.scoreColor == Color.scoreUnderPar)
    }

    @Test("scoreColor returns scoreAtPar for par")
    func test_scoreColor_atPar_returnsScoreAtPar() {
        // Given: par (3 strokes on par 3)
        let hole = HoleScore(holeNumber: 2, par: 3, strokeCount: 3)

        // Then: white color
        #expect(hole.scoreColor == Color.scoreAtPar)
    }

    @Test("scoreColor returns scoreOverPar for bogey")
    func test_scoreColor_bogey_returnsScoreOverPar() {
        // Given: bogey (4 strokes on par 3)
        let hole = HoleScore(holeNumber: 3, par: 3, strokeCount: 4)

        // Then: amber color
        #expect(hole.scoreColor == Color.scoreOverPar)
    }

    @Test("scoreColor returns scoreWayOver for double bogey")
    func test_scoreColor_doubleBogey_returnsScoreWayOver() {
        // Given: double bogey (5 strokes on par 3)
        let hole = HoleScore(holeNumber: 4, par: 3, strokeCount: 5)

        // Then: red color
        #expect(hole.scoreColor == Color.scoreWayOver)
    }

    @Test("scoreColor returns scoreWayOver for triple bogey and beyond")
    func test_scoreColor_tripleBogey_returnsScoreWayOver() {
        // Given: triple bogey (6 strokes on par 3)
        let hole = HoleScore(holeNumber: 5, par: 3, strokeCount: 6)

        // Then: red color (double bogey+)
        #expect(hole.scoreColor == Color.scoreWayOver)
    }

    // MARK: - relativeToPar computation

    @Test("relativeToPar is computed from strokeCount minus par")
    func test_relativeToPar_isStrokeCountMinusPar() {
        let hole = HoleScore(holeNumber: 1, par: 4, strokeCount: 5)
        #expect(hole.relativeToPar == 1)
    }

    @Test("relativeToPar is negative for under par")
    func test_relativeToPar_negative_forUnderPar() {
        let hole = HoleScore(holeNumber: 2, par: 5, strokeCount: 3)
        #expect(hole.relativeToPar == -2)
    }

    // MARK: - Identifiable

    @Test("id is holeNumber")
    func test_id_isHoleNumber() {
        let hole = HoleScore(holeNumber: 7, par: 3, strokeCount: 3)
        #expect(hole.id == 7)
    }
}
