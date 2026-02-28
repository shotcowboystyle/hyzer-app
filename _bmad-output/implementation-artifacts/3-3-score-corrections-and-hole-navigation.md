# Story 3.3: Score Corrections & Hole Navigation

Status: done

## Story

As a user,
I want to correct a previously entered score and navigate to any hole,
So that mistakes can be fixed without disrupting the round.

## Acceptance Criteria

1. **AC 1 -- Tap scored row to reopen picker:**
   Given a player row already has a score,
   When the user taps the scored row,
   Then the picker reopens with the current score pre-selected (FR19).

2. **AC 2 -- Correction creates superseding ScoreEvent:**
   Given the user selects a new score value from the correction picker,
   When the correction is confirmed,
   Then a new ScoreEvent is created with `supersedesEventID` pointing to the previous event (FR37),
   And the previous ScoreEvent is never mutated or deleted (NFR19),
   And the display updates to show the new score using Amendment A7 leaf-node resolution.

3. **AC 3 -- Swipe back to previous holes:**
   Given the user is on any hole card,
   When they swipe right,
   Then the previous hole card is displayed for review or correction (FR38).

4. **AC 4 -- Auto-advance on hole completion:**
   Given all players have scores for the current hole,
   When the last score is entered,
   Then the card auto-advances to the next hole after a 0.5-1 second delay (FR20),
   And the user can swipe back to the previous hole to review or correct.

5. **AC 5 -- Correction on previous hole:**
   Given the user has swiped back to a previous hole,
   When they tap a scored player row,
   Then the picker reopens for correction (same flow as AC 1),
   And a new superseding ScoreEvent is created (same as AC 2).

6. **AC 6 -- No auto-advance on correction:**
   Given the user corrects a score on the current hole (all players were already scored),
   When the correction completes,
   Then no auto-advance occurs (auto-advance only fires when the last *missing* score is entered).

## Tasks / Subtasks

- [x] Task 1: Add `correctScore()` method to `ScoringService` (AC: 2)
  - [x] 1.1 Add `correctScore(previousEventID:roundID:holeNumber:playerID:strokeCount:reportedByPlayerID:) throws -> ScoreEvent`
  - [x] 1.2 Lookup previous event by ID, validate it exists in the context
  - [x] 1.3 Create new ScoreEvent with `supersedesEventID` set to `previousEventID`
  - [x] 1.4 Insert and save to modelContext; throw on failure (never `try?`)
  - [x] 1.5 Add `precondition` guards matching `createScoreEvent()` (strokeCount 1-10, holeNumber >= 1)

- [x] Task 2: Add `correctScore()` to `ScorecardViewModel` (AC: 1, 2, 5)
  - [x] 2.1 Add `correctScore(previousEventID:playerID:holeNumber:strokeCount:) throws`
  - [x] 2.2 Delegates to `ScoringService.correctScore()` passing roundID and reportedByPlayerID from init
  - [x] 2.3 Sets `saveError` on failure for alert binding

- [x] Task 3: Enable scored-row tap in `HoleCardView` (AC: 1, 5)
  - [x] 3.1 Remove `guard score == nil else { return }` from onTapGesture
  - [x] 3.2 When tapping a scored row: set `expandedPlayerID` to that player, pass current score as `preSelectedScore` to `ScoreInputView`
  - [x] 3.3 When tapping an unscored row: same as Story 3.2 behavior (no `preSelectedScore`)
  - [x] 3.4 Add `onCorrection: (String, UUID, Int) -> Void` callback -- (playerID, previousEventID, newStrokeCount)
  - [x] 3.5 Determine whether tap is initial score vs correction based on presence of resolved score

- [x] Task 4: Add pre-selection support to `ScoreInputView` (AC: 1)
  - [x] 4.1 Add optional `preSelectedScore: Int?` parameter
  - [x] 4.2 When `preSelectedScore` is non-nil, visually highlight that value (distinct from par highlight)
  - [x] 4.3 Scroll position anchors to `preSelectedScore` instead of par when correcting
  - [x] 4.4 If user selects the same score as current, collapse picker without creating a new event

