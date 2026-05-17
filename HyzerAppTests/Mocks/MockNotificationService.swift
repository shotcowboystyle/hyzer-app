import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Local test double for `NotificationService` in HyzerAppTests.
///
/// Mirrors `MockNotificationService` in HyzerKitTests (separate copy — test targets
/// cannot share source files across module boundaries).
final class MockNotificationService: NotificationService, @unchecked Sendable {
    var nextAuthorizationStatus: NotificationAuthorizationStatus = .authorized
    var payloadToReturn: RoundStartedPayload?
    var completePayloadToReturn: RoundCompletePayload?
    var suppressionResult: Bool = false

    private(set) var requestAuthorizationCallCount = 0
    private(set) var currentAuthorizationStatusCallCount = 0
    private(set) var shouldSuppressPresentationCallCount = 0
    private(set) var parsePayloadCallCount = 0
    private(set) var parseCompletePayloadCallCount = 0

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        currentAuthorizationStatusCallCount += 1
        return nextAuthorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> NotificationAuthorizationStatus {
        requestAuthorizationCallCount += 1
        return nextAuthorizationStatus
    }

    func shouldSuppressPresentation(for payload: RoundStartedPayload, localPlayerID: UUID?) -> Bool {
        shouldSuppressPresentationCallCount += 1
        return suppressionResult
    }

    func parseRoundStartedPayload(_ userInfo: [AnyHashable: Any]) -> RoundStartedPayload? {
        parsePayloadCallCount += 1
        return payloadToReturn
    }

    func parseRoundCompletePayload(_ userInfo: [AnyHashable: Any]) -> RoundCompletePayload? {
        parseCompletePayloadCallCount += 1
        return completePayloadToReturn
    }
}
