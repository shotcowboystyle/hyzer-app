import Foundation
@testable import HyzerKit

/// In-memory test double for `NotificationService`.
///
/// Mirrors the structure of `MockCloudKitClient`:
/// - Tracked call counts for assertion
/// - Settable return values for stubbing
/// - Captured arguments for inspection
final class MockNotificationService: NotificationService, @unchecked Sendable {
    // MARK: - Stubbed return values

    var nextAuthorizationStatus: NotificationAuthorizationStatus = .authorized

    /// When set to non-nil, `parseRoundStartedPayload` returns this payload.
    var payloadToReturn: RoundStartedPayload?

    /// When set to non-nil, `parseRoundCompletePayload` returns this payload.
    var completePayloadToReturn: RoundCompletePayload?

    /// Controls `shouldSuppressPresentation` return value.
    var suppressionResult: Bool = false

    // MARK: - Call tracking

    private(set) var currentAuthorizationStatusCallCount = 0
    private(set) var requestAuthorizationCallCount = 0
    private(set) var shouldSuppressPresentationCallCount = 0
    private(set) var parsePayloadCallCount = 0
    private(set) var parseCompletePayloadCallCount = 0

    /// All user-info dictionaries passed to `parseRoundStartedPayload`.
    private(set) var capturedParsePayloadArgs: [[AnyHashable: Any]] = []

    /// All user-info dictionaries passed to `parseRoundCompletePayload`.
    private(set) var capturedParseCompletePayloadArgs: [[AnyHashable: Any]] = []

    // MARK: - NotificationService

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
        capturedParsePayloadArgs.append(userInfo)
        return payloadToReturn
    }

    func parseRoundCompletePayload(_ userInfo: [AnyHashable: Any]) -> RoundCompletePayload? {
        parseCompletePayloadCallCount += 1
        capturedParseCompletePayloadArgs.append(userInfo)
        return completePayloadToReturn
    }

    // MARK: - Test helpers

    func reset() {
        nextAuthorizationStatus = .authorized
        payloadToReturn = nil
        completePayloadToReturn = nil
        suppressionResult = false
        currentAuthorizationStatusCallCount = 0
        requestAuthorizationCallCount = 0
        shouldSuppressPresentationCallCount = 0
        parsePayloadCallCount = 0
        parseCompletePayloadCallCount = 0
        capturedParsePayloadArgs.removeAll()
        capturedParseCompletePayloadArgs.removeAll()
    }
}