- [x] Task 5: Wire correction callbacks in `ScorecardContainerView` (AC: 1, 2, 5)
  - [x] 5.1 Pass correction callback from ViewModel through to `HoleCardView`
  - [x] 5.2 HoleCardView determines previous event ID from resolved score and calls correction callback
  - [x] 5.3 Error handling: correction errors surface via same `saveError` alert binding

- [x] Task 6: Implement auto-advance logic in `ScorecardContainerView` (AC: 4, 6)
  - [x] 6.1 Add computed property: `allPlayersScored(for holeNumber: Int) -> Bool` checking if every player has a resolved score
  - [x] 6.2 After a score is entered (not corrected), check if all players are now scored for `currentHole`
  - [x] 6.3 If all scored AND `currentHole < round.holeCount`: schedule advance after 0.5-1s delay using `Task.sleep`
  - [x] 6.4 Cancel pending advance if user swipes manually before delay expires
  - [x] 6.5 Animate the advance using `AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion:)`
  - [x] 6.6 Do NOT auto-advance after corrections (AC 6) -- only after new initial scores

- [x] Task 7: Write `ScoringService` correction tests in HyzerKitTests (AC: 2)
  - [x] 7.1 Test: `correctScore` creates event with non-nil `supersedesEventID` matching previous event ID
  - [x] 7.2 Test: `correctScore` preserves original event (both exist in context after correction)
  - [x] 7.3 Test: `correctScore` validates previous event exists (throws if not found)
  - [x] 7.4 Test: `correctScore` sets correct roundID, holeNumber, playerID, strokeCount, reportedByPlayerID, deviceID
  - [x] 7.5 Test: multiple corrections chain correctly (A -> B -> C, only C is leaf)
  - [x] 7.6 Test: leaf-node resolution returns C (the latest correction) in a chain A -> B -> C

- [x] Task 8: Write `ScorecardViewModel` correction tests in HyzerAppTests (AC: 1, 2)
  - [x] 8.1 Test: `correctScore` creates superseding ScoreEvent via ScoringService
  - [x] 8.2 Test: `correctScore` passes correct roundID and reportedByPlayerID
  - [x] 8.3 Test: `correctScore` sets saveError on failure

- [x] Task 9: Write auto-advance unit tests (AC: 4, 6)
  - [x] 9.1 Test: auto-advance triggers when all players have scores on current hole (verify `currentHole` changes)
  - [x] 9.2 Test: auto-advance does NOT trigger when some players are unscored
  - [x] 9.3 Test: auto-advance does NOT trigger after a correction (all were already scored)
  - [x] 9.4 Test: auto-advance does NOT trigger on the last hole

## Dev Notes

### Score Correction Flow (Amendment A7)

The correction flow is the core addition for this story. It leverages the supersession chain already designed in Story 3.2:

1. User taps a **scored** player row on any hole card
2. `ScoreInputView` opens with the current score pre-selected (not par-anchored for corrections)
3. User selects a new score value
4. A new `ScoreEvent` is created with `supersedesEventID` pointing to the event being corrected
5. The old event remains in SwiftData (append-only, never deleted)
6. `HoleCardView.resolveCurrentScore()` (already implemented) finds the new leaf node automatically

**Key insight:** The leaf-node resolution in `HoleCardView` already handles supersession chains. For Story 3.2, every event was a leaf node. For Story 3.3, the resolution code works unchanged -- it finds the event that no other event points to via `supersedesEventID`.

Existing resolution code in `HoleCardView`:
```swift
private func resolveCurrentScore(playerID: String) -> ScoreEvent? {
    let playerScores = scores.filter { $0.playerID == playerID }
    let supersededIDs = Set(playerScores.compactMap(\.supersedesEventID))
    return playerScores.first { !supersededIDs.contains($0.id) }
}
```

This correctly resolves chains of any length: A -> B -> C returns C (the leaf).

### ScoringService Correction Method

Add a `correctScore()` method alongside the existing `createScoreEvent()`:

