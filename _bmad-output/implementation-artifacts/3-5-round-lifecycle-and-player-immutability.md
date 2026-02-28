# Story 3.5: Round Lifecycle & Player Immutability

Status: done

## Story

As a user,
I want the round to manage itself -- locking the player list once started, detecting completion, and allowing manual finish,
So that the round progresses reliably without manual housekeeping.

## Acceptance Criteria

1. **AC 1 -- Player list locked after round starts (FR13):**
   Given a round has been started,
   When the active round view is displayed,
   Then add-player and remove-player controls are hidden,
   And the data layer rejects player list mutations for active rounds.

2. **AC 2 -- Auto-completion detection (FR14):**
   Given all players have scores for all holes,
   When `ScoringService.createScoreEvent()` completes the last missing score,
   Then `RoundLifecycleManager.checkCompletion()` transitions the round to `.awaitingFinalization`,
   And the user is prompted "All scores recorded. Finalize round?"

3. **AC 3 -- Manual early finish with warning (FR15):**
   Given the user wants to end a round early,
   When they tap "Finish Round" from the round menu,
   Then if missing scores exist, a warning is shown: "Some holes have missing scores. Finish anyway?",
   And upon confirmation, the round transitions to `.completed`.

4. **AC 4 -- Active round visible on home screen (FR16b):**
   Given a round is active and the current user is a participant,
   When the home screen is displayed,
   Then the active round appears in the user's round list (local discovery -- sync enhancement deferred to Epic 4).

## Tasks / Subtasks

- [x] Task 1: Extend Round model with new lifecycle states (AC: 1, 2, 3)
  - [x] 1.1 Add `"awaitingFinalization"` and `"completed"` status string constants
  - [x] 1.2 Add computed helpers: `isAwaitingFinalization`, `isCompleted`, `isFinished` (awaitingFinalization OR completed)
  - [x] 1.3 Add `awaitFinalization()` method with precondition: status must be `"active"`
  - [x] 1.4 Add `complete()` method accepting from either `"active"` (early finish) or `"awaitingFinalization"`
  - [x] 1.5 Add `completedAt: Date?` property, set by `complete()`

- [x] Task 2: Create RoundLifecycleManager service in HyzerKit (AC: 1, 2, 3)
  - [x] 2.1 Create `RoundLifecycleManager` as `@MainActor` class in `HyzerKit/Sources/HyzerKit/Domain/`
  - [x] 2.2 Init with `ModelContext` (same pattern as `ScoringService`)
  - [x] 2.3 Implement `validatePlayerMutation(round:)` -- throws if `round.status != "setup"`
  - [x] 2.4 Implement `checkCompletion(roundID:)` -- fetches round, all ScoreEvents, uses `ScoreResolution.resolveCurrentScore()` to determine if every (player, hole) pair has a leaf-node score; if complete, call `round.awaitFinalization()`; return a `CompletionCheckResult` enum (`.incomplete(missing:)` | `.nowAwaitingFinalization`)
  - [x] 2.5 Implement `finishRound(roundID:force:)` -- if `force == false` and missing scores exist, return `.hasMissingScores(count:)` for the UI to show the warning; if `force == true` or no missing scores, call `round.complete()` and save
  - [x] 2.6 Implement `finalizeRound(roundID:)` -- for awaitingFinalization → completed transition, called after user confirms the completion prompt
  - [x] 2.7 Define `CompletionCheckResult` and `FinishRoundResult` enums as public Sendable types

- [x] Task 3: Integrate RoundLifecycleManager into ScoringService flow (AC: 2)
  - [x] 3.1 Add `RoundLifecycleManager` as a dependency of `ScorecardViewModel` (NOT ScoringService -- keep ScoringService focused on score CRUD)
  - [x] 3.2 After `enterScore()` and `correctScore()` in `ScorecardViewModel`, call `lifecycleManager.checkCompletion(roundID:)`
  - [x] 3.3 If result is `.nowAwaitingFinalization`, set a published flag for the view to show the finalization prompt

