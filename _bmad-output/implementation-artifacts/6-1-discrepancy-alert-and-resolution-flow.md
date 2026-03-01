# Story 6.1: Discrepancy Alert & Resolution Flow

Status: review

## Story

As a round organizer,
I want to see conflicting scores side-by-side with who recorded each and resolve the conflict with a single tap,
so that score disputes are handled fairly without disrupting the round.

## Acceptance Criteria (BDD)

### AC1: Organizer-only notification of discrepancies

**Given** the `ConflictDetector` flags a discrepancy for a {player, hole} during `SyncEngine.pullRecords()`
**When** the discrepancy is persisted as a `Discrepancy` record with status `.unresolved`
**Then** only the round organizer sees an in-app discrepancy badge on the leaderboard pill (FR49)
**And** non-organizer participants see no badge or notification about the conflict

### AC2: Side-by-side conflict display with attribution

**Given** the organizer taps the discrepancy badge or opens the discrepancy list
**When** the conflicting scores are displayed
**Then** both values are shown side-by-side with attribution: player name, hole number, score A recorded by Person X, score B recorded by Person Y, with timestamps (FR50)
**And** the view uses design tokens (`TypographyTokens.h2` for header, `score` for values, `caption` for attribution)
**And** accessibility labels describe both options fully for VoiceOver

### AC3: Single-tap resolution creating authoritative ScoreEvent

**Given** the organizer taps the correct score in the resolution view
**When** the resolution is confirmed
**Then** a new authoritative `ScoreEvent` is created with the selected `strokeCount` (FR52)
**And** the new event's `reportedByPlayerID` is set to the organizer's Player.id
**And** the new event's `supersedesEventID` is `nil` (authoritative resolution, not a correction chain)
**And** the `Discrepancy` record is updated: `status = .resolved`, `resolvedByEventID` = new event's id
**And** `StandingsEngine.recompute(for:trigger:.conflictResolution)` is called
**And** the resolution event is persisted to SwiftData (syncs to CloudKit via normal push flow)

### AC4: Silent leaderboard update for non-organizer participants

**Given** a discrepancy is resolved by the organizer
**When** other participants' devices sync the resolution ScoreEvent via `pullRecords()`
**Then** their leaderboards update silently with no notification about the conflict (FR51)
**And** `resolveCurrentScore()` returns the authoritative score (leaf-node resolution handles it)

### AC5: Multiple discrepancy handling

**Given** multiple unresolved discrepancies exist for a round
**When** the organizer views the discrepancy list
**Then** each discrepancy is listed separately with player name + hole number
**And** each can be resolved independently in sequence
**And** the badge count reflects the remaining unresolved count
**And** the badge clears when all discrepancies are resolved

### AC6: Discrepancy badge on leaderboard pill

**Given** unresolved discrepancies exist for the current round
**When** the current user is the round organizer
**Then** a count badge appears on the leaderboard pill (e.g., red circle with number)
**And** tapping the badge presents the discrepancy resolution sheet
**And** the badge animates in using `AnimationTokens.springGentle` (reduce-motion aware)

## Tasks / Subtasks

