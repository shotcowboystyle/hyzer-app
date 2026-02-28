# Story 3.6: Round Completion & Summary - Codebase Exploration Report

**Date:** 2026-02-28
**Status:** Complete exploration - Ready for implementation spec

## Executive Summary

The hyzer-app codebase is well-structured with clear separation of concerns across HyzerKit (domain/shared), HyzerApp (iOS views/viewmodels), and HyzerWatch (watch companion). Story 3.5 has been completed and provides the foundation for Story 3.6. The infrastructure is in place to build the Round Completion & Summary feature.

---

## 1. ROUND MODEL - Current State

**File:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-app/HyzerKit/Sources/HyzerKit/Models/Round.swift`

### Key Properties
- `id: UUID` — unique round identifier
- `courseID: UUID` — flat FK to Course (not @Relationship per Amendment A8)
- `organizerID: UUID` — player ID of round creator
- `playerIDs: [String]` — player UUIDs (stored as strings for CloudKit compatibility)
- `guestNames: [String]` — guest player round-scoped labels
- `status: String` — lifecycle state ("setup" | "active" | "awaitingFinalization" | "completed")
- `holeCount: Int` — denormalized from Course
- `createdAt: Date` — round creation timestamp
- `startedAt: Date?` — set when `start()` called
- **`completedAt: Date?`** — set when `complete()` called (NEW in Story 3.5)

### Status Helpers (Computed)
- `isSetup` — status == "setup"
- `isActive` — status == "active"
- `isAwaitingFinalization` — status == "awaitingFinalization"
- `isCompleted` — status == "completed"
- `isFinished` — isAwaitingFinalization || isCompleted

### Lifecycle Methods
- `start()` — "setup" → "active", sets `startedAt`
- `awaitFinalization()` — "active" → "awaitingFinalization" (auto-triggered when all holes scored)
- `complete()` — "active"/"awaitingFinalization" → "completed", sets `completedAt`

**IMPLICATION FOR 3.6:** The round has complete lifecycle state; we can query completed rounds and extract final timestamps.

---

## 2. SCORECARD CONTAINER VIEW - Current Post-Completion Behavior

**File:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-app/HyzerApp/Views/Scoring/ScorecardContainerView.swift`

### Current Completion Flow (Story 3.5 Implementation)
1. After all holes scored: `isAwaitingFinalization` flag set in ViewModel
2. Alert shown: "Finalize Round?" with confirm/keep-scoring buttons
3. User confirms → `finalizeRound()` called
4. Round transitions to "completed"
5. **Navigation:** HomeView's `@Query` filter excludes completed rounds, so ScoringTabView auto-shows "No round in progress" state
6. Post-completion happens via automatic SwiftData @Query updates, NOT explicit navigation

### Key Code Locations
- Lines 114-130: Finalization prompt alert
- Lines 220-246: `finishRoundTapped()` and `finishRoundForced()` for manual early finish
- Lines 250-258: `finalizeRoundConfirmed()` for confirmation flow
- **CRITICAL:** No explicit post-completion view shown yet; only returns to home

**IMPLICATION FOR 3.6:** We need to insert a Round Summary view BEFORE the automatic HomeView transition. Can be done via:
- Modal sheet presentation triggered when `isRoundCompleted` flag is set
- Dismiss sheet → HomeView naturally updates via @Query

---

## 3. SCORECARD VIEW MODEL - Lifecycle State Management

**File:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-app/HyzerApp/ViewModels/ScorecardViewModel.swift`

### Published State (Observable)
- `roundID: UUID` — the active round
- `reportedByPlayerID: UUID` — person entering scores
- `saveError: Error?` — scoring errors
- `isAwaitingFinalization: Bool` — all scores recorded, prompt pending
- `isRoundCompleted: Bool` — set after `finalizeRound()` or `finishRound(force:true)` succeeds

### Key Methods
- `enterScore(playerID:holeNumber:strokeCount:isRoundFinished:)` — creates ScoreEvent, calls `checkCompletionIfActive()`
- `correctScore(...)` — creates superseding ScoreEvent, calls `checkCompletionIfActive()`
- `finishRound(force:)` — delegates to lifecycle manager; returns `.hasMissingScores` or `.completed`
- `finalizeRound()` — delegates to lifecycle manager; sets `isRoundCompleted = true`
- `dismissFinalizationPrompt()` — resets `isAwaitingFinalization` flag

### Completion Detection
- `checkCompletionIfActive()` (line 109-120):
  - Only runs if `!isAwaitingFinalization` (avoids redundant checks)
  - Calls `lifecycleManager.checkCompletion(roundID:)`
  - If `.nowAwaitingFinalization`, sets `isAwaitingFinalization = true`
  - Errors are logged but not re-raised (safe to continue)

**IMPLICATION FOR 3.6:** `isRoundCompleted` flag can trigger summary view presentation. ViewModel is properly isolated from AppServices (dependency injection only).

---

## 4. APP SERVICES - Available Services

**File:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-app/HyzerApp/App/AppServices.swift`

