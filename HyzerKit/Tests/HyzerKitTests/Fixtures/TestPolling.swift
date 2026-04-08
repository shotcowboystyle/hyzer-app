import Foundation

/// Polls a condition at short intervals until it returns `true` or the timeout is reached.
///
/// Replaces bare `Task.sleep(for: .milliseconds(N))` in tests with a deterministic
/// polling loop that terminates as soon as the condition is met — faster on fast machines,
/// still reliable on slow CI.
///
/// - Parameters:
///   - timeout: Maximum time to wait before returning `false`. Default 2 seconds.
///   - pollInterval: Time between polls. Default 10ms.
///   - condition: Closure evaluated each poll cycle. Return `true` to stop waiting.
/// - Returns: `true` if the condition was met within timeout, `false` otherwise.
@discardableResult
@MainActor
func awaitCondition(
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(10),
    _ condition: () async throws -> Bool
) async rethrows -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if try await condition() { return true }
        try? await Task.sleep(for: pollInterval)
    }
    return false
}
