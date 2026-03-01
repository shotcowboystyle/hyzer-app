# Story 7.1: Watch App Shell & Leaderboard Display

Status: ready-for-dev

## Story

As a Watch user,
I want to see live standings on my wrist during a round,
so that I can track the competition without pulling out my phone.

## Acceptance Criteria

1. **Given** a round is active on the paired phone, **When** the Watch app launches, **Then** a purpose-built leaderboard displays current standings with position, player name, and +/- par score (FR53), **And** each player gets a full-width row with no horizontal scrolling.

2. **Given** the phone sends a standings update via `WatchConnectivity`, **When** the Watch receives the message, **Then** the leaderboard updates with the new standings (FR56), **And** standings reshuffles animate to match the phone's competitive moment.

3. **Given** the phone is unreachable, **When** the Watch app loads, **Then** the leaderboard displays the last known standings from the app group JSON cache, **And** a stale indicator shows relative time since last update (e.g., "2m ago") when `lastUpdatedAt` exceeds 30 seconds.

4. **Given** the phone sends standings, **When** the delivery method is chosen, **Then** `sendMessage` is used for instant delivery when both apps are active, **And** `WatchCacheManager` writes to app group JSON as a persistent fallback.

## Tasks / Subtasks

- [ ] Task 1: Create `WatchConnectivityClient` protocol in HyzerKit (AC: 2, 4)
  - [ ] 1.1 Define `WatchConnectivityClient` protocol in `HyzerKit/Sources/HyzerKit/Communication/WatchConnectivityClient.swift`
  - [ ] 1.2 Define `WatchMessage` enum (Sendable, Codable) with `.standingsUpdate(StandingsSnapshot)` and `.scoreEvent(WatchScorePayload)` cases in `HyzerKit/Sources/HyzerKit/Communication/WatchMessage.swift`
  - [ ] 1.3 Define `StandingsSnapshot` struct (Sendable, Codable, Equatable) containing `[Standing]` data + `roundID` + `currentHole` + `lastUpdatedAt: Date` in `HyzerKit/Sources/HyzerKit/Communication/StandingsSnapshot.swift`
  - [ ] 1.4 Write unit tests for `WatchMessage` encoding/decoding roundtrip and `StandingsSnapshot` serialization

- [ ] Task 2: Create `WatchCacheManager` for app group JSON persistence (AC: 3, 4)
  - [ ] 2.1 Implement `WatchCacheManager` in `HyzerKit/Sources/HyzerKit/Communication/WatchCacheManager.swift` with `save(_ snapshot: StandingsSnapshot)` and `loadLatest() -> StandingsSnapshot?`
  - [ ] 2.2 Use `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shotcowboystyle.hyzerapp")` for storage path
  - [ ] 2.3 Write unit tests for save/load roundtrip, missing file returns nil, corrupted file returns nil

- [ ] Task 3: Implement `PhoneConnectivityService` on iOS side (AC: 2, 4)
  - [ ] 3.1 Create `PhoneConnectivityService` in `HyzerApp/Services/PhoneConnectivityService.swift` conforming to `WCSessionDelegate`
  - [ ] 3.2 Implement `sendStandings(_ snapshot: StandingsSnapshot)` — use `sendMessage` when reachable, write to `WatchCacheManager` always
  - [ ] 3.3 Handle incoming `WatchMessage` from Watch (score events — wire to `ScoringService` in story 7.2)
  - [ ] 3.4 Expose `isWatchReachable: Bool` as observable state
  - [ ] 3.5 Wire `StandingsEngine` observation to auto-push standings on every `StandingsChange`
  - [ ] 3.6 Register `PhoneConnectivityService` in `AppServices.swift`

- [ ] Task 4: Implement `WatchConnectivityService` on watchOS side (AC: 1, 2, 3)
  - [ ] 4.1 Create `WatchConnectivityService` in `HyzerWatch/Services/WatchConnectivityService.swift` conforming to `WCSessionDelegate`
  - [ ] 4.2 Implement received message handler: decode `WatchMessage`, update `currentSnapshot: StandingsSnapshot?`
  - [ ] 4.3 On receive, also persist to `WatchCacheManager` for offline fallback
  - [ ] 4.4 On launch, load last snapshot from `WatchCacheManager` if no live data
  - [ ] 4.5 Expose `isPhoneReachable: Bool` and `lastUpdatedAt: Date?` as observable state

