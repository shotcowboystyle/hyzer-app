import Foundation
import Testing

public enum WaitUntilError: Error, CustomStringConvertible {
    case timeout(elapsed: Duration, condition: String, sourceLocation: SourceLocation)

    public var description: String {
        switch self {
        case .timeout(let elapsed, let condition, _):
            return "waitUntil timed out after \(elapsed) while waiting for: \(condition)"
        }
    }
}

/// Polls `condition` every `pollInterval` until it returns true OR `timeout` elapses.
///
/// Use this in place of `Task.sleep(for: .milliseconds(N))` or
/// `for _ in 0..<N { await Task.yield() }` patterns. Those fixed-delay
/// patterns flake under CI runner load; `waitUntil` is bounded by the
/// condition becoming true, not by an arbitrary wall-clock duration.
///
/// **When to use:** Testing that an async pipeline has propagated a
/// state change (e.g., a view-model property update after a service
/// call, a publisher fires, a downstream effect runs).
///
/// **When NOT to use:** Testing rate limiters or throttle windows.
/// Those require a controllable clock seam (e.g., `ContinuousClock`
/// injected via dependency) — `waitUntil` polls real wall-clock time
/// and cannot fast-forward time. If you find yourself writing
/// `waitUntil(... timeout: .seconds(30))` for a throttle test, stop
/// and refactor the throttle to accept a clock parameter.
///
/// **Example:**
/// ```swift
/// try await waitUntil(
///     { await sut.discoveredRounds.count == 1 },
///     conditionDescription: "discovered rounds updated"
/// )
/// ```
public func waitUntil(
    _ condition: @MainActor () async -> Bool,
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(10),
    conditionDescription: String = "<unspecified>",
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let clock = ContinuousClock()
    let start = clock.now
    let deadline = start.advanced(by: timeout)

    while clock.now < deadline {
        try Task.checkCancellation()
        if await condition() { return }
        try await clock.sleep(for: pollInterval)
    }

    // One final check after deadline — handles the case where
    // the condition becomes true precisely at the deadline.
    if await condition() { return }

    let elapsed = clock.now - start
    // Attach sourceLocation to the error so callers who catch the timeout (e.g.,
    // inverted-waitUntil negative assertions) can re-report it at their call site.
    // For uncaught throws, Swift Testing attributes the failure to the test
    // function — which is already the caller's file:line.
    throw WaitUntilError.timeout(
        elapsed: elapsed,
        condition: conditionDescription,
        sourceLocation: sourceLocation
    )
}
