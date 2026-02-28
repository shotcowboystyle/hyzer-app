# Story 3.6: Round Completion & Summary

Status: ready-for-dev

## Story

As a user,
I want to see a polished round summary with final standings when the round ends,
So that the round lands with satisfying closure and I can share the results.

## Acceptance Criteria

1. **AC 1 -- Round summary displayed on completion (FR58):**
   Given a round has been finalized (auto-detect or manual finish),
   When the round transitions to `"completed"`,
   Then a round summary view slides up displaying: course name, date, final standings with +/- par for all players.

2. **AC 2 -- Screenshot-ready layout with warm off-course register:**
   Given the round summary is displayed,
   When the user views it,
   Then the layout uses warm off-course typography (H1 course name, H2 player names, body metadata),
   And generous spacing (`SpacingTokens.lg` / `.xl`),
   And score-state colors (under/at/over par) on each player's score,
   And the design is optimized for screenshot readability (no interactive elements that require context).

3. **AC 3 -- Share functionality:**
   Given the round summary is displayed,
   When the user taps the Share button,
   Then the system share sheet opens with a screenshot-optimized rendering of the summary card.

4. **AC 4 -- Dismissal returns to home screen:**
   Given the user dismisses the round summary (drag-down or Done button),
   When they return to the home screen,
   Then no active round is shown (HomeView `@Query` already excludes `"completed"` rounds),
   And the completed round is accessible from the round list.

5. **AC 5 -- Accessibility:**
   Given VoiceOver is active,
   When the round summary is presented,
   Then VoiceOver reads: "Round complete at [course]. [Winner name] finished first at [score]. You finished [position] at [score]."

## Tasks / Subtasks

- [ ] Task 1: Create RoundSummaryViewModel in HyzerApp (AC: 1, 2, 3)
  - [ ] 1.1 Create `RoundSummaryViewModel` as `@MainActor @Observable` class in `HyzerApp/ViewModels/`
  - [ ] 1.2 Init receives: `round: Round`, `standings: [Standing]`, `courseName: String`, `holesPlayed: Int`, `coursePar: Int`
  - [ ] 1.3 Expose computed properties: `formattedDate` (from `round.completedAt ?? Date()`), `playerRows: [SummaryPlayerRow]` (position, name, formattedScore, totalStrokes, scoreColor, medal indicator for top 3)
  - [ ] 1.4 Expose `shareSnapshot()` method that renders the summary card to a `UIImage` using `ImageRenderer`

- [ ] Task 2: Create RoundSummaryView in HyzerApp (AC: 1, 2, 5)
  - [ ] 2.1 Create `RoundSummaryView.swift` in `HyzerApp/Views/Scoring/` (co-located with scorecard views; will be reused by Epic 8 History from here)
  - [ ] 2.2 Header: course name (`TypographyTokens.h1`, centered), date below (`TypographyTokens.caption`, `ColorTokens.textSecondary`)
  - [ ] 2.3 Standings list: for each player row -- position number with medal treatment for 1st/2nd/3rd (confident typography, no confetti), player name (`TypographyTokens.h2`), score +/- par (`TypographyTokens.score`, SF Mono, `Standing.scoreColor`), total strokes (`TypographyTokens.caption`, secondary)
  - [ ] 2.4 Divider using `ColorTokens.border`
  - [ ] 2.5 Metadata section: holes played count, organizer name (round creator)
  - [ ] 2.6 Share button: prominent, `ColorTokens.accent`, bottom of view
  - [ ] 2.7 Done/Dismiss button (toolbar or navigation bar)
  - [ ] 2.8 Use `SpacingTokens.lg` and `.xl` for generous warm-register spacing
  - [ ] 2.9 Accessibility: set `.accessibilityLabel` on the container with the scripted VoiceOver text

