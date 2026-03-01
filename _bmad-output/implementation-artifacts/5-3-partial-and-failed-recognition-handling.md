# Story 5.3: Partial & Failed Recognition Handling

Status: done

## Story

As a user,
I want graceful handling when voice recognition doesn't fully work,
so that I can still score efficiently without starting over.

## Acceptance Criteria

1. Given `VoiceParser` returns `.partial` (some names resolved, others not), when the confirmation overlay appears, then resolved names display their scores normally, and unresolved entries are highlighted with "?" for manual correction (FR27), and the user can tap unresolved entries to select the correct player from a picker.

2. Given an unresolved entry is tapped, when the player picker appears, then all round players are shown and tapping one resolves the entry into a `ScoreCandidate`, and if all entries are now resolved the overlay transitions to `.confirming` and starts the 1.5-second auto-commit timer.

3. Given `VoiceParser` returns `.failed` (no names resolved), when the error state appears, then the user sees "Couldn't understand. Try again?" with retry and cancel options (FR28), and retry returns to listening mode, and cancel dismisses the overlay.

4. Given any voice recognition failure (partial or failed), when the user cancels or falls back, then no ScoreEvents are created, and the scoring view is in the same state as before voice input was activated.

5. Given `VoiceParser.partial` has an unresolved entry with a paired stroke count, when the user selects the correct player from the picker, then the resolved `ScoreCandidate` retains the parser's stroke count (not reset to par), allowing correction only if wrong.

## Tasks / Subtasks

- [x] Task 1: Add `UnresolvedCandidate` type to HyzerKit and update `VoiceParseResult.partial` (AC: 1, 5)
  - [x] 1.1: Add `public struct UnresolvedCandidate: Sendable` to `HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift` — fields: `spokenName: String`, `strokeCount: Int`
  - [x] 1.2: Update `VoiceParseResult.partial` associated value: `case partial(recognized: [ScoreCandidate], unresolved: [UnresolvedCandidate])`
  - [x] 1.3: Update `VoiceParser.parse()` — in the unresolved branch, append `UnresolvedCandidate(spokenName: nameToken, strokeCount: strokeCount)` instead of `unresolved.append(nameToken)`
  - [x] 1.4: Update `VoiceParserTests.swift` — update the `test_parse_unknownName_returnsPartial` test to use `unresolved[0].spokenName == "Zork"` instead of `unresolved.contains("Zork")`, and add a test asserting `unresolved[0].strokeCount == 5`

- [x] Task 2: Extend `VoiceOverlayViewModel` state machine (AC: 1, 2, 3, 4)
  - [x] 2.1: Add `.partial(recognized: [ScoreCandidate], unresolved: [UnresolvedCandidate])` case to `VoiceOverlayViewModel.State` enum
  - [x] 2.2: Add `.failed(transcript: String)` case to `VoiceOverlayViewModel.State` enum
  - [x] 2.3: Update `startListening()` `.partial` branch — set `state = .partial(recognized: recognized, unresolved: unresolved)` (remove the old placeholder that dropped unresolved entries and started the timer)
  - [x] 2.4: Update `startListening()` `.failed` branch — set `state = .failed(transcript: transcript)` WITHOUT setting `isTerminated = true` (removes the old `state = .error(.noSpeechDetected)` + `isTerminated = true`)
  - [x] 2.5: Expose round players for the picker — add `let availablePlayers: [VoicePlayerEntry]` as a private-set stored property, set from `players` in init: `self.availablePlayers = players`
  - [x] 2.6: Add `func resolveUnresolved(at index: Int, player: VoicePlayerEntry)` — guard `case .partial(var recognized, var unresolved) = state`, guard `unresolved.indices.contains(index)`, create `ScoreCandidate(playerID: player.playerID, displayName: player.displayName, strokeCount: unresolved[index].strokeCount)`, append to `recognized`, remove from `unresolved`. If `unresolved.isEmpty` → `state = .confirming(recognized)` and start auto-commit timer (if not VoiceOver focused). Otherwise → `state = .partial(recognized: recognized, unresolved: unresolved)`.
  - [x] 2.7: Add `func retry()` — cancels `timerTask`, calls `startListening()` (which resets state to `.listening` and begins new recognition)

