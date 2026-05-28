import Testing
import Foundation
import TestSupport

@Suite("WaitUntil")
@MainActor
struct WaitUntilTests {

    @Test("returns immediately when condition is already true")
    func test_waitUntil_returns_whenConditionBecomesTrueImmediately() async throws {
        try await waitUntil({ true }, conditionDescription: "always-true condition")
    }

    @Test("returns after several polls when condition becomes true on the Nth call")
    func test_waitUntil_returns_whenConditionBecomesTrueAfterSeveralPolls() async throws {
        var callCount = 0
        // 30s timeout is load-bearing: under full 432-test parallel load, MainActor
        // re-acquisition after each clock.sleep can take 1–3 seconds. A measured run
        // at 5s timed out at ~10s elapsed for just 3 polls. Do NOT tighten without
        // first removing the parallel-load source (e.g., `@Suite(.serialized)`).
        try await waitUntil(
            {
                callCount += 1
                return callCount >= 3
            },
            timeout: .seconds(30),
            conditionDescription: "condition true after 3 polls"
        )
        #expect(callCount >= 3)
    }

    @Test("throws WaitUntilError.timeout when condition never becomes true")
    func test_waitUntil_throws_whenConditionNeverBecomesTrue() async {
        do {
            try await waitUntil(
                { false },
                timeout: .milliseconds(50),
                pollInterval: .milliseconds(10),
                conditionDescription: "never-true condition"
            )
            Issue.record("Expected waitUntil to throw WaitUntilError.timeout")
        } catch let error as WaitUntilError {
            if case .timeout(_, let condition, _) = error {
                #expect(condition == "never-true condition")
            } else {
                Issue.record("Unexpected WaitUntilError case: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    /// Time-based test — loose bounds (`>= 2` polls) are load-bearing. Under full
    /// 432-test parallel suite, each `clock.sleep(20ms)` can take ~50ms+ due to
    /// MainActor pressure, so the helper completes only 2 polls in a 100ms window.
    /// A broken impl polling every 49ms would also pass `>= 2`; the strict regression
    /// detector here is the CancellationError catch — it asserts the helper does not
    /// silently swallow cancellation as a timeout.
    @Test("respects pollInterval timing approximately")
    func test_waitUntil_respectsPollInterval() async throws {
        var pollCount = 0
        let start = ContinuousClock.now

        do {
            try await waitUntil(
                {
                    pollCount += 1
                    return false
                },
                timeout: .milliseconds(100),
                pollInterval: .milliseconds(20),
                conditionDescription: "counting polls"
            )
            Issue.record("Expected waitUntil to throw WaitUntilError.timeout")
        } catch is WaitUntilError {
            // Expected timeout
        } catch is CancellationError {
            Issue.record("Unexpected CancellationError — test task should not be cancelled")
            return
        }

        let elapsed = ContinuousClock.now - start
        #expect(pollCount >= 2, "expected at least 2 polls in 100ms window, got \(pollCount)")
        #expect(elapsed >= .milliseconds(80), "elapsed \(elapsed) should be at least 80ms")
    }
}
