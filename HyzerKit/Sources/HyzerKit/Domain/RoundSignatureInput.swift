import Foundation

/// Deterministic input to `RoundSignatureHasher.hash(_:)`.
///
/// Value type — never persisted; constructed fresh by `RoundSummaryViewModel.signatureInput`
/// at view-render time. Mirrors the value-type discipline of `StandingsSnapshot`,
/// `Standing`, and `DiscoveredRoundPayload`.
///
/// **Determinism invariants (AC #1, #7):**
/// - `playerIDs` MUST already be sorted ASCII-string order by the caller. Storing them
///   pre-sorted (rather than sorting in the hasher) makes the contract explicit at the
///   call site and lets tests assert against a known canonical form.
/// - `sortedTotalStrokes` MUST already be sorted ascending by the caller.
/// - Equality is structural: two inputs with identical `courseID`, `playerIDs`, and
///   `sortedTotalStrokes` are equal regardless of when or where they were constructed.
public struct RoundSignatureInput: Sendable, Equatable, Hashable {
    public let courseID: UUID
    public let playerIDs: [String]
    public let sortedTotalStrokes: [Int]

    public init(courseID: UUID, playerIDs: [String], sortedTotalStrokes: [Int]) {
        assert(
            playerIDs == playerIDs.sorted(),
            "RoundSignatureInput.playerIDs must be pre-sorted ASCII order by the caller — see doc comment"
        )
        assert(
            sortedTotalStrokes == sortedTotalStrokes.sorted(),
            "RoundSignatureInput.sortedTotalStrokes must be sorted ascending by the caller — see doc comment"
        )
        self.courseID = courseID
        self.playerIDs = playerIDs
        self.sortedTotalStrokes = sortedTotalStrokes
    }
}
