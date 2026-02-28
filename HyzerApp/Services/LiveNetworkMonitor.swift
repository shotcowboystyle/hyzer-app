import Network
import HyzerKit

/// Live implementation of `NetworkMonitor` wrapping `NWPathMonitor`.
///
/// Declared in HyzerApp (not HyzerKit) because `Network.framework` is not
/// available on the macOS test host used for `swift test --package-path HyzerKit`.
/// Mirrors the split used by `LiveICloudIdentityProvider` and `LiveCloudKitClient`.
///
/// **NWPathMonitor notes:**
/// - Requires a dedicated `DispatchQueue` — this is the ONE acceptable DispatchQueue
///   use in the codebase (required by the Network framework API).
/// - `pathUpdateHandler` is bridged to an `AsyncStream<Bool>` via continuation
///   so callers can use it with `async/await`.
final class LiveNetworkMonitor: NetworkMonitor, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.shotcowboystyle.hyzerapp.NetworkMonitor", qos: .utility)

    // Continuation that feeds pathUpdates stream — guarded by the NWPathMonitor queue.
    private var continuation: AsyncStream<Bool>.Continuation?

    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.continuation?.yield(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        continuation?.finish()
        monitor.cancel()
    }

    // MARK: - NetworkMonitor

    var isConnected: Bool {
        monitor.currentPath.status == .satisfied
    }

    var pathUpdates: AsyncStream<Bool> {
        AsyncStream<Bool> { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            // Emit current state immediately, then wire up future updates.
            continuation.yield(isConnected)
            self.continuation = continuation
        }
    }
}