- [ ] Task 3: Create SummaryCardSnapshotView for screenshot rendering (AC: 3)
  - [ ] 3.1 Create a private `SummaryCardSnapshotView` inside `RoundSummaryView.swift` (not a separate file) -- a non-interactive version of the summary optimized for `ImageRenderer` output
  - [ ] 3.2 Fixed width (390pt -- iPhone logical width), no scroll, no buttons, explicit background color (`ColorTokens.backgroundPrimary`)
  - [ ] 3.3 In `RoundSummaryViewModel.shareSnapshot()`, use `ImageRenderer` to render `SummaryCardSnapshotView` to `UIImage`

- [ ] Task 4: Wire share sheet (AC: 3)
  - [ ] 4.1 In `RoundSummaryView`, add `.sheet` presentation of `ShareLink` or use `UIActivityViewController` wrapper
  - [ ] 4.2 Share item: the `UIImage` from `shareSnapshot()` plus text: "Round at [course] -- [winner] wins at [score]!"
  - [ ] 4.3 Use `@State var isShareSheetPresented` to control presentation

- [ ] Task 5: Integrate summary presentation into ScorecardContainerView (AC: 1, 4)
  - [ ] 5.1 In `ScorecardContainerView`, observe `ScorecardViewModel.isRoundCompleted`
  - [ ] 5.2 When `isRoundCompleted` becomes `true`, present `RoundSummaryView` as a `.fullScreenCover` (not `.sheet` -- prevents accidental drag-dismiss during the celebration moment; dismiss via explicit Done button)
  - [ ] 5.3 Pass data to `RoundSummaryViewModel`: the completed `Round`, current `StandingsEngine.currentStandings`, course name from the round's associated `Course`, holes played count, course par
  - [ ] 5.4 On dismiss of the full-screen cover, navigate back to home (the `@Query` in HomeView will automatically show "No round in progress" since the round status is now `"completed"`)
  - [ ] 5.5 Use `AnimationCoordinator.animation(.springGentle)` for the presentation transition

- [ ] Task 6: Handle early-finish (manual) summary path (AC: 1)
  - [ ] 6.1 When `ScorecardViewModel.finishRound()` returns `.completed`, set `isRoundCompleted = true` (same trigger as finalization path)
  - [ ] 6.2 For early-finish rounds, the standings will show "—" for unscored holes (already handled by `StandingsEngine` which uses `ScoreResolution` leaf-node resolution -- missing holes simply have no score)
  - [ ] 6.3 Verify the summary displays correctly with partial scores (holes played shows actual scored holes, not total course holes)

- [ ] Task 7: Write RoundSummaryViewModel tests in HyzerAppTests (AC: 1, 2, 3)
  - [ ] 7.1 Test: ViewModel initializes with round data and produces correct `playerRows` (sorted by position)
  - [ ] 7.2 Test: `formattedDate` uses `round.completedAt`
  - [ ] 7.3 Test: Medal indicators assigned only to positions 1, 2, 3
  - [ ] 7.4 Test: Score colors match `Standing.scoreColor` (under=green, at=white, over=amber)
  - [ ] 7.5 Test: `shareSnapshot()` produces non-nil `UIImage`
  - [ ] 7.6 Test: Handles tied positions correctly (same score = same position number)
  - [ ] 7.7 Test: Early-finish round with missing scores displays correctly

- [ ] Task 8: Write integration test for completion → summary flow (AC: 1, 4)
  - [ ] 8.1 Test: `ScorecardViewModel.isRoundCompleted` is `true` after `finalizeRound()` succeeds
  - [ ] 8.2 Test: `ScorecardViewModel.isRoundCompleted` is `true` after `finishRound()` with force=true succeeds
  - [ ] 8.3 Verify existing `ScorecardViewModelTests` still pass (no regressions)

## Dev Notes

### Architecture Decisions

**RoundSummaryView lives in `Views/Scoring/`, not `Views/History/`:**
The summary is presented as part of the scoring flow (immediately after completion). Epic 8 (History) will reuse this same view for detail drill-down. Keeping it in `Scoring/` matches the current navigation context. When Epic 8 implements `HistoryListView`, it will import `RoundSummaryView` directly -- no refactoring needed.

