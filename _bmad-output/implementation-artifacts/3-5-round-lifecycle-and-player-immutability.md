# Story 3.5: Round Lifecycle & Player Immutability

Status: ready-for-dev

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

- [ ] Task 1: Extend Round model with new lifecycle states (AC: 1, 2, 3)
  - [ ] 1.1 Add `"awaitingFinalization"` and `"completed"` status string constants
  - [ ] 1.2 Add computed helpers: `isAwaitingFinalization`, `isCompleted`, `isFinished` (awaitingFinalization OR completed)
  - [ ] 1.3 Add `awaitFinalization()` method with precondition: status must be `"active"`
  - [ ] 1.4 Add `complete()` method accepting from either `"active"` (early finish) or `"awaitingFinalization"`
  - [ ] 1.5 Add `completedAt: Date?` property, set by `complete()`

- [ ] Task 2: Create RoundLifecycleManager service in HyzerKit (AC: 1, 2, 3)
  - [ ] 2.1 Create `RoundLifecycleManager` as `@MainActor` class in `HyzerKit/Sources/HyzerKit/Domain/`
  - [ ] 2.2 Init with `ModelContext` (same pattern as `ScoringService`)
  - [ ] 2.3 Implement `validatePlayerMutation(round:)` -- throws if `round.status != "setup"`
  - [ ] 2.4 Implement `checkCompletion(roundID:)` -- fetches round, all ScoreEvents, uses `ScoreResolution.resolveCurrentScore()` to determine if every (player, hole) pair has a leaf-node score; if complete, call `round.awaitFinalization()`; return a `CompletionCheckResult` enum (`.incomplete(missing:)` | `.nowAwaitingFinalization`)
  - [ ] 2.5 Implement `finishRound(roundID:force:)` -- if `force == false` and missing scores exist, return `.hasMissingScores(count:)` for the UI to show the warning; if `force == true` or no missing scores, call `round.complete()` and save
  - [ ] 2.6 Implement `finalizeRound(roundID:)` -- for awaitingFinalization → completed transition, called after user confirms the completion prompt
  - [ ] 2.7 Define `CompletionCheckResult` and `FinishRoundResult` enums as public Sendable types

- [ ] Task 3: Integrate RoundLifecycleManager into ScoringService flow (AC: 2)
  - [ ] 3.1 Add `RoundLifecycleManager` as a dependency of `ScorecardViewModel` (NOT ScoringService -- keep ScoringService focused on score CRUD)
  - [ ] 3.2 After `enterScore()` and `correctScore()` in `ScorecardViewModel`, call `lifecycleManager.checkCompletion(roundID:)`
  - [ ] 3.3 If result is `.nowAwaitingFinalization`, set a published flag for the view to show the finalization prompt

- [ ] Task 4: Wire RoundLifecycleManager into AppServices (AC: 1, 2, 3)
  - [ ] 4.1 Add `roundLifecycleManager: RoundLifecycleManager` property to `AppServices`
  - [ ] 4.2 Initialize with `modelContainer.mainContext`
  - [ ] 4.3 Pass to `ScorecardViewModel` on construction

