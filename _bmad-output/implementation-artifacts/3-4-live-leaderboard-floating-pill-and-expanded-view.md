# Story 3.4: Live Leaderboard -- Floating Pill & Expanded View

Status: ready-for-dev

## Story

As a user,
I want to see live standings in a floating pill and expand to a full leaderboard,
So that I always know who's winning without leaving the scoring view.

## Acceptance Criteria

1. **AC 1 -- Real-time standings ranked by relative score to par:**
   Given an active round with at least one score entered,
   When the standings are computed,
   Then players are ranked by relative score to par (FR39),
   And partial round standings show holes-played count per player (FR43).

2. **AC 2 -- Persistent floating leaderboard pill:**
   Given the scoring view during an active round,
   When it is displayed,
   Then a persistent floating leaderboard pill overlays the top of the screen (FR40),
   And the pill shows condensed standings with position, name, and +/- par score,
   And the pill horizontally scrolls to keep the current user visible.

3. **AC 3 -- Expand pill to full standings:**
   Given the user taps the floating pill,
   When the expanded leaderboard appears,
   Then it presents as a modal sheet (not navigation push) with full standings (FR41),
   And the user can dismiss by swiping down, returning to the exact hole card.

4. **AC 4 -- Animated position changes on standings shift:**
   Given a new score changes the standings,
   When the StandingsEngine recomputes,
   Then the pill pulses briefly (scale 1.0 to 1.03, 0.3s) and position change arrows appear,
   And the expanded leaderboard (if open) animates rows to new positions with spring timing <500ms (FR42, NFR6),
   And all animations respect `accessibilityReduceMotion` (NFR15).

5. **AC 5 -- StandingsChange includes animation context:**
   Given `StandingsEngine.recompute(for:trigger:)` is called,
   When the trigger is `.localScore`,
   Then `StandingsChange` includes previous and new standings for animation differentiation.

## Tasks / Subtasks

- [ ] Task 1: Create `Standing` model in HyzerKit (AC: 1)
  - [ ] 1.1 Create `HyzerKit/Sources/HyzerKit/Domain/Standing.swift`
  - [ ] 1.2 Implement `Standing` struct: `Identifiable`, `Sendable`, `Equatable` with properties: `playerID: String`, `playerName: String`, `position: Int`, `totalStrokes: Int`, `holesPlayed: Int`, `scoreRelativeToPar: Int`
  - [ ] 1.3 `id` should be `playerID`

- [ ] Task 2: Create `StandingsChange` and `StandingsChangeTrigger` types in HyzerKit (AC: 5)
  - [ ] 2.1 Create `HyzerKit/Sources/HyzerKit/Domain/StandingsChangeTrigger.swift` -- enum with cases `.localScore`, `.remoteSync`, `.conflictResolution`
  - [ ] 2.2 Create `HyzerKit/Sources/HyzerKit/Domain/StandingsChange.swift` -- struct with `previousStandings: [Standing]`, `newStandings: [Standing]`, `trigger: StandingsChangeTrigger`, `positionChanges: [String: (from: Int, to: Int)]`
  - [ ] 2.3 Both types must be `Sendable`

- [ ] Task 3: Create `StandingsEngine` in HyzerKit (AC: 1, 5)
  - [ ] 3.1 Create `HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift`
  - [ ] 3.2 `@MainActor @Observable final class StandingsEngine` -- NOT an actor
  - [ ] 3.3 Init takes `modelContext: ModelContext`
  - [ ] 3.4 Implement `recompute(for roundID: UUID, trigger: StandingsChangeTrigger) -> StandingsChange`
  - [ ] 3.5 Fetch all ScoreEvents for the round, resolve leaf nodes via `supersedesEventID` chain (Amendment A7)
  - [ ] 3.6 Fetch Holes for the round's course to get par values
  - [ ] 3.7 Compute `scoreRelativeToPar` = totalStrokes - totalParForHolesPlayed
  - [ ] 3.8 Rank players: primary sort by `scoreRelativeToPar` ascending, secondary by `playerName` ascending (alphabetical tiebreak)
  - [ ] 3.9 Compute `positionChanges` by comparing previous vs new standings positions
  - [ ] 3.10 Store `currentStandings: [Standing]` as published observable property
  - [ ] 3.11 Store `latestChange: StandingsChange?` as published observable property for animation triggers
  - [ ] 3.12 Resolve player names: fetch `Player` by ID for registered players; use guest name directly for guest IDs (prefixed `"guest:"`)