### Wired Services
- `modelContainer: ModelContainer` — SwiftData container
- `scoringService: ScoringService` — score CRUD operations
- `standingsEngine: StandingsEngine` — live standings computation
- `roundLifecycleManager: RoundLifecycleManager` — round state transitions

### Initialization Pattern
- Single composition root, created once at app startup
- ViewModels receive individual services via constructor injection, NOT the container
- All services are `@MainActor` `@Observable`

**IMPLICATION FOR 3.6:** No new services needed; existing `StandingsEngine` can compute final standings for summary. Summary ViewModel should receive `StandingsEngine` via DI.

---

## 5. STANDINGS ENGINE - Data Source for Summary

**File:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-app/HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift`

### Public Interface
- `currentStandings: [Standing]` — most recent computed standings
- `latestChange: StandingsChange?` — animation context from last recompute
- `recompute(for roundID:, trigger:) -> StandingsChange` — synchronous fetch & compute

### Standing Data Structure (per player)
```swift
public struct Standing: Identifiable, Sendable, Equatable {
    let playerID: String                    // UUID string or "guest:{name}"
    let playerName: String
    let position: Int                       // 1-based ranking (ties share position)
    let totalStrokes: Int                   // sum of all leaf-node scores
    let holesPlayed: Int                    // count of distinct holes with scores
    let scoreRelativeToPar: Int             // totalStrokes - totalPar (negative = under)
}
```

### Standing Formatting Extensions (`Standing+Formatting.swift`)
- `formattedScore: String` — displays "-2", "E", "+1" etc.
- `scoreColor: Color` — returns scoreUnderPar (green), scoreAtPar (white), scoreOverPar (amber)

**IMPLICATION FOR 3.6:** Summary view can use `StandingsEngine.currentStandings` directly; no new computation needed. Standings are automatically finalized when round completes (last score enters → auto-advance → completion triggers).

---

## 6. HOME VIEW - Round Visibility & Query Patterns

**File:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-app/HyzerApp/Views/HomeView.swift`

### Structure
- 3-tab shell: Scoring, History (placeholder), Courses
- `ScoringTabView` within first tab

### Active Round Query (Line 32-35)
```swift
@Query(
    filter: #Predicate<Round> { $0.status == "active" || $0.status == "awaitingFinalization" },
    sort: \Round.startedAt
) private var activeRounds: [Round]
```

### Display Logic (Line 43-49)
- If `activeRounds.first` exists: show `ScorecardContainerView`
- Else: show "No round in progress" with "Start Round" button
- Transition animated with `.opacity` and `AnimationTokens.springGentle`

### Completed Rounds
- NOT included in query; removed automatically when round transitions to "completed"
- History tab (placeholder, Epic 8) will eventually list completed rounds

**IMPLICATION FOR 3.6:** When round completes:
1. Round status changes to "completed"
2. `@Query` automatically removes it from `activeRounds`
3. `ScorecardContainerView` is replaced by "No round in progress" state
4. Summary view must be presented BEFORE this transition; show sheet, then dismiss sheet → HomeView updates

---

## 7. DESIGN TOKENS - Visual Language for Summary

### ColorTokens (`ColorTokens.swift`)
```swift
// Backgrounds
.backgroundPrimary  // #0A0A0C (dark, 11px from black)
.backgroundElevated // #1C1C1E (card level)
.backgroundTertiary // #2C2C2E (separator level)

// Text
.textPrimary    // #F5F5F7 (high contrast white)
.textSecondary  // #8E8E93 (muted gray)

// Accent & States
.accentPrimary      // #30D5C8 (teal)
.scoreUnderPar      // #34C759 (green)
.scoreOverPar       // #FF9F0A (amber)
.scoreAtPar         // #F5F5F7 (white)
.scoreWayOver       // #FF453A (red)
```