- [ ] Task 5: Build `WatchLeaderboardView` and `WatchLeaderboardViewModel` (AC: 1, 2, 3)
  - [ ] 5.1 Create `WatchLeaderboardViewModel` in `HyzerWatch/ViewModels/WatchLeaderboardViewModel.swift` — `@MainActor @Observable final class`, receives `WatchConnectivityService`
  - [ ] 5.2 Expose `standings: [Standing]`, `isStale: Bool`, `staleDurationText: String`, `isConnected: Bool`
  - [ ] 5.3 Compute `isStale` when `lastUpdatedAt` exceeds 30 seconds from now
  - [ ] 5.4 Create `WatchLeaderboardView` in `HyzerWatch/Views/WatchLeaderboardView.swift` — `List`-based layout with full-width rows
  - [ ] 5.5 Each row: position number + player name + score relative to par (color-coded: green under, amber over, white at par)
  - [ ] 5.6 Use design tokens: `ColorTokens` for score colors, `TypographyTokens` for text hierarchy, `SpacingTokens` for padding
  - [ ] 5.7 Animate standings reshuffles with `AnimationTokens.leaderboardReshuffleDuration` via `AnimationCoordinator`

- [ ] Task 6: Build `WatchStaleIndicatorView` (AC: 3)
  - [ ] 6.1 Create `WatchStaleIndicatorView` in `HyzerWatch/Views/WatchStaleIndicatorView.swift`
  - [ ] 6.2 Show relative time ("30s ago", "2m ago", "5m ago") when snapshot is stale
  - [ ] 6.3 Use `ColorTokens.warning` for stale indicator color
  - [ ] 6.4 Use `TypographyTokens.caption` for indicator text size

- [ ] Task 7: Wire Watch app entry point (AC: 1)
  - [ ] 7.1 Update `HyzerWatchApp.swift` to create `WatchConnectivityService` and inject into views
  - [ ] 7.2 Replace placeholder `WatchRootView` with `WatchLeaderboardView`
  - [ ] 7.3 Activate `WCSession` on app launch

- [ ] Task 8: Write tests (AC: 1, 2, 3, 4)
  - [ ] 8.1 `WatchMessage` encode/decode tests in HyzerKitTests
  - [ ] 8.2 `StandingsSnapshot` serialization tests in HyzerKitTests
  - [ ] 8.3 `WatchCacheManager` save/load/missing/corrupt tests in HyzerKitTests
  - [ ] 8.4 `WatchLeaderboardViewModel` tests — standings mapping, stale detection, stale text formatting
  - [ ] 8.5 `WatchLeaderboardViewModel` tests — snapshot update triggers view state change

## Dev Notes

### Architecture Constraints

- **Phone is the sole CloudKit sync node.** Watch NEVER communicates directly with CloudKit. All sync flows: Watch <-> Phone <-> CloudKit.
- **No SwiftData on Watch.** Watch uses JSON file persistence via `WatchCacheManager` in the shared app group container. The Watch does NOT have a `ModelContainer`.
- **Two distinct UIs.** Phone and Watch share data models and design tokens, not layout or interaction patterns. The Watch is a leaderboard terminal, not a shrunken phone app.
- **Event sourcing invariant.** ScoreEvents are append-only and immutable. Watch-originated scores (story 7.2) will create ScoreEvents on the phone side, not the Watch.

### Communication Pattern

```
Phone (StandingsEngine)
  ├── sendMessage (active session, instant) ──> Watch (WatchConnectivityService)
  └── WatchCacheManager.save (app group JSON) ──> Watch (WatchCacheManager.load on launch)

Watch (WatchConnectivityService)
  └── transferUserInfo (guaranteed delivery) ──> Phone (PhoneConnectivityService)
      └── ScoringService.createScoreEvent (story 7.2 scope)
```

