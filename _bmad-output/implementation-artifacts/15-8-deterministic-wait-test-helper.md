# Story 15.8: Deterministic-Wait Test Helper (`Task.sleep` Replacement)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer triaging flaky CI failures,
I want a `await waitUntil(_:timeout:)` helper that replaces the `Task.sleep(for: .milliseconds(20))` / `for _ in 0..<20 { await Task.yield() }` flaky-timing patterns in `AppServicesNearbyDiscoveryTests` and `WatchVoiceViewModel`,
So that the flaky-timing thread called out in CLAUDE.md "Known Technical Debt" closes and the test suite's pass rate is no longer dependent on CI runner load.

## Acceptance Criteria

1. **Given** `HyzerKit/Tests/TestSupport/Sources/TestSupport/WaitUntil.swift` is created (in the same shared target created by Story 15.7), **when** the API is inspected, **then** it exposes:
   ```swift
   public func waitUntil(
       _ condition: @MainActor () async -> Bool,
       timeout: Duration = .seconds(2),
       pollInterval: Duration = .milliseconds(10),
       sourceLocation: Testing.SourceLocation = #_sourceLocation
   ) async throws
   ```
   The helper polls `condition` every `pollInterval` and throws `WaitUntilError.timeout` (a public error type colocated in the same file) when `timeout` elapses without the condition becoming true. Polling is `ContinuousClock`-backed (not `Task.sleep` — `ContinuousClock` is the canonical Swift 5.7+ time abstraction). Swift Testing's `SourceLocation` parameter (auto-defaulted via `#_sourceLocation`) ensures failure messages point at the call-site test, not at WaitUntil.swift.

2. **Given** a test that previously used `Task.sleep(for: .milliseconds(20))` or `for _ in 0..<20 { await Task.yield() }` as a wait primitive is refactored to use `waitUntil`, **when** the test runs under both fast (M1/M2 Mac, low load) and slow (CI runner, high load) conditions, **then** it passes deterministically — the polling backoff is bounded by `timeout` and the condition is checked at most `timeout / pollInterval` times before throwing. The wait time is determined by when the condition becomes true, not by an arbitrary fixed delay.

3. **Given** the known flaky tests are refactored:
   - `AppServicesNearbyDiscoveryTests.test_handleDiscoveredRound_*` family (Story 14.1 spec lines 366–390 — multiple tests using `for _ in 0..<20 { await Task.yield() }`)
   - `WatchVoiceViewModel` auto-commit-timer test (Story 14.2 dev notes Debug Log References — "passes when run in isolation" indicates flake)
   - Any other test exercising async-pipeline-propagation via `Task.sleep` patterns (use `grep -rn "Task.sleep\|Task.yield" HyzerKit/Tests HyzerAppTests` to enumerate)
   **when** the canonical test command (Story 15.2 baseline) runs **10 times in a row**, **then** every run passes — no flake on any of the previously-flaky tests.

4. **Given** the canonical test command is re-run after the refactor, **when** the test count is compared to the Story 15.2 reconciled baseline (post-Story-15.7), **then** the count is identical — this is a refactor of existing tests, not new tests; no count change. The previously-flaky tests now pass deterministically; counts remain stable.

5. **Given** a future story adds a new async-pipeline test, **when** the dev reads the doc comment on `WaitUntil.swift`, **then** the doc comment explains: (a) why `waitUntil` exists (replacing `Task.sleep`/`Task.yield` flaky patterns), (b) when to use it (testing async propagation, NOT testing rate-limiters or throttle windows — for that, use a controllable clock seam, which is out of scope here), (c) a one-line example usage. The comment is the canonical documentation for the helper; CLAUDE.md "Known Technical Debt" gets a one-line cross-reference removing the old flaky-timing bullet.

6. **Given** the deferred-work cleanup is complete, **when** `_bmad-output/implementation-artifacts/deferred-work.md` is read, **then** the bullets specifically about `Task.sleep` flaky timing are removed (Story 14.1 line 99). The CLAUDE.md "Known Technical Debt" entry referencing `Task.sleep(for: .milliseconds(100))` is removed.

