# Story 7.2: Crown Score Entry

Status: in-progress

## Story

As a Watch user,
I want to enter a score by rotating the Digital Crown,
so that I can score from my wrist without touching the screen.

## Acceptance Criteria

1. **Given** the Watch leaderboard is displayed, **When** the user taps a player name, **Then** the Crown input screen appears with a large centered number defaulting to par for the current hole (FR30, FR31), **And** the player name is displayed at top.

2. **Given** the Crown input screen is active, **When** the user rotates the Digital Crown, **Then** the score increments or decrements by 1 per detent, anchored at par (FR31), **And** a haptic tick fires within 50ms of each Crown detent (FR32, NFR4), **And** the large number updates in real time with score-state color (green under par, amber over par, white at par).

3. **Given** the user has selected a score, **When** they tap to confirm, **Then** the score is recorded with a strong haptic confirmation pulse (FR33, FR57), **And** the Watch returns to the leaderboard with updated standings.

4. **Given** the user wants to cancel, **When** they navigate back, **Then** no score is recorded and the leaderboard is unchanged (FR34).

5. **Given** the Crown score entry is confirmed, **When** the Watch processes the score, **Then** a `WatchScorePayload` is created and sent to the phone via `transferUserInfo` for guaranteed delivery (FR54, NFR12), **And** the phone creates a `ScoreEvent` via `ScoringService.createScoreEvent()`.

## Tasks / Subtasks

- [ ] Task 1: Add `currentHolePar` to `StandingsSnapshot` (AC: 1)
  - [ ] 1.1 Add `currentHolePar: Int` property to `StandingsSnapshot` in `HyzerKit/Sources/HyzerKit/Communication/StandingsSnapshot.swift` (default = 3)
  - [ ] 1.2 Update `PhoneConnectivityService.sendStandings(engine:)` to populate `currentHolePar` — add `activeHolePar: Int` property (set by scoring views alongside `activeHole`)
  - [ ] 1.3 Update existing `StandingsSnapshot` tests to include `currentHolePar` in fixtures
  - [ ] 1.4 Update existing `WatchCacheManager` tests if snapshot serialization changed

- [ ] Task 2: Create `WatchScoringViewModel` in HyzerKit (AC: 1, 2, 3, 4, 5)
  - [ ] 2.1 Create `WatchScoringViewModel` in `HyzerKit/Sources/HyzerKit/Communication/WatchScoringViewModel.swift` — `@MainActor @Observable public final class`
  - [ ] 2.2 Constructor: `init(playerName:, playerID:, holeNumber:, parValue:, roundID:, connectivityClient: any WatchConnectivityClient)`
  - [ ] 2.3 Expose `currentScore: Int` (starts at `parValue`), `playerName: String`, `holeNumber: Int`, `parValue: Int`
  - [ ] 2.4 Expose computed `scoreColor: Color` using `Standing.scoreColorForRelative(currentScore - parValue)` or inline logic matching `Standing+Formatting` pattern
  - [ ] 2.5 Expose computed `formattedScoreRelativeToPar: String` (e.g., "-1", "E", "+2")
  - [ ] 2.6 Implement `confirmScore()` — builds `WatchScorePayload` and calls `connectivityClient.transferUserInfo(.scoreEvent(payload))`, sets `isConfirmed = true`
  - [ ] 2.7 Score bounds: clamp `currentScore` to 1...15 range (1 = ace, 15 = extreme high)

- [ ] Task 3: Create `WatchScoringView` on watchOS (AC: 1, 2, 3, 4)
  - [ ] 3.1 Create `WatchScoringView` in `HyzerWatch/Views/WatchScoringView.swift`
  - [ ] 3.2 Layout: player name at top (`TypographyTokens.body`), large centered score number (`TypographyTokens.scoreLarge` or `TypographyTokens.hero`), hole info below, confirm button at bottom
  - [ ] 3.3 Bind `viewModel.currentScore` to `.digitalCrownRotation` — increment/decrement by 1 per detent
  - [ ] 3.4 Score number color: `viewModel.scoreColor` (green under, white at, amber over par)
  - [ ] 3.5 Haptic feedback: `WKInterfaceDevice.current().play(.click)` on each Crown detent (< 50ms latency via direct binding)
  - [ ] 3.6 Confirm button: calls `viewModel.confirmScore()`, plays `WKInterfaceDevice.current().play(.success)` strong haptic, dismisses view
  - [ ] 3.7 Cancel: standard watchOS back navigation via `@Environment(\.dismiss)` — no score recorded
  - [ ] 3.8 Use `AnimationCoordinator.animation()` for score color transition (respects reduce motion)
  - [ ] 3.9 Accessibility: score label announces "Score: [n], [relative to par text]" on Crown rotation

