import Testing
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for `LiveNotificationService.parseRoundStartedPayload` and
/// `parseRoundCompletePayload` — the actual production parsers that lift round metadata
/// out of CloudKit subscription `userInfo` envelopes.
///
/// The HyzerKit-side tests (`RoundCompletePayloadTests`) cover only the value type and
/// the mock surface — those tests cannot reach `LiveNotificationService` because it
/// lives in HyzerApp. This suite validates the real envelope-parsing logic, including
/// subscription-ID gating which prevents payload-misroute when two subscriptions exist.
@Suite("LiveNotificationService")
struct LiveNotificationServiceTests {

    private let service = LiveNotificationService()

    // MARK: - parseRoundCompletePayload — happy path

    @Test("parseRoundCompletePayload returns the payload for a valid Round-complete-update envelope")
    func test_complete_validUserInfo() {
        let roundID = UUID()
        let userInfo = makeCompleteUserInfo(
            roundID: roundID,
            sid: "Round-complete-update",
            courseName: "Cedar Creek",
            winnerFirstName: "Alice",
            winnerScoreDisplay: "-3"
        )

        let result = service.parseRoundCompletePayload(userInfo)

        #expect(result != nil)
        #expect(result?.roundID == roundID)
        #expect(result?.courseName == "Cedar Creek")
        #expect(result?.winnerFirstName == "Alice")
        #expect(result?.winnerScoreDisplay == "-3")
    }

    // MARK: - parseRoundCompletePayload — SID gating (regression on payload misroute)

    @Test("parseRoundCompletePayload returns nil for a Round-active-creation envelope")
    func test_complete_wrongSID_returnsNil() {
        let userInfo = makeCompleteUserInfo(
            roundID: UUID(),
            sid: "Round-active-creation",
            courseName: "Pines",
            winnerFirstName: "Bob",
            winnerScoreDisplay: "+1"
        )
        #expect(service.parseRoundCompletePayload(userInfo) == nil)
    }

    @Test("parseRoundCompletePayload returns nil when sid is missing")
    func test_complete_missingSID_returnsNil() {
        var userInfo = makeCompleteUserInfo(
            roundID: UUID(),
            sid: "Round-complete-update",
            courseName: "X",
            winnerFirstName: "Y",
            winnerScoreDisplay: "E"
        )
        if var ck = userInfo["ck"] as? [String: Any],
           var qry = ck["qry"] as? [String: Any] {
            qry.removeValue(forKey: "sid")
            ck["qry"] = qry
            userInfo["ck"] = ck
        }
        #expect(service.parseRoundCompletePayload(userInfo) == nil)
    }

    // MARK: - parseRoundCompletePayload — missing fields

    @Test("parseRoundCompletePayload returns nil when courseName is missing")
    func test_complete_missingCourseName_returnsNil() {
        let userInfo = makeCompleteUserInfo(
            roundID: UUID(),
            sid: "Round-complete-update",
            courseName: nil,
            winnerFirstName: "Alice",
            winnerScoreDisplay: "-3"
        )
        #expect(service.parseRoundCompletePayload(userInfo) == nil)
    }

    @Test("parseRoundCompletePayload returns nil when winnerFirstName is missing")
    func test_complete_missingWinnerFirstName_returnsNil() {
        let userInfo = makeCompleteUserInfo(
            roundID: UUID(),
            sid: "Round-complete-update",
            courseName: "Cedar Creek",
            winnerFirstName: nil,
            winnerScoreDisplay: "-3"
        )
        #expect(service.parseRoundCompletePayload(userInfo) == nil)
    }

    @Test("parseRoundCompletePayload returns nil when winnerScoreDisplay is missing")
    func test_complete_missingWinnerScoreDisplay_returnsNil() {
        let userInfo = makeCompleteUserInfo(
            roundID: UUID(),
            sid: "Round-complete-update",
            courseName: "Cedar Creek",
            winnerFirstName: "Alice",
            winnerScoreDisplay: nil
        )
        #expect(service.parseRoundCompletePayload(userInfo) == nil)
    }

    @Test("parseRoundCompletePayload returns nil for malformed roundID")
    func test_complete_invalidRoundID_returnsNil() {
        let userInfo: [AnyHashable: Any] = [
            "ck": [
                "qry": [
                    "rid": "not-a-uuid",
                    "sid": "Round-complete-update",
                    "af": [
                        "courseName": "Cedar Creek",
                        "winnerFirstName": "Alice",
                        "winnerScoreDisplay": "-3"
                    ]
                ]
            ]
        ]
        #expect(service.parseRoundCompletePayload(userInfo) == nil)
    }

    @Test("parseRoundCompletePayload returns nil for empty user-info dictionary")
    func test_complete_emptyDict_returnsNil() {
        #expect(service.parseRoundCompletePayload([:]) == nil)
    }

    // MARK: - parseRoundStartedPayload — SID gating (regression for Story 12.1 + 12.2 coexistence)

    @Test("parseRoundStartedPayload returns nil for a Round-complete-update envelope")
    func test_started_wrongSID_returnsNil() {
        let organizerID = UUID()
        let userInfo: [AnyHashable: Any] = [
            "ck": [
                "qry": [
                    "rid": UUID().uuidString,
                    "sid": "Round-complete-update",
                    "af": [
                        "organizerID": organizerID.uuidString,
                        "organizerFirstName": "Alice",
                        "courseName": "Cedar Creek"
                    ]
                ]
            ]
        ]
        #expect(service.parseRoundStartedPayload(userInfo) == nil)
    }

    @Test("parseRoundStartedPayload returns the payload for a valid Round-active-creation envelope")
    func test_started_validUserInfo() {
        let roundID = UUID()
        let organizerID = UUID()
        let userInfo: [AnyHashable: Any] = [
            "ck": [
                "qry": [
                    "rid": roundID.uuidString,
                    "sid": "Round-active-creation",
                    "af": [
                        "organizerID": organizerID.uuidString,
                        "organizerFirstName": "Alice",
                        "courseName": "Cedar Creek"
                    ]
                ]
            ]
        ]

        let result = service.parseRoundStartedPayload(userInfo)

        #expect(result != nil)
        #expect(result?.roundID == roundID)
        #expect(result?.organizerID == organizerID)
        #expect(result?.organizerFirstName == "Alice")
        #expect(result?.courseName == "Cedar Creek")
    }

    // MARK: - Helpers

    /// Builds a Round-complete-update envelope; any field passed as `nil` is omitted.
    private func makeCompleteUserInfo(
        roundID: UUID,
        sid: String,
        courseName: String?,
        winnerFirstName: String?,
        winnerScoreDisplay: String?
    ) -> [AnyHashable: Any] {
        var af: [String: Any] = [:]
        if let courseName { af["courseName"] = courseName }
        if let winnerFirstName { af["winnerFirstName"] = winnerFirstName }
        if let winnerScoreDisplay { af["winnerScoreDisplay"] = winnerScoreDisplay }
        return [
            "ck": [
                "qry": [
                    "rid": roundID.uuidString,
                    "sid": sid,
                    "af": af
                ]
            ]
        ]
    }
}