- [ ] Task 4: Add `StandingsEngine` to `AppServices` (AC: 1)
  - [ ] 4.1 Add `let standingsEngine: StandingsEngine` property to `AppServices`
  - [ ] 4.2 Initialize with the domain store `modelContext`
  - [ ] 4.3 Wire `StandingsEngine` into `ScoringService` or call `recompute()` from ViewModel after score entry

- [ ] Task 5: Create `LeaderboardViewModel` (AC: 1, 2, 3, 4, 5)
  - [ ] 5.1 Create `HyzerApp/ViewModels/LeaderboardViewModel.swift`
  - [ ] 5.2 `@MainActor @Observable final class LeaderboardViewModel`
  - [ ] 5.3 Init takes `standingsEngine: StandingsEngine`, `roundID: UUID`, `currentPlayerID: String`
  - [ ] 5.4 Expose `currentStandings: [Standing]` (observed from engine)
  - [ ] 5.5 Expose `isExpanded: Bool` for sheet presentation
  - [ ] 5.6 Expose `showPulse: Bool` for pill pulse animation trigger
  - [ ] 5.7 Expose `positionChanges: [String: (from: Int, to: Int)]` for arrow indicators
  - [ ] 5.8 Implement `handleScoreEntered()` -- calls `standingsEngine.recompute(for:trigger:.localScore)`, triggers pulse, updates position changes
  - [ ] 5.9 Implement `currentPlayerStandingIndex: Int?` for auto-scroll to current user

- [ ] Task 6: Create `LeaderboardPillView` (AC: 2, 4)
  - [ ] 6.1 Create `HyzerApp/Views/Leaderboard/LeaderboardPillView.swift`
  - [ ] 6.2 `.ultraThinMaterial` background with `Color.backgroundElevated` overlay at reduced opacity
  - [ ] 6.3 32pt fixed height, `clipShape(Capsule())`
  - [ ] 6.4 Horizontal `ScrollView` with `ScrollViewReader` for auto-scroll to current player
  - [ ] 6.5 Each entry: position number + player name (truncated) + score relative to par with score-state color
  - [ ] 6.6 Score colors: `Color.scoreUnderPar` (green), `Color.scoreAtPar` (white), `Color.scoreOverPar` (amber)
  - [ ] 6.7 Tap gesture opens expanded view (`viewModel.isExpanded = true`)
  - [ ] 6.8 Pulse animation: `scaleEffect` 1.0 -> 1.03 -> 1.0 over 0.3s, triggered by `showPulse`
  - [ ] 6.9 All text uses `TypographyTokens.caption` with `@ScaledMetric`
  - [ ] 6.10 VoiceOver: `"Leaderboard: [leader name] leads at [score] par"` semantic label
  - [ ] 6.11 Respect `accessibilityReduceMotion` via `AnimationCoordinator`

- [ ] Task 7: Create `LeaderboardExpandedView` (AC: 3, 4)
  - [ ] 7.1 Create `HyzerApp/Views/Leaderboard/LeaderboardExpandedView.swift`
  - [ ] 7.2 Presented as `.sheet` modal (not navigation push)
  - [ ] 7.3 Header: "Leaderboard" + round progress ("Through X of Y holes")
  - [ ] 7.4 Full-width player rows: position, name, +/- par score, position change arrow (up/down)
  - [ ] 7.5 Row height >= 44pt (`SpacingTokens.minimumTouchTarget`)
  - [ ] 7.6 Dividers using `Color.backgroundTertiary`
  - [ ] 7.7 Position change arrows: show up/down briefly (fade in 0.2s, hold 1.5s, fade out 0.3s)
  - [ ] 7.8 Row position animated with `AnimationTokens.springGentle` (0.4s reshuffle)
  - [ ] 7.9 Vertical `ScrollView` for overflow
  - [ ] 7.10 Player names use `TypographyTokens.h3`, scores use `TypographyTokens.score`
  - [ ] 7.11 VoiceOver: full ranked list with position context per row
  - [ ] 7.12 Respect `accessibilityReduceMotion` via `AnimationCoordinator`