- [ ] Task 4: Wire navigation from `WatchLeaderboardView` (AC: 1)
  - [ ] 4.1 Add `NavigationStack` to `WatchLeaderboardView` if not present (or use `NavigationLink`/`.navigationDestination`)
  - [ ] 4.2 Make player rows tappable — navigate to `WatchScoringView` with ViewModel built from `snapshot.currentHolePar`, `snapshot.currentHole`, `snapshot.roundID`, and tapped `Standing.playerID`/`playerName`
  - [ ] 4.3 Pass `WatchConnectivityService` (as `WatchConnectivityClient`) to `WatchScoringViewModel` constructor

- [ ] Task 5: Wire phone-side `WatchScorePayload` → `ScoringService` (AC: 5)
  - [ ] 5.1 Add `scoringService: ScoringService` and `localPlayerID: UUID?` properties to `PhoneConnectivityService`
  - [ ] 5.2 Wire in `AppServices.init`: pass `scoringService` and resolve local player ID from `Player` table
  - [ ] 5.3 In `handleIncomingData`, for `.scoreEvent(let payload)`: call `scoringService.createScoreEvent(roundID: payload.roundID, holeNumber: payload.holeNumber, playerID: payload.playerID, strokeCount: payload.strokeCount, reportedByPlayerID: localPlayerID)`
  - [ ] 5.4 After score creation, trigger `standingsEngine.recompute()` so updated standings push back to Watch

- [ ] Task 6: Write tests (AC: 1, 2, 3, 4, 5)
  - [ ] 6.1 `WatchScoringViewModelTests` in `HyzerKit/Tests/HyzerKitTests/Communication/WatchScoringViewModelTests.swift`
  - [ ] 6.2 Test: initial score equals par value
  - [ ] 6.3 Test: score color changes correctly (under/at/over par)
  - [ ] 6.4 Test: `confirmScore()` calls `transferUserInfo` with correct `WatchScorePayload`
  - [ ] 6.5 Test: score clamped within valid range (1...15)
  - [ ] 6.6 Test: `formattedScoreRelativeToPar` returns correct strings ("E", "-1", "+2")
  - [ ] 6.7 Test: `isConfirmed` set to `true` after `confirmScore()`
  - [ ] 6.8 Update existing `StandingsSnapshot` tests for `currentHolePar` field
  - [ ] 6.9 Test: `WatchScorePayload` round-trip encode/decode (already exists in `WatchMessageTests` — verify coverage)

## Dev Notes

### Architecture Constraints

- **Phone is the sole CloudKit sync node.** Watch scores are sent to the phone via `transferUserInfo` (guaranteed delivery). The phone creates the `ScoreEvent` via `ScoringService`, which triggers sync to CloudKit. Watch NEVER writes directly to SwiftData or CloudKit.
- **Event sourcing invariant.** `ScoreEvent` is append-only and immutable. No UPDATE or DELETE. The phone creates the event — the Watch only sends the payload.
- **No SwiftData on Watch.** Watch has no `ModelContainer`. All data comes from `StandingsSnapshot` (JSON).
- **`WatchScoringViewModel` lives in HyzerKit** (not HyzerWatch). Same pattern as `WatchLeaderboardViewModel` — enables macOS-hosted unit tests without importing WatchConnectivity.
- **ViewModel receives individual services via constructor injection**, never the full container.

### Communication Pattern for Score Entry

```
Watch:
  User taps player on WatchLeaderboardView
    → WatchScoringView appears (Crown input, default = par)
    → User rotates Crown (haptic tick per detent)
    → User taps confirm (strong haptic pulse)
      → WatchScoringViewModel.confirmScore()
        → WatchConnectivityClient.transferUserInfo(.scoreEvent(WatchScorePayload))

Phone (PhoneConnectivityService receives):
  handleIncomingData → .scoreEvent(payload)
    → ScoringService.createScoreEvent(
        roundID: payload.roundID,
        holeNumber: payload.holeNumber,
        playerID: payload.playerID,
        strokeCount: payload.strokeCount,
        reportedByPlayerID: localPlayerID
      )
    → StandingsEngine.recompute() (triggered by ScoreEvent insertion)
    → PhoneConnectivityService auto-pushes updated standings → Watch
```