- `sendMessage`: Used for live standings pushes when both apps are active. Best-effort, not guaranteed.
- `transferUserInfo`: Used by Watch for sending ScoreEvents to phone (story 7.2). Guaranteed delivery, queued if phone unreachable.
- `WatchCacheManager`: JSON file in app group. Written by phone after every standings push. Read by Watch on launch as fallback.

### ViewModel Pattern

Follow the established pattern from previous stories:
- `@MainActor @Observable final class`
- Constructor injection of individual services (NOT the full services container)
- No `DispatchQueue` — use `@MainActor` isolation
- Error state as optional `Error?` property
- Swift 6 strict concurrency compliance (`SWIFT_STRICT_CONCURRENCY = complete`)

### Watch Leaderboard UX Requirements

- **Hero data hierarchy**: Position + name + score are the only data. No secondary info.
- **Full-width rows**: No horizontal scrolling. Each player gets a full row.
- **12pt vertical padding** between rows (use `SpacingTokens.sm` + `SpacingTokens.xs`).
- **Score color coding**: `ColorTokens.scoreUnderPar` (green), `ColorTokens.scoreOverPar` (amber), `ColorTokens.scoreAtPar` (white).
- **Arm's-length readability**: Use `TypographyTokens.score` for the score value.
- **Stale indicator**: Show relative time since last update when `lastUpdatedAt` > 30 seconds. Use `ColorTokens.warning`.
- **Reduce motion**: Use `AnimationCoordinator.animation()` for all animations — respects `accessibilityReduceMotion`.
- **Accessibility**: VoiceOver labels on all leaderboard rows (e.g., "Player name, position 2, 1 under par").

### Existing Code to Reuse

| Component | Location | Usage |
|-----------|----------|-------|
| `Standing` | `HyzerKit/Sources/HyzerKit/Domain/Standing.swift` | Leaderboard row data — position, playerName, scoreRelativeToPar |
| `StandingsEngine` | `HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift` | Phone-side only — observe `currentStandings` to push to Watch |
| `StandingsChange` | `HyzerKit/Sources/HyzerKit/Domain/StandingsChange.swift` | Trigger for pushing updates to Watch |
| `StandingsChangeTrigger` | `HyzerKit/Sources/HyzerKit/Domain/StandingsChangeTrigger.swift` | Enum: `.localScore`, `.remoteSync`, `.conflictResolution` |
| `ColorTokens` | `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift` | Score colors, backgrounds, text |
| `TypographyTokens` | `HyzerKit/Sources/HyzerKit/Design/TypographyTokens.swift` | Font hierarchy (hero, h1-h3, body, caption, score) |
| `SpacingTokens` | `HyzerKit/Sources/HyzerKit/Design/SpacingTokens.swift` | 8pt grid spacing (xs=4, sm=8, md=16, lg=24) |
| `AnimationTokens` | `HyzerKit/Sources/HyzerKit/Design/AnimationTokens.swift` | `leaderboardReshuffleDuration`, `springStiff` |
| `AnimationCoordinator` | `HyzerKit/Sources/HyzerKit/Design/AnimationCoordinator.swift` | Reduce-motion aware animation wrapper |

### New Files to Create

**HyzerKit (shared — Communication/):**
- `HyzerKit/Sources/HyzerKit/Communication/WatchConnectivityClient.swift` — Protocol
- `HyzerKit/Sources/HyzerKit/Communication/WatchMessage.swift` — Typed message enum
- `HyzerKit/Sources/HyzerKit/Communication/StandingsSnapshot.swift` — Serializable standings data
- `HyzerKit/Sources/HyzerKit/Communication/WatchCacheManager.swift` — App group JSON persistence

**HyzerApp (iOS — Services/):**
- `HyzerApp/Services/PhoneConnectivityService.swift` — iOS-side WCSession delegate

**HyzerWatch (watchOS):**
- `HyzerWatch/Services/WatchConnectivityService.swift` — Watch-side WCSession delegate
- `HyzerWatch/ViewModels/WatchLeaderboardViewModel.swift` — Watch leaderboard state
- `HyzerWatch/Views/WatchLeaderboardView.swift` — Watch leaderboard UI
- `HyzerWatch/Views/WatchStaleIndicatorView.swift` — Staleness indicator