```swift
public func correctScore(
    previousEventID: UUID,
    roundID: UUID,
    holeNumber: Int,
    playerID: String,
    strokeCount: Int,
    reportedByPlayerID: UUID
) throws -> ScoreEvent {
    precondition((1...10).contains(strokeCount), "strokeCount must be 1-10")
    precondition(holeNumber >= 1, "holeNumber must be >= 1")

    // Validate the previous event exists
    let descriptor = FetchDescriptor<ScoreEvent>(predicate: #Predicate { $0.id == previousEventID })
    let results = try modelContext.fetch(descriptor)
    guard !results.isEmpty else {
        throw ScoringServiceError.previousEventNotFound(previousEventID)
    }

    let event = ScoreEvent(
        roundID: roundID,
        holeNumber: holeNumber,
        playerID: playerID,
        strokeCount: strokeCount,
        reportedByPlayerID: reportedByPlayerID,
        deviceID: deviceID
    )
    event.supersedesEventID = previousEventID
    modelContext.insert(event)
    try modelContext.save()
    return event
}
```

**Error type:** Add a `ScoringServiceError` enum for typed errors:
```swift
public enum ScoringServiceError: Error, Sendable {
    case previousEventNotFound(UUID)
}
```

**NOT modifying ScoreEvent init:** The `supersedesEventID` is set *after* construction via the public property. The ScoreEvent init always creates with `supersedesEventID = nil` (its default). This preserves the existing API for `createScoreEvent()` and is consistent with how SwiftData `@Model` properties work.

### HoleCardView Correction UX

Current state: scored rows have `guard score == nil else { return }` preventing taps. For Story 3.3:

1. **Remove the guard** -- scored rows become tappable
2. **Distinguish initial score vs correction:** Check if `resolveCurrentScore()` returns non-nil
   - If nil (unscored): call `onScore` callback (existing behavior)
   - If non-nil (scored): call `onCorrection` callback with `(playerID, previousEvent.id, newStrokeCount)`
3. **Pre-select current score in picker:** Pass resolved score's `strokeCount` to `ScoreInputView.preSelectedScore`
4. **Same-score selection:** If user selects the same score, collapse the picker without creating a new event (no-op correction)

Visual feedback for correctable rows:
- Scored rows retain their score-state color coding (under par, at par, over par)
- On tap, the inline picker opens identically to initial scoring
- The pre-selected score button has a distinct indicator (e.g., ring/outline) to show "this is the current value"

### ScoreInputView Pre-Selection

Add an optional `preSelectedScore: Int?` parameter:
- When nil (initial scoring): scroll anchors at par, par value highlighted with accent background (existing)
- When non-nil (correction): scroll anchors at `preSelectedScore`, that value has a distinct "current" indicator (e.g., a ring/border in `Color.textSecondary`)
- Par highlight remains visible in both modes (it's reference information)
- If user taps `preSelectedScore` (same value), fire a `onCancel` instead of `onSelect` -- the picker collapses without creating a correction event

### Auto-Advance Implementation

Auto-advance is the second major feature for this story. Implementation approach:

```swift
// In ScorecardContainerView
@State private var autoAdvanceTask: Task<Void, Never>?

private func handleScoreEntered(isCorrection: Bool) {
    // Only auto-advance for NEW scores, not corrections
    guard !isCorrection else { return }

    // Check if all players are scored for current hole
    guard allPlayersScored(for: currentHole) else { return }

    // Don't advance past the last hole
    guard currentHole < round.holeCount else { return }

    // Cancel any pending advance (e.g., if user is rapidly scoring)
    autoAdvanceTask?.cancel()

    autoAdvanceTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(750)) // 0.75s delay (midpoint of 0.5-1s spec)

        guard !Task.isCancelled else { return }

        withAnimation(AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion)) {
            currentHole += 1
        }
    }
}
```

**Cancel on manual swipe:** The `TabView` selection binding (`$currentHole`) changing manually (via swipe) should cancel any pending auto-advance. Use `.onChange(of: currentHole)` to cancel.

**allPlayersScored helper:**
```swift
private func allPlayersScored(for holeNumber: Int) -> Bool {
    let players = buildPlayerList()  // existing method
    return players.allSatisfy { player in
        resolveCurrentScore(playerID: player.id, holeNumber: holeNumber) != nil
    }
}
```

Note: The `resolveCurrentScore` logic currently lives in `HoleCardView`. For auto-advance, `ScorecardContainerView` needs the same logic. Options:
1. **Extract to a shared helper function** (recommended) -- create a free function or static method
2. Duplicate the logic (not recommended)

Recommend extracting to a utility on `ScorecardContainerView` or as a top-level function in the Scoring directory:
```swift
func resolveCurrentScore(for playerID: String, hole: Int, in events: [ScoreEvent]) -> ScoreEvent? {
    let holeEvents = events.filter { $0.playerID == playerID && $0.holeNumber == hole }
    let supersededIDs = Set(holeEvents.compactMap(\.supersedesEventID))
    return holeEvents.first { !supersededIDs.contains($0.id) }
}
```

### Swipe Navigation (FR38)

Swipe back to previous holes is already free with `TabView(.page)`. The user can swipe left/right to navigate between holes. No additional work needed for the basic gesture.

What this story adds:
- **Awareness that previous holes are correctable** -- scored rows on previous holes are tappable (same as current hole)
- **Auto-advance creates forward momentum** -- after all scores entered, card advances; swipe back is manual
- UX principle: "Auto-advance, manual-retreat" (from UX spec)

### Concurrency

- `ScorecardViewModel.correctScore()` is synchronous `throws` (same as `enterScore`)
- `ScoringService.correctScore()` is synchronous `throws` (same as `createScoreEvent`)
- Auto-advance uses `Task.sleep` for the delay -- this is the one async element
- `autoAdvanceTask` is `@State` on the View, cancelled on manual swipe
- All code stays `@MainActor` -- no actors, no `DispatchQueue`

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros, `#expect`) -- NOT XCTest.