- [ ] Task 8: Integrate pill into `ScorecardContainerView` (AC: 2, 4)
  - [ ] 8.1 Create `LeaderboardViewModel` in `ScorecardContainerView.onAppear` alongside `ScorecardViewModel`
  - [ ] 8.2 Wrap existing content in `ZStack` with `LeaderboardPillView` overlaid at top
  - [ ] 8.3 Pill positioned with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` and top padding for safe area
  - [ ] 8.4 Add `.sheet(isPresented: $leaderboardViewModel.isExpanded)` for expanded view
  - [ ] 8.5 After each score entry (in `handleScoreEntered`), call `leaderboardViewModel.handleScoreEntered()`
  - [ ] 8.6 After each correction, also call `leaderboardViewModel.handleScoreEntered()` (corrections change standings too)

- [ ] Task 9: Add `AnimationTokens` for leaderboard (AC: 4)
  - [ ] 9.1 Add `leaderboardReshuffleDuration: TimeInterval = 0.4` to `AnimationTokens` (if not already present)
  - [ ] 9.2 Add `pillPulseDelay: TimeInterval = 0.2` to `AnimationTokens` (if not already present)
  - [ ] 9.3 Verify `springGentle` exists (should already exist from Story 3.2/3.3)

- [ ] Task 10: Write `StandingsEngine` tests in HyzerKitTests (AC: 1, 5)
  - [ ] 10.1 Create `HyzerKit/Tests/HyzerKitTests/Domain/StandingsEngineTests.swift`
  - [ ] 10.2 Test: single player single hole -- standings show correct relative-to-par score
  - [ ] 10.3 Test: multiple players ranked correctly (lower relative-to-par first)
  - [ ] 10.4 Test: alphabetical tiebreak when scores are equal
  - [ ] 10.5 Test: partial round -- `holesPlayed` reflects only holes with scores
  - [ ] 10.6 Test: supersession chain -- only leaf-node scores used (corrected scores ignored)
  - [ ] 10.7 Test: `StandingsChange.positionChanges` correctly detects position shifts
  - [ ] 10.8 Test: mixed registered + guest players resolve names correctly
  - [ ] 10.9 Test: trigger type is preserved in `StandingsChange`
  - [ ] 10.10 Use `ModelConfiguration(isStoredInMemoryOnly: true)` with all models registered

- [ ] Task 11: Write `LeaderboardViewModel` tests in HyzerAppTests (AC: 1, 2, 4, 5)
  - [ ] 11.1 Add tests in `HyzerAppTests/LeaderboardViewModelTests.swift`
  - [ ] 11.2 Test: `handleScoreEntered()` calls `standingsEngine.recompute` with `.localScore` trigger
  - [ ] 11.3 Test: `showPulse` becomes true after `handleScoreEntered()` and resets
  - [ ] 11.4 Test: `positionChanges` populated from `StandingsChange`
  - [ ] 11.5 Test: `currentPlayerStandingIndex` returns correct index for current player

## Dev Notes

### StandingsEngine Design (Architecture Spec)

`StandingsEngine` is the domain service that computes rankings from `ScoreEvent` data. It lives in HyzerKit (shared package) and is `@MainActor @Observable` -- NOT a Swift `actor`. This is explicit in the architecture: "Concurrency boundaries: SyncEngine as actor, StandingsEngine as @MainActor."

**Core computation algorithm:**
1. Fetch all `ScoreEvent` records for the given `roundID`
2. Group by `(playerID, holeNumber)` pairs
3. For each group, resolve the leaf node (event not superseded by any other event) using `supersedesEventID` chain -- reuse the same resolution algorithm from `resolveCurrentScore(for:hole:in:)` already extracted in Story 3.3 (`HoleCardView.swift`)
4. Sum `strokeCount` across all resolved leaf scores per player = `totalStrokes`
5. Count distinct hole numbers with scores per player = `holesPlayed`
6. Fetch par values for the course's holes; sum par for only the holes each player has scored = `totalParForHolesPlayed`
7. `scoreRelativeToPar = totalStrokes - totalParForHolesPlayed`
8. Sort: ascending by `scoreRelativeToPar`, then alphabetical by `playerName`
9. Assign `position` (1-based, handle ties with same position)

**Reuse existing `resolveCurrentScore` helper:** The free function `resolveCurrentScore(for:hole:in:)` was extracted to `HoleCardView.swift` in Story 3.3. For Story 3.4, this function should be moved to HyzerKit (e.g., `HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift`) so both `StandingsEngine` (HyzerKit) and `HoleCardView` (HyzerApp) can use it. The function signature:

```swift
public func resolveCurrentScore(for playerID: String, hole: Int, in events: [ScoreEvent]) -> ScoreEvent?
```

**Important:** The current implementation lives in `HoleCardView.swift` as a file-level function. Moving it to HyzerKit is required because `StandingsEngine` lives in HyzerKit and cannot import HyzerApp.

### Floating Pill Overlay Pattern

The pill overlays the scoring view using a `ZStack` in `ScorecardContainerView`:

```swift
ZStack(alignment: .top) {
    // Existing TabView with hole cards
    TabView(selection: $currentHole) { ... }

    // Floating pill overlay
    LeaderboardPillView(viewModel: leaderboardViewModel)
        .padding(.top, SpacingTokens.md) // Below safe area
        .padding(.horizontal, SpacingTokens.md)
}
.sheet(isPresented: $leaderboardViewModel.isExpanded) {
    LeaderboardExpandedView(viewModel: leaderboardViewModel)
}
```

### Score Display Format

Relative-to-par display format:
- Under par: `-2` (green, `Color.scoreUnderPar`)
- At par: `E` (white, `Color.scoreAtPar`) -- display "E" not "0"
- Over par: `+1` (amber, `Color.scoreOverPar`)

For the pill, each entry is compact: `"1. Jake -2"` with appropriate color on the score portion.

### Pill Pulse Animation

The pulse fires after a score changes standings:

```swift
// In LeaderboardPillView
.scaleEffect(showPulse ? 1.03 : 1.0)
.animation(
    AnimationCoordinator.animation(
        .easeInOut(duration: 0.3),
        reduceMotion: reduceMotion
    ),
    value: showPulse
)
```

The `LeaderboardViewModel` sets `showPulse = true` after `recompute()`, then resets it after a short delay so the animation triggers once per score entry.

### Position Change Arrows

Arrows appear temporarily when a player's position changes:

```swift
// In LeaderboardExpandedView row
if let change = positionChanges[standing.playerID] {
    if change.to < change.from {
        Text("▲").foregroundStyle(Color.scoreUnderPar) // Moved up
    } else if change.to > change.from {
        Text("▼").foregroundStyle(Color.scoreOverPar) // Moved down
    }
}
```

Arrows fade in (0.2s), hold (1.5s), fade out (0.3s) using a `Task.sleep` sequence in the ViewModel that clears `positionChanges` after 2 seconds total.

### Guest Player Handling

Round has both `playerIDs: [String]` (registered UUIDs) and `guestNames: [String]`. Guest player IDs follow the pattern `"guest:{name}"`. When resolving standings:
- Registered players: fetch `Player` by UUID, use `displayName`
- Guest players: detect `"guest:"` prefix, extract name portion

### Data Flow: Score Entry -> Standings Update

```
User enters score -> ScorecardViewModel.enterScore()
  -> ScoringService.createScoreEvent() inserts ScoreEvent
  -> ScorecardContainerView.handleScoreEntered()
  -> leaderboardViewModel.handleScoreEntered()
  -> standingsEngine.recompute(for: roundID, trigger: .localScore)
  -> StandingsEngine updates currentStandings + latestChange
  -> LeaderboardPillView re-renders (pulse triggers)
  -> LeaderboardExpandedView re-renders (if open, rows animate)
