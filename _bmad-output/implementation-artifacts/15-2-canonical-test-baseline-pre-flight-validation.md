# Story 15.2: Canonical 407-Test Baseline Pre-Flight Validation on Simulator

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer about to upload a TestFlight build,
I want a documented green run of the canonical `xcodebuild test` command against the test-count baseline on the `iPhone 17 with Watch` simulator, plus a single authoritative reconciliation of the three divergent test-count figures floating across CLAUDE.md, Story 9.3, and Story 14.2,
So that no regression slips into TestFlight from a series of sim-unavailable dev-agent runs that deferred this gate.

## Acceptance Criteria

1. **Given** a clean checkout of current `main` HEAD on a Mac with Xcode 16.x and the `iPhone 17 with Watch` simulator installed, **when** the canonical command `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'` runs end-to-end, **then** the build succeeds, SwiftLint pre-build emits zero warnings, every test suite passes, and the run is captured in `_bmad-output/implementation-artifacts/15-2-evidence/canonical-test-run.txt` (gitignored per the `*-evidence/` glob) — this closes the gate that Stories 9.1, 9.2, 9.3, 14.1, 14.2 all deferred with the same phrase ("simulator unavailable on dev machine").

2. **Given** the test run produces a final pass count, **when** the count is compared to the three figures currently in play (CLAUDE.md "Project Status" — `407 tests`; Story 14.2 Completion Notes — `423 HyzerKit tests + 28 HyzerApp suites`; Story 9.3 AC7 — `278` HyzerKit-package-test baseline), **then** a single authoritative reconciled count is recorded with a per-target breakdown (HyzerKit + HyzerAppTests + any HyzerWatch tests if a watch test target exists). The reconciled count and breakdown replace the existing `407 tests` figure in `CLAUDE.md` "Project Status" and `407 tests` references in `_bmad-output/implementation-artifacts/9-3-*.md` AC7 (the latter is historical — annotate as resolved rather than rewriting).

3. **Given** the `swift test --package-path HyzerKit` (host-only, no simulator) command runs in isolation, **when** its output is parsed, **then** the HyzerKit-only test count matches the per-target breakdown from AC #2 — this validates that the simulator run and the host-only run agree on the HyzerKit portion. Any divergence indicates a HyzerKit test that fails under one runner but not the other (likely a `Task.sleep`-style flake — note in Completion Notes; do not block the AC if the flake is the known `WatchVoiceViewModel` timer test that Story 14.2 dev notes acknowledge).

4. **Given** the canonical command is unavailable on the dev machine (the recurring sim-unavailable pattern from Stories 9.1, 9.2, 9.3, 14.1, 14.2), **when** the dev agent is unable to run the gate, **then** the story stays in `ready-for-dev` and is explicitly deferred to a reviewer with simulator access — the story does NOT get marked `done` based on `swift test --package-path HyzerKit` alone. This AC is the explicit anti-pattern: the half-measure that's been used for five stories in a row.

5. **Given** the canonical run flakes intermittently (one or more tests pass on second run but fail on first), **when** the dev agent observes the flake, **then** the flaky test is recorded by name in Completion Notes with a one-sentence description of its failure mode (e.g., "`WatchVoiceViewModel.test_autoCommitTimerFires` — `Task.sleep`-based assert sometimes finishes before the timer; known debt per Story 14.2 dev notes"). The story can still close if the flake is in the existing `CLAUDE.md` "Known Technical Debt" list (specifically `Task.sleep` flaky-timing tests). New flakes that are not in the known-debt list block the story and require a follow-up.

6. **Given** the reconciled count and breakdown are recorded, **when** `CLAUDE.md` "Project Status" is read, **then** a single sentence documents the canonical baseline going forward (format: "**Test count baseline:** X tests — N1 HyzerKit + N2 HyzerAppTests + N3 HyzerWatch (as of `git rev-parse HEAD` on YYYY-MM-DD).") so future stories quote one number rather than three divergent ones.

## Tasks / Subtasks

- [ ] **Task 1: Confirm simulator availability on the dev machine** (AC: 1, 4)
  - [ ] 1.1 Run `xcrun simctl list devices | grep "iPhone 17 with Watch"`. Expected output: at least one matching device with `(Shutdown)` or `(Booted)` status. If output is empty, the simulator is not installed — fall through to AC #4 deferral.
  - [ ] 1.2 If `iPhone 17 with Watch` is unavailable, check `xcrun simctl list devices | grep "iPhone 17"` for any iPhone 17 variant (Story 14.2 dev notes acknowledge `iPhone 17 Pro` as a fallback when the paired-with-Watch variant is not provisioned). If only a non-Watch-paired variant is available, the watchOS portion of the test target will not run — note this in Completion Notes and proceed with the iOS-only run.
  - [ ] 1.3 If no `iPhone 17` variant is available at all, the dev machine is sim-incomplete. Surface to the user via Completion Notes: `"Simulator unavailable on dev machine. Per AC #4, this story is deferred to a reviewer with simulator access. No regression test was performed."` Do NOT mark the story `done` in this case.

