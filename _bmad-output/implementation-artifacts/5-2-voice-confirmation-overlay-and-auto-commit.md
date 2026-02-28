# Story 5.2: Voice Confirmation Overlay & Auto-Commit

Status: review

## Story

As a user,
I want to see what the system heard, verify it's correct, and have it commit automatically,
so that scoring is fast and hands-free in the common case.

## Acceptance Criteria

1. Given `VoiceParser` returns `.success` with all names resolved, when the confirmation overlay appears, then all parsed player-score pairs are displayed (e.g., "Mike .... 3, Jake .... 4, Sarah ... 2") (FR24), and a 1.5-second auto-commit timer begins (FR25).

2. Given the auto-commit timer is running, when the timer expires without user interaction, then all parsed scores are committed as ScoreEvents via `ScoringService` (FR25), and the overlay dismisses and the leaderboard pill updates.

3. Given the user taps an entry in the confirmation overlay, when the entry becomes editable, then an inline picker or number pad appears for correction (FR26), and the auto-commit timer resets to 1.5 seconds after each correction.

4. Given the user speaks scores for a subset of players (e.g., "Jake 4" only), when the overlay appears, then only the spoken player-score pairs are shown and committed (FR29), and unmentioned players remain unscored on the hole card.

5. Given VoiceOver is active, when the confirmation overlay appears, then all parsed scores are announced immediately, and an explicit "Commit Scores" button is present (visually de-emphasized) for VoiceOver users, and the auto-commit timer pauses when VoiceOver focus is on any overlay entry.

6. Given the voice-to-leaderboard pipeline completes (no corrections), when measured end-to-end from speech completion to leaderboard reshuffle, then the total time is under 3 seconds (NFR1).

## Tasks / Subtasks

- [x] Task 1: Create `VoiceRecognitionServiceProtocol` for testability (AC: 6)
  - [x] 1.1: Create `HyzerApp/Protocols/VoiceRecognitionServiceProtocol.swift` — `@MainActor protocol VoiceRecognitionServiceProtocol: AnyObject` with `func recognize() async throws -> String` and `func stopListening()`
  - [x] 1.2: Conform existing `VoiceRecognitionService` to `VoiceRecognitionServiceProtocol`
  - [x] 1.3: Add `stopListening()` method to `VoiceRecognitionService` — stops `audioEngine`, cancels `recognitionTask`

- [x] Task 2: Create `VoiceOverlayViewModel` (AC: 1, 2, 3, 4, 5, 6)
  - [x] 2.1: Create `HyzerApp/ViewModels/VoiceOverlayViewModel.swift` — `@MainActor @Observable final class`
  - [x] 2.2: Constructor injection: `voiceRecognitionService: any VoiceRecognitionServiceProtocol`, `scoringService: ScoringService`, `parser: VoiceParser`, `roundID: UUID`, `holeNumber: Int`, `reportedByPlayerID: UUID`, `players: [VoicePlayerEntry]`
  - [x] 2.3: Implement `startListening()` — calls `voiceRecognitionService.recognize()`, feeds transcript into `parser.parse()`, sets state to `.confirming`
  - [x] 2.4: Implement auto-commit timer — 1.5s countdown via `Task.sleep`, resets on correction, cancels on dismiss
  - [x] 2.5: Implement `correctScore(at index: Int, newStrokeCount: Int)` — updates the `ScoreCandidate` in the list, resets timer to 1.5s
  - [x] 2.6: Implement `commitScores()` — iterates `[ScoreCandidate]`, calls `scoringService.createScoreEvent()` for each, sets state to `.committed`
  - [x] 2.7: Implement `cancel()` — cancels timer, calls `stopListening()` if active, sets state to `.dismissed`
  - [x] 2.8: Implement VoiceOver timer pause — expose `isVoiceOverFocused: Bool` property, pause timer when `true`
  - [x] 2.9: State enum: `.idle`, `.listening`, `.confirming([ScoreCandidate])`, `.committed`, `.dismissed`, `.error(VoiceParseError)`

