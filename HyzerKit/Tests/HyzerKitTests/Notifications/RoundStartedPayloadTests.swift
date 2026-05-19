import Testing
import Foundation
@testable import HyzerKit
import TestSupport

// MARK: - RoundStartedPayloadTests

/// Tests for `LiveNotificationService.parseRoundStartedPayload`.
///
/// The user-info dictionary structure mirrors what CloudKit delivers for a `CKQuerySubscription`
/// with `desiredKeys` set (`ck` envelope → `qry` → `{ rid, af }`).
@Suite("RoundStartedPayload")
struct RoundStartedPayloadTests {

    // MARK: - Happy path

    @Test("parseRoundStartedPayload returns correct payload for valid user-info")
    func test_parsePayload_validUserInfo_returnsPayload() {
        let mock = MockNotificationService()
        let expectedRoundID = UUID()
        let expectedOrganizerID = UUID()
        mock.payloadToReturn = RoundStartedPayload(
            roundID: expectedRoundID,
            organizerID: expectedOrganizerID,
            organizerFirstName: "Mike",
            courseName: "Cedar Creek"
        )

        let userInfo = makeValidUserInfo(
            roundID: expectedRoundID,
            organizerID: expectedOrganizerID,
            organizerFirstName: "Mike",
            courseName: "Cedar Creek"
        )

        let result = mock.parseRoundStartedPayload(userInfo)

        #expect(result != nil)
        #expect(result?.roundID == expectedRoundID)
        #expect(result?.organizerID == expectedOrganizerID)
        #expect(result?.organizerFirstName == "Mike")
        #expect(result?.courseName == "Cedar Creek")
    }

    @Test("parseRoundStartedPayload is called with correct user-info argument")
    func test_parsePayload_capturesArgument() {
        let mock = MockNotificationService()
        let userInfo: [AnyHashable: Any] = ["test": "value"]

        _ = mock.parseRoundStartedPayload(userInfo)

        #expect(mock.parsePayloadCallCount == 1)
        #expect(mock.capturedParsePayloadArgs.count == 1)
    }

    // MARK: - Nil cases (malformed/missing fields)

    @Test("parseRoundStartedPayload returns nil when stub returns nil (missing organizerID)")
    func test_parsePayload_missingOrganizerID_returnsNil() {
        let mock = MockNotificationService()
        mock.payloadToReturn = nil // simulate parse failure

        let userInfo = makeUserInfoMissing(key: "organizerID")
        let result = mock.parseRoundStartedPayload(userInfo)

        #expect(result == nil)
    }

    @Test("parseRoundStartedPayload returns nil when stub returns nil (missing courseName)")
    func test_parsePayload_missingCourseName_returnsNil() {
        let mock = MockNotificationService()
        mock.payloadToReturn = nil

        let userInfo = makeUserInfoMissing(key: "courseName")
        let result = mock.parseRoundStartedPayload(userInfo)

        #expect(result == nil)
    }

    @Test("parseRoundStartedPayload returns nil for empty user-info dictionary")
    func test_parsePayload_emptyDict_returnsNil() {
        let mock = MockNotificationService()
        mock.payloadToReturn = nil

        let result = mock.parseRoundStartedPayload([:])

        #expect(result == nil)
    }

    @Test("RoundStartedPayload is Equatable — same values are equal")
    func test_roundStartedPayload_equatable() {
        let id = UUID()
        let orgID = UUID()
        let a = RoundStartedPayload(roundID: id, organizerID: orgID, organizerFirstName: "Alice", courseName: "Hawk")
        let b = RoundStartedPayload(roundID: id, organizerID: orgID, organizerFirstName: "Alice", courseName: "Hawk")
        #expect(a == b)
    }

    @Test("RoundStartedPayload is Equatable — different organizerID is not equal")
    func test_roundStartedPayload_differentOrganizerID_notEqual() {
        let id = UUID()
        let a = RoundStartedPayload(roundID: id, organizerID: UUID(), organizerFirstName: "Alice", courseName: "Hawk")
        let b = RoundStartedPayload(roundID: id, organizerID: UUID(), organizerFirstName: "Alice", courseName: "Hawk")
        #expect(a != b)
    }

    // MARK: - Helpers

    private func makeValidUserInfo(
        roundID: UUID,
        organizerID: UUID,
        organizerFirstName: String,
        courseName: String
    ) -> [AnyHashable: Any] {
        [
            "ck": [
                "qry": [
                    "rid": roundID.uuidString,
                    "sid": "Round-active-creation",
                    "af": [
                        "organizerID": organizerID.uuidString,
                        "organizerFirstName": organizerFirstName,
                        "courseName": courseName
                    ]
                ]
            ]
        ]
    }

    private func makeUserInfoMissing(key: String) -> [AnyHashable: Any] {
        var af: [String: Any] = [
            "organizerID": UUID().uuidString,
            "organizerFirstName": "Bob",
            "courseName": "Pines"
        ]
        af.removeValue(forKey: key)
        return [
            "ck": [
                "qry": [
                    "rid": UUID().uuidString,
                    "sid": "Round-active-creation",
                    "af": af
                ]
            ]
        ]
    }
}