**ScoringService correction tests (HyzerKitTests):**
- Tests live in `HyzerKit/Tests/HyzerKitTests/Domain/ScoringServiceTests.swift` -- extend existing suite
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` with all models registered
- Key assertion: after correction, BOTH original and new event exist; new event has `supersedesEventID` set
- Chain test: create A, correct to B, correct to C -- verify leaf resolution returns C

**ViewModel correction tests (HyzerAppTests):**
- Tests live in `HyzerAppTests/ScorecardViewModelTests.swift` -- extend existing suite
- Test `correctScore` delegates to ScoringService correctly
- Test error handling sets `saveError`

**Auto-advance tests:**
- Auto-advance is timing-dependent (delay). Test the logic, not the timing:
  - Test `allPlayersScored` returns correct boolean
  - Test that correction does NOT trigger advance logic
  - Test that scoring on last hole does NOT trigger advance
- Integration test for auto-advance behavior may be difficult without UI tests; focus on unit-testable logic

### Current File State

| File | Current State | Story 3.3 Action |
|------|--------------|-------------------|
| `HyzerKit/Sources/HyzerKit/Domain/ScoringService.swift` | `createScoreEvent()` only | **Modify** -- add `correctScore()` method and `ScoringServiceError` enum |
| `HyzerApp/ViewModels/ScorecardViewModel.swift` | `enterScore()` only | **Modify** -- add `correctScore()` method |
| `HyzerApp/Views/Scoring/HoleCardView.swift` | Scored rows disabled | **Modify** -- enable scored-row tap, add `onCorrection` callback, extract score resolution |
| `HyzerApp/Views/Scoring/ScoreInputView.swift` | Par-anchored only | **Modify** -- add `preSelectedScore` parameter, same-score cancel |
| `HyzerApp/Views/Scoring/ScorecardContainerView.swift` | No auto-advance | **Modify** -- add auto-advance logic, wire correction callbacks, extract score resolution helper |
| `HyzerKit/Tests/HyzerKitTests/Domain/ScoringServiceTests.swift` | 6 tests | **Modify** -- add correction tests (5-6 new tests) |
| `HyzerAppTests/ScorecardViewModelTests.swift` | 3 tests | **Modify** -- add correction + auto-advance tests (3-4 new tests) |

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Mutate or delete existing ScoreEvents | Create new event with `supersedesEventID` pointing to previous |
| Use timestamps for "current score" resolution | Use supersession chain leaf-node (Amendment A7) |
| Auto-advance after corrections | Only auto-advance after the last *missing* score is entered |
| Block on `Task.sleep` without cancellation support | Always check `Task.isCancelled` after sleep |
| Duplicate score resolution logic in multiple views | Extract to shared helper function |
| Add StandingsEngine or leaderboard logic | Standings are Story 3.4 |
| Add RoundLifecycleManager / completion detection | Round lifecycle is Story 3.5 |
| Use `try?` for save operations | Always `try` and propagate errors |
| Hardcode animation durations or styles | Use `AnimationTokens` and `AnimationCoordinator` |
| Use `print()` for debugging | No logging for this story |
| Make ScoringService an actor | Plain class; all callers are @MainActor |
| Create a `CardStackView.swift` | Architecture lists it but it's not needed -- `TabView(.page)` handles card stack |
| Add "Scored by [name]" attribution | Deferred to when sync makes it meaningful (Epic 4+) |

### Previous Story Intelligence (Story 3.2)

Key learnings from Story 3.2 that directly apply:

1. **Amendment A7 already implemented:** `HoleCardView.resolveCurrentScore()` works for chains. Don't rewrite it -- extract and reuse.
2. **Score color coding works with corrections:** The color is derived from strokeCount vs par. When a correction changes the score, the color updates automatically because it reads from the resolved (leaf) event.
3. **`guard score == nil` blocks corrections:** Story 3.2 review (finding H1) added this guard to prevent re-scoring. Story 3.3 must remove it and replace with correction flow.
4. **ScrollView in ScoreInputView:** Story 3.2 review (finding H2) wrapped picker in ScrollView. The `defaultScrollAnchor` can be adjusted for corrections to anchor at the current score.
5. **Alert binding pattern:** Story 3.2 review (finding M1) fixed alert binding with `showingErrorBinding` computed property. Reuse same pattern for correction errors.
6. **AnimationCoordinator + reduce motion:** Story 3.2 review (finding M2) established the pattern. Auto-advance must also use `AnimationCoordinator.animation()`.
7. **Preconditions:** Story 3.2 review (finding M3) added preconditions. `correctScore()` must have same guards.
8. **Haptic generator stored property:** Story 3.2 review (finding L1) moved haptic to stored property. Corrections should fire the same haptic.
9. **`#Predicate` needs `import Foundation`** and captured locals for predicates: `let id = previousEventID` before using in `#Predicate`.
10. **`Player.fixture()` NOT available in HyzerAppTests:** Use `Player(displayName:)` directly.
11. **All ViewModels are `@MainActor @Observable`** -- no exceptions.
12. **iOS 26 + SwiftData + AppGroup simulator issue:** Same caveat applies. HyzerKit unit tests pass; simulator tests may fail.

