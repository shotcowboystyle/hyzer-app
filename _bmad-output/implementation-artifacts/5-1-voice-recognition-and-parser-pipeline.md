# Story 5.1: Voice Recognition & Parser Pipeline

Status: review

## Story

As a user,
I want to speak player names and scores and have the system understand them,
so that I can enter scores without touching the screen.

## Acceptance Criteria

1. Given the user taps the microphone button on a hole card, when the voice input activates, then a listening indicator appears and on-device speech recognition begins (FR21), and the voice confirmation overlay appears within 500ms of speech completion (NFR7).

2. Given the user speaks "Mike 3, Jake 4, Sarah 2", when the transcript is processed by `VoiceParser`, then the parser tokenizes the input, classifies tokens as names or numbers, and assembles player-score pairs (FR22), and player names are matched against the known player list using fuzzy matching (FR23).

3. Given a spoken name fragment like "Mike" when the display name is "Michael", when `FuzzyNameMatcher` processes the token, then the alias map is checked first, then Levenshtein distance fallback matches within threshold (FR23).

4. Given `VoiceParser` is in HyzerKit, when it processes a transcript, then it executes as a `nonisolated` pure function with no platform imports (no Speech framework dependency), and it can be called from any isolation context without `await`.

5. Given `VoiceRecognitionService` wraps `SFSpeechRecognizer`, when it is compiled, then it lives exclusively in `HyzerApp/Services/` (never in HyzerKit) and uses on-device recognition only (`requiresOnDeviceRecognition = true`).

6. Given `VoiceParseResult` returns `.success`, `.partial`, or `.failed`, when crossing isolation boundaries, then it conforms to `Sendable`.

## Tasks / Subtasks

- [x] Task 1: Create `VoiceParseResult` enum and supporting types (AC: 6)
  - [x] 1.1: Create `HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift` — `Sendable` enum with `.success([ScoreCandidate])`, `.partial(recognized:unresolved:)`, `.failed(transcript:)`
  - [x] 1.2: Create `ScoreCandidate` struct (playerID: String, displayName: String, strokeCount: Int) — `Sendable`
  - [x] 1.3: Create `Token` enum/struct for classified tokens (name, number, noise) — `Sendable`

- [x] Task 2: Create `FuzzyNameMatcher` (AC: 3)
  - [x] 2.1: Create `HyzerKit/Sources/HyzerKit/Voice/FuzzyNameMatcher.swift` — `nonisolated`, `Sendable` struct
  - [x] 2.2: Implement alias map lookup: check `Player.aliases` array for exact case-insensitive match first
  - [x] 2.3: Implement Levenshtein distance fallback: accept >80% match, flag 50-80% as ambiguous, reject <50%
  - [x] 2.4: Initializer takes `[(playerID: String, displayName: String, aliases: [String])]` — no SwiftData dependency
  - [x] 2.5: Write `FuzzyNameMatcherTests.swift` in `HyzerKit/Tests/HyzerKitTests/Voice/`

- [x] Task 3: Create `TokenClassifier` (AC: 2)
  - [x] 3.1: Create `HyzerKit/Sources/HyzerKit/Voice/TokenClassifier.swift` — `nonisolated`, `Sendable` struct
  - [x] 3.2: Classify tokens as `.name(String)`, `.number(Int)`, or `.noise(String)`
  - [x] 3.3: Handle both digit strings ("3") and word numbers ("three") — reject out-of-range (>10)
  - [x] 3.4: Write `TokenClassifierTests.swift` in `HyzerKit/Tests/HyzerKitTests/Voice/`

- [x] Task 4: Create `VoiceParser` with tokenize-classify-assemble pipeline (AC: 2, 4)
  - [x] 4.1: Create `HyzerKit/Sources/HyzerKit/Voice/VoiceParser.swift` — `nonisolated`, `Sendable` struct
  - [x] 4.2: `parse(transcript:players:)` — tokenize transcript by whitespace/commas, classify each token, assemble name-number pairs
  - [x] 4.3: Return `.success` when all names resolved, `.partial` when some unresolved, `.failed` when none resolved
  - [x] 4.4: Handle subset scoring — "Jake 4" alone is valid (only scores Jake)
  - [x] 4.5: Write `VoiceParserTests.swift` in `HyzerKit/Tests/HyzerKitTests/Voice/`

