# Story 7.3: Watch Voice Scoring & Bidirectional Communication

Status: ready-for-dev

## Story

As a Watch user,
I want to speak scores from my wrist and have them processed by the phone,
so that I have the same voice scoring experience without pulling out my phone.

## Acceptance Criteria

1. **Given** the Watch scoring view is active, **When** the user taps the microphone button, **Then** the voice input request is routed to the paired phone for recognition and parsing (FR55), **And** a listening indicator is displayed on the Watch while the phone processes, **And** parsed results are sent back to the Watch for display.

2. **Given** the paired phone is unreachable (`isReachable == false`), **When** the user taps the microphone button on the Watch, **Then** voice input is unavailable with a clear "Phone required for voice" message, **And** the Crown input remains available as fallback (FR55), **And** the mic button appears disabled/dimmed.

3. **Given** a voice parse result is returned from the phone, **When** the result is `.success`, **Then** the Watch displays a confirmation overlay with player name(s) and score(s), **And** auto-commits after 1.5 seconds (matching phone behavior), **And** a haptic confirmation fires on the Watch (FR57).

4. **Given** a voice parse result is returned from the phone, **When** the result is `.partial` or `.failed`, **Then** the Watch displays the failure state with the transcript, **And** offers a retry option and Crown fallback, **And** no auto-commit occurs.

5. **Given** a score is confirmed via voice on the Watch, **When** the score is transmitted to the phone, **Then** the phone processes it through `ScoringService.createScoreEvent()` (FR56), **And** the score syncs to all other devices via CloudKit, **And** the Watch returns to the leaderboard.

6. **Given** standings change on the phone, **When** the phone sends an update to the Watch, **Then** the Watch leaderboard updates bidirectionally (FR56), **And** a haptic confirmation fires on the Watch for score-related actions (FR57).

## Tasks / Subtasks

- [ ] Task 1: Add Codable conformance to voice types for WatchConnectivity transport (AC: 1, 3, 4)
  - [ ] 1.1 Add `Codable` conformance to `ScoreCandidate` in `HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift`
  - [ ] 1.2 Add `Codable` conformance to `UnresolvedCandidate` in the same file
  - [ ] 1.3 Add `Codable` conformance to `VoiceParseResult` in the same file (requires manual `Codable` implementation for enum with associated values)
  - [ ] 1.4 Add `Codable` conformance to `VoiceParseError` in `HyzerKit/Sources/HyzerKit/Voice/VoiceParseError.swift`
  - [ ] 1.5 Write encode/decode roundtrip tests for all newly-Codable voice types

- [ ] Task 2: Extend `WatchMessage` with voice communication cases (AC: 1, 3, 4)
  - [ ] 2.1 Add `.voiceRequest(WatchVoiceRequest)` case to `WatchMessage` enum (Watch → Phone) — contains `roundID`, `holeNumber`, `playerEntries: [VoicePlayerEntry]` (so phone can run `VoiceParser` with the player list)
  - [ ] 2.2 Add `.voiceResult(WatchVoiceResult)` case to `WatchMessage` enum (Phone → Watch) — wraps `VoiceParseResult` for transport
  - [ ] 2.3 Create `WatchVoiceRequest` struct (`Sendable, Codable, Equatable`) with: `roundID: UUID`, `holeNumber: Int`, `playerEntries: [VoicePlayerEntry]`
  - [ ] 2.4 Create `WatchVoiceResult` struct (`Sendable, Codable, Equatable`) with: `result: VoiceParseResult`, `holeNumber: Int`, `roundID: UUID`
  - [ ] 2.5 Add `Codable` conformance to `VoicePlayerEntry` (currently only `Sendable`)
  - [ ] 2.6 Update `WatchMessage` Codable implementation to handle new cases
  - [ ] 2.7 Write encode/decode roundtrip tests for new message types in `WatchMessageTests.swift`

