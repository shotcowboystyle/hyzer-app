import Foundation
@testable import HyzerKit

public extension Round {
    /// Creates a Round with test defaults. Use in tests only.
    static func fixture(
        courseID: UUID = UUID(),
        organizerID: UUID = UUID(),
        playerIDs: [String] = [],
        guestNames: [String] = [],
        holeCount: Int = 18
    ) -> Round {
        Round(
            courseID: courseID,
            organizerID: organizerID,
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: holeCount
        )
    }
}