- [x] Task 3: Update `VoiceOverlayView` for new states (AC: 1, 2, 3)
  - [x] 3.1: Add `.partial` case to the `switch viewModel.state` in `VoiceOverlayView.body` → call `partialView(recognized:unresolved:)`
  - [x] 3.2: Add `.failed` case to the `switch viewModel.state` → call `failedView`
  - [x] 3.3: Implement `partialView(recognized: [ScoreCandidate], unresolved: [UnresolvedCandidate])` — renders resolved rows identically to `confirmingView` player rows (same `playerScoreRow`), then renders unresolved rows with `unresolvedRow(entry:index:)`. No progress bar (timer not running). Footer: "Tap unresolved names to correct" (caption, textSecondary). Add "Cancel" button (plain style, textSecondary).
  - [x] 3.4: Implement `unresolvedRow(entry: UnresolvedCandidate, index: Int)` — same row layout as `playerScoreRow` but: spoken name in `textSecondary` (dimmed), score shows "?" in `Color.textSecondary`, row has a yellow/warning tint border or background, tap opens `playerPickerSheet` for that index
  - [x] 3.5: Implement player picker as a SwiftUI `.sheet` or `.confirmationDialog` — presents `viewModel.availablePlayers` as a list; selecting a player calls `viewModel.resolveUnresolved(at: unresolvedIndex!, player: player)` and dismisses the sheet. Use `@State private var unresolvedIndex: Int?` to track which row is tapped.
  - [x] 3.6: Implement `failedView` — `.ultraThinMaterial` overlay card with: title "Couldn't understand" (`TypographyTokens.h3`, `textPrimary`), subtitle "Try again?" (`TypographyTokens.body`, `textSecondary`), "Try Again" button (accentPrimary, filled style) calling `viewModel.retry()`, "Cancel" button (plain style, textSecondary) calling `viewModel.cancel()`. Minimum touch targets: `SpacingTokens.minimumTouchTarget` (44pt).
  - [x] 3.7: VoiceOver for partial state — on appear announce "Partial recognition. [count] scores confirmed, [count] unresolved. Tap the highlighted names to select the correct player." Unresolved rows: `accessibilityLabel("\(entry.spokenName), unresolved, score \(entry.strokeCount)")`, `accessibilityHint("Double-tap to pick the correct player")`.
  - [x] 3.8: VoiceOver for failed state — on appear announce "Couldn't understand. Double-tap Try Again to retry, or Cancel to return to scoring."

- [x] Task 4: Write `VoiceOverlayViewModelTests` additions (AC: 1, 2, 3, 4)
  - [x] 4.1: Test: `startListening_partialTranscript_setsPartialState` — mock returns "Zork 5 Jake 4" (Zork unknown, Jake known); after listen, state is `.partial` with 1 recognized (Jake 4) and 1 unresolved (spokenName: "Zork", strokeCount: 5)
  - [x] 4.2: Test: `resolveUnresolved_lastEntry_transitionsToConfirming` — from `.partial` with 1 unresolved, call `resolveUnresolved(at: 0, player: sarahEntry)`; state becomes `.confirming` with combined candidates; `timerResetCount` incremented
  - [x] 4.3: Test: `resolveUnresolved_notLast_remainsPartial` — from `.partial` with 2 unresolved, resolve index 0; state stays `.partial` with 1 remaining unresolved
  - [x] 4.4: Test: `resolveUnresolved_retainsStrokeCountFromParser` — resolved `ScoreCandidate.strokeCount` equals the `UnresolvedCandidate.strokeCount` (not 0 or par)
  - [x] 4.5: Test: `startListening_failedTranscript_setsFailedState` — mock returns "blah blah blah" (no players match); state is `.failed(transcript:)` and `isTerminated == false`
  - [x] 4.6: Test: `retry_fromFailedState_resetsToListeningAndRecognizes` — after `.failed`, call `retry()`; `mock.recognizeCallCount == 2`; state eventually `.confirming` on second attempt
  - [x] 4.7: Test: `cancel_fromPartialState_createsNoScoreEvents` — from `.partial` state, call `cancel()`; state is `.dismissed`, no ScoreEvents in context, `isTerminated == true`
  - [x] 4.8: Test: `cancel_fromFailedState_createsNoScoreEvents` — from `.failed` state, call `cancel()`; state is `.dismissed`, no ScoreEvents

