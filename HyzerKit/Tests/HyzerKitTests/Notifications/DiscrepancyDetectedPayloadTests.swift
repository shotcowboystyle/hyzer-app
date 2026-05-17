import Testing
import Foundation
@testable import HyzerKit

/// Tests for the `DiscrepancyDetectedPayload` value type and its mock parser contract.
///
/// Live parser SID/field validation lives in `HyzerAppTests/LiveNotificationServiceTests.swift`
/// — `LiveNotificationService` is in HyzerApp and is not reachable from this test target.
@Suite("DiscrepancyDetectedPayload")
struct DiscrepancyDetectedPayloadTests {

    // MARK: - Equatable / Sendable contract

    @Test("DiscrepancyDetectedPayload is Equatable — same values are equal")
    func test_equatable_sameValues() {
        let did = UUID()
        let rid = UUID()
        let a = DiscrepancyDetectedPayload(discrepancyID: did, roundID: rid, playerID: "player-1", holeNumber: 5)
        let b = DiscrepancyDetectedPayload(discrepancyID: did, roundID: rid, playerID: "player-1", holeNumber: 5)
        #expect(a == b)
    }

    @Test("DiscrepancyDetectedPayload is Equatable — different discrepancyID is not equal")
    func test_equatable_differentDiscrepancyID() {
        let rid = UUID()
        let a = DiscrepancyDetectedPayload(discrepancyID: UUID(), roundID: rid, playerID: "player-1", holeNumber: 5)
        let b = DiscrepancyDetectedPayload(discrepancyID: UUID(), roundID: rid, playerID: "player-1", holeNumber: 5)
        #expect(a != b)
    }

    @Test("DiscrepancyDetectedPayload preserves all fields through init")
    func test_initPreservesFields() {
        let did = UUID()
        let rid = UUID()
        let payload = DiscrepancyDetectedPayload(
            discrepancyID: did,
            roundID: rid,
            playerID: "guest:abc123",
            holeNumber: 9
        )
        #expect(payload.discrepancyID == did)
        #expect(payload.roundID == rid)
        #expect(payload.playerID == "guest:abc123")
        #expect(payload.holeNumber == 9)
    }

    @Test("DiscrepancyDetectedPayload supports String playerID for guest IDs")
    func test_guestPlayerID() {
        let payload = DiscrepancyDetectedPayload(
            discrepancyID: UUID(),
            roundID: UUID(),
            playerID: "guest:some-uuid",
            holeNumber: 3
        )
        #expect(payload.playerID.hasPrefix("guest:"))
    }

    // MARK: - Mock parser stub contract

    @Test("MockNotificationService.parseDiscrepancyDetectedPayload returns the configured stub")
    func test_mock_returnsConfiguredStub() {
        let mock = MockNotificationService()
        let expected = DiscrepancyDetectedPayload(
            discrepancyID: UUID(),
            roundID: UUID(),
            playerID: "player-abc",
            holeNumber: 7
        )
        mock.discrepancyPayloadToReturn = expected

        let result = mock.parseDiscrepancyDetectedPayload(["any": "userInfo"])
        #expect(result == expected)
    }

    @Test("MockNotificationService.parseDiscrepancyDetectedPayload increments call count and captures arg")
    func test_mock_capturesArgument() {
        let mock = MockNotificationService()
        let userInfo: [AnyHashable: Any] = ["test": "value"]

        _ = mock.parseDiscrepancyDetectedPayload(userInfo)

        #expect(mock.parseDiscrepancyPayloadCallCount == 1)
        #expect(mock.capturedParseDiscrepancyPayloadArgs.count == 1)
    }

    @Test("MockNotificationService.parseDiscrepancyDetectedPayload returns nil when not configured")
    func test_mock_returnsNilByDefault() {
        let mock = MockNotificationService()
        let result = mock.parseDiscrepancyDetectedPayload(["key": "value"])
        #expect(result == nil)
    }
}
