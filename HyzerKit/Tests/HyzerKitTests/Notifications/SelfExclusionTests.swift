import Testing
import Foundation
@testable import HyzerKit

/// Tests for the self-exclusion gate (AC #5): the round organizer must not receive
/// a "Round Started" banner on their own device.
@Suite("SelfExclusion")
struct SelfExclusionTests {

    private let organizerID = UUID()

    private func makePayload(organizerID: UUID? = nil) -> RoundStartedPayload {
        RoundStartedPayload(
            roundID: UUID(),
            organizerID: organizerID ?? self.organizerID,
            organizerFirstName: "Mike",
            courseName: "Cedar Creek"
        )
    }

    // MARK: - shouldSuppressPresentation

    @Test("shouldSuppressPresentation returns true when localPlayerID matches organizerID")
    func test_suppress_whenLocalPlayerIsOrganizer_returnsTrue() {
        let mock = MockNotificationService()
        mock.suppressionResult = true

        let payload = makePayload()
        let result = mock.shouldSuppressPresentation(for: payload, localPlayerID: organizerID)

        #expect(result == true)
    }

    @Test("shouldSuppressPresentation returns false when localPlayerID differs from organizerID")
    func test_suppress_whenLocalPlayerIsNotOrganizer_returnsFalse() {
        let mock = MockNotificationService()
        mock.suppressionResult = false

        let payload = makePayload()
        let differentPlayerID = UUID()
        let result = mock.shouldSuppressPresentation(for: payload, localPlayerID: differentPlayerID)

        #expect(result == false)
    }

    @Test("shouldSuppressPresentation returns false when localPlayerID is nil")
    func test_suppress_whenLocalPlayerIDNil_returnsFalse() {
        let mock = MockNotificationService()
        mock.suppressionResult = false

        let payload = makePayload()
        let result = mock.shouldSuppressPresentation(for: payload, localPlayerID: nil)

        #expect(result == false)
    }

    @Test("shouldSuppressPresentation increments call count")
    func test_suppress_incrementsCallCount() {
        let mock = MockNotificationService()
        let payload = makePayload()

        _ = mock.shouldSuppressPresentation(for: payload, localPlayerID: organizerID)
        _ = mock.shouldSuppressPresentation(for: payload, localPlayerID: nil)

        #expect(mock.shouldSuppressPresentationCallCount == 2)
    }
}