## Dev Notes

### Critical Architecture Constraints

**Do NOT change these from 5.2:**
- `VoiceOverlayViewModel` is `@MainActor @Observable final class` — no change to isolation
- `VoiceParser` is `nonisolated` — no change. Instantiate inline in `VoiceOverlayViewModel`
- `VoiceOverlayView` is a SwiftUI struct receiving `@Bindable var viewModel: VoiceOverlayViewModel`
- Services are injected individually — never `AppServices` container
- Platform boundary: `VoiceOverlayView` and `VoiceOverlayViewModel` live in `HyzerApp/` only. `VoiceParser`, `VoiceParseResult`, `UnresolvedCandidate`, `ScoreCandidate` live in `HyzerKit/`

**Concurrency — unchanged from 5.2:**

| Component | Isolation | Rationale |
|---|---|---|
| `VoiceOverlayViewModel` | `@MainActor` | Drives SwiftUI overlay state |
| `VoiceParser` | `nonisolated` | Stateless pure function, no `await` |
| `ScoringService` | `@MainActor` (via caller) | Writes to main `ModelContext` |

### HyzerKit Changes Are Required

This story modifies HyzerKit (a local Swift Package), not just HyzerApp. Three files change:

1. **`HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift`** — add `UnresolvedCandidate` struct, update `.partial` associated value
2. **`HyzerKit/Sources/HyzerKit/Voice/VoiceParser.swift`** — update `parse()` to populate `UnresolvedCandidate`
3. **`HyzerKit/Tests/HyzerKitTests/Voice/VoiceParserTests.swift`** — update `.partial` pattern match

Run `swift test --package-path HyzerKit` after HyzerKit changes before touching HyzerApp.

**`UnresolvedCandidate` must be `Sendable`** (same as `ScoreCandidate`). Place it in `VoiceParseResult.swift` alongside `ScoreCandidate` — they are peer types.

### Breaking Change to `VoiceParseResult.partial`

The existing `VoiceOverlayViewModel.startListening()` has this placeholder (line 112–117):
```swift
case .partial(let recognized, _):
    // Story 5.3 will handle partial UX; for now, confirm what was recognised
    state = .confirming(recognized)
    if !isVoiceOverFocused {
        startAutoCommitTimer()
    }
```
**Story 5.3 replaces this entire branch** with:
```swift
case .partial(let recognized, let unresolved):
    state = .partial(recognized: recognized, unresolved: unresolved)
    // No timer — user must resolve all unresolved entries first
```

The `.failed` branch also changes (remove `state = .error(.noSpeechDetected)` + `isTerminated = true`):
```swift
case .failed(let transcript):
    state = .failed(transcript: transcript)
    // isTerminated stays false — retry is available
```

### Partial State — Key Design Decision

The `VoiceParseResult.partial` case exposes `unresolved: [UnresolvedCandidate]` where each entry has both the `spokenName` (what was heard) AND the `strokeCount` (the number paired with it in the transcript). This is critical: when the user resolves "Zork" to "Sarah", the resolved `ScoreCandidate` uses the stroke count from the parser pair — Sarah 5 — not some default. The user corrects only if wrong.

The `resolveUnresolved(at:player:)` method must build the `ScoreCandidate` as:
```swift
ScoreCandidate(
    playerID: player.playerID,
    displayName: player.displayName,
    strokeCount: unresolved[index].strokeCount  // Keep parser's stroke count
)
```

### Partial State — Auto-Commit Timer

The auto-commit timer does NOT start while in `.partial` state. It only starts when `resolveUnresolved` empties the unresolved list and transitions to `.confirming`. This preserves the "all entries confirmed" invariant for auto-commit. `isVoiceOverFocused` check still applies when starting the timer on resolution.