## Tasks / Subtasks

- [ ] **Task 1: Verify prerequisite (Story 15.7 TestSupport exists)** (AC: 1)
  - [ ] 1.1 Confirm `HyzerKit/Tests/TestSupport/Sources/TestSupport/` exists and the `TestSupport` target is in `HyzerKit/Package.swift`. If Story 15.7 has not been merged, this story cannot proceed — request Story 15.7 be merged first OR include the TestSupport target creation as an additional Task 0 of this story (NOT recommended — keeps stories independently mergeable).
  - [ ] 1.2 Run `swift build --package-path HyzerKit` and confirm clean build of the TestSupport target.

- [ ] **Task 2: Implement `waitUntil`** (AC: 1, 5)
  - [ ] 2.1 Create `HyzerKit/Tests/TestSupport/Sources/TestSupport/WaitUntil.swift`:
    ```swift
    import Foundation
    import Testing

    public enum WaitUntilError: Error, CustomStringConvertible {
        case timeout(elapsed: Duration, condition: String)

        public var description: String {
            switch self {
            case .timeout(let elapsed, let condition):
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
    ///     { await sut.discoveredRounds.count == 1 }
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
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if await condition() {
                return
            }
            try await clock.sleep(for: pollInterval)
        }

        // One final check after deadline — handles the case where
        // the condition becomes true precisely at the deadline.
        if await condition() {
            return
        }

        throw WaitUntilError.timeout(elapsed: timeout, condition: conditionDescription)
    }
    ```
    The implementation uses `ContinuousClock` for the polling backoff (canonical Swift 5.7+ time API), which is itself a Sendable abstraction over the system clock; it does NOT depend on `Task.sleep` directly — `clock.sleep(for:)` is the structured-concurrency equivalent.
  - [ ] 2.2 Note the `Testing` framework import is what makes `SourceLocation` and `#_sourceLocation` available — this is the Swift Testing version of XCTest's `XCTFail` source-location-pointer mechanism. Required for accurate failure attribution.
  - [ ] 2.3 The `condition` closure is `@MainActor` because most viewmodel state lives on MainActor. If a test needs to poll non-MainActor state, the test can wrap the condition body in `await` of an actor-isolated property — `@MainActor` works for the common case.

- [ ] **Task 3: Refactor `AppServicesNearbyDiscoveryTests`** (AC: 3)
  - [ ] 3.1 Find every occurrence of `for _ in 0..<20 { await Task.yield() }` and `try? await Task.sleep(for: .milliseconds(20))` in `HyzerKitTests/Services/AppServicesNearbyDiscoveryTests.swift` (or wherever the suite lives — `grep -rn` to confirm path). Per Story 14.1 spec line 390, these patterns appear throughout the file.
  - [ ] 3.2 For each occurrence, identify what state-change the test is waiting for (e.g., `appServices.activeRound == .some(round)`, `appServices.cloudKitClient.fetchCallCount > 0`, etc.). Replace the pattern with `try await waitUntil({ await /* same condition */ })`. Add a descriptive `conditionDescription` parameter if helpful.
  - [ ] 3.3 Add `import TestSupport` to the test file if not already present.
  - [ ] 3.4 Run the file's tests 10 times in succession (`for i in {1..10}; do xcodebuild test -only-testing:HyzerKitTests/AppServicesNearbyDiscoveryTests ...; done`). Confirm: all 10 runs pass.

- [ ] **Task 4: Refactor `WatchVoiceViewModel` auto-commit timer test** (AC: 3)
  - [ ] 4.1 Find the auto-commit timer test (per Story 14.2 dev notes Debug Log References: "WatchVoiceViewModel flaky test in HyzerKit full suite (auto-commit timer)"). Likely in `HyzerKit/Tests/HyzerKitTests/Watch/WatchVoiceViewModelTests.swift` — verify path with `grep -rn "auto.?commit" HyzerKit/Tests`.
  - [ ] 4.2 The test likely uses a fixed `Task.sleep` to wait for the auto-commit timer to fire. Replace with `waitUntil({ await viewModel.committedScore != nil })` or equivalent.
  - [ ] 4.3 BUT: if the test is actually testing the timer's *timing* (verifying the timer fires after exactly N seconds), `waitUntil` is the wrong tool — see the doc comment from Task 2.1. In that case, this test needs a controllable-clock refactor; file a follow-up story and skip this refactor for now. Add a NOTE in Completion Notes.
  - [ ] 4.4 Run the test 10 times to verify deterministic pass.