### Project Structure Notes

- No new files needed -- all changes are modifications to existing files
- No new directories needed
- `project.yml` and `Package.swift` auto-discover changes -- no updates needed
- No need to run `xcodegen generate` (no new directories)

### Scope Boundaries

**IN scope for Story 3.3:**
- Score correction via tap on scored row (FR19)
- Correction creates superseding ScoreEvent with `supersedesEventID` (FR37)
- Picker reopens with current score pre-selected
- Same-score tap cancels without creating event
- Auto-advance to next hole when all players scored (FR20)
- Auto-advance delay 0.5-1s
- Cancel auto-advance on manual swipe
- No auto-advance after corrections
- Swipe navigation to any previous hole (FR38 -- already works via TabView)
- Correction on previous holes (same flow as current hole)
- NFR19 compliance (append-only, no mutation/deletion)

**OUT of scope (future stories):**
- StandingsEngine / standings computation (Story 3.4)
- Floating leaderboard pill (Story 3.4)
- Running +/- par on player rows (Story 3.4)
- RoundLifecycleManager / auto-completion detection (Story 3.5)
- Round completion / summary (Story 3.6)
- Voice input / voice corrections (Epic 5)
- CloudKit sync (Epic 4)
- "Scored by [name]" attribution (deferred)
- "Tap to correct" hint text for first-time users (UX polish, can be added later)

### References

