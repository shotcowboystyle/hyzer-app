import Testing
import Foundation
@testable import HyzerKit
import TestSupport

/// Tests for the `RoundCompletePayload` value type and its mock parser contract.
///
/// **Parser behavior** (validating `userInfo` structure) is tested against the real
/// `LiveNotificationService` in `HyzerAppTests/LiveNotificationServiceTests.swift`
/// — that class lives in HyzerApp and is not reachable from this test target.
@Suite("RoundCompletePayload")
struct RoundCompletePayloadTests {

    // MARK: - Equatable / Sendable contract

    @Test("RoundCompletePayload is Equatable — same values are equal")
    func test_roundCompletePayload_equatable() {
        let id = UUID()
        let a = RoundCompletePayload(roundID: id, courseName: "Hawk", winnerFirstName: "Alice", winnerScoreDisplay: "E")
        let b = RoundCompletePayload(roundID: id, courseName: "Hawk", winnerFirstName: "Alice", winnerScoreDisplay: "E")
        #expect(a == b)
    }

    @Test("RoundCompletePayload is Equatable — different roundID is not equal")
    func test_roundCompletePayload_differentRoundID_notEqual() {
        let a = RoundCompletePayload(roundID: UUID(), courseName: "Hawk", winnerFirstName: "Alice", winnerScoreDisplay: "E")
        let b = RoundCompletePayload(roundID: UUID(), courseName: "Hawk", winnerFirstName: "Alice", winnerScoreDisplay: "E")
        #expect(a != b)
    }

    @Test("RoundCompletePayload preserves all fields through init")
    func test_roundCompletePayload_initPreservesFields() {
        let id = UUID()
        let payload = RoundCompletePayload(
            roundID: id,
            courseName: "Cedar Creek",
            winnerFirstName: "Alice",
            winnerScoreDisplay: "-3"
        )
        #expect(payload.roundID == id)
        #expect(payload.courseName == "Cedar Creek")
        #expect(payload.winnerFirstName == "Alice")
        #expect(payload.winnerScoreDisplay == "-3")
    }

    // MARK: - Mock parser stub contract (regression on MockNotificationService surface)

    @Test("MockNotificationService.parseRoundCompletePayload returns the configured stub")
    func test_mock_parsePayload_returnsConfiguredStub() {
        let mock = MockNotificationService()
        let expected = RoundCompletePayload(
            roundID: UUID(),
            courseName: "Cedar Creek",
            winnerFirstName: "Alice",
            winnerScoreDisplay: "-3"
        )
        mock.completePayloadToReturn = expected

        let result = mock.parseRoundCompletePayload(["any": "userInfo"])
        #expect(result == expected)
    }

    @Test("MockNotificationService.parseRoundCompletePayload increments call count and captures arg")
    func test_mock_parsePayload_capturesArgument() {
        let mock = MockNotificationService()
        let userInfo: [AnyHashable: Any] = ["test": "value"]

        _ = mock.parseRoundCompletePayload(userInfo)

        #expect(mock.parseCompletePayloadCallCount == 1)
        #expect(mock.capturedParseCompletePayloadArgs.count == 1)
    }
}