- [x] Task 5: Create `VoiceRecognitionService` iOS-only wrapper (AC: 1, 5)
  - [x] 5.1: Create `HyzerApp/Services/VoiceRecognitionService.swift` — `@MainActor` class, imports `Speech` framework
  - [x] 5.2: Request microphone + speech recognition permissions (throw `VoiceParseError` on denial)
  - [x] 5.3: Configure `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
  - [x] 5.4: `recognize()` async method returns transcript `String` (or throws `VoiceParseError`)
  - [x] 5.5: Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to `project.yml` under HyzerApp target

- [x] Task 6: Create `VoiceParseError` enum (AC: 5)
  - [x] 6.1: Create in `HyzerKit/Sources/HyzerKit/Voice/VoiceParseError.swift` — `Error`, `Sendable`
  - [x] 6.2: Cases: `.microphonePermissionDenied`, `.recognitionUnavailable`, `.noSpeechDetected`

- [x] Task 7: Integration test — voice-to-standings pipeline (AC: 2, 4)
  - [x] 7.1: Create `HyzerKit/Tests/HyzerKitTests/Integration/VoiceToStandingsIntegrationTests.swift`
  - [x] 7.2: Feed transcript string into `VoiceParser.parse()`, assert `VoiceParseResult`, create `ScoreEvent`s via `ScoringService`, call `StandingsEngine.recompute()`, assert correct standings
  - [x] 7.3: No `SFSpeechRecognizer` needed — tests the parser-to-standings pipeline only

## Dev Notes

### Critical Architecture Constraints

**Platform boundary — the cardinal rule:**
- `HyzerKit` must NEVER import `Speech` framework. HyzerKit is compiled for iOS, watchOS, AND macOS. The `Speech` framework is not available on watchOS/macOS.
- `VoiceRecognitionService` (wraps `SFSpeechRecognizer`) lives in `HyzerApp/Services/` ONLY.
- `VoiceParser`, `VoiceParseResult`, `TokenClassifier`, `FuzzyNameMatcher` live in `HyzerKit/Sources/HyzerKit/Voice/` — pure Swift, no platform imports.

**Concurrency boundaries:**
| Component | Isolation | Rationale |
|---|---|---|
| `VoiceParser` | `nonisolated` | Stateless pure functions. No mutable state. Callable without `await`. |
| `VoiceRecognitionService` | `@MainActor` | iOS-only, interacts with UI permission prompts. |
| `FuzzyNameMatcher` | `nonisolated` | Stateless after init. Pure matching logic. |
| `TokenClassifier` | `nonisolated` | Stateless. Pure classification logic. |

**Sendable types crossing boundaries:**
- `VoiceParseResult`, `ScoreCandidate`, `Token`, `VoiceParseError` — all must conform to `Sendable`.

### Voice Pipeline Architecture

```
SFSpeechRecognizer (HyzerApp/Services/)
  → transcript: String
    → VoiceParser.parse(transcript:players:) (HyzerKit/Voice/, nonisolated)
      → tokenize: split by whitespace/commas → [String]
      → classify: TokenClassifier → [Token] (.name/.number/.noise)
      → assemble: pair names with following numbers → [ScoreCandidate]
      → match: FuzzyNameMatcher resolves names against player list
      → return: VoiceParseResult (.success/.partial/.failed)
