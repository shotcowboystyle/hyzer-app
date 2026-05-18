# Story 15.4: On-Device History-Services Performance Verification

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer claiming PMVP-NFR4 satisfaction (`PlayerTrendService` renders `<500ms` for 250-round histories),
I want the on-device measurement performed on a physical iPhone 12+ at 250 rounds, plus device-time baselines for `PersonalBestService.computeBest` and `HeadToHeadService.computeRecord`,
So that AC #3 of Story 13.1 has device-measured evidence and adjacent history services have a documented regression bar that future PRs can compare against.

## Acceptance Criteria

1. **Given** a release-configuration Hyzer build is installed on a physical iPhone 12+ running iOS 18+ (no simulator — Story 13.1 explicitly excluded macOS x86 simulator measurements as the basis for AC #3, noting the simulator-measured time was `~0.84s` for 250 rounds), **when** a fixture player with exactly 250 completed rounds is loaded into SwiftData and `PlayerTrendView` is presented for that player, **then** the median time from view-appear to first-paint of the chart over 5 invocations is `<500ms` (PMVP-NFR4; Story 13.1 AC #3). Measurement methodology uses `os_signpost` markers wrapped around `PlayerTrendService.computeTrend(playerID:maxRounds:)` AND the SwiftUI rendering frame timeline; both numbers are recorded — the dominant cost should be the service call.

2. **Given** the same fixture player + course is loaded, **when** `PersonalBestService.computeBest(playerID:courseID:)` is invoked 5 times, **then** the median time is recorded as the on-device baseline for the service. There is NO formal `<500ms` budget for `PersonalBestService` in any prior story — this AC establishes the baseline number for future regression comparison. The expected ballpark is `<200ms` at the PMVP `maxRounds = 500` bound (Story 13.2 dev notes).

3. **Given** the same fixture player + a second fixture player who participated in at least 10 of the 250 rounds, **when** `HeadToHeadService.computeRecord(playerA:playerB:)` is invoked 5 times, **then** the median time is recorded as the on-device baseline. As with AC #2, no formal budget exists — this AC establishes a baseline. The expected ballpark is `<300ms` (HeadToHead loops the per-round StandingsEngine recompute, so it should be more expensive than PB but bounded).

4. **Given** any single measurement (PlayerTrend, PersonalBest, or HeadToHead) exceeds an informal regression threshold (`PlayerTrend >500ms`, `PB >2s`, `HeadToHead >3s`), **when** the failure surfaces during verification, **then** Story 15.4 still closes (the measurement was performed), the failing number is recorded in Completion Notes, AND a follow-up story is filed naming the service and proposing an optimization approach (batched fetch, indexed predicate, etc.). Failing AC #1's `<500ms` budget for PlayerTrend is a launch-relevant signal — flag in Completion Notes with "BLOCKER for AC claim of PMVP-NFR4."

5. **Given** the three median numbers are recorded, **when** Story 13.1's AC #3 is re-read, **then** either (a) AC #3 is now claimed as fully satisfied because the device measurement is at-or-below 500ms (Story 13.1 Completion Note #8 currently states this is not claimed), OR (b) AC #3 is explicitly flagged as not satisfied with the device number documented (informing whether PlayerTrendService needs optimization before launch). The decision is recorded in `_bmad-output/implementation-artifacts/15-4-evidence/perf.md`.

6. **Given** the seeding script and measurement results are committed, **when** the `_bmad-output/implementation-artifacts/deferred-work.md` Story 13.1 AC #3 deferral bullet is read, **then** the bullet is removed and replaced with the on-device number (e.g., `- AC #3 PlayerTrendService measurement: 380ms on iPhone 14 (median of 5 runs, fixture: 250 rounds). PMVP-NFR4 satisfied. [Story 15.4]`).

## Tasks / Subtasks

- [ ] **Task 1: Identify and provision the test device** (AC: 1)
  - [ ] 1.1 **User elicitation:** Before any work, ask the user for (a) which physical iPhone is available for testing (the device must be iPhone 12 or later per Story 14.2 dev notes — Apple A14 Bionic or newer), (b) whether the user can install a debug or release build via Xcode for ~30 minutes of testing, (c) the iCloud account the device should be signed into (test-only Apple ID preferred so it doesn't pollute the developer's primary iCloud with fixture rounds).
  - [ ] 1.2 If no physical device is available, the story is fully deferred to the user-provided-device path — Story 15.4 stays `ready-for-dev` with an explicit Completion Note: `"No physical device available. Deferred to next session with hardware access. AC #3 of Story 13.1 remains unclaimed."` Do NOT close the story based on simulator measurements.
  - [ ] 1.3 Confirm Xcode 16.x is installed and the device is paired (in `xcrun xctrace list devices`). The device should appear with `(<udid>)` and a non-error status.

- [ ] **Task 2: Build and install the test bundle** (AC: 1, 2, 3)
  - [ ] 2.1 Build a Release-configuration of HyzerApp (release-config exercises optimizations that simulator-debug does not, more closely matching TestFlight install path): `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination "platform=iOS,name=<device-name>" build`. Expect `** BUILD SUCCEEDED **`.
  - [ ] 2.2 Install on the device. The simplest path is Xcode's Product → Destination → physical device → Cmd-R. This installs the freshly-built artifact and launches the app under the debugger (signpost markers require the debugger or Instruments to be attached).
  - [ ] 2.3 Verify the app launches to the onboarding screen on the device. Onboard with a fixture display name (e.g., `Perf-Tester-15-4`).

- [ ] **Task 3: Seed 250 fixture rounds for the test player** (AC: 1)
  - [ ] 3.1 The codebase does NOT have a public 250-round seeding script (Story 13.1 dev notes describe a similar measurement using fixture-construction-loops in tests, not a runtime seeding harness). For Story 15.4's purposes, the seeding can be done via a debug-only `#if DEBUG` block in `HyzerApp/App/HyzerApp.swift` that creates 250 `Round` + 250 × 18 `ScoreEvent` records into the SwiftData store on a triggered action.
  - [ ] 3.2 Implement a single `#if DEBUG`-guarded `Button("Seed 250 Rounds")` in a debug-only `HyzerApp/Views/Debug/PerfTestSeederView.swift` that calls `await SeedHelper.seed250Rounds(into: modelContext)`. The seed helper lives in `HyzerKit/Sources/HyzerKit/Domain/SeedHelper.swift` and constructs 250 deterministic rounds with the test player as a participant, distributed across the 4 pre-seeded courses (Story 1.3) at 60+ rounds each, with stroke counts varying from `-10` to `+15` over par to exercise the score-state palette.
  - [ ] 3.3 Run the seeder once on the device. Wait for completion (expected <30 seconds). Verify by navigating to History and confirming 250 rounds are visible.
  - [ ] 3.4 **IMPORTANT:** The seeder code is `#if DEBUG`-guarded so it does not ship in Release builds. After this story closes, the seeder remains in the codebase for future perf measurements. Story 15.7's TestSupport extraction may later relocate `SeedHelper` — out of scope here.

- [ ] **Task 4: Measure `PlayerTrendService.computeTrend` on device** (AC: 1, 5)
  - [ ] 4.1 With the device attached to Xcode and Instruments not yet running, open Instruments → Time Profiler + os_signpost. Target: HyzerApp on the device.
  - [ ] 4.2 Wrap the `PlayerTrendService.computeTrend(playerID:maxRounds:)` call in `os_signpost`:
    ```swift
    let log = Logger.player_trend
    let signpostID = log.makeSignpostID()
    let state = log.beginSignpost("computeTrend", id: signpostID)
    defer { log.endSignpost("computeTrend", id: signpostID, state: state) }
    return await service.computeTrend(...)
    ```
    Add this wrapping in `PlayerTrendViewModel.load()` (or wherever the service is invoked). The wrapping is debug-only (`#if DEBUG`); remove from production code path in Story 15.4 cleanup, OR retain as documented instrumentation per CLAUDE.md observability rules (decide in Completion Notes).
  - [ ] 4.3 Open the player's trend view 5 times in a row, force-quitting between each (Cmd-Shift-H twice → swipe up). Instruments records 5 signpost intervals.
  - [ ] 4.4 Read the 5 signpost durations in Instruments. Compute the median (middle value when sorted). Record in `_bmad-output/implementation-artifacts/15-4-evidence/perf.md` as a row:
    ```
    | Run | Duration (ms) |
    |---|---|
    | 1 | XXX |
    | 2 | XXX |
    | 3 | XXX |
    | 4 | XXX |
    | 5 | XXX |
    | **Median** | **XXX** |
    ```
  - [ ] 4.5 If median exceeds 500ms, AC #1 is failed — record verbatim in Completion Notes with the device name (`iPhone 14`, etc.) and iOS version. File a follow-up story per AC #4.

- [ ] **Task 5: Measure `PersonalBestService.computeBest` on device** (AC: 2)
  - [ ] 5.1 Repeat the signpost wrapping in `PersonalBestViewModel.load()` (or wherever the service is invoked). Use a separate `Logger.personal_best` source so the signposts don't intermix in Instruments.
  - [ ] 5.2 Open the course detail view for a course where the test player has at least 60 rounds. The personal-best section renders, triggering the service call. Repeat 5 times.
  - [ ] 5.3 Record median in `perf.md`.

- [ ] **Task 6: Measure `HeadToHeadService.computeRecord` on device** (AC: 3)
  - [ ] 6.1 Repeat the signpost wrapping in `HeadToHeadViewModel.load()`.
  - [ ] 6.2 Open the head-to-head view with the test player vs. a second seeded player (the seeder in Task 3 should include a second participant in every round). Repeat 5 times.
  - [ ] 6.3 Record median in `perf.md`.

- [ ] **Task 7: Compile findings and update Story 13.1 AC #3 claim** (AC: 5, 6)
  - [ ] 7.1 Compose `perf.md` with the three median numbers, the device used, iOS version, the date measured, and a single-sentence verdict:
    ```
    # Story 15.4 — On-Device Performance Verification

    **Device:** iPhone 14 (iOS 18.2)
    **Date:** 2026-MM-DD
    **Build:** Release configuration, HEAD <SHA>
    **Fixture:** 250 rounds via SeedHelper.seed250Rounds()

    ## PlayerTrendService.computeTrend
    [table from Task 4.4]
    **Verdict:** 🟩 PASS (<500ms median) / 🟥 FAIL (>500ms median)
    **Story 13.1 AC #3 claim:** Now satisfied / Still unclaimed

    ## PersonalBestService.computeBest
    [table from Task 5.3]
    **Baseline established:** XXXms (no prior budget)

    ## HeadToHeadService.computeRecord
    [table from Task 6.3]
    **Baseline established:** XXXms (no prior budget)
    ```
  - [ ] 7.2 If AC #1 passes, update Story 13.1 by appending a single line to its Completion Notes section: `"AC #3 device measurement performed in Story 15.4. Median: XXXms on iPhone <model> (iOS <version>). Now claimed as satisfied."` Do NOT rewrite Story 13.1's text; just append.
  - [ ] 7.3 If AC #1 fails, update Story 13.1 with the failed number and a note that an optimization is needed before launch. File the follow-up story.

- [ ] **Task 8: Cleanup and close** (AC: 6)
  - [ ] 8.1 Decide whether to retain the `os_signpost` instrumentation in production code paths (CLAUDE.md observability guidance allows it; running cost is negligible). If retained, ensure the `#if DEBUG` flags are removed and the Logger source is documented in CLAUDE.md "Observability". If removed, strip the signpost code from the three viewmodels — leave no dead `#if DEBUG` blocks.
  - [ ] 8.2 Stage and commit. The diff includes: `SeedHelper.swift` (debug-guarded), `PerfTestSeederView.swift` (debug-guarded), optional `os_signpost` instrumentation in the three viewmodels, `perf.md` in the evidence directory (gitignored), and `deferred-work.md` cleanup. Conventional commit: `chore(perf): verify history services on-device (Story 15.4)`.
  - [ ] 8.3 Remove the Story 13.1 AC #3 bullet from `_bmad-output/implementation-artifacts/deferred-work.md` and replace with the on-device number per AC #6.
  - [ ] 8.4 Update `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 15.4 → `done` (or `review`).

## Dev Notes

### Why this story exists

Story 13.1's AC #3 demands a `<500ms` render time at 250 rounds — PMVP-NFR4. Story 13.1's dev agent measured this on a macOS x86 test runner and got `~0.84s` (Completion Note #8). The Completion Note explicitly states this is NOT a claim of AC #3 satisfaction — device measurement is needed. Two stories later (14.1, 14.2), the device measurement still hasn't happened. This story closes it.

The two adjacent services (`PersonalBest`, `HeadToHead`) are bundled because (a) they share the same SwiftData fetch patterns, (b) measuring all three on the same device in one session is more efficient than three separate stories, and (c) establishing on-device baselines for the two unbudgeted services creates a regression bar that future PRs can compare against.

The seeding harness is created in this story because no public 250-round seeding tool exists in the codebase. The harness is debug-only (`#if DEBUG`) so it does not ship in TestFlight or production builds — Apple does not see it.

### Current state — what is already correct (do NOT redo)

- **`PlayerTrendService`, `PersonalBestService`, `HeadToHeadService` are implemented and tested.** Stories 13.1, 13.2, 13.3 closed. All bounded by `fetchLimit`. All measured on the host via the existing performance tests in HyzerKitTests. This story adds the device measurement, not new code.
- **The 4 pre-seeded courses (Story 1.3) provide enough distribution for the fixture.** 250 rounds distributed across 4 courses gives ~60 rounds per course, which is more than enough for PersonalBest and HeadToHead measurements.
- **`os_signpost` and `Logger` are the canonical observability tools per CLAUDE.md.** No new framework needed.
- **The `*-evidence/` gitignore glob is in place.**

### What this story changes

| Change | File | Notes |
|---|---|---|
| Add seed helper | `HyzerKit/Sources/HyzerKit/Domain/SeedHelper.swift` | NEW, debug-only or always-available |
| Add debug seeder view | `HyzerApp/Views/Debug/PerfTestSeederView.swift` | NEW, `#if DEBUG` |
| Optional: add os_signpost | `HyzerApp/ViewModels/PlayerTrendViewModel.swift`, `PersonalBestViewModel.swift`, `HeadToHeadViewModel.swift` | Decide in Completion Notes whether to retain |
| Evidence | `_bmad-output/implementation-artifacts/15-4-evidence/perf.md` | LOCAL ONLY, gitignored |
| Story 13.1 update | `_bmad-output/implementation-artifacts/13-1-*.md` | Append-only Completion Note line |
| Deferred-work cleanup | `_bmad-output/implementation-artifacts/deferred-work.md` | Replace 13.1 AC #3 bullet with device number |

The seed helper is intentionally simple — 250 rounds, deterministic, fixed across runs. No random scoring, no edge-case round types. Just a baseline-establishing fixture.

### What this story must NOT touch

- **No production-code optimization.** If a measurement reveals a service is slow, file a follow-up — do NOT optimize in this story. Optimization is a separate scope.
- **No new service additions.** Don't add a fourth history service. Don't add a "PlayerStreakService" or similar.
- **No test additions beyond the seed helper.** The existing test suites for the three services already cover correctness; this story measures performance, not correctness.

### Architecture compliance

- **CLAUDE.md "Bounded SwiftData queries":** The three services already comply. Verifying that compliance via device measurement, not changing it.
- **CLAUDE.md "No silent `try?`":** The seed helper uses `try` with `do/catch` and logs failures.
- **CLAUDE.md "Git Workflow":** Branch `feature/15-4-on-device-perf-verification`. Conventional commit `chore(perf): verify history services on-device (Story 15.4)`.
- **Architecture §Performance (`architecture.md` performance section):** Reaffirms `<500ms` chart render budget. This story is the device-level enforcement.

### Library / framework requirements

- **`os_signpost` / `Logger`:** Apple-shipped, already used elsewhere in the codebase. No new dependency.
- **Instruments:** Built into Xcode 16.x; no install needed.
- **Physical iPhone 12+:** External requirement — must be provided by the user (Task 1.1 elicitation).

### File-structure requirements

```
HyzerKit/Sources/HyzerKit/Domain/SeedHelper.swift                                    [NEW — Task 3.2]
HyzerApp/Views/Debug/PerfTestSeederView.swift                                        [NEW — Task 3.2, #if DEBUG]
HyzerApp/ViewModels/PlayerTrendViewModel.swift                                       [EDIT — Task 4.2, optional os_signpost]
HyzerApp/ViewModels/PersonalBestViewModel.swift                                      [EDIT — Task 5.1, optional os_signpost]
HyzerApp/ViewModels/HeadToHeadViewModel.swift                                        [EDIT — Task 6.1, optional os_signpost]
_bmad-output/implementation-artifacts/15-4-evidence/perf.md                          [LOCAL ONLY — Task 7.1, gitignored]
_bmad-output/implementation-artifacts/13-1-score-trend-visualization-per-player.md   [EDIT — Task 7.2, append-only Completion Note]
_bmad-output/implementation-artifacts/deferred-work.md                               [EDIT — Task 8.3, replace bullet]
_bmad-output/implementation-artifacts/sprint-status.yaml                             [EDIT — Task 8.4]
```

### Testing requirements

- **The seed helper has a one-line correctness test** in `HyzerKitTests/Domain/SeedHelperTests.swift`: `test_seedHelper_creates250Rounds_with18ScoreEventsEach` — asserts the count is exactly 250 + 4500 (250 × 18) after running the seeder. This protects against a regression where the seeder under-seeds and the perf measurement uses a smaller-than-intended fixture.
- **No tests on the os_signpost wrapping** — signpost emission is unobservable at the unit-test level.

### Previous-story intelligence

**Story 13.1 Completion Note #8 (line 89 in deferred-work.md):** "AC #3 on-device `<500ms` performance measurement — already noted in Completion Note #8. macOS x86 test runner measured ~0.84s for 250 rounds; device target requires on-iPhone measurement during Task 8.2/8.3 manual verification. AC #3 not claimed as fully satisfied until measured."

This is the explicit gate Story 15.4 closes.

**Story 13.2 dev notes (deferred-work line 19):** "`fetchLimit = maxRounds * 20` multiplier under-bounds for multi-course users." This is acknowledged debt — does NOT affect Story 15.4's measurement, but the multiplier IS what determines how much SwiftData work happens. The on-device number this story records is for the CURRENT multiplier; a future optimization story will change the multiplier and re-measure.

**Story 13.3 dev notes (deferred-work line 7):** "Predicate with up to ~10k UUIDs may approach SQLite IN-clause limits." Same caveat — this story measures current behavior, not optimized behavior.

### Latest tech information (2026-05-18)

- **`os_signpost` in Swift 5.5+:** The structured-concurrency-aware API is `Logger.makeSignpostID()` + `beginSignpost(...)` + `endSignpost(...)`. Captured by Instruments without code instrumentation beyond the markers themselves.
- **Instruments time-profiler accuracy:** ±5ms at the iPhone 14 / iOS 18 level for short-lived signpost intervals. For a 500ms target, ±5ms is acceptable noise.
- **Release vs. Debug performance gap:** ~2-4× on SwiftData fetches in 2026 (Swift 6 strict concurrency + improved optimizer). MUST measure in Release; Debug-mode numbers are not representative.

### Open questions — pre-answered

**Pre-answered:**
- Median of 5 → standard methodology for this kind of measurement (per Story 14.2 dev notes implicit acknowledgment; standard mobile-perf practice)
- Seed harness location → `SeedHelper.swift` in HyzerKit Domain, debug-guarded triggering view in HyzerApp Debug
- Release-config build → required (per "latest tech information" above)
- Device floor → iPhone 12+ (per Story 14.2 dev notes)
- Retain or strip os_signpost → decided in Completion Notes (Task 8.1)

**Still requires elicitation (Task 1.1):**
- Which physical device is available
- Test iCloud account preference
- Whether user can install via Xcode for ~30 min

### Project Structure Notes

This is a measurement + minor-instrumentation story. The committed footprint is modest: one new HyzerKit file, one new HyzerApp file, three viewmodel edits (if instrumentation is retained), and a few doc updates. The evidence (`perf.md`) is gitignored.

### References

- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:89` — Story 13.1 AC #3 deferral]
- [Source: `_bmad-output/implementation-artifacts/13-1-score-trend-visualization-per-player.md` — Story 13.1 AC #3 + Completion Note #8 referencing 0.84s simulator measurement]
- [Source: `HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift` — service being measured]
- [Source: `HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift` — service being baselined]
- [Source: `HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift` — service being baselined]
- [Source: `CLAUDE.md` "Project Status" — performance budgets]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md` PMVP-NFR4 — `<500ms` budget]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Story-15.4` — this story's epic-level scope]

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