### TypographyTokens (`TypographyTokens.swift`)
- **hero** (48pt, bold, rounded) — for major headlines
- **h1** (title, bold, rounded) — main section heads
- **h2** (title2, semibold, rounded) — subsection heads
- **h3** (headline, semibold, rounded) — card titles
- **body** (body, regular, rounded) — descriptive text
- **caption** (caption, regular, rounded) — secondary labels
- **score** (title2, bold, monospaced) — score numbers
- **scoreLarge** (title, bold, monospaced) — large score display

### SpacingTokens (`SpacingTokens.swift`)
- xs=4, sm=8, md=16, lg=24, xl=32, xxl=48 (8pt grid)
- `minimumTouchTarget` = 44pt
- `scoringTouchTarget` = 52pt

### AnimationTokens + AnimationCoordinator (`AnimationTokens.swift`, `AnimationCoordinator.swift`)
- `springStiff` — response: 0.3, dampingFraction: 0.7
- `springGentle` — response: 0.5, dampingFraction: 0.8
- `scoreEntryDuration` = 0.2s
- `leaderboardReshuffleDuration` = 0.4s
- **Coordinator pattern:** `AnimationCoordinator.animation(token, reduceMotion: flag)` auto-switches to instant on reduce-motion

### UX Spec: "Warm Off-Course Register"
From `ux-design-specification.md`:
> "Typography hierarchy that makes standings data feel urgent on-course (large, bold, high-contrast) and **warm off-course in history (medium weight, comfortable reading size)**."

**IMPLICATION FOR 3.6:** Summary card should use "warm" aesthetic:
- Medium-weight typography (h2, h3, body — not hero)
- Generous spacing (md, lg, xl tokens)
- Comfortable reading pace, not urgent
- Design for screenshot sharing (clean layout, good contrast)

---

## 8. HISTORY FOLDER & ROUND SUMMARY STATUS

**Current State:** No History folder or RoundSummary files exist.

### What Exists
- HomeView has `HistoryTabView` placeholder (lines 78-93)
- Placeholder shows: "Your round history will appear here after your first completed round."
- No queries, no data display — purely a stub for Epic 8

### What's Needed for Story 3.6
- **RoundSummaryView** — full-screen or modal view showing:
  - Course name
  - Date (from `round.completedAt`)
  - Final standings (from `StandingsEngine.currentStandings`)
  - +/- par for each player
  - Screenshot-optimized layout
- **RoundSummaryViewModel** — lightweight wrapper:
  - Receives `StandingsEngine` via DI
  - No complex state; just displays data
- **No new History querying needed** — Story 3.6 scope is post-completion summary, not history tab

**IMPLICATION FOR 3.6:** Create minimal RoundSummaryView in `HyzerApp/Views/Rounds/` (alongside RoundSetupView). History tab logic deferred to Epic 8.

---

## 9. ROUND LIFECYCLE MANAGER - Completion & Finalization Flow