```

**Latency budget (NFR1 — <3s total voice-to-leaderboard):**
| Stage | Target |
|---|---|
| Speech recognition | ~1-1.5s |
| VoiceParser.parse() | ~50ms |
| ScoreEvent creation | ~10ms |
| SwiftData write | ~10ms |
| Standings recompute | ~20ms |
| Animation trigger | ~500ms |

### Player Model — aliases Field

`Player.aliases: [String]` already exists on the model (`HyzerKit/Sources/HyzerKit/Models/Player.swift:15`). This is the primary input for `FuzzyNameMatcher`. The matcher initializer takes a flattened list of `(playerID, displayName, aliases)` tuples — NOT `Player` objects (no SwiftData dependency in the matcher).

### Score Entry API — Reuse Existing

`ScoringService.createScoreEvent()` is the single entry point for all score creation (`HyzerKit/Sources/HyzerKit/Domain/ScoringService.swift:33`). Voice scoring calls the same method as tap scoring. Do NOT create a separate scoring path.

Parameters needed: `roundID: UUID`, `holeNumber: Int`, `playerID: String`, `strokeCount: Int`, `reportedByPlayerID: UUID`.

### Fuzzy Name Matching Strategy

1. **Alias map (deterministic):** Check `Player.aliases` array for exact case-insensitive match. "Mike" matches if "Mike" is in Michael's aliases.
2. **Display name prefix:** "Mic" matches "Michael" if it's a unique prefix among current players.
3. **Levenshtein distance (fuzzy):** Normalized edit distance. Accept >80% similarity, flag 50-80% as ambiguous (`.partial`), reject <50%.
4. **Confidence thresholds:** Accept >80%, prompt 50-80%, reject <50% (from UX spec).

### Number Parsing Rules

- Accept digit strings: "3", "4", "10"
- Accept word numbers: "one" through "ten"
- Reject out-of-range: anything >10 or <1
- Reject ambiguous: "thirty" (max score is 10)
- Score range enforced: 1-10 (consistent with `ScoringService` precondition)

### Info.plist Keys Required

Add to `project.yml` under HyzerApp target `info` section:
```yaml
NSMicrophoneUsageDescription: "HyzerApp uses the microphone to hear player names and scores for hands-free scoring."
NSSpeechRecognitionUsageDescription: "HyzerApp uses speech recognition to convert spoken scores into game entries. All processing happens on-device."
```

### Testing Standards

- Use **Swift Testing** framework (`@Suite`, `@Test`, `#expect`) — NOT XCTest.
- Test naming: `test_{method}_{scenario}_{expectedBehavior}`
- Test structure: Given/When/Then comments.
- Fixtures: Create `ScoreCandidate+Fixture.swift` if needed, following existing pattern in `HyzerKit/Tests/HyzerKitTests/Fixtures/`.
- `VoiceParserTests`, `TokenClassifierTests`, `FuzzyNameMatcherTests` are pure logic tests — no SwiftData, no simulator.
- `VoiceToStandingsIntegrationTests` uses `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData.
- All test files go in `HyzerKit/Tests/HyzerKitTests/Voice/` (unit) or `HyzerKit/Tests/HyzerKitTests/Integration/` (integration).

### Previous Story Intelligence (from 4-3)

**Patterns to follow:**
- `nonisolated` pure-logic struct pattern: `ConflictDetector` is the template. Stateless, `Sendable`, instantiate inline at call site. Apply same pattern to `VoiceParser`, `TokenClassifier`, `FuzzyNameMatcher`.
- CloudKit-compatible `@Model` design: all properties get defaults. Apply to any new model types.
- Enum-based results without `Equatable`: Use pattern matching in tests (`if case .success = result`). Add `Equatable` to `VoiceParseResult` sub-types where helpful.
- `Set` equality for order-independent assertions: `Set([actual]) == Set([expected])`.

**Known tech debt carried forward:**
- `Task.sleep(for: .milliseconds(100))` in integration tests — acceptable pattern for now, shared test utility is deferred.
- `ValueCollector` test helper duplication — still deferred from 4.2.

### Files This Story Creates

**New files in HyzerKit/Sources/HyzerKit/Voice/:**
- `VoiceParser.swift`
- `VoiceParseResult.swift` (includes `ScoreCandidate`, `Token`)
- `TokenClassifier.swift`
- `FuzzyNameMatcher.swift`
- `VoiceParseError.swift`

**New files in HyzerKit/Tests/HyzerKitTests/Voice/:**
- `VoiceParserTests.swift`
- `TokenClassifierTests.swift`
- `FuzzyNameMatcherTests.swift`

**New files in HyzerKit/Tests/HyzerKitTests/Integration/:**
- `VoiceToStandingsIntegrationTests.swift`

**New file in HyzerApp/Services/:**
- `VoiceRecognitionService.swift`

**Modified files:**
- `project.yml` — add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to HyzerApp info

**NOT modified (no changes needed):**
- `HyzerApp.swift` — no new `@Model` types in this story
- `AppServices.swift` — `VoiceRecognitionService` wiring happens in Story 5.2 when the ViewModel is created
- `Package.swift` — no new dependencies needed

### What This Story Does NOT Include

- No UI (VoiceOverlayView, VoiceOverlayViewModel) — that is Story 5.2
- No auto-commit timer — Story 5.2
- No partial/failed recognition UX handling — Story 5.3
- No `AppServices` wiring — Story 5.2 when the ViewModel ties it together
- No Watch voice support — Epic 7

### Project Structure Notes

- All new `Voice/` source files go under `HyzerKit/Sources/HyzerKit/Voice/` — this directory does not yet exist and must be created.
- All new `Voice/` test files go under `HyzerKit/Tests/HyzerKitTests/Voice/` — this directory does not yet exist.
- `VoiceRecognitionService.swift` goes in `HyzerApp/Services/` alongside existing `LiveCloudKitClient.swift`, `LiveICloudIdentityProvider.swift`, `LiveNetworkMonitor.swift`.
- XcodeGen uses directory-based source scanning — new Swift files in existing target directories are auto-discovered. No `project.yml` source changes needed (only Info.plist keys).
- Run `xcodegen generate` after modifying `project.yml` and before building.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Voice Processing Architecture, lines 377-383]
- [Source: _bmad-output/planning-artifacts/architecture.md — Platform Compilation Constraints, lines 719-727]
- [Source: _bmad-output/planning-artifacts/architecture.md — Concurrency Patterns, lines 604-628]
- [Source: _bmad-output/planning-artifacts/architecture.md — Voice directory structure, lines 843-847]
- [Source: _bmad-output/planning-artifacts/architecture.md — Voice-to-Leaderboard Pipeline, lines 138-158]
- [Source: _bmad-output/planning-artifacts/architecture.md — VoiceParseError enum, lines 584-588]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 5 Story 5.1 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Voice Experience Mechanics, line 390]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Fuzzy matching thresholds, line 1328]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Number parsing rules, line 1328]
- [Source: _bmad-output/implementation-artifacts/4-3-silent-merge-and-discrepancy-detection.md — nonisolated struct pattern]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- TokenClassifier word-number range check: initial implementation omitted range guard for word numbers (e.g. "thirty"). Fixed by broadening wordToNumber map to include out-of-range values (11–100) and applying `(1...10).contains(int)` guard to both digit and word paths.

### Completion Notes List

- All HyzerKit voice types are `nonisolated`, `Sendable`, and import-free (no `Speech` framework).
- `VoiceRecognitionService` lives exclusively in `HyzerApp/Services/` per platform isolation constraint.
- `FuzzyNameMatcher` uses 4-tier matching: alias → display name exact → unique prefix → Levenshtein.
- `TokenClassifier` uses a broad word-number map (one–hundred) with 1–10 range gate to correctly classify out-of-range words as `.noise` rather than `.name`.
- `VoiceParser` assembly step correctly handles name-with-no-number (skips silently) and subset scoring.
- 165 HyzerKit tests pass (0 regressions). iOS build succeeds with iPhone 17 simulator.
- `project.yml` updated with `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`; `xcodegen generate` run and committed.

### File List

- HyzerKit/Sources/HyzerKit/Voice/VoiceParseResult.swift (new)
- HyzerKit/Sources/HyzerKit/Voice/VoiceParseError.swift (new)
- HyzerKit/Sources/HyzerKit/Voice/FuzzyNameMatcher.swift (new)
- HyzerKit/Sources/HyzerKit/Voice/TokenClassifier.swift (new)
- HyzerKit/Sources/HyzerKit/Voice/VoiceParser.swift (new)
- HyzerKit/Tests/HyzerKitTests/Voice/FuzzyNameMatcherTests.swift (new)
- HyzerKit/Tests/HyzerKitTests/Voice/TokenClassifierTests.swift (new)
- HyzerKit/Tests/HyzerKitTests/Voice/VoiceParserTests.swift (new)
- HyzerKit/Tests/HyzerKitTests/Integration/VoiceToStandingsIntegrationTests.swift (new)
- HyzerApp/Services/VoiceRecognitionService.swift (new)
- project.yml (modified — added NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription)
- HyzerApp/App/Info.plist (modified — generated by xcodegen)