**RoundSummaryViewModel is a lightweight wrapper, not a service:**
All standings data is already computed by `StandingsEngine`. The ViewModel just transforms `[Standing]` into view-ready `SummaryPlayerRow` structs and handles the share snapshot. No SwiftData queries, no model mutations.

**`.fullScreenCover` instead of `.sheet`:**
The UX spec says "slides up as full-screen view." Using `.fullScreenCover` prevents accidental drag-dismiss during the celebratory moment. The user explicitly taps "Done" to dismiss, which feels more intentional and aligns with "the round is still warm" emotional design.

**`ImageRenderer` for screenshot sharing:**
Swift's native `ImageRenderer` (iOS 16+) renders SwiftUI views to `UIImage`. A dedicated `SummaryCardSnapshotView` (non-interactive, fixed width, explicit background) ensures the screenshot looks clean regardless of device. No third-party libraries needed.

**No new services or domain logic:**
This story is pure presentation. `StandingsEngine` already has final standings. `Round` already has `completedAt`. `RoundLifecycleManager` already handles state transitions. The only new code is Views and a ViewModel.

### Key Patterns to Follow

- **ViewModel DI pattern:** `RoundSummaryViewModel` receives data via init params (Round, standings, course info). It does NOT receive `AppServices` or any service container. `ScorecardContainerView` constructs it with data from its own context.
- **@MainActor:** `RoundSummaryViewModel` is `@MainActor @Observable` (same as all other ViewModels).
- **Design tokens only:** Use `ColorTokens`, `TypographyTokens`, `SpacingTokens`. Never hardcode colors, sizes, or spacing.
- **Reduce motion:** Wrap the `.fullScreenCover` transition in `AnimationCoordinator.animation()`.
- **Swift Testing:** Tests use `@Suite` / `@Test` macros, not XCTest.
- **Standing formatting reuse:** Use `Standing.formattedScore` and `Standing.scoreColor` from `Standing+Formatting.swift` -- do NOT recreate score formatting logic.

### Existing Code to Reuse (DO NOT Reinvent)

| What | Where | How to Use |
|------|-------|-----------|
| Final standings data | `StandingsEngine.currentStandings` | Pass `[Standing]` array to RoundSummaryViewModel |
| Score formatting | `Standing+Formatting.swift` | `standing.formattedScore` returns "-2", "E", "+1" |
| Score colors | `Standing+Formatting.swift` | `standing.scoreColor` returns the correct `Color` |
| Round completion state | `ScorecardViewModel.isRoundCompleted` | Already set to `true` after `finalizeRound()` and `finishRound(force: true)` |
| Animation coordination | `AnimationCoordinator.animation(_:)` | Wraps transitions for reduce-motion compliance |
| Typography tokens | `TypographyTokens.h1`, `.h2`, `.caption`, `.score` | Apply via `.font()` modifier |
| Color tokens | `ColorTokens.textPrimary`, `.textSecondary`, `.accent`, `.backgroundPrimary`, `.border` | Apply via `.foregroundStyle()` / `.background()` |
| Spacing tokens | `SpacingTokens.xs` through `.xxl` | Apply via `.padding()` |

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `RoundSummaryView.swift` | `HyzerApp/Views/Scoring/` | Round summary full-screen cover + `SummaryCardSnapshotView` (private) |
| `RoundSummaryViewModel.swift` | `HyzerApp/ViewModels/` | Transforms standings + round data into view-ready rows, handles share snapshot |
| `RoundSummaryViewModelTests.swift` | `HyzerAppTests/` | Unit tests for ViewModel logic |

### Files to Modify

| File | Changes |
|------|---------|
| `HyzerApp/Views/Scoring/ScorecardContainerView.swift` | Add `.fullScreenCover` presentation triggered by `isRoundCompleted`, construct `RoundSummaryViewModel`, handle dismiss → navigate home |
| `HyzerApp/ViewModels/ScorecardViewModel.swift` | May need minor adjustment to ensure `isRoundCompleted` stays `true` long enough for the summary presentation (verify current behavior) |

