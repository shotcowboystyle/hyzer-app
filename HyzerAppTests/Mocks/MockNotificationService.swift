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
    var discrepancyPayloadToReturn: DiscrepancyDetectedPayload?
    var suppressionResult: Bool = false

    private(set) var requestAuthorizationCallCount = 0
    private(set) var currentAuthorizationStatusCallCount = 0
    private(set) var shouldSuppressPresentationCallCount = 0
    private(set) var parsePayloadCallCount = 0
    private(set) var parseCompletePayloadCallCount = 0
    private(set) var parseDiscrepancyPayloadCallCount = 0

    // Captured user-info dictionaries — mirrors the HyzerKit `MockNotificationService` mock so
    // `AppServicesTests` can assert the payload passed through the handler chain.
    private(set) var capturedParsePayloadArgs: [[AnyHashable: Any]] = []
    private(set) var capturedParseCompletePayloadArgs: [[AnyHashable: Any]] = []
    private(set) var capturedParseDiscrepancyPayloadArgs: [[AnyHashable: Any]] = []

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

    func parseDiscrepancyDetectedPayload(_ userInfo: [AnyHashable: Any]) -> DiscrepancyDetectedPayload? {
        parseDiscrepancyPayloadCallCount += 1
        capturedParseDiscrepancyPayloadArgs.append(userInfo)
        return discrepancyPayloadToReturn
    }
}