- [ ] **Task 5: Sweep remaining `Task.sleep` / `Task.yield` test patterns** (AC: 3, 6)
  - [ ] 5.1 Run `grep -rn "Task\.sleep\|Task\.yield" HyzerKit/Tests HyzerAppTests`. For each match:
    - If it's a wait-for-state pattern: refactor with `waitUntil` per Task 3.
    - If it's a deliberate-delay pattern (e.g., testing a debounce window with controllable expectation): leave it but add a comment justifying the fixed delay.
    - If it's a `Task.sleep` outside test code (e.g., inside `HyzerApp/` production code): NOT in scope — production code can legitimately use `Task.sleep`. Do not touch.
  - [ ] 5.2 Count the number of refactored sites and the number of justified-delay sites. Record in Completion Notes for traceability.

- [ ] **Task 6: Update CLAUDE.md and deferred-work** (AC: 6)
  - [ ] 6.1 Remove the bullet `- Task.sleep(for: .milliseconds(100)) flaky timing pattern in tests — replace with deterministic waits` from CLAUDE.md "Known Technical Debt".
  - [ ] 6.2 Add a one-line replacement: `Deterministic wait helper: use TestSupport.waitUntil for async-pipeline propagation tests; see TestSupport/WaitUntil.swift doc comment for when-to-use vs. when-not-to-use guidance.`
  - [ ] 6.3 Remove the bullet from `_bmad-output/implementation-artifacts/deferred-work.md` (Story 14.1 line 99 referencing `for _ in 0..<20 { await Task.yield() }` deterministic-wait debt).

- [ ] **Task 7: Final regression and close** (AC: 4)
  - [ ] 7.1 Run `swift test --package-path HyzerKit` — same count as Story 15.2 baseline.
  - [ ] 7.2 Run `xcodebuild test ...` 10 times in succession — every run passes.
  - [ ] 7.3 SwiftLint zero warnings.
  - [ ] 7.4 Stage and commit: `feat(tests): add waitUntil deterministic-wait helper and migrate flaky tests (Story 15.8)`.
  - [ ] 7.5 Update `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 15.8 → `done`.

## Dev Notes

### Why this story exists

CLAUDE.md "Known Technical Debt" explicitly calls out `Task.sleep(for: .milliseconds(100)) flaky timing pattern in tests — replace with deterministic waits`. Story 14.1 spec line 390 acknowledged the same pattern as "authorized debt." Story 14.2 dev notes confirm the `WatchVoiceViewModel` test flakes under CI load. The pattern keeps spreading; this story closes the thread.

The helper is small (~30 lines), well-bounded (test-only, no production impact), and the refactor is mechanical (search-and-replace per usage site). The story has higher line-count impact than logical complexity.

### Current state — what is already correct (do NOT redo)

- **Story 15.7 (prereq) establishes `TestSupport` SPM target.** This story drops `WaitUntil.swift` into the same module — no separate target needed.
- **Swift Testing's `SourceLocation` mechanism** is the canonical way to thread call-site information through helpers. The `#_sourceLocation` macro auto-captures.
- **`ContinuousClock`** is the Swift 5.7+ abstraction. Replaces the older `DispatchQueue.asyncAfter` / `Timer`-based patterns.
- **`Task.sleep` in production code** is acceptable; this story does NOT touch production usage of `Task.sleep`.

### What this story changes

