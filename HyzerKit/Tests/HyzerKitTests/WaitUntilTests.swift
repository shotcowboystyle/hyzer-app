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
        // Generous timeout: under full 432-test parallel load, MainActor re-acquisition
        // after each clock.sleep can take several seconds. 3 polls at any rate is fast.
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
            if case .timeout(_, let condition) = error {
                #expect(condition == "never-true condition")
            } else {
                Issue.record("Unexpected WaitUntilError case: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    /// Time-based test — may flake under extreme CI load. Loose bounds (≥2 polls in 100ms)
    /// should be robust; if it flakes consistently, mark `.disabled` and note follow-up.
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
        } catch is WaitUntilError {
            // Expected timeout
        }

        let elapsed = ContinuousClock.now - start
        // With 100ms timeout and 20ms polls: expect ≥2 polls even under CI load.
        #expect(pollCount >= 2, "expected at least 2 polls in 100ms window, got \(pollCount)")
        #expect(elapsed >= .milliseconds(80), "elapsed \(elapsed) should be at least 80ms")
    }
}