- [x] Task 3: Create `VoiceOverlayView` (AC: 1, 3, 4, 5)
  - [x] 3.1: Create `HyzerApp/Views/Scoring/VoiceOverlayView.swift` — translucent overlay (`.ultraThinMaterial`)
  - [x] 3.2: Title: "Scores heard" using `TypographyTokens.caption`, `Color.textSecondary`
  - [x] 3.3: Player-score rows — name (`TypographyTokens.h2`, `.textPrimary`), dotted leader, score (`TypographyTokens.scoreLarge`, SF Mono), 56pt row height, score color from par comparison
  - [x] 3.4: Auto-commit progress indicator — subtle linear progress bar or countdown ring, 1.5s duration, using `Color.accentPrimary`
  - [x] 3.5: "Tap to correct" hint text — `TypographyTokens.caption`, `Color.textSecondary`
  - [x] 3.6: Correction mode — tapped row expands inline number picker (1-10), same as `ScoreInputView` pattern
  - [x] 3.7: Explicit "Commit Scores" button for VoiceOver — visually de-emphasized (`textSecondary`), always present
  - [x] 3.8: Animations — slide up from bottom with `AnimationTokens.springStiff`, fade out on commit (0.2s), respect `accessibilityReduceMotion` via `AnimationCoordinator`
  - [x] 3.9: Listening state — waveform or pulsing mic indicator during active recording

- [x] Task 4: Integrate into `ScorecardContainerView` (AC: 1, 2, 4)
  - [x] 4.1: Add microphone button to hole card UI — triggers `VoiceOverlayViewModel.startListening()`
  - [x] 4.2: Present `VoiceOverlayView` as an overlay (not sheet/modal) on `ScorecardContainerView`
  - [x] 4.3: On `.committed` — trigger `StandingsEngine.recompute()` and leaderboard pill pulse animation
  - [x] 4.4: Add `@State private var voiceOverlayViewModel: VoiceOverlayViewModel?` — presence drives overlay visibility

- [x] Task 5: Wire `VoiceRecognitionService` into `AppServices` (AC: 6)
  - [x] 5.1: Add `let voiceRecognitionService: VoiceRecognitionService` to `AppServices`
  - [x] 5.2: Initialize in `AppServices.init()` — `self.voiceRecognitionService = VoiceRecognitionService()`
  - [x] 5.3: Pass to `VoiceOverlayViewModel` creation in `ScorecardContainerView`

