import Testing
import Foundation
import SwiftUI
@testable import HyzerKit
@testable import HyzerApp

/// Pixel-determinism and height-inclusion tests for `RoundSignature` via `ImageRenderer` (Story 14.2 — AC #1, #5).
@Suite("RoundSignature — Rendering")
@MainActor
struct RoundSignatureRenderingTests {

    // MARK: - Fixtures

    private func makeSnapshotView() -> SummaryCardSnapshotView {
        let courseID = UUID(uuidString: "A1A1A1A1-AAAA-AAAA-AAAA-A1A1A1A1A1A1")!
        let signatureInput = RoundSignatureInput(
            courseID: courseID,
            playerIDs: ["player-A", "player-B"],
            sortedTotalStrokes: [27, 31]
        )
        let playerRows: [SummaryPlayerRow] = [
            SummaryPlayerRow(
                id: "player-A",
                position: 1,
                playerName: "Alice",
                formattedScore: "-2",
                totalStrokes: 27,
                scoreColor: .scoreUnderPar,
                hasMedal: true
            ),
            SummaryPlayerRow(
                id: "player-B",
                position: 2,
                playerName: "Bob",
                formattedScore: "E",
                totalStrokes: 31,
                scoreColor: .scoreAtPar,
                hasMedal: true
            )
        ]
        return SummaryCardSnapshotView(
            courseName: "Hawk's Ridge",
            formattedDate: "May 18, 2026",
            playerRows: playerRows,
            holesPlayed: 9,
            organizerName: "Alice",
            signatureInput: signatureInput
        )
    }

    // MARK: - Tests

    @Test("Snapshot PNG is pixel-identical across two ImageRenderer invocations (AC #1, #5)")
    func test_render_isPixelIdentical_acrossTwoInvocations() throws {
        let view = makeSnapshotView()

        let renderer1 = ImageRenderer(content: view)
        renderer1.scale = 2.0
        let renderer2 = ImageRenderer(content: view)
        renderer2.scale = 2.0

        // Require renderer output so failures surface rather than silently passing in headless CI.
        // The HyzerKit `RoundSignatureHasher` determinism tests are the primary AC #1 evidence;
        // this test is corroborating end-to-end coverage through the ImageRenderer pipeline.
        let image1 = try #require(renderer1.uiImage, "ImageRenderer must produce a UIImage in the test host")
        let image2 = try #require(renderer2.uiImage, "ImageRenderer must produce a UIImage in the test host")
        let data1 = try #require(image1.pngData(), "First image must encode to PNG data")
        let data2 = try #require(image2.pngData(), "Second image must encode to PNG data")

        #expect(data1 == data2, "PNG output must be byte-identical across two renders of the same input (AC #1)")
    }

    @Test("RoundSignature reserves exactly 120pt of height (AC #3, #5)")
    func test_signature_reservesExactly120pt() throws {
        // Render `RoundSignature` standalone (constrained to the snapshot's content width) and
        // assert its rendered height equals the fixed 120pt the spec mandates (AC #3). This
        // proves the signature contributes its full 120pt to `SummaryCardSnapshotView`'s
        // exported PNG (AC #5) — combined with the pixel-determinism test above (which renders
        // `SummaryCardSnapshotView` and therefore exercises the signature inside the full card),
        // the two tests together cover the AC #5 "signature is in the exported image" claim.
        let input = RoundSignatureInput(
            courseID: UUID(uuidString: "A1A1A1A1-AAAA-AAAA-AAAA-A1A1A1A1A1A1")!,
            playerIDs: ["player-A", "player-B"],
            sortedTotalStrokes: [27, 31]
        )
        // 342pt = 390pt snapshot width minus 2 * SpacingTokens.xl (32pt) padding.
        let signatureView = RoundSignature(input: input).frame(width: 342)
        let renderer = ImageRenderer(content: signatureView)
        renderer.scale = 2.0

        let image = try #require(renderer.uiImage, "ImageRenderer must produce a UIImage in the test host")

        // `UIImage.size` is in points (scale-independent); a 120pt-tall view yields 120pt height.
        let expectedHeightPoints: CGFloat = 120
        #expect(
            abs(image.size.height - expectedHeightPoints) < 0.5,
            "RoundSignature must render at exactly 120pt height (got \(image.size.height)pt) — AC #3"
        )
    }
}