### What NOT to Build (Deferred)

- **History tab / HistoryListView** -- Epic 8 (Story 8.1)
- **Player hole-by-hole breakdown** -- Epic 8 (Story 8.2)
- **CloudKit sync of round completion** -- Epic 4
- **Push notifications for round complete** -- Phase 2 polish
- **Round duration tracking** -- not in current requirements; metadata section shows "holes played" and organizer only
- **Visual round signature** -- Phase 4 (social)
- **Watch notification of round completion** -- Epic 7

### Previous Story Intelligence

From Story 3.5 (Round Lifecycle & Player Immutability):
- `ScorecardViewModel` already has `isRoundCompleted: Bool` flag set after successful `finalizeRound()` and `finishRound(force: true)`.
- Post-completion navigation currently just lets the `@Query` in HomeView auto-remove the round. Story 3.6 inserts the summary view before that transition.
- `RoundStatus` constants are strings ("setup", "active", "awaitingFinalization", "completed") -- NOT a Swift enum. Use string comparisons.
- `Round.completedAt` is set by `complete()` method -- guaranteed non-nil for completed rounds.
- Bug fix from 3.5: `OperationalStore` with empty schema was removed. Don't re-add it.
- Bug fix from 3.5: `CourseEditorViewModel.saveCourse` range loops now guarded. No action needed.
- Finalization alert had an infinite re-presentation loop (H1 finding) -- fixed by decoupling `@State` from lifecycle flag. Follow the same decoupled pattern for the summary presentation: use a separate `@State var isShowingSummary` bridged from `isRoundCompleted` via `.onChange(of:)`.

### Project Structure Notes

- New views go in `HyzerApp/Views/Scoring/` (alongside `ScorecardContainerView.swift`, `HoleCardView.swift`, `ScoreInputView.swift`)
- New ViewModel goes in `HyzerApp/ViewModels/` (alongside `ScorecardViewModel.swift`, `LeaderboardViewModel.swift`)
- New tests go in `HyzerAppTests/` (alongside `ScorecardViewModelTests.swift`, `LeaderboardViewModelTests.swift`)
- No new packages, targets, or dependencies needed
- Test count baseline: 71 HyzerKit + 77 HyzerApp = 148 total

### Critical Anti-Patterns to Avoid

- **DO NOT** query SwiftData from `RoundSummaryViewModel` -- it receives pre-computed data
- **DO NOT** create a new `StandingsEngine` instance -- use the existing one from `AppServices` via `ScorecardContainerView`
- **DO NOT** use `DispatchQueue` -- use `@MainActor` and `async/await`
- **DO NOT** add `console.log` / `print()` statements in production code
- **DO NOT** create an enum for `RoundStatus` -- keep string pattern consistent
- **DO NOT** use `.sheet` for the summary -- use `.fullScreenCover` per UX spec ("slides up as full-screen view")
- **DO NOT** add animations to the static summary card content -- UX spec says "No animation. Designed for screenshot readability." Only the presentation transition animates.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.6] -- AC definitions, FR58
- [Source: _bmad-output/planning-artifacts/architecture.md] -- File structure (`Views/History/RoundSummaryView.swift` planned path, but `Views/Scoring/` is better for current nav context), `RoundSummaryViewModel` in ViewModels
- [Source: _bmad-output/planning-artifacts/prd.md#FR58] -- "The system displays a round summary with final standings upon round completion"
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Round Summary Card] -- Full anatomy: course name H1, date caption, standings rows with position/medal/name/score/strokes, metadata, share button, screenshot-first design, accessibility label
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 6] -- "Summary card is the ride home moment", share button prominent, screenshot-optimized
- [Source: _bmad-output/implementation-artifacts/3-5-round-lifecycle-and-player-immutability.md] -- `isRoundCompleted` flag, `completedAt` property, finalization alert decoupling pattern (H1 fix)
- [Source: CLAUDE.md] -- Layer boundaries, DI pattern, testing framework, concurrency rules, design tokens

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