- `transferUserInfo`: Guaranteed delivery, queued if phone unreachable. Used for score events.
- `sendMessage`: Best-effort, instant. Used for standings pushes (story 7.1).

### Key Data Gap: `currentHolePar`

`StandingsSnapshot` currently lacks par info. The Watch needs `currentHolePar` to set the Crown's default value. Add `currentHolePar: Int` to `StandingsSnapshot`. On the phone side, `PhoneConnectivityService` needs an `activeHolePar: Int` property set by the scoring views alongside `activeHole`.

### Digital Crown Implementation

Use SwiftUI's `.digitalCrownRotation` modifier:

```swift
// Bind to a Double for smooth Crown tracking, round to Int for display
@State private var crownValue: Double = Double(viewModel.parValue)

.digitalCrownRotation(
    $crownValue,
    from: 1.0,
    through: 15.0,
    by: 1.0,
    sensitivity: .medium,
    isContinuous: false,
    isHapticFeedbackEnabled: true  // System haptic per detent (< 50ms, NFR4)
)
.onChange(of: crownValue) { _, newValue in
    viewModel.currentScore = Int(newValue.rounded())
}
```

- `isHapticFeedbackEnabled: true` provides system-level haptic ticks per detent — no manual `WKInterfaceDevice.play(.click)` needed. This is the simplest way to meet the < 50ms haptic requirement.
- `isContinuous: false` stops at bounds.
- `sensitivity: .medium` balances precision and speed.

### Haptic Feedback Patterns

| Action | Haptic | Implementation |
|--------|--------|----------------|
| Crown rotation | Tick per detent | `.digitalCrownRotation(isHapticFeedbackEnabled: true)` |
| Score confirmed | Strong pulse | `WKInterfaceDevice.current().play(.success)` |

### Score Color Coding

Reuse `Standing+Formatting.swift` pattern:
- `ColorTokens.scoreUnderPar` (green) — `currentScore < parValue`
- `ColorTokens.scoreAtPar` (white) — `currentScore == parValue`
- `ColorTokens.scoreOverPar` (amber) — `currentScore > parValue`

### Existing Code to Reuse

| Component | Location | Usage |
|-----------|----------|-------|
| `Standing` | `HyzerKit/.../Domain/Standing.swift` | Player data from leaderboard tap |
| `Standing+Formatting` | `HyzerKit/.../Domain/Standing+Formatting.swift` | `scoreColor`, `formattedScore` pattern |
| `WatchScorePayload` | `HyzerKit/.../Communication/WatchMessage.swift` | Already defined — `roundID`, `playerID`, `holeNumber`, `strokeCount`, `timestamp` |
| `WatchConnectivityClient` | `HyzerKit/.../Communication/WatchConnectivityClient.swift` | Protocol — `transferUserInfo(_:)` for guaranteed delivery |
| `WatchStandingsObservable` | `HyzerKit/.../Communication/WatchStandingsObservable.swift` | Read snapshot for hole/round context |
| `ScoringService` | `HyzerKit/.../Domain/ScoringService.swift` | Phone-side `createScoreEvent()` |
| `StandingsSnapshot` | `HyzerKit/.../Communication/StandingsSnapshot.swift` | Has `roundID`, `currentHole` — needs `currentHolePar` |
| `WatchCacheManager` | `HyzerKit/.../Communication/WatchCacheManager.swift` | JSON persistence (no changes needed) |
| `PhoneConnectivityService` | `HyzerApp/Services/PhoneConnectivityService.swift` | Wire `.scoreEvent` handling (lines 133-135) |
| `ColorTokens` | `HyzerKit/.../Design/ColorTokens.swift` | Score colors |
| `TypographyTokens` | `HyzerKit/.../Design/TypographyTokens.swift` | `score`, `scoreLarge`, `hero`, `body`, `caption` |
| `SpacingTokens` | `HyzerKit/.../Design/SpacingTokens.swift` | Layout padding |
| `AnimationTokens` | `HyzerKit/.../Design/AnimationTokens.swift` | `scoreEntryDuration` (0.2s) |
| `AnimationCoordinator` | `HyzerKit/.../Design/AnimationCoordinator.swift` | Reduce-motion aware animation |