- [x] Task 1: Create `DiscrepancyViewModel` (AC: #1, #2, #3, #5)
  - [x] 1.1 Create `HyzerApp/ViewModels/DiscrepancyViewModel.swift` as `@MainActor @Observable final class`
  - [x] 1.2 Constructor injection: `scoringService: ScoringService`, `standingsEngine: StandingsEngine`, `modelContext: ModelContext`, `roundID: UUID`, `organizerID: UUID`, `currentPlayerID: UUID`
  - [x] 1.3 Computed property `isOrganizer: Bool` — compares `currentPlayerID == organizerID`
  - [x] 1.4 Method `loadUnresolved()` — fetches `Discrepancy` records where `roundID` matches and `status == .unresolved`, stores in `unresolvedDiscrepancies: [Discrepancy]`
  - [x] 1.5 Method `loadConflictingEvents(for discrepancy: Discrepancy) -> (ScoreEvent, ScoreEvent)?` — fetches `ScoreEvent` by `eventID1` and `eventID2` from ModelContext
  - [x] 1.6 Method `resolve(discrepancy: Discrepancy, selectedStrokeCount: Int, playerID: String, holeNumber: Int) throws` — creates authoritative ScoreEvent via `scoringService`, updates Discrepancy status to `.resolved`, sets `resolvedByEventID`, calls `standingsEngine.recompute(for:trigger:.conflictResolution)`
  - [x] 1.7 Published state: `unresolvedDiscrepancies: [Discrepancy]`, `selectedDiscrepancy: Discrepancy?`, `resolveError: Error?`
  - [x] 1.8 Computed `badgeCount: Int` — count of `unresolvedDiscrepancies`

- [x] Task 2: Create `DiscrepancyResolutionView` (AC: #2, #3, #6)
  - [x] 2.1 Create `HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift`
  - [x] 2.2 Header: "Score Discrepancy" (`TypographyTokens.h2`) + player name + "Hole [n]"
  - [x] 2.3 Two score options side-by-side: score value (`TypographyTokens.score`), "Recorded by [name]" (`TypographyTokens.caption`), timestamp (`TypographyTokens.caption`)
  - [x] 2.4 Each option is a tappable card with `SpacingTokens.scoringTouchTarget` minimum hit area
  - [x] 2.5 On tap: call `viewModel.resolve(discrepancy:selectedStrokeCount:playerID:holeNumber:)`, dismiss view
  - [x] 2.6 No confirmation dialog — "confidence through feedback, not confirmation" (UX principle)
  - [x] 2.7 Accessibility: `accessibilityLabel` describing both options for VoiceOver — "Score discrepancy for [player] on hole [n]. Option one: [score], recorded by [name]. Option two: [score], recorded by [name]. Tap to select correct score."
  - [x] 2.8 Present as `.sheet` with `.presentationDetents([.medium])`

- [x] Task 3: Create `DiscrepancyListView` for multiple discrepancies (AC: #5)
  - [x] 3.1 Create `HyzerApp/Views/Discrepancy/DiscrepancyListView.swift`
  - [x] 3.2 List of unresolved discrepancies, each showing player name + hole number
  - [x] 3.3 Tapping a row sets `viewModel.selectedDiscrepancy` and navigates to `DiscrepancyResolutionView`
  - [x] 3.4 If only 1 unresolved discrepancy, skip list and go directly to resolution view

- [x] Task 4: Add discrepancy badge to `LeaderboardPillView` (AC: #1, #6)
  - [x] 4.1 Modify `HyzerApp/Views/Leaderboard/LeaderboardPillView.swift` to accept an optional `badgeCount: Int`
  - [x] 4.2 When `badgeCount > 0` and user is organizer: show red circle badge with count overlay on the pill
  - [x] 4.3 Badge uses `ColorTokens.accentPrimary` background, white text, `TypographyTokens.caption` font
  - [x] 4.4 Badge animates in with `AnimationTokens.springGentle` (reduce-motion aware via `AnimationCoordinator`)
  - [x] 4.5 Tapping badge triggers discrepancy sheet presentation (separate from leaderboard expanded tap)

- [x] Task 5: Integrate discrepancy flow into `ScorecardContainerView` (AC: #1, #5, #6)
  - [x] 5.1 Modify `HyzerApp/Views/Scoring/ScorecardContainerView.swift`
  - [x] 5.2 Add `@Query` for `Discrepancy` records filtered by current round
  - [x] 5.3 Compute `unresolvedDiscrepancies` from query results (status == `.unresolved`)
  - [x] 5.4 Create `DiscrepancyViewModel` when unresolved discrepancies exist and user is organizer
  - [x] 5.5 Pass `badgeCount` to `LeaderboardPillView`
  - [x] 5.6 Present discrepancy sheet (list or single resolution) via `.sheet` modifier
  - [x] 5.7 Guard: non-organizer participants see NO discrepancy UI

- [x] Task 6: Handle resolution ScoreEvent in sync flow (AC: #4)
  - [x] 6.1 Verified `SyncEngine.pullRecords()` would flag resolution events as potential discrepancies — added deduplication guard to `SyncEngine` that skips creating a new `Discrepancy` if one already exists for the same {roundID, playerID, holeNumber}
  - [x] 6.2 `resolveCurrentScore()` leaf-node resolution handles the authoritative event — no changes needed
  - [x] 6.3 `DiscrepancyViewModel.loadUnresolved()` filters to `status == .unresolved` — resolved discrepancies never re-surface in the UI
  - [x] 6.4 `SyncEngine` deduplication change is the only SyncEngine modification (targeted guard before Discrepancy insert)

- [x] Task 7: Create `DiscrepancyViewModelTests` (AC: #1, #2, #3, #5)
  - [x] 7.1 Create `HyzerAppTests/DiscrepancyViewModelTests.swift` using Swift Testing (`@Suite`, `@Test`)
  - [x] 7.2 Test: `test_isOrganizer_matchingPlayerID_returnsTrue`
  - [x] 7.3 Test: `test_isOrganizer_differentPlayerID_returnsFalse`
  - [x] 7.4 Test: `test_loadUnresolved_filtersToCurrentRound_unresolvedOnly`
  - [x] 7.5 Test: `test_loadConflictingEvents_returnsBothScoreEvents`
  - [x] 7.6 Test: `test_resolve_createsAuthoritativeScoreEvent_withCorrectFields`
  - [x] 7.7 Test: `test_resolve_updatesDiscrepancyStatus_toResolved`
  - [x] 7.8 Test: `test_resolve_setsResolvedByEventID`
  - [x] 7.9 Test: `test_resolve_callsStandingsRecompute_withConflictResolutionTrigger`
  - [x] 7.10 Test: `test_resolve_multipleDiscrepancies_resolvedSequentially`
  - [x] 7.11 Test: `test_badgeCount_reflectsUnresolvedCount`

- [x] Task 8: Verify sync round-trip for resolution (AC: #4)
  - [x] 8.1 Added `test_pullRecords_resolutionScoreEvent_doesNotCreateDuplicateDiscrepancy` and `test_pullRecords_resolutionScoreEvent_updatesLeaderboardSilently` to `HyzerKitTests/SyncEngineConflictTests.swift` — both pass
  - [x] 8.2 Deduplication guard in `SyncEngine` prevents `ConflictDetector` from creating a second Discrepancy when the resolution event is pulled on remote devices

## Dev Notes

### Organizer Role Decision

**Architecture flags a simplification opportunity:** Allow any player to resolve discrepancies (not just organizer). Rationale: organizer's phone is a single point of failure (dead battery, dropped in water). For 6 friends who trust each other, organizer-only adds friction.

**PRD says organizer-only (FR49).** Status: "Requires product owner approval before implementation."

**Implementation approach:** Follow the PRD (organizer-only) as written. The authorization check is a single `isOrganizer` guard — trivially changeable to any-player if approved later. The `reportedByPlayerID` on the resolution ScoreEvent provides full auditability regardless.

### Resolution ScoreEvent Design

The resolution creates a **new authoritative ScoreEvent** — NOT a correction chain. Key fields:

| Field | Value | Rationale |
|---|---|---|
| `strokeCount` | Organizer-selected value | The resolved score |
| `playerID` | Same as the discrepancy's `playerID` | Score for the same player |
| `holeNumber` | Same as the discrepancy's `holeNumber` | Score for the same hole |
| `roundID` | Same as the discrepancy's `roundID` | Same round |
| `reportedByPlayerID` | Organizer's Player.id | Audit trail: who resolved |
| `supersedesEventID` | `nil` | Not a correction — authoritative resolution |
| `deviceID` | Current device ID | Standard field |

`resolveCurrentScore()` will pick up this event as a leaf node. The two conflicting events are also leaf nodes, but the resolution event's presence means three leaf nodes exist for the same {player, hole}. The deterministic resolution (earliest `createdAt`) would return one of the originals.

**Important consideration:** After resolution, the `ConflictDetector` may flag the resolution event as a new silent merge or discrepancy against the existing conflicting events. To avoid this:
- The `Discrepancy` record is marked `.resolved` — the ViewModel filters these out
- On remote devices, `pullRecords()` will call `ConflictDetector.check()` for the resolution event — it may create a new `Discrepancy` since it sees multiple events with different strokeCounts from different devices
- **Mitigation:** After the organizer resolves, the Discrepancy for {roundID, playerID, holeNumber} already exists. The dev agent should verify whether `SyncEngine` deduplicates discrepancies by {roundID, playerID, holeNumber} or creates duplicates. If duplicates are possible, add deduplication logic: skip creating a new Discrepancy if one already exists for the same {roundID, playerID, holeNumber}

### Architecture Constraints (MUST follow)

**ViewModel Pattern:**
- `@MainActor @Observable final class` — same pattern as `LeaderboardViewModel`, `ScorecardViewModel`
- Constructor injection of individual services — NEVER inject the full `AppServices` container
- Error state as `resolveError: Error?` property — same pattern as `ScorecardViewModel.saveError`

**View Pattern:**
- Views receive ViewModels via constructor or `@Environment`
- Use `@Query` for SwiftData fetches in views
- Design tokens ONLY — never hardcode colors, fonts, spacing, or animation durations
- Accessibility: VoiceOver labels on all interactive elements, `@ScaledMetric` support via typography tokens
- Reduce-motion: use `AnimationCoordinator.animation()` which respects `accessibilityReduceMotion`

**Event Sourcing Invariants:**
- `ScoreEvent` is append-only and immutable (NFR19) — resolution creates a NEW event, never mutates existing ones
- `Discrepancy` resolution updates `status` and `resolvedByEventID` — this is the ONE place where a Discrepancy is mutated (status transition from `.unresolved` to `.resolved`)
- No UPDATE or DELETE on ScoreEvent — ever

**Concurrency Model (Swift 6 strict):**
- `DiscrepancyViewModel` is `@MainActor` — called from SwiftUI views
- `ScoringService` is `@MainActor` — safe to call from ViewModel
- `StandingsEngine` is `@MainActor` — safe to call from ViewModel
- No new actor boundaries introduced in this story

### Existing Code to Reuse (DO NOT reinvent)

| Component | Location | How to use |
|---|---|---|
| `Discrepancy` model | `HyzerKit/Models/Discrepancy.swift` | Query for unresolved, update status on resolution |
| `DiscrepancyStatus` enum | `HyzerKit/Models/Discrepancy.swift` | `.unresolved` → `.resolved` transition |
| `ConflictDetector` | `HyzerKit/Domain/ConflictDetector.swift` | Already creates discrepancies — no changes needed |
| `SyncEngine.pullRecords()` | `HyzerKit/Sync/SyncEngine.swift` | Already inserts Discrepancy records — verify round-trip |
| `ScoringService.createScoreEvent()` | `HyzerKit/Domain/ScoringService.swift` | Create the resolution ScoreEvent |
| `StandingsEngine.recompute()` | `HyzerKit/Domain/StandingsEngine.swift` | Call with `.conflictResolution` trigger after resolution |
| `StandingsChangeTrigger.conflictResolution` | `HyzerKit/Domain/StandingsChangeTrigger.swift` | Already defined — use it now |
| `resolveCurrentScore()` | `HyzerKit/Domain/ScoreResolution.swift` | Leaf-node resolution handles authoritative event |
| `Round.organizerID` | `HyzerKit/Models/Round.swift` | Check organizer status |
| `ScoreEvent` model | `HyzerKit/Models/ScoreEvent.swift` | Read `reportedByPlayerID`, `strokeCount`, `deviceID` for display |
| `Player` model | `HyzerKit/Models/Player.swift` | Fetch `displayName` for attribution text |
| `ColorTokens` | `HyzerKit/Design/ColorTokens.swift` | Badge color, score colors |
| `TypographyTokens` | `HyzerKit/Design/TypographyTokens.swift` | `h2`, `score`, `caption` |
| `SpacingTokens` | `HyzerKit/Design/SpacingTokens.swift` | `sm`, `md`, `lg`, `scoringTouchTarget` |
| `AnimationTokens` | `HyzerKit/Design/AnimationTokens.swift` | `springGentle` for badge animation |
| `AnimationCoordinator` | `HyzerKit/Design/AnimationCoordinator.swift` | Reduce-motion aware animation wrapper |
| `LeaderboardPillView` | `HyzerApp/Views/Leaderboard/LeaderboardPillView.swift` | Add badge overlay |
| `ScorecardContainerView` | `HyzerApp/Views/Scoring/ScorecardContainerView.swift` | Integration point for discrepancy flow |
| `LeaderboardViewModel` | `HyzerApp/ViewModels/LeaderboardViewModel.swift` | Pattern reference for ViewModel structure |
| `ScorecardViewModel` | `HyzerApp/ViewModels/ScorecardViewModel.swift` | Pattern reference for error handling, service injection |
| `Discrepancy+Fixture` | `HyzerKitTests/Fixtures/Discrepancy+Fixture.swift` | Test data factory |
| `ScoreEvent+Fixture` | `HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift` | Test data for conflicting events |
| `Round+Fixture` | `HyzerKitTests/Fixtures/Round+Fixture.swift` | Test data with `organizerID` |

### File Structure

**New files to create:**

```
HyzerApp/ViewModels/
└── DiscrepancyViewModel.swift         # @MainActor @Observable, resolution logic

HyzerApp/Views/Discrepancy/
├── DiscrepancyResolutionView.swift     # Side-by-side conflict display + tap-to-resolve
└── DiscrepancyListView.swift          # List of unresolved discrepancies (if multiple)

HyzerAppTests/
└── DiscrepancyViewModelTests.swift    # Comprehensive ViewModel tests
```

**Files to modify:**

```
HyzerApp/Views/Leaderboard/LeaderboardPillView.swift   # Add discrepancy badge overlay
HyzerApp/Views/Scoring/ScorecardContainerView.swift    # Integrate discrepancy query + sheet
```

### What This Story Does NOT Do (Scope Boundary)

- **NO changes to `ConflictDetector`** — detection logic is complete from Story 4.3
- **NO changes to `SyncEngine`** — discrepancy creation during pull is complete from Story 4.3
- **NO changes to `Discrepancy` model** — schema is complete from Story 4.3
- **NO push notification for discrepancies** — in-app badge only (MVP, per UX spec)
- **NO Watch discrepancy UI** — phone-only (Watch shows leaderboard result after resolution)
- **NO changes to `resolveCurrentScore()`** — existing leaf-node resolution handles it
- **NO changes to `StandingsChangeTrigger`** — `.conflictResolution` already defined
- **NO any-player resolution** — PRD says organizer-only (FR49), deviation requires product owner approval

### Previous Story Intelligence (from Story 4.3)

**Key patterns from 4.3:**
- `ConflictDetector` is `nonisolated struct` — pure logic, no SwiftData queries
- `Discrepancy` records created in `SyncEngine.pullRecords()` after conflict detection
- `DiscrepancyStatus` uses String-backed `RawRepresentable` enum (same as `SyncStatus`)
- Test count after 4.3: 136 tests → now 166 tests (30 added by Epic 5)
- `ConflictResult.discrepancy(existingEventID: UUID, incomingEventID: UUID)` uses UUIDs, not full ScoreEvent references (Sendable safety)
- Review found: `ConflictResult` missing `Equatable` — still not added (functional but verbose assertions)

**4.3 deferred items relevant to 6.1:**
- The `Discrepancy` model's `resolvedByEventID` field has been unused until this story
- `StandingsChangeTrigger.conflictResolution` has been defined but unused until this story

### Git Intelligence

**Recent commit patterns (Epic 5):**
- Feature branches: `feature/story-5-1-*`, `feature/story-5-2-*`, `feature/story-5-3-*`
- Squash merges to main via GitHub PR
- Commit style: `feat(scope): description` for features, `test(scope): description` for tests
- Stories 5.1-5.3 all added Voice features — no overlap with this story's files

### UX Design Specifications

**From UX Spec — Discrepancy Resolution View (Component #9):**
- Alert header: "Score Discrepancy" (H2) + player name + hole number
- Two score options side by side with attribution ("Recorded by [name]", timestamp)
- Each option has enough padding for comfortable tap target
- States: Presented → Selection → Resolved
- Multiple discrepancies: badge shows count, each resolved individually
- No confirmation dialog — "confidence through feedback, not confirmation"
- Accessibility: Full VoiceOver description of both options

**Sync state indicator pattern:**
- Badge on leaderboard pill for organizer (count indicator)
- Non-organizers see leaderboard update silently after resolution
- Design principle: "Agree silently, disagree loudly"

### Testing Standards

- Use **Swift Testing** (`@Suite`, `@Test`, `#expect`) — NOT XCTest
- Test naming: `test_{method}_{scenario}_{expectedBehavior}`
- Test structure: Given/When/Then comments
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData tests
- Fixture pattern: `Discrepancy.fixture(...)`, `ScoreEvent.fixture(...)`, `Round.fixture(...)`
- DiscrepancyViewModel tests need SwiftData (in-memory) for model queries
- Mock `ScoringService` if needed for isolating ViewModel logic (or use real service with in-memory store)
- Current test baseline: 166 HyzerKit tests passing

### Project Structure Notes

- `DiscrepancyViewModel` lives in `HyzerApp/ViewModels/` — same directory as `LeaderboardViewModel`, `ScorecardViewModel`
- Views live in `HyzerApp/Views/Discrepancy/` — new subdirectory following the pattern of `Views/Scoring/`, `Views/Leaderboard/`
- Tests live in `HyzerAppTests/` — ViewModel tests alongside existing ViewModel test files
- No changes to `HyzerKit` — all new code is presentation/ViewModel layer in the app target

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 6, Story 6.1: Discrepancy Alert & Resolution Flow]
- [Source: _bmad-output/planning-artifacts/architecture.md — Simplification Opportunity: Organizer Role]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Architecture: Conflict Detection (four cases)]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Architecture: ScoreEvent fields (supersedesEventID, reportedByPlayerID, deviceID)]
- [Source: _bmad-output/planning-artifacts/architecture.md — Core Architectural Decisions: StandingsEngine with .conflictResolution trigger]
- [Source: _bmad-output/planning-artifacts/architecture.md — Project Structure: Views/Discrepancy/, ViewModels/DiscrepancyViewModel]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Component #9: Discrepancy Resolution View]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 7: Score Discrepancy Resolution]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Sync State Communication: "Agree silently, disagree loudly"]
- [Source: _bmad-output/planning-artifacts/prd.md — FR49, FR50, FR51, FR52]
- [Source: _bmad-output/planning-artifacts/prd.md — NFR19: Event-sourced scoring, append-only]
- [Source: _bmad-output/implementation-artifacts/4-3-silent-merge-and-discrepancy-detection.md — ConflictDetector, Discrepancy model, SyncEngine integration]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — build succeeded on first attempt.

### Completion Notes List

- Implemented `DiscrepancyViewModel` as `@MainActor @Observable final class` with full constructor injection. `resolve()` does not throw — errors are caught, logged via `os.log`, and stored in `resolveError` matching the `ScorecardViewModel` pattern.
- Created `DiscrepancyResolutionView` with side-by-side score cards, VoiceOver accessibility labels, reduce-motion aware animation, and no confirmation dialog per UX spec.
- Created `DiscrepancyListView` with auto-skip to resolution view when only 1 discrepancy exists. Shows player name + hole number per row with minimum touch target.
- Modified `LeaderboardPillView` to accept optional `badgeCount: Int` and `onBadgeTap: (() -> Void)?`. Badge uses `Color.scoreWayOver` (red) per design token, animates with `AnimationTokens.springGentle` and `AnimationCoordinator` for reduce-motion support. Badge tap is separate from pill tap (AC6).
- Integrated discrepancy flow into `ScorecardContainerView` via `@Query` on `Discrepancy` model, `updateDiscrepancyViewModel()` helper, and `.sheet` presenter. Non-organizer guard enforced by not creating `DiscrepancyViewModel` (AC1).
- **Task 6 finding:** `SyncEngine` did NOT deduplicate Discrepancy records by {roundID, playerID, holeNumber}. Added a pre-fetch + guard before inserting Discrepancy to prevent the resolution ScoreEvent (which has `supersedesEventID = nil`) from triggering a second Discrepancy on remote devices. This is the Dev Notes mitigation applied.
- All 11 `DiscrepancyViewModelTests` written using Swift Testing with in-memory `ModelContainer`. Tests run as part of `HyzerAppTests` iOS target.
- Added 2 integration tests to `SyncEngineConflictTests.swift` verifying: (a) resolution event does not create a second Discrepancy, (b) resolved Discrepancy status is preserved after pull. HyzerKit test count: 166 → 168.
- Build: `xcodebuild BUILD SUCCEEDED` with no errors, only pre-existing asset warnings.

### File List

New files:
- `HyzerApp/ViewModels/DiscrepancyViewModel.swift`
- `HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift`
- `HyzerApp/Views/Discrepancy/DiscrepancyListView.swift`
- `HyzerAppTests/DiscrepancyViewModelTests.swift`

Modified files:
- `HyzerApp/Views/Leaderboard/LeaderboardPillView.swift`
- `HyzerApp/Views/Scoring/ScorecardContainerView.swift`
- `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift`
- `HyzerKit/Tests/HyzerKitTests/SyncEngineConflictTests.swift`
- `HyzerApp.xcodeproj/project.pbxproj`
- `_bmad-output/implementation-artifacts/6-1-discrepancy-alert-and-resolution-flow.md`
