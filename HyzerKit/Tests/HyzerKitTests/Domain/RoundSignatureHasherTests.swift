import Testing
import Foundation
@testable import HyzerKit

@Suite("RoundSignatureHasher")
struct RoundSignatureHasherTests {

    private func makeInput(
        courseID: UUID = UUID(),
        playerIDs: [String] = ["player-A", "player-B"],
        strokes: [Int] = [27, 31]
    ) -> RoundSignatureInput {
        RoundSignatureInput(courseID: courseID, playerIDs: playerIDs, sortedTotalStrokes: strokes)
    }

    @Test("Hash is 32 bytes (SHA256 output size)")
    func test_hash_length() {
        let hash = RoundSignatureHasher.hash(makeInput())
        #expect(hash.count == 32)
    }

    @Test("Hash is deterministic across two invocations on the same input")
    func test_hash_isDeterministic_acrossInvocations() {
        let input = makeInput()
        let hash1 = RoundSignatureHasher.hash(input)
        let hash2 = RoundSignatureHasher.hash(input)
        #expect(hash1 == hash2)
    }

    @Test("Hash differs when courseID differs")
    func test_hash_differs_whenCourseIDDiffers() {
        let playerIDs = ["player-A"]
        let strokes = [27]
        let hash1 = RoundSignatureHasher.hash(RoundSignatureInput(courseID: UUID(), playerIDs: playerIDs, sortedTotalStrokes: strokes))
        let hash2 = RoundSignatureHasher.hash(RoundSignatureInput(courseID: UUID(), playerIDs: playerIDs, sortedTotalStrokes: strokes))
        #expect(hash1 != hash2)
    }

    @Test("Hash differs when playerIDs differ")
    func test_hash_differs_whenPlayerIDsDiffer() {
        let courseID = UUID()
        let strokes = [27]
        let hash1 = RoundSignatureHasher.hash(RoundSignatureInput(courseID: courseID, playerIDs: ["player-A"], sortedTotalStrokes: strokes))
        let hash2 = RoundSignatureHasher.hash(RoundSignatureInput(courseID: courseID, playerIDs: ["player-B"], sortedTotalStrokes: strokes))
        #expect(hash1 != hash2)
    }

    @Test("Hash differs when strokes differ")
    func test_hash_differs_whenStrokesDiffer() {
        let courseID = UUID()
        let playerIDs = ["player-A"]
        let hash1 = RoundSignatureHasher.hash(RoundSignatureInput(courseID: courseID, playerIDs: playerIDs, sortedTotalStrokes: [27]))
        let hash2 = RoundSignatureHasher.hash(RoundSignatureInput(courseID: courseID, playerIDs: playerIDs, sortedTotalStrokes: [28]))
        #expect(hash1 != hash2)
    }

    @Test("Display names are not a hash input — RoundSignatureInput has no name field")
    func test_hash_isStableAcross_displayNameVariation() {
        // No runtime assertion is possible: RoundSignatureInput's type definition has no
        // displayName field, so the compiler enforces this invariant at compile time
        // (AC #2 / Dev Notes: "Display names are NOT a signature input"). This @Test exists
        // as documentation of the structural guarantee.
    }
}