### Failed State — isTerminated Invariant

Current code sets `isTerminated = true` on `.failed` parse result. **This must change.** `ScorecardContainerView` uses `.onChange(of: viewModel.isTerminated)` to dismiss the overlay. If `isTerminated = true` fires on `.failed`, the overlay dismisses before the user can tap "Try Again".

The new contract:
- `isTerminated = true` only on: `.committed`, `.dismissed`, or `.error`
- `.failed` state keeps `isTerminated = false`
- Only `cancel()` sets `isTerminated = true` from `.failed` state

### Retry Flow

`retry()` calls `startListening()` which already sets `state = .listening`. No `isTerminated` cleanup needed because it was never set. The mock's `recognizeCallCount` increments on each call — tests verify this.

```swift
func retry() {
    timerTask?.cancel()
    timerTask = nil
    startListening()
}
```

### Partial State — Player Picker UI

The picker shows `viewModel.availablePlayers` — ALL players in the round (including already-resolved ones). Design rationale: the user might want to reassign a resolved player too (e.g., "Mike" was resolved to the wrong Mike). But for this story, the picker only covers resolving unresolved entries.

Recommended SwiftUI pattern: use a `.sheet(isPresented:)` controlled by `@State private var unresolvedIndex: Int?`:

```swift
.sheet(item: $unresolvedIndexBinding) { index in
    PlayerPickerSheet(
        players: viewModel.availablePlayers,
        onSelect: { player in
            viewModel.resolveUnresolved(at: index, player: player)
            unresolvedIndex = nil
        }
    )
}
```

Keep `PlayerPickerSheet` as a private inner view or separate file in `HyzerApp/Views/Scoring/`. It's a simple `List` of player names with `checkmark` accessory.

### VoiceOverlayView — Switch Statement

Current `body` switch:
```swift
switch viewModel.state {
case .listening: listeningView
case .confirming(let candidates): confirmingView(candidates: candidates)
default: EmptyView()
}
```

Updated (5.3 adds two cases — leave the default for `.idle`, `.committed`, `.dismissed`, `.error`):
```swift
switch viewModel.state {
case .listening: listeningView
case .confirming(let candidates): confirmingView(candidates: candidates)
case .partial(let recognized, let unresolved): partialView(recognized: recognized, unresolved: unresolved)
case .failed: failedView
default: EmptyView()
}
```

### Visual Design — Unresolved Row