**Tests:**
- `HyzerKit/Tests/HyzerKitTests/Communication/WatchMessageTests.swift`
- `HyzerKit/Tests/HyzerKitTests/Communication/StandingsSnapshotTests.swift`
- `HyzerKit/Tests/HyzerKitTests/Communication/WatchCacheManagerTests.swift`

### Existing Files to Modify

- `HyzerApp/App/AppServices.swift` — Add `PhoneConnectivityService` property and initialization
- `HyzerWatch/App/HyzerWatchApp.swift` — Replace placeholder, create services, activate WCSession
- `HyzerWatch/Views/WatchRootView.swift` — Replace with `WatchLeaderboardView` (or delete and replace)
- `project.yml` — Verify HyzerWatch sources include new `Services/` and `ViewModels/` directories (auto-discovered via `sources: [HyzerWatch]`)

### Testing Strategy

- **HyzerKit domain tests** (`swift test --package-path HyzerKit`): `WatchMessage` encode/decode, `StandingsSnapshot` serialization, `WatchCacheManager` save/load with in-memory file paths.
- **Watch ViewModel tests**: Create mock `WatchConnectivityService` protocol for `WatchLeaderboardViewModel` testing. Test stale detection, standings mapping, text formatting.
- **No simulator needed** for HyzerKit tests. Watch app build verification via `xcodebuild build` only (cannot run on macOS 15).
- Use **Swift Testing** (`@Suite`, `@Test`) — NOT XCTest.
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` for any SwiftData-adjacent tests.

### App Group Configuration

Both apps already have matching entitlements:
- iOS: `HyzerApp/App/HyzerApp.entitlements` — `group.com.shotcowboystyle.hyzerapp`
- watchOS: `HyzerWatch/App/HyzerWatch.entitlements` — `group.com.shotcowboystyle.hyzerapp`

The `WatchCacheManager` file path should be:
```swift
let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.shotcowboystyle.hyzerapp"
)
let cacheURL = containerURL?.appendingPathComponent("standings-cache.json")
```

### WCSession Activation Pattern

Both iOS and watchOS must activate `WCSession` early:
```swift
// In service init or app launch:
if WCSession.isSupported() {
    let session = WCSession.default
    session.delegate = self
    session.activate()
}
```

The `WCSessionDelegate` requires implementing:
- `session(_:activationDidCompleteWith:error:)` (required on both platforms)
- `sessionDidBecomeInactive(_:)` (iOS only)
- `sessionDidDeactivate(_:)` (iOS only — call `session.activate()` again)
- `session(_:didReceiveMessage:)` (for `sendMessage` reception)
- `session(_:didReceiveUserInfo:)` (for `transferUserInfo` reception)

### Performance Requirements

| Metric | Target | Implementation |
|--------|--------|----------------|
| Cross-device standings update | < 5 seconds | `sendMessage` for active sessions |
| Stale indicator threshold | 30 seconds | `Date().timeIntervalSince(lastUpdatedAt) > 30` |
| Watch app launch to leaderboard | < 1 second | Load from `WatchCacheManager` immediately, update live when connected |
| Offline recovery | 4+ hours | JSON cache persists in app group indefinitely |

### Project Structure Notes

- All new HyzerKit code goes in `HyzerKit/Sources/HyzerKit/Communication/` — a new directory for cross-device communication abstractions.
- Watch-specific views/ViewModels follow the same structure as the iOS app: `HyzerWatch/Views/`, `HyzerWatch/ViewModels/`, `HyzerWatch/Services/`.
- The `project.yml` HyzerWatch target uses `sources: [HyzerWatch]` which auto-discovers all Swift files in subdirectories — no `project.yml` changes needed for new files.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Communication Architecture, Watch State Management]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 7, Story 7.1]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Watch Design Direction, Journey 5]
- [Source: HyzerKit/Sources/HyzerKit/Domain/Standing.swift — Standing model reuse]
- [Source: HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift — Phone-side standings computation]
- [Source: HyzerWatch/App/HyzerWatch.entitlements — App group configuration]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