- [x] Task 6: Write `VoiceOverlayViewModelTests` (AC: 1, 2, 3, 4, 5)
  - [x] 6.1: Create `HyzerAppTests/VoiceOverlayViewModelTests.swift` — `@MainActor @Suite`
  - [x] 6.2: Create `MockVoiceRecognitionService` implementing `VoiceRecognitionServiceProtocol` — configurable transcript return and error throwing
  - [x] 6.3: Test: `startListening` with successful transcript sets state to `.confirming` with correct `ScoreCandidate`s
  - [x] 6.4: Test: `commitScores` creates one ScoreEvent per candidate via `ScoringService`
  - [x] 6.5: Test: `correctScore` updates the candidate strokeCount and resets timer state
  - [x] 6.6: Test: `cancel` sets state to `.dismissed` and creates no ScoreEvents
  - [x] 6.7: Test: subset scoring — single player transcript only commits that player's score
  - [x] 6.8: Test: VoiceOver focus pauses timer (set `isVoiceOverFocused = true`, verify timer doesn't fire)
  - [x] 6.9: Test: recognition error sets state to `.error` with correct `VoiceParseError`

## Dev Notes

### Critical Architecture Constraints

**VoiceOverlayViewModel receives individual services — never AppServices:**
```swift
VoiceOverlayViewModel(
    voiceRecognitionService: appServices.voiceRecognitionService,
    scoringService: appServices.scoringService,
    parser: VoiceParser(),
    roundID: round.id,
    holeNumber: currentHole,
    reportedByPlayerID: reportedByPlayerID,
    players: voicePlayerEntries
)
```
This is created in `ScorecardContainerView` when the user taps the mic button.

**Concurrency boundaries:**

| Component | Isolation | Rationale |
|---|---|---|
| `VoiceOverlayViewModel` | `@MainActor` | Drives SwiftUI overlay state. |
| `VoiceRecognitionService` | `@MainActor` | iOS-only, interacts with AVAudioEngine/Speech. |
| `VoiceParser` | `nonisolated` | Stateless pure function. Instantiate inline. No `await`. |
| `ScoringService` | `@MainActor` (via caller) | Writes to main `ModelContext`. |

**Platform boundary — the cardinal rule:**
- `VoiceOverlayView` and `VoiceOverlayViewModel` live in `HyzerApp/` only.
- `VoiceParser` and result types are imported from `HyzerKit`.
- No `Speech` framework imports in HyzerKit.

### Score Entry — Reuse Existing ScoringService

`ScoringService.createScoreEvent()` is the single entry point for all score creation. Voice scoring calls the **same method** as tap scoring. Do NOT create a separate scoring path.

```swift
// For each ScoreCandidate in the confirmed list:
try scoringService.createScoreEvent(
    roundID: roundID,
    holeNumber: holeNumber,
    playerID: candidate.playerID,
    strokeCount: candidate.strokeCount,
    reportedByPlayerID: reportedByPlayerID
)
```

After all scores committed, trigger `StandingsEngine.recompute(for: roundID, trigger: .localScore)` — this is the same flow that `ScorecardViewModel.enterScore()` uses.

### Auto-Commit Timer Implementation

```swift
// In VoiceOverlayViewModel:
private var timerTask: Task<Void, Never>?

func startAutoCommitTimer() {
    timerTask?.cancel()
    timerTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        self?.commitScores()
    }
}
```

- Timer starts when state enters `.confirming`.
- Timer resets (cancel + restart) on every `correctScore()` call.
- Timer cancels on `cancel()` or `commitScores()`.
- Timer pauses when `isVoiceOverFocused` is `true` — implement by cancelling the timer task when focus enters, restarting when focus leaves (not by freezing `Task.sleep`).

### VoiceOver Accessibility Requirements

This is the most accessibility-critical transient screen. Required behaviors:

1. **Announce on appear:** VoiceOver reads: "Voice scores confirmed. [name] [score]. [name] [score]. Auto-saving in 1.5 seconds. Tap any score to correct."
2. **Explicit commit button:** "Commit Scores" button — always present, visually de-emphasized (`Color.textSecondary`, `TypographyTokens.caption`). VoiceOver users cannot rely on auto-commit timer while navigating.
3. **Pause timer during navigation:** When VoiceOver focus is on any overlay entry, cancel the timer task. When focus leaves all overlay entries, restart the timer. Use `.accessibilityFocused` binding.
4. **Score context:** Announce "[Player name], [score], [relation to par]" — never just the number. Use `.accessibilityElement(children: .combine)` on rows.
5. **Group related elements:** Player row (name + score) is one VoiceOver element, not separate ones.
6. **Decorative elements hidden:** Progress bar, dotted leaders, animations → `.accessibilityHidden(true)`.

### Voice Overlay UI Anatomy (from UX Spec)

```
┌──────────────────────────────────────┐
│  Scores heard           (caption)    │
│                                      │
│  Mike ................ 3  ← 56pt row │
│  Jake ................ 4  ← 56pt row │
│  Sarah ............... 2  ← 56pt row │
│                                      │
│  ████████░░░░░░░░ 1.5s   (progress)  │
│                                      │
│  Tap to correct     (hint, caption)  │
│  [Commit Scores]    (a11y button)    │
└──────────────────────────────────────┘
```

- Background: `.ultraThinMaterial` over the current hole card
- Score colors: `Color.scoreUnderPar` (birdie), `Color.scoreAtPar` (par), `Color.scoreOverPar` (bogey), `Color.scoreWayOver` (double+)
- Each row: 56pt height, `SpacingTokens.scoringTouchTarget` (52pt) minimum tap area
- Score font: `TypographyTokens.scoreLarge` (SF Mono, title size, bold)
- Name font: `TypographyTokens.h2` (SF Pro Rounded, semibold)
- Row needs par value from the current hole to compute score color

### Voice Overlay Animation Sequence

```
VoiceOverlayView appear (<500ms per NFR7)
  → withAnimation(AnimationCoordinator.animation(.springStiff, reduceMotion: reduceMotion))
  → Auto-commit countdown (1.5s)
  → VoiceOverlayView dismiss (opacity fade, 0.2s)
  → LeaderboardPillView pulse (after AnimationTokens.pillPulseDelay)
  → LeaderboardExpandedView reshuffle (concurrent spring)
```

Reduce-motion alternative: instant appear/disappear (no slide-in animation).

### Overlay Presentation Pattern

Present as a SwiftUI `.overlay()` on `ScorecardContainerView` — NOT as a sheet or fullScreenCover. The overlay sits on top of the hole card and dismisses in place.

```swift
// In ScorecardContainerView body:
.overlay {
    if let voiceVM = voiceOverlayViewModel {
        VoiceOverlayView(viewModel: voiceVM, par: currentHolePar)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

### Converting Player Query to VoicePlayerEntry

`ScorecardContainerView` already queries `allPlayers: [Player]` and builds `scorecardPlayers`. To create `[VoicePlayerEntry]` for the parser:

```swift
private var voicePlayerEntries: [VoicePlayerEntry] {
    allPlayers
        .filter { round.playerIDs.contains($0.id.uuidString) }
        .map { VoicePlayerEntry(playerID: $0.id.uuidString, displayName: $0.displayName, aliases: $0.aliases) }
}
```

Guest players cannot be voice-scored (no display name in the alias system). This is acceptable — guests are manual-tap only.

### VoiceRecognitionServiceProtocol — Testability

`VoiceRecognitionService` is currently a concrete class with no protocol. This story must create a protocol so `VoiceOverlayViewModel` can be tested with a mock:

```swift
// HyzerApp/Protocols/VoiceRecognitionServiceProtocol.swift
@MainActor
protocol VoiceRecognitionServiceProtocol: AnyObject {
    func recognize() async throws -> String
    func stopListening()
}
```

The protocol file goes in `HyzerApp/Protocols/` (create directory if needed). It stays in `HyzerApp/` because it references behavior specific to the iOS `Speech` framework — it does NOT go in HyzerKit.

### MockVoiceRecognitionService — Test Double

```swift
// HyzerAppTests/Mocks/MockVoiceRecognitionService.swift
@MainActor
final class MockVoiceRecognitionService: VoiceRecognitionServiceProtocol {
    var transcriptToReturn: String = ""
    var errorToThrow: VoiceParseError?
    var recognizeCallCount = 0

    func recognize() async throws -> String {
        recognizeCallCount += 1
        if let error = errorToThrow { throw error }
        return transcriptToReturn
    }

    func stopListening() {}
}
```

### Testing Standards

- **Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`) — NOT XCTest.
- **Naming:** `test_{method}_{scenario}_{expectedBehavior}`
- **Structure:** Given/When/Then comments.
- **Isolation:** `@MainActor` on the test suite (matching ViewModel isolation).
- **SwiftData:** `ModelConfiguration(isStoredInMemoryOnly: true)` for any `ScoringService` tests.
- **Timer testing:** Use `Task.sleep(for: .milliseconds(100))` after operations to allow async propagation. Timer behavior can be tested by checking state before and after the 1.5s window — use `Task.sleep(for: .seconds(2))` to verify auto-commit fired.
- **Pattern matching:** Use `if case .confirming(let candidates) = vm.state` for enum state assertions (matching 5.1 test patterns).