| Change | File | Notes |
|---|---|---|
| Add waitUntil helper | `HyzerKit/Tests/TestSupport/Sources/TestSupport/WaitUntil.swift` | NEW, ~30 LOC |
| Refactor discovery tests | `HyzerKit/Tests/HyzerKitTests/Services/AppServicesNearbyDiscoveryTests.swift` (verify path) | Multiple `Task.yield`/`Task.sleep` sites replaced |
| Refactor watch voice test | `HyzerKit/Tests/HyzerKitTests/Watch/WatchVoiceViewModelTests.swift` (verify path) | Likely one site; may need controllable-clock follow-up per Task 4.3 |
| Sweep other patterns | Various test files (Task 5) | Per-site refactor or justified-delay comment |
| CLAUDE.md update | `CLAUDE.md` "Known Technical Debt" | Remove old bullet, add new pointer |
| Deferred-work cleanup | `_bmad-output/implementation-artifacts/deferred-work.md` | Remove Story 14.1 line 99 bullet |

### What this story must NOT touch

- **No production code changes.** Test-only.
- **No new tests added.** Refactor, not new feature.
- **No `Task.sleep` removal in production code.** Production `Task.sleep` is for legitimate purposes (debouncing, polling external state at intervals, etc.); leave alone.
- **No controllable-clock refactors.** Per the WaitUntil doc comment, those are a separate concern. If a test needs a controllable clock to test throttling, FILE the follow-up — don't bundle into 15.8.

### Architecture compliance

- **CLAUDE.md "Concurrency":** `ContinuousClock` is the Swift 6 strict-concurrency-compliant time API. Aligned.
- **CLAUDE.md "Git Workflow":** Branch `feature/15-8-waituntil-helper`. Conventional commit per Task 7.4.
- **Architecture §Testing:** Swift Testing framework; helpers in TestSupport. This story extends both surfaces.

### Library / framework requirements

- **Swift Testing** — already required by all `@Suite` `@Test` test files; `SourceLocation` import is the new additional surface.
- **`ContinuousClock`** — built into Swift 5.7+ standard library; no dependency.
- **No new third-party packages.**

### File-structure requirements

```
HyzerKit/Tests/TestSupport/Sources/TestSupport/WaitUntil.swift                          [NEW — Task 2.1]
HyzerKit/Tests/HyzerKitTests/Services/AppServicesNearbyDiscoveryTests.swift             [EDIT — Task 3, refactor multiple sites]
HyzerKit/Tests/HyzerKitTests/Watch/WatchVoiceViewModelTests.swift                       [EDIT — Task 4, refactor or follow-up]
<other test files surfaced by Task 5.1 grep>                                            [EDIT — per-site]
CLAUDE.md                                                                               [EDIT — Task 6.1, 6.2]
_bmad-output/implementation-artifacts/deferred-work.md                                  [EDIT — Task 6.3]
_bmad-output/implementation-artifacts/sprint-status.yaml                                [EDIT — Task 7.5]
```

### Testing requirements

- **One sanity test on the helper itself:** `HyzerKit/Tests/TestSupport/Tests/WaitUntilTests.swift` (if SwiftPM supports nested test targets in the TestSupport module, otherwise add to HyzerKitTests). Tests:
  - `test_waitUntil_returns_whenConditionBecomesTrueImmediately` — condition initially true; helper returns without sleeping.
  - `test_waitUntil_returns_whenConditionBecomesTrueAfterSeveralPolls` — condition flips true after 3 polls; helper returns.
  - `test_waitUntil_throws_whenConditionNeverBecomesTrue` — condition stays false; helper throws `WaitUntilError.timeout` after `timeout` elapses.
  - `test_waitUntil_respectsPollInterval` — measure that polls happen ~every `pollInterval` (with tolerance, since this IS time-based) — flag as "this test is itself time-based and may flake under CI; if it flakes, mark as `@Suite(.disabled)` and note in Completion Notes."
  
  The four tests are the only new tests this story adds (counterbalancing the ones it refactors, so net count is +4).

