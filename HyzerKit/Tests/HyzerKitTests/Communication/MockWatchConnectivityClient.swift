import Foundation
@testable import HyzerKit

/// Shared mock for `WatchConnectivityClient` used across Watch ViewModel tests.
@MainActor
final class MockWatchConnectivityClient: WatchConnectivityClient {
    var isReachable: Bool = false
    private(set) var sentMessages: [WatchMessage] = []
    private(set) var transferredMessages: [WatchMessage] = []
    var sendMessageError: Error?

    func sendMessage(_ message: WatchMessage) throws {
        if let error = sendMessageError { throw error }
        sentMessages.append(message)
    }

    func transferUserInfo(_ message: WatchMessage) {
        transferredMessages.append(message)
    }
}