```

### Concurrency

- All code is `@MainActor` -- StandingsEngine, LeaderboardViewModel, views
- No actors, no `DispatchQueue`, no `nonisolated`
- `Task.sleep` only for pulse reset and arrow fade timers
- Swift 6 strict concurrency enforced (`SWIFT_STRICT_CONCURRENCY = complete`)
- All types crossing boundaries must be `Sendable`

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros, `#expect`) -- NOT XCTest.

**StandingsEngine tests (HyzerKitTests):**
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` with all models registered: `ScoreEvent`, `Player`, `Round`, `Course`, `Hole`
- Use existing fixture factories: `Player.fixture()`, `ScoreEvent` created directly
- Test leaf-node resolution via supersession chains
- Test edge cases: no scores yet, single player, all tied

**LeaderboardViewModel tests (HyzerAppTests):**
- Instantiate real `StandingsEngine` with in-memory store
- Test observation: `handleScoreEntered()` updates `currentStandings`
- Test `showPulse` lifecycle
- `Player.fixture()` is NOT available in HyzerAppTests -- use `Player(displayName:)` directly

### Current File State

| File | Current State | Story 3.4 Action |
|------|--------------|-------------------|
| `HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift` | Does not exist | **Create** -- core standings computation |
| `HyzerKit/Sources/HyzerKit/Domain/Standing.swift` | Does not exist | **Create** -- standings model |
| `HyzerKit/Sources/HyzerKit/Domain/StandingsChange.swift` | Does not exist | **Create** -- change result with animation context |
| `HyzerKit/Sources/HyzerKit/Domain/StandingsChangeTrigger.swift` | Does not exist | **Create** -- trigger enum |
| `HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift` | Does not exist | **Create** -- extract `resolveCurrentScore` from HoleCardView |
| `HyzerApp/Views/Scoring/HoleCardView.swift` | Contains `resolveCurrentScore` free function | **Modify** -- replace with `import` from HyzerKit |
| `HyzerApp/Views/Scoring/ScorecardContainerView.swift` | No leaderboard integration | **Modify** -- add ZStack overlay, create LeaderboardViewModel, wire recompute |
| `HyzerApp/ViewModels/LeaderboardViewModel.swift` | Does not exist | **Create** -- leaderboard state management |
| `HyzerApp/Views/Leaderboard/LeaderboardPillView.swift` | Does not exist | **Create** -- floating pill UI |
| `HyzerApp/Views/Leaderboard/LeaderboardExpandedView.swift` | Does not exist | **Create** -- modal expanded standings |
| `HyzerApp/App/AppServices.swift` | No StandingsEngine | **Modify** -- add StandingsEngine property |
| `HyzerKit/Sources/HyzerKit/Design/AnimationTokens.swift` | `springStiff`, `springGentle`, `scoreEntryDuration` | **Modify** -- add `leaderboardReshuffleDuration`, `pillPulseDelay` if missing |
| `HyzerKit/Tests/HyzerKitTests/Domain/StandingsEngineTests.swift` | Does not exist | **Create** -- standings computation tests |
| `HyzerAppTests/LeaderboardViewModelTests.swift` | Does not exist | **Create** -- ViewModel tests |

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Make StandingsEngine a Swift `actor` | Use `@MainActor @Observable final class` |
| Use timestamps for score resolution | Use supersession chain leaf-node (Amendment A7) via `resolveCurrentScore` |
| Hardcode colors, spacing, fonts, or durations | Use `ColorTokens`, `SpacingTokens`, `TypographyTokens`, `AnimationTokens` |
| Ignore `accessibilityReduceMotion` | Wrap ALL animations in `AnimationCoordinator.animation()` |
| Present expanded view as navigation push | Present as `.sheet` modal |
| Duplicate `resolveCurrentScore` logic | Extract to HyzerKit `ScoreResolution.swift` and import everywhere |
| Add RoundLifecycleManager / completion detection | Round lifecycle is Story 3.5 |
| Add round completion summary | Round completion is Story 3.6 |
| Add CloudKit sync triggers | Sync is Epic 4; only use `.localScore` trigger for now |
| Use `print()` for debugging | No console logging |
| Use `try?` for save operations | Always `try` and propagate errors |
| Add VoiceParser or voice confirmation | Voice is Epic 5 |
| Create per-player drill-down from leaderboard | Hole-by-hole breakdown is Story 8.2 |
| Use generic VoiceOver labels | Use domain-specific semantic labels: "Leaderboard", position context |
| Put `@Query` in ViewModels | `@Query` belongs in Views only; pass data to ViewModels |
| Show "0" for even par | Display "E" for even par |

### Previous Story Intelligence (Story 3.3)

Key learnings from Story 3.3 that directly apply:

1. **`resolveCurrentScore(for:hole:in:)` exists** as a free function in `HoleCardView.swift`. Move it to HyzerKit for reuse by StandingsEngine.
2. **`ScorecardContainerView` already has `allPlayersScored(for:)`** helper that uses score resolution. After extracting resolution to HyzerKit, update this too.
3. **AnimationCoordinator + reduce motion** pattern established: `AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion)`.
4. **Alert binding pattern:** `showingErrorBinding` computed property on ViewModels. Reuse for any leaderboard errors.
5. **Haptic generator stored property:** `UIImpactFeedbackGenerator` stored as `@State` property. Pill tap could use this for feedback.
6. **`#Predicate` needs `import Foundation`** and captured locals for UUID comparison.
7. **`Player.fixture()` NOT available in HyzerAppTests** -- use `Player(displayName:)` directly.
8. **All ViewModels are `@MainActor @Observable`** -- no exceptions.
9. **iOS 26 + SwiftData + AppGroup simulator issue:** HyzerKit unit tests via `swift test` pass; `xcodebuild test` may crash at simulator startup. Run `swift test --package-path HyzerKit` for reliable testing.
10. **`ScoringServiceError` is `Equatable`** for Swift Testing assertions.
11. **Auto-advance `Task.sleep` with cancellation** pattern: same pattern applies to pulse reset and arrow fade timers.