**File:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-app/HyzerKit/Sources/HyzerKit/Domain/RoundLifecycleManager.swift`

### Public Methods (All @MainActor)

#### `checkCompletion(roundID:) -> CompletionCheckResult`
- Fetches round + all ScoreEvents for that round
- Counts (player, hole) pairs with no resolved leaf-node score
- If count == 0 AND round.isActive:
  - Calls `round.awaitFinalization()`
  - Saves to SwiftData
  - Returns `.nowAwaitingFinalization`
- Else: returns `.incomplete(missing: count)`

#### `finishRound(roundID:force:) -> FinishRoundResult`
- If `force == false` AND missing scores exist: returns `.hasMissingScores(count:)` without side effects
- If `force == true` OR no missing scores:
  - Calls `round.complete()`
  - Saves to SwiftData
  - Returns `.completed`
- Valid from "active" or "awaitingFinalization" states only

#### `finalizeRound(roundID:)`
- Valid from "awaitingFinalization" state only
- Calls `round.complete()`, sets `completedAt` timestamp
- Saves to SwiftData
- Used after user confirms "All scores recorded. Finalize?" prompt

### Error Handling
- Throws `RoundLifecycleError.roundNotFound` if round doesn't exist
- Throws `RoundLifecycleError.invalidStateForTransition` if preconditions violated
- Rethrows SwiftData persistence errors (never silently fails)

**IMPLICATION FOR 3.6:** All state transitions are already handled. Summary view is purely a presentation layer; no new business logic needed in RoundLifecycleManager.

---

## 10. LEADERBOARD PATTERNS - View Reference Models

### LeaderboardExpandedView (`Views/Leaderboard/LeaderboardExpandedView.swift`)
- Full-screen modal sheet showing standings
- Renders `viewModel.currentStandings` as scrollable list
- Each row displays: position, name, +/- score (formatted), position-change arrows
- Uses `AnimationTokens.springGentle` for position animations
- Touch target >= 44pt (minimum accessibility)

### LeaderboardPillView (`Views/Leaderboard/LeaderboardPillView.swift`)
- Floating capsule showing condensed standings
- Horizontal scroll, 32pt height, .ultraThinMaterial blur
- Pulses (1.03x scale) after standings change
- Taps open expanded view as sheet

### LeaderboardViewModel (`ViewModels/LeaderboardViewModel.swift`)
- Delegates `currentStandings` to `StandingsEngine.currentStandings`
- Tracks `isExpanded` (sheet presentation state)
- Tracks `positionChanges` for arrow animations (cleared after 2s)
- Method: `handleScoreEntered()` — recomputes standings, triggers pulse, clears arrows

**IMPLICATION FOR 3.6:** RoundSummaryView can follow similar pattern:
- Accept `StandingsEngine` via DI
- Display `currentStandings` as list (similar layout to LeaderboardExpandedView)
- Add course name and date header
- Optimize for screenshot aesthetics (warm register)

---

## 11. TESTING PATTERNS - Swift Testing Framework

**Framework:** Swift Testing (not XCTest)
- Syntax: `@Suite` (test class), `@Test` (test method)
- Async support: `@Test func foo() async throws`

### HyzerKit Tests Pattern (`HyzerKitTests/`)
- In-memory SwiftData: `ModelConfiguration(isStoredInMemoryOnly: true)`
- Fixtures: `Round.fixture()`, `Player.fixture()` in `Fixtures/` directory
- Service init: `ScoringService(modelContext:, deviceID:)`

### HyzerApp ViewModel Tests Pattern (`HyzerAppTests/`)
- Same ModelContext setup
- Create services and inject into ViewModel
- Test observable state changes with `#expect(vm.flag == expected)`
- Example: `ScorecardViewModelTests.swift` (lines 15-43 show setup pattern)

**IMPLICATION FOR 3.6:** 
- RoundSummaryViewModel tests: create context, StandingsEngine, init ViewModel, verify standings are read-only display
- No mutations needed; tests focus on view initialization and data binding

---

## KEY IMPLEMENTATION INSIGHTS

### 1. Navigation Architecture
- **No explicit navigation stack** for post-completion
- HomeView uses `@Query` to drive state changes
- When round.status changes to "completed", `@Query` filters it out
- Summary view must be modal sheet (presenting before transition) to avoid being dismissed

### 2. Data Flow for Summary
1. User confirms finalization (or force-finishes)
2. `ScorecardViewModel.isRoundCompleted` flag set to true
3. `ScorecardContainerView` observes flag change
4. Present `RoundSummaryView` as sheet
5. Sheet shows final standings from `StandingsEngine.currentStandings`
6. User dismisses sheet
7. HomeView @Query updates automatically (round no longer in active query)

### 3. Standings are Already Computed
- `StandingsEngine.recompute()` called after every score entry
- When last score lands, standings finalize
- No separate "finalize standings" step needed
- Summary just displays already-computed standings

### 4. Timing Consideration
- `RoundLifecycleManager.finalizeRound()` must be called BEFORE summary view presented
- This ensures `round.completedAt` is set for display
- Or: present summary AFTER manager call completes (async coordination)

### 5. Design Register
- Current leaderboard views (pill, expanded) are "on-course urgent" register (large, bold, high-contrast)
- Summary view should be "warm off-course" register per UX spec (medium weight, comfortable reading, generous spacing)
- Distinct visual treatment signals "moment has passed, now in reflection"

---

## FILES REQUIRING EXAMINATION FOR IMPLEMENTATION