- **Regression check (AC #4):** Test count after refactor + 4 new helper-self-tests = Story 15.2 baseline + 4. CLAUDE.md "Project Status" gets a +4 nudge; mention in Completion Notes.

### Previous-story intelligence

**CLAUDE.md "Known Technical Debt":** "`Task.sleep(for: .milliseconds(100))` flaky timing pattern in tests — replace with deterministic waits." Explicit instruction. Story 15.8 IS the deterministic-wait extraction.

**Story 14.1 deferred-work (line 99):** "Tests use `for _ in 0..<20 { await Task.yield() }` and `try? await Task.sleep(for: .milliseconds(20))` to wait for async pipeline propagation — CLAUDE.md known flaky-timing tech debt, authorized by Story 14.1 spec line 390. Needs deterministic-wait helper."

**Story 14.2 Debug Log References:** "`WatchVoiceViewModel` flaky test in HyzerKit full suite (auto-commit timer) is pre-existing tech debt (`Task.sleep` timing race, noted in CLAUDE.md). Passes when run in isolation." The flake is acknowledged; Story 15.8 fixes it.

### Latest tech information (2026-05-18)

- **`ContinuousClock` vs. `SuspendingClock`:** `ContinuousClock` does NOT pause when the process is suspended; appropriate for short-lived polling. `SuspendingClock` pauses; appropriate for long-lived waits. For test polling (millisecond-scale), `ContinuousClock` is the right choice.
- **Swift Testing's `SourceLocation` macro `#_sourceLocation`** is the standard pattern as of swift-testing 0.7+. Auto-captures the call-site for failure-attribution accuracy.
- **`clock.sleep(for:)`** is the structured-concurrency-aware sleep; it cooperates with task cancellation (cancelling the parent task interrupts the sleep). Better than `try? await Task.sleep(...)`.

### Open questions — pre-answered

**Pre-answered:**
- Helper name → `waitUntil` (matches industry-standard naming: XCTest's `XCTNSPredicateExpectation`, Quick/Nimble's `waitUntil`)
- Default timeout → 2 seconds (long enough for any reasonable async propagation on CI; short enough to fail fast on real timeouts)
- Default poll interval → 10ms (responsive enough that fast conditions don't oversleep; not so tight that the poll loop dominates CPU on slow CI)
- Clock → `ContinuousClock`
- Source location → Swift Testing's `SourceLocation`

**Still requires elicitation (Task 4.3):** Whether `WatchVoiceViewModel` test is testing state propagation (refactor with `waitUntil`) or timer timing (file follow-up for controllable-clock seam).

### Project Structure Notes

The committed diff is moderate: one new ~30-LOC helper, ~10-20 line-touches across test files for refactors, four new sanity tests, plus doc updates. Logical complexity is low.

### References

- [Source: `CLAUDE.md` "Known Technical Debt" — `Task.sleep` flaky timing entry]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:99` — Story 14.1 deterministic-wait deferral]
- [Source: `_bmad-output/implementation-artifacts/14-2-generative-visual-round-signature-on-summary-card.md:537` — WatchVoiceViewModel flake acknowledgment]
- [Source: `_bmad-output/implementation-artifacts/14-1-multipeerconnectivity-nearby-active-round-discovery.md` — Story 14.1 spec line 390 referenced; full file]
- [Source: `HyzerKit/Tests/TestSupport/Sources/TestSupport/` — Story 15.7 created this directory]
- [Source: `HyzerKit/Tests/HyzerKitTests/Services/AppServicesNearbyDiscoveryTests.swift` (verify path) — primary refactor target]
- [Source: `HyzerKit/Tests/HyzerKitTests/Watch/WatchVoiceViewModelTests.swift` (verify path) — secondary refactor target]
- [Source: Swift Standard Library `ContinuousClock` documentation]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Story-15.8` — this story's epic-level scope]

## Dev Agent Record

### Agent Model Used

<!-- Filled by dev agent during execution -->

### Debug Log References

<!-- Filled by dev agent during execution -->

### Completion Notes List

<!-- Filled by dev agent during execution -->

### File List

<!-- Filled by dev agent during execution -->

### Change Log

<!-- Filled by dev agent during execution -->