### XcodeGen and Project Structure

- New directories (`HyzerApp/Views/Leaderboard/`) are auto-discovered by `project.yml` glob patterns -- no `xcodegen generate` needed
- New files in `HyzerKit/Sources/HyzerKit/Domain/` are auto-discovered by `Package.swift` -- no manifest changes needed
- New test files in `HyzerKit/Tests/HyzerKitTests/Domain/` and `HyzerAppTests/` are auto-discovered
- No changes to `project.yml` or `Package.swift` required

### Scope Boundaries

**IN scope for Story 3.4:**
- `StandingsEngine` with `recompute(for:trigger:)` (FR39)
- `Standing` model with relative-to-par ranking (FR39)
- Partial round standings with `holesPlayed` count (FR43)
- `LeaderboardPillView` -- floating pill, `.ultraThinMaterial`, horizontal scroll (FR40)
- `LeaderboardExpandedView` -- modal sheet with full standings (FR41)
- Pill pulse animation on standings change
- Position change arrows (up/down) with fade timing (FR42)
- Row reshuffle animation in expanded view (FR42, NFR6)
- `accessibilityReduceMotion` compliance for all animations (NFR15)
- VoiceOver semantic labels (NFR17)
- Dynamic Type scaling (NFR16)
- Extract `resolveCurrentScore` to HyzerKit for shared use
- Wire standings recompute into score entry flow
- `StandingsChangeTrigger` enum (`.localScore` only used now; `.remoteSync` and `.conflictResolution` for future epics)