- [ ] Task 5: Enforce player list immutability in UI (AC: 1)
  - [ ] 5.1 In `RoundSetupView`, add/remove player controls are already only shown during setup (round doesn't exist yet) -- verify this is correct and no mutation path exists post-start
  - [ ] 5.2 In `ScorecardContainerView`, ensure no player add/remove affordance exists
  - [ ] 5.3 If any code path in views or VMs allows player mutation on a non-setup round, guard it with `lifecycleManager.validatePlayerMutation(round:)`

- [ ] Task 6: Add finalization prompt UI (AC: 2)
  - [ ] 6.1 In `ScorecardContainerView`, observe `ScorecardViewModel.isAwaitingFinalization` flag
  - [ ] 6.2 Show an `.alert` or confirmation overlay: "All scores recorded. Finalize round?"
  - [ ] 6.3 On confirm, call `lifecycleManager.finalizeRound(roundID:)` which transitions to `.completed`
  - [ ] 6.4 On dismiss/cancel, remain in `awaitingFinalization` (user can still correct scores)
  - [ ] 6.5 Use `TypographyTokens` and `ColorTokens` for styling; keep it simple (no custom overlay needed -- standard `.alert` is fine)

- [ ] Task 7: Add "Finish Round" manual action (AC: 3)
  - [ ] 7.1 Add a toolbar menu item or contextual menu in `ScorecardContainerView`: "Finish Round"
  - [ ] 7.2 On tap, call `lifecycleManager.finishRound(roundID:force: false)`
  - [ ] 7.3 If result is `.hasMissingScores(count:)`, show warning alert: "X scores are missing. Finish anyway?"
  - [ ] 7.4 On confirm, call `lifecycleManager.finishRound(roundID:force: true)`
  - [ ] 7.5 On cancel, dismiss and stay in active round

- [ ] Task 8: Guard scoring against completed rounds (AC: 2, 3)
  - [ ] 8.1 In `ScorecardViewModel.enterScore()` and `correctScore()`, check `round.isFinished` -- if true, throw or no-op (round is done)
  - [ ] 8.2 In `HoleCardView`, disable score input rows when the round is completed (gray out tap targets)
  - [ ] 8.3 In `ScoreInputView`, disable the stepper/buttons when round is completed

- [ ] Task 9: Update HomeView for round visibility (AC: 4)
  - [ ] 9.1 Verify `HomeView.ScoringTabView` already queries for `status == "active"` rounds -- confirm `awaitingFinalization` rounds are also shown (they should be, since the user is still interacting with the round)
  - [ ] 9.2 Update the `@Query` predicate to include both `"active"` and `"awaitingFinalization"` rounds: `$0.status == "active" || $0.status == "awaitingFinalization"`
  - [ ] 9.3 When a round transitions to `"completed"`, the scoring tab should show the "Start Round" button again (no active round)

- [ ] Task 10: Post-completion navigation (AC: 2, 3)
  - [ ] 10.1 After round completes (from either finalization prompt or manual finish), navigate away from the scoring view
  - [ ] 10.2 For now (Story 3.6 will add the summary card), simply dismiss the scorecard and return to the home screen's "Start Round" state
  - [ ] 10.3 Use a brief animation/transition so the completion feels intentional, not abrupt

- [ ] Task 11: Write RoundLifecycleManager tests in HyzerKitTests (AC: 1, 2, 3)
  - [ ] 11.1 Test: checkCompletion returns `.incomplete` when scores are missing
  - [ ] 11.2 Test: checkCompletion returns `.nowAwaitingFinalization` when all holes scored for all players
  - [ ] 11.3 Test: checkCompletion handles corrections correctly (superseded scores don't count as missing)
  - [ ] 11.4 Test: finishRound with force=false returns `.hasMissingScores` when incomplete
  - [ ] 11.5 Test: finishRound with force=true completes round even with missing scores
  - [ ] 11.6 Test: finalizeRound transitions awaitingFinalization → completed
  - [ ] 11.7 Test: validatePlayerMutation throws for active/awaitingFinalization/completed rounds
  - [ ] 11.8 Test: validatePlayerMutation succeeds for setup rounds
  - [ ] 11.9 Test: complete() sets completedAt timestamp
  - [ ] 11.10 Test: round state transitions enforce valid preconditions (e.g., cannot go active → setup)

- [ ] Task 12: Write ViewModel integration tests in HyzerAppTests (AC: 2, 3)
  - [ ] 12.1 Test: ScorecardViewModel triggers completion check after score entry
  - [ ] 12.2 Test: ScorecardViewModel sets isAwaitingFinalization flag when lifecycle manager reports completion
  - [ ] 12.3 Test: Score entry is rejected on completed rounds

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

### Debug Log References

### Completion Notes List

### File List