### Models & Domain (HyzerKit)
- ✓ Round.swift — Lifecycle complete
- ✓ Standing.swift & Standing+Formatting.swift — Display ready
- ✓ StandingsEngine.swift — Data source ready
- ✓ RoundLifecycleManager.swift — State transitions complete
- ScoreEvent.swift, Player.swift, Course.swift, Hole.swift — All read-only for summary context

### Views (HyzerApp)
- ✓ ScorecardContainerView.swift — Knows when to trigger summary
- ✓ HomeView.swift — Auto-updates when round completes
- ✓ LeaderboardExpandedView.swift — Reference for summary list layout
- LeaderboardPillView.swift — Reference for compact display
- ContentView.swift — Root routing (no changes needed)

### ViewModels (HyzerApp)
- ✓ ScorecardViewModel.swift — `isRoundCompleted` flag available
- LeaderboardViewModel.swift — Reference for standings display pattern

### AppServices
- ✓ AppServices.swift — `StandingsEngine` already wired

### Tests
- ✓ ScorecardViewModelTests.swift — Test setup pattern
- ✓ RoundLifecycleManagerTests.swift — Lifecycle patterns

### Design System (HyzerKit)
- ✓ ColorTokens.swift — Color palette for summary
- ✓ TypographyTokens.swift — "Warm" typography choices
- ✓ SpacingTokens.swift — Generous spacing for comfort
- ✓ AnimationTokens.swift + AnimationCoordinator.swift — Optional entrance animations

---

## FILES TO CREATE FOR STORY 3.6

### Minimal (MVP) Implementation
1. **HyzerApp/Views/Rounds/RoundSummaryView.swift**
   - Modal view showing course name, date, final standings
   - Receives Round object (or roundID for querying)
   - Displays StandingsEngine.currentStandings
   - Screenshot-optimized layout
   - Dismiss button returns to home

2. **HyzerApp/ViewModels/RoundSummaryViewModel.swift**
   - Lightweight ViewModel wrapping data display
   - Receives StandingsEngine via DI
   - No complex state; read-only access to standings

3. **HyzerAppTests/RoundSummaryViewModelTests.swift**
   - Verify ViewModel initializes with standings
   - Verify standings data accessible and properly formatted

### Integration
- Modify ScorecardContainerView to present RoundSummaryView sheet when `isRoundCompleted == true`
- Add Round context to sheet so summary can display course name and date

---

## STORY 3.6 ACCEPTANCE CRITERIA MAPPING

### AC 1: "Summary displays course name, date, final standings"
- **Source:** Round.courseID, Round.completedAt
- **Data:** StandingsEngine.currentStandings (playerName, position, scoreRelativeToPar)
- **Implementation:** RoundSummaryView queries Course by ID, displays all fields

### AC 2: "Layout clean and screenshot-ready"
- **Design tokens:** Warm register typography (h2/h3/body), generous spacing
- **Reference:** LeaderboardExpandedView layout pattern
- **Consideration:** Remove toolbar items, focus on content area

### AC 3: "Dismiss → home screen shows no active round"
- **Current behavior:** Automatic via @Query
- **Implementation:** Modal sheet; dismiss allows HomeView to update naturally

---

## REMAINING UNKNOWNS / DEFERRED

1. **Round summary persistence** — Does summary card remain accessible from History tab? (Epic 8 scope)
2. **Watch companion summary** — Does Watch show completion summary? (Epic 7 scope)
3. **CloudKit sync of completion** — When does round completion sync to other devices? (Epic 4 scope)
4. **Screenshot sharing UX** — Any in-app share button or just standard iOS share? (Post-MVP polish)
5. **Hole-by-hole detail** — Does summary link to player detail views? (FR61, Epic 8 scope)

---

## RECOMMENDATIONS FOR IMPLEMENTATION SPEC

1. **Start minimal:** Just display the summary card on completion, then dismiss to home
2. **Reuse patterns:** Model on LeaderboardExpandedView for layout, Standing+Formatting for score display
3. **Warm aesthetic:** Use h2/h3/body typography, md/lg/xl spacing, calm color palette
4. **Async coordination:** Ensure RoundLifecycleManager.finalizeRound() completes before summary presented
5. **DI pattern:** RoundSummaryViewModel receives StandingsEngine; no AppServices container access
6. **Tests:** Basic initialization + standings display verification; no complex state transitions
7. **Navigation:** Use modal sheet + dismiss flow; don't fight SwiftUI's @Query-driven architecture
