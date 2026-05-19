import Foundation
import HyzerKit

/// In-memory test double for `NotificationService`.
///
/// Mirrors the structure of `MockCloudKitClient`:
/// - Tracked call counts for assertion
/// - Settable return values for stubbing
/// - Captured arguments for inspection
public final class MockNotificationService: NotificationService, @unchecked Sendable {
    // MARK: - Stubbed return values

    public var nextAuthorizationStatus: NotificationAuthorizationStatus = .authorized

    /// When set to non-nil, `parseRoundStartedPayload` returns this payload.
    public var payloadToReturn: RoundStartedPayload?

    /// When set to non-nil, `parseRoundCompletePayload` returns this payload.
    public var completePayloadToReturn: RoundCompletePayload?

    /// When set to non-nil, `parseDiscrepancyDetectedPayload` returns this payload.
    public var discrepancyPayloadToReturn: DiscrepancyDetectedPayload?

    /// Controls `shouldSuppressPresentation` return value.
    public var suppressionResult: Bool = false

    // MARK: - Call tracking

    public private(set) var currentAuthorizationStatusCallCount = 0
    public private(set) var requestAuthorizationCallCount = 0
    public private(set) var shouldSuppressPresentationCallCount = 0
    public private(set) var parsePayloadCallCount = 0
    public private(set) var parseCompletePayloadCallCount = 0
    public private(set) var parseDiscrepancyPayloadCallCount = 0

    /// All user-info dictionaries passed to `parseRoundStartedPayload`.
    public private(set) var capturedParsePayloadArgs: [[AnyHashable: Any]] = []

    /// All user-info dictionaries passed to `parseRoundCompletePayload`.
    public private(set) var capturedParseCompletePayloadArgs: [[AnyHashable: Any]] = []

    /// All user-info dictionaries passed to `parseDiscrepancyDetectedPayload`.
    public private(set) var capturedParseDiscrepancyPayloadArgs: [[AnyHashable: Any]] = []

    public init() {}

    // MARK: - NotificationService

    public func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        currentAuthorizationStatusCallCount += 1
        return nextAuthorizationStatus
    }

    @discardableResult
    public func requestAuthorization() async -> NotificationAuthorizationStatus {
        requestAuthorizationCallCount += 1
        return nextAuthorizationStatus
    }

    public func shouldSuppressPresentation(for payload: RoundStartedPayload, localPlayerID: UUID?) -> Bool {
        shouldSuppressPresentationCallCount += 1
        return suppressionResult
    }

    public func parseRoundStartedPayload(_ userInfo: [AnyHashable: Any]) -> RoundStartedPayload? {
        parsePayloadCallCount += 1
        capturedParsePayloadArgs.append(userInfo)
        return payloadToReturn
    }

    public func parseRoundCompletePayload(_ userInfo: [AnyHashable: Any]) -> RoundCompletePayload? {
        parseCompletePayloadCallCount += 1
        capturedParseCompletePayloadArgs.append(userInfo)
        return completePayloadToReturn
    }

    public func parseDiscrepancyDetectedPayload(_ userInfo: [AnyHashable: Any]) -> DiscrepancyDetectedPayload? {
        parseDiscrepancyPayloadCallCount += 1
        capturedParseDiscrepancyPayloadArgs.append(userInfo)
        return discrepancyPayloadToReturn
    }

    // MARK: - Test helpers

    public func reset() {
        nextAuthorizationStatus = .authorized
        payloadToReturn = nil
        completePayloadToReturn = nil
        discrepancyPayloadToReturn = nil
        suppressionResult = false
        currentAuthorizationStatusCallCount = 0
        requestAuthorizationCallCount = 0
        shouldSuppressPresentationCallCount = 0
        parsePayloadCallCount = 0
        parseCompletePayloadCallCount = 0
        parseDiscrepancyPayloadCallCount = 0
        capturedParsePayloadArgs.removeAll()
        capturedParseCompletePayloadArgs.removeAll()
        capturedParseDiscrepancyPayloadArgs.removeAll()
    }
}