- [ ] Task 3: Implement phone-side voice request handling (AC: 1, 5)
  - [ ] 3.1 Add `voiceRecognitionService: VoiceRecognitionServiceProtocol?` property to `PhoneConnectivityService`
  - [ ] 3.2 Add `voiceParser: VoiceParser` property to `PhoneConnectivityService` (it's a value type, no DI needed — just `VoiceParser()`)
  - [ ] 3.3 In `handleIncomingData`, add handler for `.voiceRequest(let request)`: call `handleWatchVoiceRequest(_:)`
  - [ ] 3.4 Implement `handleWatchVoiceRequest(_ request:)`: call `voiceRecognitionService?.recognize()`, parse with `voiceParser.parse(transcript:players:)`, send `.voiceResult(...)` back via `sendMessage` (best-effort instant delivery)
  - [ ] 3.5 Handle recognition errors: send `.voiceResult` with `.failed` result containing error description
  - [ ] 3.6 Wire `voiceRecognitionService` injection in `AppServices.init` — pass the existing `VoiceRecognitionService` instance

- [ ] Task 4: Create `WatchVoiceViewModel` in HyzerKit (AC: 1, 2, 3, 4, 5)
  - [ ] 4.1 Create `WatchVoiceViewModel` in `HyzerKit/Sources/HyzerKit/Communication/WatchVoiceViewModel.swift` — `@MainActor @Observable public final class`
  - [ ] 4.2 Constructor: `init(roundID:, holeNumber:, playerEntries:, connectivityClient: any WatchConnectivityClient)`
  - [ ] 4.3 Expose `state: WatchVoiceState` enum — `.idle`, `.listening`, `.confirming([ScoreCandidate])`, `.partial(recognized:unresolved:)`, `.failed(transcript:)`, `.committed`, `.unavailable`
  - [ ] 4.4 Implement `startVoiceRequest()`: check `isReachable` → if false, set `.unavailable`; if true, send `.voiceRequest(...)` via `sendMessage`, set `.listening`
  - [ ] 4.5 Implement `handleVoiceResult(_ result: WatchVoiceResult)`: transition state based on parse result — `.success` → `.confirming`, `.partial` → `.partial`, `.failed` → `.failed`
  - [ ] 4.6 Implement `confirmScores()`: for each `ScoreCandidate` in confirming state, send `.scoreEvent(WatchScorePayload)` via `transferUserInfo` (guaranteed delivery), set `.committed`
  - [ ] 4.7 Implement auto-commit timer: 1.5s delay on `.confirming` state, then `confirmScores()` — matching phone `VoiceOverlayViewModel` behavior
  - [ ] 4.8 Implement `cancel()`, `retry()` methods
  - [ ] 4.9 Score bounds: validate `strokeCount` in 1...10 range from voice candidates

- [ ] Task 5: Create `WatchVoiceOverlayView` on watchOS (AC: 1, 2, 3, 4)
  - [ ] 5.1 Create `WatchVoiceOverlayView` in `HyzerWatch/Views/WatchVoiceOverlayView.swift`
  - [ ] 5.2 Layout states: listening indicator (pulsing mic icon), confirming (player name + score, countdown indicator), partial/failed (transcript + retry button), unavailable (message + dismiss)
  - [ ] 5.3 Use design tokens: `TypographyTokens.body` for player names, `TypographyTokens.score` for stroke counts, `ColorTokens` for score colors
  - [ ] 5.4 Haptic feedback: `WKInterfaceDevice.current().play(.success)` on score confirmation (FR57)
  - [ ] 5.5 Auto-dismiss on `.committed` state transition
  - [ ] 5.6 Accessibility: announce state transitions for VoiceOver users

- [ ] Task 6: Add mic button to `WatchScoringView` and wire navigation (AC: 1, 2)
  - [ ] 6.1 Add microphone button to `WatchScoringView` — positioned below the confirm button, uses SF Symbol `mic.fill`
  - [ ] 6.2 Mic button disabled/dimmed when `connectivityClient.isReachable == false`
  - [ ] 6.3 Mic button tap presents `WatchVoiceOverlayView` as a sheet/overlay
  - [ ] 6.4 Pass `WatchConnectivityClient` reference and round/hole/player context to `WatchVoiceViewModel`

- [ ] Task 7: Wire Watch-side voice result reception (AC: 3, 4, 6)
  - [ ] 7.1 In `WatchConnectivityService`, handle incoming `.voiceResult(let result)` in `handleIncomingData`
  - [ ] 7.2 Add `voiceResultHandler: ((WatchVoiceResult) -> Void)?` callback on `WatchConnectivityService` for forwarding to `WatchVoiceViewModel`
  - [ ] 7.3 Wire `voiceResultHandler` from `WatchVoiceOverlayView` when it appears (set handler → start request → handle result → clear handler)
  - [ ] 7.4 Haptic confirmation on standings update receipt: add `WKInterfaceDevice.current().play(.notification)` when new standings arrive via `.standingsUpdate` with a score change (FR57)

- [ ] Task 8: Write tests (AC: 1, 2, 3, 4, 5, 6)
  - [ ] 8.1 Create `WatchVoiceViewModelTests` in `HyzerKit/Tests/HyzerKitTests/Communication/WatchVoiceViewModelTests.swift`
  - [ ] 8.2 Test: `startVoiceRequest` when reachable sends `.voiceRequest` via `sendMessage`
  - [ ] 8.3 Test: `startVoiceRequest` when unreachable sets state to `.unavailable`
  - [ ] 8.4 Test: `handleVoiceResult` with `.success` transitions to `.confirming` with correct candidates
  - [ ] 8.5 Test: `handleVoiceResult` with `.partial` transitions to `.partial` state
  - [ ] 8.6 Test: `handleVoiceResult` with `.failed` transitions to `.failed` state
  - [ ] 8.7 Test: `confirmScores` sends `transferUserInfo` with `.scoreEvent` for each candidate
  - [ ] 8.8 Test: auto-commit timer fires after 1.5s in `.confirming` state
  - [ ] 8.9 Test: `cancel()` resets state to `.idle`
  - [ ] 8.10 Test: `retry()` re-sends voice request
  - [ ] 8.11 Test: score bounds — candidates with strokeCount outside 1...10 are clamped
  - [ ] 8.12 Update `WatchMessageTests` for new voice message types encode/decode roundtrip
  - [ ] 8.13 Write `VoiceParseResult` Codable roundtrip tests in `HyzerKit/Tests/HyzerKitTests/Voice/`

## Dev Notes

### Architecture Constraints

- **Phone is the sole CloudKit sync node.** Watch scores flow to phone via `transferUserInfo` (guaranteed delivery). Phone creates `ScoreEvent` via `ScoringService`, which triggers sync to CloudKit. Watch NEVER writes directly to SwiftData or CloudKit.
- **Event sourcing invariant.** `ScoreEvent` is append-only and immutable. No UPDATE or DELETE. The phone creates the event — the Watch only sends the payload.
- **No SwiftData on Watch.** Watch has no `ModelContainer`. All data comes from `StandingsSnapshot` (JSON).
- **Speech framework stays on phone.** `VoiceRecognitionService` imports `Speech` and lives in `HyzerApp/Services/` — iOS only. HyzerKit MUST NEVER import the Speech framework. The Watch cannot directly perform speech recognition — it relays requests to the phone.
- **ViewModel lives in HyzerKit** (not HyzerWatch). Same pattern as `WatchLeaderboardViewModel` and `WatchScoringViewModel` — enables macOS-hosted unit tests without importing WatchConnectivity.
- **ViewModel receives individual services via constructor injection**, never the full container.

### Voice-Over-WatchConnectivity Flow

```
Watch:
  User taps mic button on WatchScoringView
    → WatchVoiceOverlayView appears
      → WatchVoiceViewModel.startVoiceRequest()
        → Check isReachable — if false: state = .unavailable, STOP
        → WatchConnectivityClient.sendMessage(.voiceRequest(WatchVoiceRequest))
          (best-effort instant delivery — requires phone to be reachable)
        → state = .listening

Phone (PhoneConnectivityService receives):
  handleIncomingData → .voiceRequest(request)
    → VoiceRecognitionService.recognize() — records from phone mic
    → VoiceParser.parse(transcript:, players: request.playerEntries)
    → PhoneConnectivityService.sendMessage(.voiceResult(WatchVoiceResult))
      (best-effort instant — Watch must be reachable)

Watch (WatchConnectivityService receives):
  handleIncomingData → .voiceResult(result)
    → voiceResultHandler?(result)
      → WatchVoiceViewModel.handleVoiceResult(result)
        → .success: state = .confirming, start 1.5s auto-commit timer
        → .partial: state = .partial (show retry + Crown fallback)
        → .failed: state = .failed (show retry + Crown fallback)

  On auto-commit or manual confirm:
    → WatchVoiceViewModel.confirmScores()
      → For each ScoreCandidate:
        → WatchConnectivityClient.transferUserInfo(.scoreEvent(WatchScorePayload))
          (guaranteed delivery — survives app termination)
      → state = .committed
      → Haptic: WKInterfaceDevice.current().play(.success)
```

### Key Design Decisions

1. **`sendMessage` for voice round-trip, `transferUserInfo` for confirmed scores.** Voice requests are interactive and time-sensitive — they need instant delivery (`sendMessage`). Once a score is confirmed, it uses `transferUserInfo` for guaranteed delivery (same as Crown scoring in 7.2). If the phone becomes unreachable mid-voice-flow, the Watch handles it gracefully (show failure, offer Crown fallback).

2. **Phone listens from its own mic, not Watch mic.** Per FR55: "Speech recognition runs on the paired iPhone." The Watch sends a *request* to start voice recognition, and the phone records from its own mic and runs `SFSpeechRecognizer`. This avoids streaming raw audio over BLE (complex, latency-heavy). User should hold the phone (or have it nearby) when using voice from Watch.

3. **Player entries sent with voice request.** The `WatchVoiceRequest` includes `playerEntries: [VoicePlayerEntry]` so the phone can run `VoiceParser.parse(transcript:players:)` without needing its own player context. This keeps the phone handler stateless with respect to the current round's player list.

4. **No partial/unresolved resolution on Watch.** The Watch's small screen makes resolving unresolved candidates impractical. If the result is `.partial` or `.failed`, the Watch shows the transcript and offers retry or Crown fallback. Complex resolution (picking from player list) is deferred to the phone UI.

5. **Auto-commit timer matches phone behavior (1.5s).** Consistency with `VoiceOverlayViewModel`'s auto-commit UX. Timer is reset if user interacts.

### Codable Gap: Voice Types

The existing voice types in `HyzerKit/Sources/HyzerKit/Voice/` are `Sendable` and `Equatable` but NOT `Codable`:
- `ScoreCandidate` — needs `Codable` (simple struct, synthesizable)
- `UnresolvedCandidate` — needs `Codable` (simple struct, synthesizable)
- `VoiceParseResult` — needs `Codable` (enum with associated values — requires manual implementation)
- `VoiceParseError` — needs `Codable` (simple enum, synthesizable if cases have no associated values — check for `.recognitionUnavailable` etc.)
- `VoicePlayerEntry` — needs `Codable` (simple struct, synthesizable)

All of these must be `Codable` to serialize into `WatchMessage` for WatchConnectivity transport. Adding `Codable` to these types is backwards-compatible — no existing code breaks.

### WatchMessage Evolution

Current cases (from 7.1 and 7.2):
```swift
public enum WatchMessage: Sendable, Codable {
    case standingsUpdate(StandingsSnapshot)  // Phone → Watch
    case scoreEvent(WatchScorePayload)       // Watch → Phone
}
```

New cases for 7.3:
```swift
case voiceRequest(WatchVoiceRequest)     // Watch → Phone
case voiceResult(WatchVoiceResult)       // Phone → Watch
```

The existing `WatchMessage` Codable uses `{ "type": "<case>", "<case>": <payload> }` JSON format. New cases must follow the same pattern. The `WatchMessageTests` already test unknown type rejection — add tests for new types.

### Existing Code to Reuse

| Component | Location | Usage |
|-----------|----------|-------|
| `VoiceParser` | `HyzerKit/.../Voice/VoiceParser.swift` | Phone-side: parse transcript against player list |
| `VoiceParseResult` | `HyzerKit/.../Voice/VoiceParseResult.swift` | Result type sent back to Watch |
| `ScoreCandidate` | `HyzerKit/.../Voice/VoiceParseResult.swift` | Confirmed player-score pairs |
| `UnresolvedCandidate` | `HyzerKit/.../Voice/VoiceParseResult.swift` | Unresolved names (Watch shows as failure) |
| `VoicePlayerEntry` | `HyzerKit/.../Voice/VoiceParser.swift` | Player context sent with voice request |
| `VoiceParseError` | `HyzerKit/.../Voice/VoiceParseError.swift` | Error cases for recognition failures |
| `VoiceRecognitionService` | `HyzerApp/Services/VoiceRecognitionService.swift` | Phone-side speech recognition (iOS only) |
| `VoiceRecognitionServiceProtocol` | `HyzerApp/Protocols/VoiceRecognitionServiceProtocol.swift` | Protocol for DI |
| `WatchScoringViewModel` | `HyzerKit/.../Communication/WatchScoringViewModel.swift` | Pattern reference — Crown scoring VM in HyzerKit |
| `VoiceOverlayViewModel` | `HyzerApp/ViewModels/VoiceOverlayViewModel.swift` | Pattern reference — phone voice overlay states |
| `WatchMessage` | `HyzerKit/.../Communication/WatchMessage.swift` | Add new cases |
| `WatchConnectivityClient` | `HyzerKit/.../Communication/WatchConnectivityClient.swift` | Protocol — `sendMessage` + `transferUserInfo` |
| `WatchConnectivityService` | `HyzerWatch/Services/WatchConnectivityService.swift` | Watch-side — handle new `.voiceResult` case |
| `PhoneConnectivityService` | `HyzerApp/Services/PhoneConnectivityService.swift` | Phone-side — handle new `.voiceRequest` case |
| `StandingsSnapshot` | `HyzerKit/.../Communication/StandingsSnapshot.swift` | Has `roundID`, `currentHole`, `currentHolePar` |
| `WatchScorePayload` | `HyzerKit/.../Communication/WatchMessage.swift` | Reuse for confirmed voice scores |
| `ColorTokens` | `HyzerKit/.../Design/ColorTokens.swift` | Score colors |
| `TypographyTokens` | `HyzerKit/.../Design/TypographyTokens.swift` | Text styles |
| `SpacingTokens` | `HyzerKit/.../Design/SpacingTokens.swift` | Layout padding |
| `AnimationCoordinator` | `HyzerKit/.../Design/AnimationCoordinator.swift` | Reduce-motion aware animation |
| `MockWatchConnectivityClient` | `HyzerKitTests/.../Communication/` | Reuse in new tests |

### New Files to Create

**HyzerKit (shared):**
- `HyzerKit/Sources/HyzerKit/Communication/WatchVoiceViewModel.swift`

**HyzerWatch (watchOS):**
- `HyzerWatch/Views/WatchVoiceOverlayView.swift`

**Tests:**
- `HyzerKit/Tests/HyzerKitTests/Communication/WatchVoiceViewModelTests.swift`

### Existing Files to Modify

- `HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift` — Add `Codable` to `ScoreCandidate`, `UnresolvedCandidate`, `VoiceParseResult`
- `HyzerKit/Sources/HyzerKit/Voice/VoiceParseError.swift` — Add `Codable` to `VoiceParseError`
- `HyzerKit/Sources/HyzerKit/Voice/VoiceParser.swift` — Add `Codable` to `VoicePlayerEntry`
- `HyzerKit/Sources/HyzerKit/Communication/WatchMessage.swift` — Add `voiceRequest`/`voiceResult` cases, new payload types
- `HyzerApp/Services/PhoneConnectivityService.swift` — Handle `.voiceRequest`, wire `voiceRecognitionService` and `voiceParser`
- `HyzerApp/App/AppServices.swift` — Pass `voiceRecognitionService` to `PhoneConnectivityService`
- `HyzerWatch/Services/WatchConnectivityService.swift` — Handle `.voiceResult`, add `voiceResultHandler` callback
- `HyzerWatch/Views/WatchScoringView.swift` — Add mic button, wire to `WatchVoiceOverlayView`
- `HyzerKit/Tests/HyzerKitTests/Communication/WatchMessageTests.swift` — Add tests for new message types

### Testing Strategy

- **HyzerKit domain tests** (`swift test --package-path HyzerKit`): `WatchVoiceViewModel` logic — state machine transitions, reachability gating, auto-commit timer, score confirmation sends payloads.
- **Mock `WatchConnectivityClient`**: Reuse existing `MockWatchConnectivityClient` that records `sentMessages` and `transferredMessages`.
- **No simulator needed** for HyzerKit tests. Watch view build verification via `xcodebuild build` only.
- **Voice type Codable tests**: Roundtrip encode/decode for `VoiceParseResult`, `ScoreCandidate`, `VoicePlayerEntry`.
- Use **Swift Testing** (`@Suite`, `@Test`) — NOT XCTest.
- **Current baseline**: 219 tests in 27 suites — do not regress.

### Performance Requirements

| Metric | Target | Implementation |
|--------|--------|----------------|
| Voice round-trip latency | < 3s (network dependent) | `sendMessage` both ways (instant when reachable) |
| Score delivery | Guaranteed | `transferUserInfo` for confirmed scores (queued) |
| Auto-commit delay | 1.5s | Matches phone `VoiceOverlayViewModel` behavior |
| Haptic feedback | Immediate on confirmation | `WKInterfaceDevice.current().play(.success)` |

### Concurrency

- `WatchVoiceViewModel`: `@MainActor @Observable` — all state is main-actor-isolated.
- Auto-commit timer: `Task.sleep(for: .seconds(1.5))` — cancellable via `Task` handle, runs on `@MainActor`.
- Phone-side `handleWatchVoiceRequest`: async — `recognize()` is `async throws`, runs on `@MainActor`.
- `VoiceParser.parse(transcript:players:)` is `nonisolated` / `Sendable` — safe to call from any context.

### Previous Story (7.2) Learnings

- **ViewModel in HyzerKit, not Watch target.** `WatchScoringViewModel` lives in HyzerKit for macOS unit tests. Apply same pattern to `WatchVoiceViewModel`.
- **Separate NSObject delegate.** `@Observable` doesn't support NSObject subclasses. WCSession delegate is a separate `SessionDelegate` class — already handled in 7.1.
- **`Standing` has `Codable` and `Hashable`.** Added in 7.1/7.2 — available for serialization and NavigationLink.
- **Score clamping pattern.** `WatchScoringViewModel` uses a private `_rawScore` backing store with computed `currentScore` setter. Voice candidates should be validated similarly.
- **`PhoneConnectivityService` retains `standingsEngine`.** Set via `startObservingStandings` — auto-pushes updated standings to Watch via observation loop. Voice-confirmed scores will trigger same recompute → auto-push.
- **219 HyzerKit tests pass.** Do not regress.

### Project Structure Notes

- New HyzerKit files go in `HyzerKit/Sources/HyzerKit/Communication/` — same directory as story 7.1/7.2 communication code.
- New Watch views go in `HyzerWatch/Views/` — auto-discovered by `project.yml` (`sources: [HyzerWatch]`).
- No `project.yml` changes needed for new files.
- Voice type modifications in `HyzerKit/Sources/HyzerKit/Voice/` — existing directory.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Watch Communication Flow, Voice FR55, FR56, FR57, NFR4, NFR12]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 7, Story 7.3]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Watch Voice Scoring, Bidirectional Communication]
- [Source: _bmad-output/implementation-artifacts/7-2-crown-score-entry.md — Previous Story learnings]
- [Source: HyzerKit/Sources/HyzerKit/Communication/WatchMessage.swift — WatchMessage enum, WatchScorePayload]
- [Source: HyzerKit/Sources/HyzerKit/Communication/WatchConnectivityClient.swift — Protocol: sendMessage + transferUserInfo]
- [Source: HyzerKit/Sources/HyzerKit/Voice/VoiceParser.swift — VoiceParser, VoicePlayerEntry]
- [Source: HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift — VoiceParseResult, ScoreCandidate, UnresolvedCandidate]
- [Source: HyzerApp/Services/VoiceRecognitionService.swift — SFSpeechRecognizer integration (iOS only)]
- [Source: HyzerApp/ViewModels/VoiceOverlayViewModel.swift — State machine pattern, auto-commit timer]
- [Source: HyzerApp/Services/PhoneConnectivityService.swift — scoreEvent handling pattern, wiring point]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