Unresolved rows follow the same layout as resolved rows (56pt height, name + dotted leader + score), but with these differences:
- Name: `Color.textSecondary` (dimmed, not `.textPrimary`)
- Score: shows "?" string in `Color.textSecondary` (not the actual `strokeCount` — it's shown in the picker after selection)
- Row background: `Color.scoreOverPar.opacity(0.1)` for a subtle amber warning tint
- No score color logic needed (not displaying a number yet)

Do NOT use `Color.error` or red — this is an ambiguity state, not an error. Amber/warning is appropriate.

### No Changes Needed To

- `HyzerApp/App/AppServices.swift` — no new services required
- `HyzerApp/Services/VoiceRecognitionService.swift` — no changes
- `HyzerApp/Views/Scoring/ScorecardContainerView.swift` — the `.onChange(of: viewModel.isTerminated)` dismissal logic is already correct; fixing `isTerminated` behavior in ViewModel is sufficient
- `project.yml` — no new capabilities, directories, or Info.plist keys
- `Package.swift` — no new dependencies

### Testing Standards — Follow 5.2 Patterns

- **Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`) — NOT XCTest
- **Isolation:** `@MainActor` on test suite (matching ViewModel)
- **SwiftData:** `ModelConfiguration(isStoredInMemoryOnly: true)` for any tests touching `ScoringService`
- **Async propagation:** `try await Task.sleep(for: .milliseconds(100))` after `startListening()` before asserting state
- **State pattern matching:** `if case .partial(let recognized, let unresolved) = vm.state { ... }`
- **Retry test:** Check `mock.recognizeCallCount == 2` after `retry()` + sleep to verify second recognition fired
- **Timer tests for partial→confirming:** After `resolveUnresolved`, state is `.confirming` — do NOT sleep 1.5s; just check state synchronously (transition is synchronous)

The `makeVM` helper in `VoiceOverlayViewModelTests.swift` does NOT need to change — same signature, same players setup. Add new tests to the existing `@Suite`.

### Previous Story Intelligence (from 5.2 review)

From the **Code Review Fixes** section of 5.2:
- `nonisolated(unsafe)` pattern for `voiceRecognitionService` and `timerTask` in `deinit` — do not disturb this
- `announceScores()` helper uses `UIAccessibility.isVoiceOverRunning` check (not `@AccessibilityFocusState`) — follow same pattern for 5.3 accessibility announcements
- `timerResetCount` observable property triggers View progress bar reset — only relevant for `.confirming` state; no analog needed in `.partial` (no timer)

Known tech debt carried forward (do not address in this story):
- `Task.sleep(for: .milliseconds(100))` in tests — acceptable pattern
- `ValueCollector` test helper duplication — still deferred

### Project Structure Notes

- `UnresolvedCandidate` goes in `HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift` alongside `ScoreCandidate` and `Token` — these are peer types
- `PlayerPickerSheet` (if created as a separate file) goes in `HyzerApp/Views/Scoring/` alongside `VoiceOverlayView.swift` — or inline as a private extension
- No new directories needed — XcodeGen auto-discovers all existing directories
- Run `xcodegen generate` only if `project.yml` changes (none expected)

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5 Story 5.3 acceptance criteria (FR27, FR28)]
- [Source: _bmad-output/planning-artifacts/architecture.md — Voice data flow: `.partial` → `VoiceOverlayView` shows "did you mean...?", `.failed` → manual entry fallback]
- [Source: _bmad-output/planning-artifacts/architecture.md — Journey map J2: Voice Correction, `.partial` → player picker path]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Voice flow diagram, Partial branch: "Show resolved names + highlight unresolved with '?' → User taps to correct"]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Voice overlay states table: "Partial match" and "Error" states]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 3: Voice scoring, key decisions re partial recognition]
- [Source: _bmad-output/implementation-artifacts/5-2-voice-confirmation-overlay-and-auto-commit.md — Dev Notes: isTerminated invariant, auto-commit timer impl, Code Review Fixes (VoiceOver, timerResetCount, nonisolated pattern)]
- [Source: HyzerApp/ViewModels/VoiceOverlayViewModel.swift — lines 112-119: existing placeholder .partial/.failed handling to be replaced]
- [Source: HyzerKit/Sources/HyzerKit/Voice/VoiceParser.swift — parse() method, unresolved branch]
- [Source: HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift — VoiceParseResult enum, ScoreCandidate, Token]
- [Source: HyzerApp/Views/Scoring/VoiceOverlayView.swift — existing body switch, playerScoreRow pattern, DottedLeader component]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Task 1: Added `UnresolvedCandidate` struct to `VoiceParseResult.swift` alongside `ScoreCandidate`. Updated `VoiceParseResult.partial` associated value from `[String]` to `[UnresolvedCandidate]`. Updated `VoiceParser.parse()` to populate `UnresolvedCandidate(spokenName:strokeCount:)` in the unresolved branch. Updated `VoiceParserTests.swift` to use `unresolved[0].spokenName` and assert `strokeCount`. 166/166 HyzerKit tests pass.
- Task 2: Extended `VoiceOverlayViewModel.State` with `.partial` and `.failed` cases. Updated `startListening()` to route `.partial` → `.partial` state (no timer) and `.failed` → `.failed` state (isTerminated stays false). Added `availablePlayers` stored property. Added `resolveUnresolved(at:player:)` which transitions to `.confirming` + starts timer when last entry resolved. Added `retry()` which cancels timer and restarts listening.
- Task 3: Updated `VoiceOverlayView.body` switch with `.partial` and `.failed` cases. Implemented `partialView` (resolved rows + unresolved rows with "?" and amber tint, no progress bar, Cancel button). Implemented `unresolvedRow` (dimmed name, "?" score, amber background, sheet trigger). Implemented player picker via `sheet(item:)` with `IdentifiableIndex` wrapper and `PlayerPickerSheet` inner view. Implemented `failedView` ("Couldn't understand" / "Try again?" / Try Again + Cancel buttons with 44pt min touch targets). Added VoiceOver announcements for both states.
- Task 4: Added 8 new tests to `VoiceOverlayViewModelTests.swift` covering partial state detection, resolution flows (last/not-last), stroke count retention, failed state detection, retry flow, and cancel from both states. Fixed test `resolveUnresolved_retainsStrokeCountFromParser` to use "Zork 7 Jake 4" (needs ≥1 recognized player for .partial). Pre-existing flaky test `autoCommitTimer_firesAfterDelay_commitsScores` (from Story 5.2) is timing-sensitive — confirmed pre-existing, not introduced by this story.
- Code Review Fixes: (1) Added `Equatable` to `UnresolvedCandidate`. (2) Made recognized player rows non-interactive in partial view (added `interactive` param to `playerScoreRow`). (3) Added `pickablePlayers` computed property to filter already-recognized players from picker. (4) Added "Partial recognition" header to `partialView`. (5) Added `pickablePlayers_excludesAlreadyRecognizedPlayers` test. All 166 HyzerKit + 107 HyzerApp tests pass.

### File List

- `HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift` — added `UnresolvedCandidate` struct (Sendable + Equatable), updated `.partial` associated value
- `HyzerKit/Sources/HyzerKit/Voice/VoiceParser.swift` — updated `parse()` unresolved branch to use `UnresolvedCandidate`
- `HyzerKit/Tests/HyzerKitTests/Voice/VoiceParserTests.swift` — updated `.partial` pattern match assertions
- `HyzerApp/ViewModels/VoiceOverlayViewModel.swift` — added `.partial`/`.failed` state cases, `availablePlayers` property, `pickablePlayers` computed property, `resolveUnresolved(at:player:)`, `retry()`
- `HyzerApp/Views/Scoring/VoiceOverlayView.swift` — added `.partial`/`.failed` cases to body switch, `partialView` (with header, non-interactive recognized rows, pickablePlayers filter), `unresolvedRow`, `failedView`, `PlayerPickerSheet`, `IdentifiableIndex`, VoiceOver announce helpers
- `HyzerAppTests/VoiceOverlayViewModelTests.swift` — added 9 new tests (AC 1–4 coverage + pickablePlayers filter)

## Code Review Record

### Reviewer

claude-opus-4-6 (adversarial review via BMAD workflow)

### Date

2026-02-28

### Findings and Fixes

| # | Severity | Issue | Fix Applied |
|---|----------|-------|-------------|
| 1 | HIGH | `playerScoreRow` tap in `.partial` view sets stale `correctionIndex`; `correctScore()` silently no-ops in `.partial` state | Added `interactive` parameter to `playerScoreRow`; partial view passes `interactive: false` |
| 2 | HIGH | `UnresolvedCandidate` missing `Equatable` conformance (asymmetry with `ScoreCandidate`) | Added `Equatable` conformance |
| 3 | MEDIUM | Player picker shows all players including already-recognized ones, allowing duplicate ScoreEvent creation | Added `pickablePlayers` computed property filtering recognized IDs; sheet uses it |
| 4 | MEDIUM | No test for duplicate-player filtering | Added `pickablePlayers_excludesAlreadyRecognizedPlayers` test |
| 5 | MEDIUM | `partialView` missing header label (inconsistent with `confirmingView`) | Added "Partial recognition" caption header |

### Deferred (LOW, not fixed)

- `VoicePlayerEntry` missing `Equatable` (consistency improvement, no functional impact)
- `PlayerPickerSheet` missing toolbar dismiss button (swipe-to-dismiss works, VoiceOver improvement)
- `retry()` missing `.failed` state guard (only called from `failedView`, no current misuse risk)
