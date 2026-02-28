import Foundation
@testable import HyzerKit

public extension Discrepancy {
    /// Creates a Discrepancy with test defaults. Use in tests only.
    static func fixture(
        roundID: UUID = UUID(),
        playerID: String = UUID().uuidString,
        holeNumber: Int = 1,
        eventID1: UUID = UUID(),
        eventID2: UUID = UUID(),
        status: DiscrepancyStatus = .unresolved
    ) -> Discrepancy {
        let discrepancy = Discrepancy(
            roundID: roundID,
            playerID: playerID,
            holeNumber: holeNumber,
            eventID1: eventID1,
            eventID2: eventID2
        )
        discrepancy.status = status
        return discrepancy
    }
}
