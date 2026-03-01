import Foundation

/// Abstract interface for Watch ↔ Phone bidirectional communication.
///
/// Protocol lives in HyzerKit so both HyzerApp and HyzerWatch can depend on it without
/// importing WatchConnectivity in the shared package. The concrete implementations
/// (`PhoneConnectivityService`, `WatchConnectivityService`) live in the platform-specific targets.
///
/// Errors thrown by `WatchConnectivityClient.sendMessage(_:)`.
public enum WatchConnectivityError: Error, Sendable {
    /// The paired device is not currently reachable for instant messaging.
    case notReachable
    /// The message could not be encoded for transmission.
    case encodingFailed(Error)
}

/// All conforming types must be usable from `@MainActor` context.
@MainActor
public protocol WatchConnectivityClient: AnyObject {
    /// Whether the paired device is currently reachable for instant messaging.
    var isReachable: Bool { get }

    /// Sends a message via best-effort delivery. Both apps must be active and reachable.
    /// - Throws: If the message cannot be encoded or the session is not reachable.
    func sendMessage(_ message: WatchMessage) throws

    /// Enqueues a message for guaranteed delivery via the system queue.
    /// Delivery occurs when the counterpart app becomes active, even if currently unreachable.
    func transferUserInfo(_ message: WatchMessage)
}
