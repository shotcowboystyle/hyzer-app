import Foundation
import HyzerKit

/// Controllable test double for `WatchConnectivityClient`.
///
/// Captures all `sendMessage` and `transferUserInfo` calls in order, and allows
/// the test to script `isReachable` and a throwable error for the next
/// `sendMessage` call. The protocol is `@MainActor`, so the mock is too.
///
/// Used by:
/// - `HyzerKitTests` contract tests on `WatchMessage` encoding round-trips.
/// - Future Path-B work that injects `WatchConnectivityClient` into `AppServices`
///   (currently `PhoneConnectivityService` is constructed directly inside
///   `AppServices.init`, so the runtime path uses the live `WCSession`-backed
///   implementation. The mock is staged here so that DI refactor is a one-line
///   change at the AppServices call site, not a new file).
@MainActor
public final class MockWatchConnectivityClient: WatchConnectivityClient {

    // MARK: Scriptable state

    public var isReachable: Bool = true

    /// If non-nil, the next `sendMessage` call throws this error and clears it.
    public var sendMessageErrorToThrow: WatchConnectivityError?

    // MARK: Captured calls

    public private(set) var sentMessages: [WatchMessage] = []
    public private(set) var transferredMessages: [WatchMessage] = []

    public var sendMessageCallCount: Int { sentMessages.count }
    public var transferUserInfoCallCount: Int { transferredMessages.count }

    public init() {}

    // MARK: WatchConnectivityClient

    public func sendMessage(_ message: WatchMessage) throws {
        if let error = sendMessageErrorToThrow {
            sendMessageErrorToThrow = nil
            throw error
        }
        guard isReachable else {
            throw WatchConnectivityError.notReachable
        }
        sentMessages.append(message)
    }

    public func transferUserInfo(_ message: WatchMessage) {
        transferredMessages.append(message)
    }

    // MARK: Test helpers

    /// Drops all captured state. Useful between assertion phases in a single test
    /// when you want to assert only on calls that follow a specific action.
    public func resetCaptured() {
        sentMessages.removeAll()
        transferredMessages.removeAll()
    }
}
