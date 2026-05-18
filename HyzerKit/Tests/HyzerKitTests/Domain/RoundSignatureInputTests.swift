import Testing
import Foundation
@testable import HyzerKit

@Suite("RoundSignatureInput")
struct RoundSignatureInputTests {

    @Test("Two inputs with identical fields in different call order compare equal")
    func test_equatable_structuralEquality() {
        let courseID = UUID()
        let playerIDs = ["player-A", "player-B"]
        let strokes = [27, 31]

        let input1 = RoundSignatureInput(courseID: courseID, playerIDs: playerIDs, sortedTotalStrokes: strokes)
        let input2 = RoundSignatureInput(courseID: courseID, playerIDs: playerIDs, sortedTotalStrokes: strokes)

        #expect(input1 == input2)
    }

    @Test("Inputs with different courseID are not equal")
    func test_equatable_differentCourseID_notEqual() {
        let playerIDs = ["player-A"]
        let strokes = [27]

        let input1 = RoundSignatureInput(courseID: UUID(), playerIDs: playerIDs, sortedTotalStrokes: strokes)
        let input2 = RoundSignatureInput(courseID: UUID(), playerIDs: playerIDs, sortedTotalStrokes: strokes)

        #expect(input1 != input2)
    }

    @Test("Inputs with different playerIDs are not equal")
    func test_equatable_differentPlayerIDs_notEqual() {
        let courseID = UUID()
        let strokes = [27]

        let input1 = RoundSignatureInput(courseID: courseID, playerIDs: ["player-A"], sortedTotalStrokes: strokes)
        let input2 = RoundSignatureInput(courseID: courseID, playerIDs: ["player-B"], sortedTotalStrokes: strokes)

        #expect(input1 != input2)
    }

    @Test("Inputs with different sortedTotalStrokes are not equal")
    func test_equatable_differentStrokes_notEqual() {
        let courseID = UUID()
        let playerIDs = ["player-A"]

        let input1 = RoundSignatureInput(courseID: courseID, playerIDs: playerIDs, sortedTotalStrokes: [27])
        let input2 = RoundSignatureInput(courseID: courseID, playerIDs: playerIDs, sortedTotalStrokes: [28])

        #expect(input1 != input2)
    }
}
