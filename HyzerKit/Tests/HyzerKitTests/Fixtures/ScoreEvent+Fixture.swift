import Foundation
@testable import HyzerKit

public extension ScoreEvent {
    /// Creates a ScoreEvent with test defaults. Use in tests only.
    static func fixture(
        roundID: UUID = UUID(),
        holeNumber: Int = 1,
        playerID: String = UUID().uuidString,
        strokeCount: Int = 3,
        reportedByPlayerID: UUID = UUID(),
        deviceID: String = "test-device"
    ) -> ScoreEvent {
        ScoreEvent(
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID,
            deviceID: deviceID
        )
    }
}