- [Source: _bmad-output/planning-artifacts/prd.md -- FR19: Tap previously scored row to correct]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR20: Auto-advance to next hole when all scored, swipe back to review/correct]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR37: Score correction creates new superseding ScoreEvent]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR38: Navigate to any previous hole to view or correct]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR19: Append-only event sourcing, no mutation/deletion]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A7: Current score uses supersession chain leaf-node resolution]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Type-Level Invariant Enforcement: ScoreEvent no update/delete API]
- [Source: _bmad-output/planning-artifacts/architecture.md -- ScoringService: ScoreEvent creation, validation, superseding]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Conflict detection using supersedesEventID]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Auto-advance to next hole after 0.5-1s delay when all scored]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Tap scoring flow: corrections reopen picker with current score]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Auto-advance, manual-retreat design principle]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Horizontal swipe for round navigation]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Hole card states: editing, previous hole (swiped back)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Card auto-advance swipe: standard TabView page transition, 0.4s]
- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 3 Story 3.3 scope and acceptance criteria]
- [Source: _bmad-output/implementation-artifacts/3-2-hole-card-tap-scoring-and-scoreevent-creation.md -- Previous story patterns, review findings, and learnings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `ScoringServiceError` required `Equatable` conformance for Swift Testing `#expect(throws:)` macro — added to enum declaration.
- SourceKit diagnostics for HyzerKit imports are false positives from the git worktree context; actual builds and tests pass cleanly.
- iOS 26 + SwiftData + AppGroup simulator issue (known from Story 3.2) causes `xcodebuild test` to crash at app startup. HyzerKit unit tests via `swift test` all pass. `xcodebuild build` succeeds without errors.

### Completion Notes List

- Implemented `ScoringServiceError` (Equatable, Sendable) and `correctScore()` in `ScoringService` — uses `#Predicate` with captured local for UUID comparison, precondition guards matching `createScoreEvent()`.
- Added `correctScore()` to `ScorecardViewModel` — delegates to service, propagates errors to caller.
- Extracted `resolveCurrentScore(for:hole:in:)` as a top-level function in `HoleCardView.swift` — shared by both `HoleCardView` and `ScorecardContainerView` (avoids duplication, per dev notes recommendation).
- Updated `HoleCardView` to remove the `guard score == nil` block; all rows are now tappable. Uses `@State private var correctionPreviousEventID: UUID?` to track correction vs initial entry mode. `onCorrection` callback added.
- Updated `ScoreInputView` with `preSelectedScore: Int?` — ring border overlay for current value, scroll anchor at pre-selected value for corrections, same-value tap fires `onCancel` without creating event.
- Updated `ScorecardContainerView` with auto-advance: `Task.sleep(for: .milliseconds(750))`, `autoAdvanceTask?.cancel()` on manual swipe via `.onChange(of: currentHole)`, correction path guarded with `isCorrection` flag.
- 41 HyzerKit tests pass (35 original + 6 new correction tests). Build succeeded. SwiftLint clean (runs as build script).
- All 9 story tasks and 35 subtasks completed.

### File List

- `HyzerKit/Sources/HyzerKit/Domain/ScoringService.swift` — added `ScoringServiceError` enum and `correctScore()` method
- `HyzerApp/ViewModels/ScorecardViewModel.swift` — added `correctScore()` method
- `HyzerApp/Views/Scoring/HoleCardView.swift` — extracted `resolveCurrentScore(for:hole:in:)` top-level helper, removed scored-row guard, added `onCorrection` callback, `correctionPreviousEventID` state, pre-selection passthrough
- `HyzerApp/Views/Scoring/ScoreInputView.swift` — added `preSelectedScore` parameter, ring indicator, scroll anchor, same-value cancel
- `HyzerApp/Views/Scoring/ScorecardContainerView.swift` — added `onCorrection` wiring, `correctScore()`, `handleScoreEntered()`, `allPlayersScored()`, auto-advance Task with cancel-on-swipe
- `HyzerKit/Tests/HyzerKitTests/Domain/ScoringServiceTests.swift` — added 6 correction tests (Tasks 7.1–7.6)
- `HyzerAppTests/ScorecardViewModelTests.swift` — added 3 correction tests (Tasks 8.1–8.3) and 4 auto-advance logic tests (Tasks 9.1–9.4)