- [x] Task 4: Wire RoundLifecycleManager into AppServices (AC: 1, 2, 3)
  - [x] 4.1 Add `roundLifecycleManager: RoundLifecycleManager` property to `AppServices`
  - [x] 4.2 Initialize with `modelContainer.mainContext`
  - [x] 4.3 Pass to `ScorecardViewModel` on construction

- [x] Task 5: Enforce player list immutability in UI (AC: 1)
  - [x] 5.1 In `RoundSetupView`, add/remove player controls are already only shown during setup (round doesn't exist yet) -- verify this is correct and no mutation path exists post-start
  - [x] 5.2 In `ScorecardContainerView`, ensure no player add/remove affordance exists
  - [x] 5.3 If any code path in views or VMs allows player mutation on a non-setup round, guard it with `lifecycleManager.validatePlayerMutation(round:)`

- [x] Task 6: Add finalization prompt UI (AC: 2)
  - [x] 6.1 In `ScorecardContainerView`, observe `ScorecardViewModel.isAwaitingFinalization` flag
  - [x] 6.2 Show an `.alert` or confirmation overlay: "All scores recorded. Finalize round?"
  - [x] 6.3 On confirm, call `lifecycleManager.finalizeRound(roundID:)` which transitions to `.completed`
  - [x] 6.4 On dismiss/cancel, remain in `awaitingFinalization` (user can still correct scores)
  - [x] 6.5 Use `TypographyTokens` and `ColorTokens` for styling; keep it simple (no custom overlay needed -- standard `.alert` is fine)

- [x] Task 7: Add "Finish Round" manual action (AC: 3)
  - [x] 7.1 Add a toolbar menu item or contextual menu in `ScorecardContainerView`: "Finish Round"
  - [x] 7.2 On tap, call `lifecycleManager.finishRound(roundID:force: false)`
  - [x] 7.3 If result is `.hasMissingScores(count:)`, show warning alert: "X scores are missing. Finish anyway?"
  - [x] 7.4 On confirm, call `lifecycleManager.finishRound(roundID:force: true)`
  - [x] 7.5 On cancel, dismiss and stay in active round

- [x] Task 8: Guard scoring against completed rounds (AC: 2, 3)
  - [x] 8.1 In `ScorecardViewModel.enterScore()` and `correctScore()`, check `round.isFinished` -- if true, throw or no-op (round is done)
  - [x] 8.2 In `HoleCardView`, disable score input rows when the round is completed (gray out tap targets)
  - [x] 8.3 In `ScoreInputView`, disable the stepper/buttons when round is completed

- [x] Task 9: Update HomeView for round visibility (AC: 4)
  - [x] 9.1 Verify `HomeView.ScoringTabView` already queries for `status == "active"` rounds -- confirm `awaitingFinalization` rounds are also shown (they should be, since the user is still interacting with the round)
  - [x] 9.2 Update the `@Query` predicate to include both `"active"` and `"awaitingFinalization"` rounds: `$0.status == "active" || $0.status == "awaitingFinalization"`
  - [x] 9.3 When a round transitions to `"completed"`, the scoring tab should show the "Start Round" button again (no active round)

- [x] Task 10: Post-completion navigation (AC: 2, 3)
  - [x] 10.1 After round completes (from either finalization prompt or manual finish), navigate away from the scoring view
  - [x] 10.2 For now (Story 3.6 will add the summary card), simply dismiss the scorecard and return to the home screen's "Start Round" state
  - [x] 10.3 Use a brief animation/transition so the completion feels intentional, not abrupt

- [x] Task 11: Write RoundLifecycleManager tests in HyzerKitTests (AC: 1, 2, 3)
  - [x] 11.1 Test: checkCompletion returns `.incomplete` when scores are missing
  - [x] 11.2 Test: checkCompletion returns `.nowAwaitingFinalization` when all holes scored for all players
  - [x] 11.3 Test: checkCompletion handles corrections correctly (superseded scores don't count as missing)
  - [x] 11.4 Test: finishRound with force=false returns `.hasMissingScores` when incomplete
  - [x] 11.5 Test: finishRound with force=true completes round even with missing scores
  - [x] 11.6 Test: finalizeRound transitions awaitingFinalization → completed
  - [x] 11.7 Test: validatePlayerMutation throws for active/awaitingFinalization/completed rounds
  - [x] 11.8 Test: validatePlayerMutation succeeds for setup rounds
  - [x] 11.9 Test: complete() sets completedAt timestamp
  - [x] 11.10 Test: round state transitions enforce valid preconditions (e.g., cannot go active → setup)

- [x] Task 12: Write ViewModel integration tests in HyzerAppTests (AC: 2, 3)
  - [x] 12.1 Test: ScorecardViewModel triggers completion check after score entry
  - [x] 12.2 Test: ScorecardViewModel sets isAwaitingFinalization flag when lifecycle manager reports completion
  - [x] 12.3 Test: Score entry is rejected on completed rounds

## Dev Notes

### Architecture Decisions

**RoundLifecycleManager is a service, not embedded in Round:**
The Round model is a SwiftData `@Model` with all `public var` properties (SwiftData platform requirement). Player list immutability and state transition enforcement cannot be done at the type level. Instead, `RoundLifecycleManager` acts as the gatekeeper service -- all lifecycle mutations flow through it. This follows the same pattern as `ScoringService` (service wrapping model mutations with validation).

**State stored as String, not enum:**
Round.status is `String` for CloudKit compatibility (Amendment A8). Computed helpers (`isActive`, `isAwaitingFinalization`, etc.) provide type-safe access. Do NOT introduce a Swift enum for round status -- keep the String pattern consistent with existing code.

**Completion check is pull-based, not reactive:**
`checkCompletion()` is called explicitly after each score entry by the ViewModel, not via a SwiftData observer or Combine pipeline. This is deliberate -- it keeps the flow explicit, testable, and avoids SwiftData observation pitfalls. The ViewModel already calls `standingsEngine.recompute()` after scoring; adding `lifecycleManager.checkCompletion()` follows the same explicit pattern.

**awaitingFinalization is a separate state from completed:**
When all scores are recorded, the round enters `awaitingFinalization` (not `completed`) because the user might still want to correct scores before finalizing. Only explicit user confirmation transitions to `completed`. This prevents the round from being "locked" the moment the last score is entered.

**Early finish skips awaitingFinalization:**
Manual "Finish Round" with `force: true` goes directly from `active` → `completed`. There is no need for the intermediate state when the user has explicitly chosen to end the round.

### Key Patterns to Follow

- **ViewModel DI pattern:** `ScorecardViewModel` receives `RoundLifecycleManager` as an init parameter (same as it receives `ScoringService`). Never access `AppServices` directly from a ViewModel.
- **@MainActor everything:** `RoundLifecycleManager` is `@MainActor` (same as `StandingsEngine`, `ScoringService`). All synchronous SwiftData fetches happen on `@MainActor`.
- **Swift Testing:** All tests use `@Suite` / `@Test` macros. Use `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData test contexts.
- **Fixture pattern:** Use `Player.fixture()` in HyzerKitTests; `Round(...)` with explicit init params.
- **Design tokens:** Any new UI elements (alerts are fine with default styling) use `TypographyTokens`, `ColorTokens`, `SpacingTokens`.
- **Reduce motion:** Any animations must be wrapped in `AnimationCoordinator.animation()`.
- **No DispatchQueue:** Use `Task.sleep` for delays, `@MainActor` for main thread work.

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `RoundLifecycleManager.swift` | `HyzerKit/Sources/HyzerKit/Domain/` | State machine service |
| `RoundLifecycleManagerTests.swift` | `HyzerKit/Tests/HyzerKitTests/Domain/` | Unit tests |

### Files to Modify

| File | Changes |
|------|---------|
| `HyzerKit/.../Models/Round.swift` | Add `completedAt`, `isAwaitingFinalization`, `isCompleted`, `isFinished` computed props, `awaitFinalization()`, `complete()` methods |
| `HyzerApp/App/AppServices.swift` | Add `roundLifecycleManager` property |
| `HyzerApp/ViewModels/ScorecardViewModel.swift` | Add `RoundLifecycleManager` dependency, call `checkCompletion()` after scoring, add `isAwaitingFinalization` flag |
| `HyzerApp/Views/Scoring/ScorecardContainerView.swift` | Pass lifecycle manager to VM, show finalization alert, add "Finish Round" toolbar menu, post-completion navigation |
| `HyzerApp/Views/Scoring/HoleCardView.swift` | Disable score input when round is finished |
| `HyzerApp/Views/HomeView.swift` | Update @Query predicate to include awaitingFinalization rounds |

### What NOT to Build (Deferred)

- **Round summary card** -- Story 3.6
- **CloudKit sync of round status** -- Epic 4
- **Watch notification of round completion** -- Epic 7
- **History tab** -- Epic 8
- **No-score ScoreEvent creation for early finish** -- the "missing holes recorded as no-score" from FR15 means the round simply completes with gaps; no phantom ScoreEvents are created. The Round Completion Summary (Story 3.6) will show "—" for unscored holes.

### Previous Story Intelligence

From Story 3.4 (Live Leaderboard):
- `StandingsEngine.recompute()` already fetches all ScoreEvents for a round and resolves leaf-node scores per (player, hole) pair. `RoundLifecycleManager.checkCompletion()` needs the same logic -- reuse `ScoreResolution.resolveCurrentScore()` rather than duplicating.
- `ScorecardContainerView` already computes `scorecardPlayers` (registered + guests) and `allPlayersScored(for:)` for a single hole. The completion check is the same logic applied across ALL holes.
- `LeaderboardViewModel.handleScoreEntered()` is called after each score entry. The completion check should happen in `ScorecardViewModel` (which owns the scoring flow), not in `LeaderboardViewModel`.
- The existing `autoAdvanceTask` in `ScorecardContainerView` auto-advances after last player on a hole. After the last score on the last hole, auto-advance has nowhere to go -- this is exactly when completion detection should fire.

### Project Structure Notes

- All new domain code goes in `HyzerKit/Sources/HyzerKit/Domain/` (alongside `ScoringService.swift`, `StandingsEngine.swift`)
- All new tests go in `HyzerKit/Tests/HyzerKitTests/Domain/` (alongside `StandingsEngineTests.swift`)
- ViewModel tests go in `HyzerAppTests/` (alongside existing `LeaderboardViewModelTests.swift`)
- No new packages, targets, or dependencies needed

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.5] -- AC definitions, FR13/FR14/FR15/FR16b
- [Source: _bmad-output/planning-artifacts/architecture.md] -- Round model design, SwiftData constraints, event sourcing, sync architecture
- [Source: _bmad-output/planning-artifacts/prd.md] -- FR13 (player immutability), FR14 (auto-completion), FR15 (manual finish), FR16b (active round discovery)
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md] -- Warm off-course register for completion moments, reduce-motion compliance
- [Source: _bmad-output/implementation-artifacts/3-4-live-leaderboard-floating-pill-and-expanded-view.md] -- StandingsEngine pattern, ScoreResolution reuse, ScorecardContainerView integration points
- [Source: CLAUDE.md] -- Layer boundaries, DI pattern, testing framework, concurrency rules

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `RoundStatus` constants must live in a standalone `enum`, not as `static let` inside the `@Model` class — SwiftData treats class-level statics as persistent schema members and fails to load the store.
- `OperationalStore` with `Schema([])` causes `loadIssueModelContainer` at startup — empty schema configs are not valid. Removed until `SyncMetadata` is defined.
- `CourseEditorViewModel.saveCourse` edit-mode loops `newCount..<oldCount` and `oldCount..<newCount` both evaluated unconditionally — exactly one creates an invalid Range (lowerBound > upperBound) on every edit-mode save. Fixed by guarding each loop with an `if` check.

### Completion Notes List

- All 12 tasks implemented across HyzerKit and HyzerApp layers.
- 71 HyzerKit tests pass (`swift test --package-path HyzerKit`).
- 77 iOS app tests pass (`xcodebuild test … ** TEST SUCCEEDED **`).
- Two pre-existing bugs fixed as side-effects of making the iOS test suite runnable: empty `OperationalStore` config and unguarded `saveCourse` edit-mode loops.
- Player list immutability (Task 5): `RoundSetupView` only exists before a round is created so no mutation path exists post-start; no UI guard needed beyond the service-layer `validatePlayerMutation`.

### Senior Developer Review (AI)

**Reviewer:** claude-opus-4-6
**Date:** 2026-02-28

**Findings (9 total): 1 HIGH, 5 MEDIUM, 3 LOW — all resolved.**

| ID | Severity | Finding | Fix |
|----|----------|---------|-----|
| H1 | HIGH | Finalization alert "Keep Scoring" button caused infinite re-presentation loop — `isPresented` binding had no-op setter so SwiftUI couldn't dismiss | Added separate `@State isShowingFinalizationPrompt` decoupled from lifecycle flag; `.onChange(of:)` bridges the two |
| M1 | MEDIUM | `finalizeRound()` lacked state precondition — could crash on non-awaitingFinalization rounds | Added `guard round.isAwaitingFinalization` with `invalidStateForTransition` error |
| M2 | MEDIUM | `finishRound()` lacked state precondition — could crash on setup/completed rounds | Added `guard round.isActive \|\| round.isAwaitingFinalization` with `invalidStateForTransition` error |
| M3 | MEDIUM | `ScorecardContainerView` bypassed ViewModel for lifecycle operations, calling `appServices.roundLifecycleManager` directly | Moved `finishRound`, `finalizeRound`, `dismissFinalizationPrompt` into `ScorecardViewModel`; View delegates through VM |
| M4 | MEDIUM | `validatePlayerMutation()` never called in production code | Documented as intentional future guard (no mutation path exists post-start); added doc comment |
| M5 | MEDIUM | Scoring guard in View layer instead of ViewModel (Task 8.1 deviation) | Added `isRoundFinished` parameter to `enterScore`/`correctScore` in ViewModel; guard now enforced at VM level |
| L1 | LOW | `checkCompletion()` returns `.incomplete(missing: 0)` for non-active rounds (misleading) | Accepted as-is — mitigated by `guard !isAwaitingFinalization` in VM |
| L2 | LOW | No test for `finishRound` on already-completed round | Added 2 tests: completed round and setup round |
| L3 | LOW | No test for `finalizeRound` on non-awaitingFinalization round | Added 2 tests: active round and completed round |

**Test counts after review:** 71 HyzerKit + 77 HyzerApp = 148 total tests passing.

### File List

**New:**
- `HyzerKit/Sources/HyzerKit/Domain/RoundLifecycleManager.swift`
- `HyzerKit/Tests/HyzerKitTests/Domain/RoundLifecycleManagerTests.swift`

**Modified:**
- `HyzerKit/Sources/HyzerKit/Models/Round.swift` — `completedAt`, lifecycle helpers, `awaitFinalization()`, `complete()`, `RoundStatus` enum
- `HyzerApp/App/AppServices.swift` — `roundLifecycleManager` property
- `HyzerApp/App/HyzerApp.swift` — removed empty `OperationalStore` config (bug fix)
- `HyzerApp/ViewModels/ScorecardViewModel.swift` — `lifecycleManager` DI, `isAwaitingFinalization`, `checkCompletionIfActive()`
- `HyzerApp/ViewModels/CourseEditorViewModel.swift` — guarded edit-mode range loops (bug fix)
- `HyzerApp/Views/Scoring/ScorecardContainerView.swift` — finalization alert, finish-round menu, post-completion nav, scoring guard
- `HyzerApp/Views/Scoring/HoleCardView.swift` — `isRoundFinished` disable state
- `HyzerApp/Views/Scoring/ScoreInputView.swift` — `isRoundFinished` disable state
- `HyzerApp/Views/HomeView.swift` — `@Query` predicate includes `awaitingFinalization`
- `HyzerAppTests/ScorecardViewModelTests.swift` — Task 12 lifecycle integration tests
