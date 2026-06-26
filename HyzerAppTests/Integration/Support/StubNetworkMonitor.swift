import Foundation
@testable import HyzerKit

/// Shared `NetworkMonitor` stub. Defaults to `isConnected = true` with an empty
/// updates stream — sufficient for any test that needs `AppServices` to construct
/// without exercising the offline-recovery path.
///
/// To test the offline → online transition, instantiate with `isConnected: false`
/// and pass a continuation via `makeStream()` to yield path updates.
struct StubNetworkMonitor: NetworkMonitor {
    let isConnected: Bool
    let pathUpdates: AsyncStream<Bool>

    init(isConnected: Bool = true) {
        self.isConnected = isConnected
        self.pathUpdates = AsyncStream { _ in }
    }

    /// Factory that returns both the monitor and the continuation, so tests can
    /// drive `pathUpdates` from the outside (e.g., to simulate connectivity
    /// regained).
    static func scriptable(isConnected: Bool = true) -> (StubNetworkMonitor, AsyncStream<Bool>.Continuation) {
        var continuation: AsyncStream<Bool>.Continuation!
        let stream = AsyncStream<Bool> { continuation = $0 }
        let monitor = StubNetworkMonitor(isConnected: isConnected, stream: stream)
        return (monitor, continuation)
    }

    private init(isConnected: Bool, stream: AsyncStream<Bool>) {
        self.isConnected = isConnected
        self.pathUpdates = stream
    }
}