### Previous Story Intelligence (from 5.1)

**Patterns to follow:**
- `VoiceParser` is `nonisolated`, instantiate inline — don't inject it as a dependency requiring protocol. Just `let parser = VoiceParser()`.
- `VoicePlayerEntry` is the boundary type — build from `Player` model in the View layer, not in the ViewModel.
- `ScoreCandidate` is `Sendable` and `Equatable` — safe to store and compare in tests.
- `VoiceParseResult` enum uses `if case` pattern matching — not `Equatable` at the top level.

**Code review fixes from 5.1 to be aware of:**
- `VoiceRecognitionService.recognize()` has a `hasResumed` guard against double-resume. Do not modify this method.
- `[self]` capture (not `[weak self]`) in recognition callback is intentional — prevents async hang.

**Known tech debt:**
- `Task.sleep(for: .milliseconds(100))` in integration tests — acceptable pattern.
- `ValueCollector` test helper duplication — still deferred.

### What This Story Does NOT Include

- No `.partial` or `.failed` result UX — that is Story 5.3
- No discrepancy resolution — that is Story 6.1
- No Watch voice support — that is Epic 7
- Handle `.partial`/`.failed` from `VoiceParser` by setting `state = .error` — Story 5.3 will replace this with proper UX

### Files This Story Creates

**New files in HyzerApp/Views/Scoring/:**
- `VoiceOverlayView.swift`

**New files in HyzerApp/ViewModels/:**
- `VoiceOverlayViewModel.swift`

**New files in HyzerApp/Protocols/:**
- `VoiceRecognitionServiceProtocol.swift`

**New files in HyzerAppTests/:**
- `VoiceOverlayViewModelTests.swift`

**New files in HyzerAppTests/Mocks/:**
- `MockVoiceRecognitionService.swift`