- [ ] **Task 2: Run the canonical test command** (AC: 1, 5)
  - [ ] 2.1 On the branch `feature/15-2-canonical-test-baseline-validation` (per CLAUDE.md "Git Workflow"), run the canonical command verbatim: `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch' | tee build/canonical-test-run.txt`. Expect `** TEST SUCCEEDED **`. The `tee` ensures the full log is captured for evidence (AC #1).
  - [ ] 2.2 If the run fails with a non-flake error (compilation error, asset bundle issue, SwiftLint warning at error level), surface the error verbatim — this is a launch-blocker regression and Story 15.2 cannot close until it's fixed. Do NOT attempt to fix the regression in this story; file a new bug-fix story per CLAUDE.md "Bug Fixes Require Tests" and re-run 15.2 after the fix.
  - [ ] 2.3 If one or more tests fail with the appearance of flake (passes on second run, fails on first), follow AC #5: record the flaky test by name in Completion Notes. If the flake is in CLAUDE.md "Known Technical Debt" (specifically `Task.sleep` patterns), the story can still close — the flake is acknowledged debt. If the flake is new, do NOT close the story; file the new flake as a follow-up story.

- [ ] **Task 3: Copy the canonical run log to the evidence directory** (AC: 1)
  - [ ] 3.1 Create the evidence directory: `mkdir -p _bmad-output/implementation-artifacts/15-2-evidence/`. The `.gitignore` glob `_bmad-output/implementation-artifacts/*-evidence/` (Story 9.3 Task 6.2) covers it; no additional gitignore edit needed.
  - [ ] 3.2 Move `build/canonical-test-run.txt` to `_bmad-output/implementation-artifacts/15-2-evidence/canonical-test-run.txt`. The file is gitignored as evidence.
  - [ ] 3.3 Add a placeholder `README.md` inside the evidence directory with one line: `Evidence from Story 15.2 — canonical test run log. Gitignored.`

- [ ] **Task 4: Reconcile the three divergent test-count figures** (AC: 2)
  - [ ] 4.1 Parse the canonical run log for the final test count. The Xcode test output line is typically `Test Suite 'All tests' passed at <timestamp>. Executed N tests, with 0 failures (0 unexpected) in M (P) seconds`. Extract `N`.
  - [ ] 4.2 Parse per-target counts from the same log. Each test target's summary appears separately (`Test Suite 'HyzerKitTests.xctest' passed at <ts>. Executed N1 tests...` and `Test Suite 'HyzerAppTests.xctest' passed at <ts>. Executed N2 tests...`). If a `HyzerWatchTests` target exists, capture its count too.
  - [ ] 4.3 Compare `N` (total) against the three existing figures (CLAUDE.md: 407, Story 14.2: 423+28-suites, Story 9.3: 278 HyzerKit). Resolve any discrepancy by trusting the live `N` over the historical numbers — the historical figures were correct at their respective points in time but have drifted post-Story-14.2's 10 HyzerKit additions and post-other-story additions.
  - [ ] 4.4 Edit `CLAUDE.md` "Project Status" section: replace the current `407 tests` line with the reconciled format from AC #6:
    `**Test count baseline:** N tests — N1 HyzerKit + N2 HyzerAppTests + N3 HyzerWatch (as of git rev-parse HEAD on 2026-MM-DD).`
    Include the actual commit SHA in the parenthetical so future readers can locate the snapshot.

- [ ] **Task 5: Validate via the host-only HyzerKit run** (AC: 3)
  - [ ] 5.1 Run `swift test --package-path HyzerKit` (no simulator dependency). Expect the same `N1` count as Task 4.2.
  - [ ] 5.2 If the host-only count differs from the simulator-derived `N1`, surface to the user — the two should agree (the HyzerKit package is the same code under both runners). Common causes: a flaky test (note per AC #5), a `@testable import` that has different behavior on the macOS host vs. the iOS simulator, or a SwiftPM cache state difference.
  - [ ] 5.3 If counts agree, record both in Completion Notes for cross-reference.

- [ ] **Task 6: Annotate historical references to the old count** (AC: 2)
  - [ ] 6.1 Read `_bmad-output/implementation-artifacts/9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md`. Find every reference to `407 tests` or `278 tests`. Do NOT rewrite the historical text (per Story 15.6's "frozen artifact policy" question — leaving historical numbers in place is also acceptable per that policy). Instead, append a single annotation line at the end of the AC7 section or the relevant Completion Notes section: `_Note (Story 15.2 reconciliation, YYYY-MM-DD): canonical baseline is now N tests (N1 + N2 + N3); the 407/278 figures are historical snapshots._`
  - [ ] 6.2 Read `_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md`. Apply the same annotation pattern if the retro references a specific test count that the user wants annotated; otherwise leave the retro untouched per Story 15.6's frozen-artifact policy.

- [ ] **Task 7: Commit and close** (AC: 6)
  - [ ] 7.1 Stage and commit: `chore(docs): reconcile canonical test baseline (Story 15.2)`. The commit body should quote the final reconciled count from Task 4.
  - [ ] 7.2 Update `_bmad-output/implementation-artifacts/sprint-status.yaml` — set Story 15.2 from `ready-for-dev` to `done` (or `review` if PR-flow is being followed strictly).
  - [ ] 7.3 Remove the bullet from `_bmad-output/implementation-artifacts/deferred-work.md` that reads "Run canonical xcodebuild test ... against the 407-test baseline (AC7). Reason for deferral: current machine has no simulator..." (Story 9.2 deferral list).

## Dev Notes

### Why this story exists

Five prior stories (9.1, 9.2, 9.3, 14.1, 14.2) deferred the canonical simulator test gate with the same explanation: "simulator unavailable on dev machine." That deferral chain has reached its limit — TestFlight uploads have happened without a documented green simulator run, and the test-count baseline in CLAUDE.md (`407 tests`) is now out of sync with reality (Story 14.2 added 10 HyzerKit tests; previous stories added others; the actual count is closer to 423 + 28 HyzerApp suites per Story 14.2 Completion Notes). This story closes the gate explicitly: either a reviewer with simulator access runs it, or the story stays open. No more half-measures.

The reconciliation work in Task 4 is bundled because the canonical run produces the authoritative number — separating it into a separate story would force the dev agent to either (a) report two divergent numbers in two PRs or (b) wait for this PR to merge before fixing CLAUDE.md, which is silly.

### Current state — what is already correct (do NOT redo)

- **The test suites themselves are green at the HyzerKit-host level.** `swift test --package-path HyzerKit` passes consistently across all prior dev-agent runs (Story 14.2 reports `413 + 10 = 423 tests` HyzerKit-side, modulo the known `WatchVoiceViewModel` flake).
- **The `iPhone 17 with Watch` destination is documented in CLAUDE.md "Build & Test Commands"** as canonical. Use it verbatim; do not substitute `iPhone 17 Pro` unless `iPhone 17 with Watch` is genuinely unavailable on the dev machine (Story 14.2 confirmed both can be available).
- **SwiftLint pre-build emits zero warnings** at the existing rule levels (verified across multiple recent stories). If new warnings appear in Task 2, they are a regression — surface as a launch-blocker per CLAUDE.md "Coding Standards" enforcement.
- **No `Package.swift`, `project.yml`, or test target additions are in scope.** This story only runs existing tests; if the run reveals a missing test target or broken Package.swift wiring, that is a regression to be filed separately.

### What this story changes

| Change | File | Notes |
|---|---|---|
| Replace `407 tests` figure | `CLAUDE.md` "Project Status" | Per AC #6 format |
| Annotate historical test-count refs | `_bmad-output/implementation-artifacts/9-3-*.md` (AC7 area) | Single line per location; do not rewrite history |
| Remove resolved bullet | `_bmad-output/implementation-artifacts/deferred-work.md` | The 9.2 "run canonical test" bullet |
| Create evidence directory | `_bmad-output/implementation-artifacts/15-2-evidence/README.md` | Single placeholder line; gitignored screenshots and log |
| Sprint status transition | `_bmad-output/implementation-artifacts/sprint-status.yaml` | `ready-for-dev` → `done` (or `review`) |

The committed diff is tiny. The bulk of the work is the simulator run + log capture, which is operational evidence.

### What this story must NOT touch

- **No test additions.** If the canonical run reveals a missing assertion or a gap, file a follow-up — do not expand the test suite in this story.
- **No production-code changes.** This is a verification-and-documentation story. Even if a SwiftLint warning surfaces, the fix belongs in a separate PR (CLAUDE.md "Bug Fixes Require Tests" — every fix needs its own test, which is out of scope here).
- **No Package.swift or project.yml changes.** If the test targets need re-wiring, that is itself a story.

### Architecture compliance

- **CLAUDE.md "Bounded queries", "No silent `try?`", "Accessibility first", "Design tokens only":** Inapplicable. No Swift edits.
- **CLAUDE.md "Git Workflow":** Branch `feature/15-2-canonical-test-baseline-validation`. Conventional commit `chore(docs): reconcile canonical test baseline (Story 15.2)`.
- **Architecture §Testing (`architecture.md`):** Reaffirms `swift test --package-path HyzerKit` (host) + `xcodebuild test ...` (simulator) as the canonical pair. Story 15.2 enforces both.

### Library / framework requirements

- **No new dependencies.** This story is a verification + reconciliation pass.
- **`xcodebuild` 16.x** is the required tool; default Xcode 16.x installation suffices.

### File-structure requirements

```
CLAUDE.md                                                                            [EDIT — Task 4.4]
_bmad-output/implementation-artifacts/9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md  [EDIT — Task 6.1, annotation only]
_bmad-output/implementation-artifacts/deferred-work.md                               [EDIT — Task 7.3, remove resolved bullet]
_bmad-output/implementation-artifacts/15-2-evidence/README.md                        [NEW — Task 3.3]
_bmad-output/implementation-artifacts/15-2-evidence/canonical-test-run.txt           [LOCAL ONLY — Task 3.2, gitignored]
_bmad-output/implementation-artifacts/sprint-status.yaml                             [EDIT — Task 7.2]
```

Files that must NOT appear in the final diff: any Swift source, any test file, any `Package.swift` or `project.yml`.

### Testing requirements

This story IS the testing requirement — it exists to run the existing tests. No new tests are written. CLAUDE.md "Bug Fixes Require Tests" does not apply: this is not a bug fix, it is a deferred verification gate being closed.

The single new artifact is the canonical run log, captured as gitignored evidence.

### Previous-story intelligence

**Story 9.2 Task 6 explicitly deferred this run:** "Run canonical `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'` against the 407-test baseline (AC7). Reason for deferral: current machine has no simulator." That same explanation appears in 9.1, 9.3, 14.1, and 14.2. Five stories in a row.

**Story 14.2 Completion Notes report `423 HyzerKit + 28 HyzerApp suites`** — this is the most recent test-count snapshot. Task 4 should agree with these numbers ±1 (modulo the `WatchVoiceViewModel` flake noise, which can show ±1).

**Story 9.3 AC7 explicitly preserved the `407` figure** as a baseline expectation at story-creation time. The figure was correct as of `2026-05-16` (the 9.3 creation date) — pre-Story-13.1, pre-Story-13.2, pre-Story-13.3, pre-Story-14.1, pre-Story-14.2 additions. Now it's stale.

**The `WatchVoiceViewModel` auto-commit timer test** is the known flaky test (per Story 14.2 dev notes). It is `Task.sleep`-based and is the canonical example of the debt that Story 15.8 closes. For Story 15.2's purposes, the flake is acknowledged — the story closes if the flake is the only flake observed.

### Latest tech information (2026-05-18)

- **`xcodebuild test` with `-destination 'platform=iOS Simulator,name=iPhone 17 with Watch'`** is the canonical destination per CLAUDE.md. Xcode 16.x supports this destination natively. If the destination string fails to match a simulator, `xcrun simctl list devices` reveals what's installed.
- **`** TEST FAILED **`** in `xcodebuild` output can be misleading — Story 14.2 Debug Log References note that the indicator can appear even when all 28 suites pass (a known Xcode 16 quirk in heterogeneous test target output). Read the actual final test summary line, not the raw `** TEST <state> **` marker.
- **`tee build/canonical-test-run.txt`** preserves stdout+stderr in a single file for evidence capture. The `build/` directory is gitignored per Story 9.1.

### Open questions — pre-answered at story-creation time

**Pre-answered:**
- Canonical destination → `iPhone 17 with Watch` (per CLAUDE.md "Build & Test Commands"); `iPhone 17 Pro` is acceptable fallback per Story 14.2 dev notes
- Test-count format → `N total — N1 HyzerKit + N2 HyzerAppTests + N3 HyzerWatch (as of git SHA on YYYY-MM-DD)` (per AC #6)
- Flake policy → known `Task.sleep` flakes acknowledged, new flakes file follow-up stories (per AC #5)
- Historical annotation → append, do not rewrite (per Story 15.6 frozen-artifact policy question; one-line annotation is the safe minimum)

**Still requires elicitation:**
- None. All work is mechanical.

### Project Structure Notes

This story's footprint is minimal — one CLAUDE.md edit, one deferred-work.md edit, one annotation line in Story 9.3's file, one evidence directory README. Acceptance is a captured log file (gitignored).

### References

- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:43` — Story 9.2 deferred canonical test run]
- [Source: `_bmad-output/implementation-artifacts/14-2-generative-visual-round-signature-on-summary-card.md:546` — `HyzerKit test count: 413 + 10 = 423` snapshot]
- [Source: `_bmad-output/implementation-artifacts/9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md:30, 91, 307-309` — 407 + 278 baseline references]
- [Source: `CLAUDE.md` "Project Status" — current `407 tests` figure]
- [Source: `CLAUDE.md` "Build & Test Commands" — canonical command syntax]
- [Source: `CLAUDE.md` "Known Technical Debt" — `Task.sleep` flaky timing acknowledged]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Story-15.2` — this story's epic-level scope]

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