### New Files to Create

**HyzerKit (shared):**
- `HyzerKit/Sources/HyzerKit/Communication/WatchScoringViewModel.swift`

**HyzerWatch (watchOS):**
- `HyzerWatch/Views/WatchScoringView.swift`

**Tests:**
- `HyzerKit/Tests/HyzerKitTests/Communication/WatchScoringViewModelTests.swift`

### Existing Files to Modify

- `HyzerKit/Sources/HyzerKit/Communication/StandingsSnapshot.swift` — Add `currentHolePar: Int` property
- `HyzerApp/Services/PhoneConnectivityService.swift` — Add `activeHolePar`, `scoringService`, `localPlayerID`; wire `.scoreEvent` handling (lines 133-136)
- `HyzerApp/App/AppServices.swift` — Pass `scoringService` to `PhoneConnectivityService`, resolve `localPlayerID`
- `HyzerWatch/Views/WatchLeaderboardView.swift` — Add navigation to `WatchScoringView` on player tap
- `HyzerWatch/App/HyzerWatchApp.swift` — Pass `WatchConnectivityService` to `WatchScoringView` for DI (if NavigationStack wiring requires it)

### Testing Strategy

- **HyzerKit domain tests** (`swift test --package-path HyzerKit`): `WatchScoringViewModel` logic — initial score, color, confirm sends payload, bounds clamping, formatting.
- **Mock `WatchConnectivityClient`**: Create a test double that records `transferUserInfo` calls and their payloads.
- **No simulator needed** for HyzerKit tests. Watch app build verification via `xcodebuild build` only.
- Use **Swift Testing** (`@Suite`, `@Test`) — NOT XCTest.
- Existing `WatchMessageTests` already cover `WatchScorePayload` encode/decode — verify, don't duplicate.

### Performance Requirements

| Metric | Target | Implementation |
|--------|--------|----------------|
| Crown haptic latency | < 50ms | `.digitalCrownRotation(isHapticFeedbackEnabled: true)` — system-level |
| Score delivery | Guaranteed | `transferUserInfo` (queued, survives app termination) |
| Crown to confirm | 2 interactions | Tap player + rotate + tap confirm |
| UI responsiveness | Instant | `@Observable` drives SwiftUI updates, no async in Crown path |

### Concurrency

- `WatchScoringViewModel`: `@MainActor @Observable` — all state is main-actor-isolated.
- `confirmScore()` is synchronous — `transferUserInfo` enqueues and returns immediately.
- On the phone side, `handleIncomingData` runs on `@MainActor` (forwarded from delegate callback). `ScoringService.createScoreEvent()` is synchronous (same actor).

### Previous Story (7.1) Learnings

- **ViewModel in HyzerKit, not Watch target.** `WatchLeaderboardViewModel` lives in HyzerKit to enable macOS unit tests. Apply same pattern to `WatchScoringViewModel`.
- **Separate NSObject delegate.** `@Observable` doesn't support NSObject subclasses. WCSession delegate is a separate `SessionDelegate` class.
- **`withObservationTracking` for auto-push.** Phone uses recursive observation (no Combine) to auto-push standings. Story 7.2 needs standings to re-push after phone processes Watch score.
- **`Standing` has `Codable`.** Added in 7.1 — available for serialization.
- **200 HyzerKit tests pass.** Do not regress.

### Project Structure Notes

- New HyzerKit files go in `HyzerKit/Sources/HyzerKit/Communication/` — same directory as story 7.1 communication code.
- New Watch views go in `HyzerWatch/Views/` — auto-discovered by `project.yml` (`sources: [HyzerWatch]`).
- No `project.yml` changes needed for new files.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Watch Communication Flow, Crown Scoring FR30-FR34, NFR4]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 7, Story 7.2]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Watch Scoring, Crown Interaction]
- [Source: _bmad-output/implementation-artifacts/7-1-watch-app-shell-and-leaderboard-display.md — Previous Story]
- [Source: HyzerKit/Sources/HyzerKit/Communication/WatchMessage.swift — WatchScorePayload definition]
- [Source: HyzerKit/Sources/HyzerKit/Domain/ScoringService.swift — createScoreEvent API]
- [Source: HyzerApp/Services/PhoneConnectivityService.swift — scoreEvent wiring point (lines 133-135)]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
