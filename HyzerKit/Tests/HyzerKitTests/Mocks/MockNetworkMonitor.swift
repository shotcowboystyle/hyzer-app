import Foundation
@testable import HyzerKit

/// Controllable test double for `NetworkMonitor`.
///
/// Exposes `setConnected(_:)` to simulate connectivity changes in tests.
/// Thread-safe via `@unchecked Sendable` — all mutations happen from test code
/// which controls the call site.
final class MockNetworkMonitor: NetworkMonitor, @unchecked Sendable {
    private var _isConnected: Bool
    private var _continuation: AsyncStream<Bool>.Continuation?

    init(initiallyConnected: Bool = true) {
        self._isConnected = initiallyConnected
    }

    // MARK: - NetworkMonitor

    var isConnected: Bool { _isConnected }

    var pathUpdates: AsyncStream<Bool> {
        AsyncStream<Bool> { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            // Emit current state immediately.
            continuation.yield(self._isConnected)
            self._continuation = continuation
        }
    }

    // MARK: - Test helpers

    /// Simulates a connectivity change. Emits the new state on `pathUpdates`.
    func setConnected(_ connected: Bool) {
        _isConnected = connected
        _continuation?.yield(connected)
    }

    /// Closes the path updates stream (e.g. to simulate monitor teardown).
    func finish() {
        _continuation?.finish()
    }
}