**Modified files:**
- `HyzerApp/App/AppServices.swift` — add `voiceRecognitionService` property
- `HyzerApp/Services/VoiceRecognitionService.swift` — conform to protocol, add `stopListening()`
- `HyzerApp/Views/Scoring/ScorecardContainerView.swift` — add mic button, overlay presentation, `voiceOverlayViewModel` state

**NOT modified:**
- `HyzerKit/` — no changes needed (all voice types from 5.1 are sufficient)
- `project.yml` — no new capabilities or Info.plist keys needed
- `Package.swift` — no new dependencies

### Project Structure Notes

- `HyzerApp/Protocols/` directory may not exist — create it. XcodeGen auto-discovers new directories under `HyzerApp/`.
- `HyzerAppTests/Mocks/` directory may not exist — create it. XcodeGen auto-discovers.
- Run `xcodegen generate` after any `project.yml` changes (none expected for this story, but always verify).
- All views in `HyzerApp/Views/Scoring/` — `VoiceOverlayView` is a peer to `ScorecardContainerView`, `HoleCardView`, `ScoreInputView`.
- All ViewModels in `HyzerApp/ViewModels/` — flat directory, no subdirectories.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Voice Processing Architecture, Data Flow: Voice Scoring]
- [Source: _bmad-output/planning-artifacts/architecture.md — Voice Overlay Animation Sequence]
- [Source: _bmad-output/planning-artifacts/architecture.md — Voice Overlay VoiceOver Pattern]
- [Source: _bmad-output/planning-artifacts/architecture.md — Concurrency Patterns, actor isolation table]
- [Source: _bmad-output/planning-artifacts/architecture.md — Calling Conventions after ScoringService.createScoreEvent()]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5 Story 5.2 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 3: Scoring a Hole (Voice)]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Voice Confirmation Overlay component spec]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Feedback & Confirmation Patterns]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — VoiceOver Rules]
- [Source: _bmad-output/implementation-artifacts/5-1-voice-recognition-and-parser-pipeline.md — Dev Notes, Code Review Fixes]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Created `VoiceRecognitionServiceProtocol` in `HyzerApp/Protocols/` with `recognize()` and `stopListening()` methods; `VoiceRecognitionService` now conforms and exposes `stopListening()` publicly.
- `VoiceOverlayViewModel` is `@MainActor @Observable` with full state machine (idle → listening → confirming → committed/dismissed/error), 1.5s auto-commit timer via `Task.sleep`, VoiceOver timer-pause via `isVoiceOverFocused`, and `isTerminated`/`isCommitted` boolean flags for `Equatable` SwiftUI observation.
- `VoiceOverlayView` uses `.ultraThinMaterial`, dotted leader rows (56pt height), a `GeometryReader`-based linear progress bar, listening waveform state, inline `ScoreInputView` correction, and an explicit "Commit Scores" button for VoiceOver. Reduce-motion respects `AnimationCoordinator`.
- `ScorecardContainerView` now has a mic toolbar button (trailing, alongside the menu), `voiceOverlayContent` `@ViewBuilder` for the overlay, and `handleVoiceOverlayTerminated` method to avoid Swift type-checker complexity. Extracted `trailingToolbarContent` for the same reason.
- `AppServices` gets `voiceRecognitionService: VoiceRecognitionService` property and init line.
- 9 new `VoiceOverlayViewModelTests` written and passing; `MockVoiceRecognitionService` added in `HyzerAppTests/Mocks/`.
- Fixed pre-existing test failure in `ICloudIdentityResolutionTests` (missing `cloudKitClient`/`networkMonitor` args) with local stub conformances.
- All 97 HyzerApp tests pass; 166 HyzerKit tests continue passing; SwiftLint clean.

### File List

**New files:**
- `HyzerApp/Protocols/VoiceRecognitionServiceProtocol.swift`
- `HyzerApp/ViewModels/VoiceOverlayViewModel.swift`
- `HyzerApp/Views/Scoring/VoiceOverlayView.swift`
- `HyzerAppTests/VoiceOverlayViewModelTests.swift`
- `HyzerAppTests/Mocks/MockVoiceRecognitionService.swift`

**Modified files:**
- `HyzerApp/App/AppServices.swift`
- `HyzerApp/Services/VoiceRecognitionService.swift`
- `HyzerApp/Views/Scoring/ScorecardContainerView.swift`
- `HyzerAppTests/ICloudIdentityResolutionTests.swift` (pre-existing bug fix: missing stub args)
- `HyzerApp.xcodeproj/project.pbxproj` (regenerated by xcodegen for new directories)