**OUT of scope (future stories):**
- Round lifecycle management (Story 3.5)
- Round completion summary with final standings (Story 3.6)
- CloudKit sync triggers for `.remoteSync` (Epic 4)
- Watch leaderboard display (Story 7.1)
- Voice scoring flow (Epic 5)
- Discrepancy resolution triggers (Epic 6)
- Player drill-down / hole-by-hole breakdown (Story 8.2)
- Running +/- on individual player rows in hole cards (not in any story spec)

### References

- [Source: _bmad-output/planning-artifacts/prd.md -- FR39: Real-time standings ranked by relative score to par]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR40: Persistent condensed leaderboard (floating pill)]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR41: Expand pill to full standings]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR42: Animated position changes on standings shift, <500ms (NFR6)]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR43: Partial round standings with holes-played count]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR3: Tap feedback <100ms]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR6: Leaderboard reshuffle <500ms]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR15: All animations respect accessibilityReduceMotion]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR16: Dynamic Type scaling up to AX3]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR17: Meaningful VoiceOver labels]
- [Source: _bmad-output/planning-artifacts/architecture.md -- StandingsEngine: @MainActor @Observable, recompute(for:trigger:) emitting StandingsChange]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Concurrency boundaries: StandingsEngine as @MainActor]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A7: Current score uses supersession chain leaf-node resolution]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Layer boundaries: HyzerKit for domain logic, HyzerApp for Views + ViewModels]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Floating pill: .ultraThinMaterial, 32pt height, horizontal scroll, pulse animation]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Expanded leaderboard: modal sheet, animated reshuffles, position change arrows]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Score colors: green (under), white (even), amber (over)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Card Stack + Floating Pill design direction]
- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 3 Story 3.4 scope and acceptance criteria]
- [Source: _bmad-output/implementation-artifacts/3-3-score-corrections-and-hole-navigation.md -- Previous story patterns, resolveCurrentScore extraction, AnimationCoordinator usage]

### Project Structure Notes

- New directory: `HyzerApp/Views/Leaderboard/` -- auto-discovered by XcodeGen glob patterns
- New files in existing directories: `HyzerKit/Sources/HyzerKit/Domain/` -- auto-discovered by Package.swift
- No `project.yml` changes needed
- No `Package.swift` changes needed
- No `xcodegen generate` needed

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
