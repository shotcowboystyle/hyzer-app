# Story 8.2: Player Hole-by-Hole Breakdown

Status: ready-for-dev

## Story

As a user,
I want to tap a player in a past round to see their score on every hole,
so that I can review individual performance in detail.

## Acceptance Criteria

1. **Given** the user is viewing a past round's final standings (in `HistoryRoundDetailView`), **when** they tap a player row, **then** the player's hole-by-hole breakdown is displayed (FR61), **and** each hole shows: hole number, par, the player's score, and +/- par for that hole.

2. **Given** the hole-by-hole breakdown is displayed, **when** the user reviews it, **then** scores use the same score-state color coding as the active scoring view: green (`scoreUnderPar`) for under par, white (`scoreAtPar`) for par, amber (`scoreOverPar`) for bogey, red (`scoreWayOver`) for double bogey+, **and** score numbers use `TypographyTokens.score` (SF Mono).

3. **Given** the hole-by-hole breakdown is displayed, **when** the user scrolls to the bottom, **then** a summary row shows the player's total strokes, total par, and overall +/- par with the same color coding as the standings view.

4. **Given** the progressive disclosure pattern, **when** the user navigates History list -> Round detail -> Player breakdown -> Hole-by-hole, **then** the full 4-level progressive disclosure is complete per the UX specification.

## Tasks / Subtasks

- [ ] Task 1: Create `HoleScore` value type and per-hole formatting in HyzerKit (AC: 1, 2)
  - [ ] 1.1 Create `HyzerKit/Sources/HyzerKit/Domain/HoleScore.swift` — `Sendable` struct with `holeNumber`, `par`, `strokeCount`, `relativeToPar`
  - [ ] 1.2 Add `formattedRelativeToPar` computed property: "-1", "E", "+1", "+2" (same format as `Standing.formattedScore`)
  - [ ] 1.3 Add `scoreColor` computed property using 4-tier per-hole logic: `scoreUnderPar` (<0), `scoreAtPar` (==0), `scoreOverPar` (+1), `scoreWayOver` (+2 or more)

- [ ] Task 2: Create `PlayerHoleBreakdownViewModel` (AC: 1, 3)
  - [ ] 2.1 Create `HyzerApp/ViewModels/PlayerHoleBreakdownViewModel.swift` — `@MainActor @Observable final class`
  - [ ] 2.2 Constructor receives `modelContext`, `roundID`, `playerID`, `playerName`
  - [ ] 2.3 `computeBreakdown()` method: fetch all `ScoreEvent`s for the round, fetch `Hole`s for the course, use `resolveCurrentScore(for:hole:in:)` per hole, produce `[HoleScore]` sorted by hole number
  - [ ] 2.4 Expose `holeScores: [HoleScore]`, `totalStrokes`, `totalPar`, `overallRelativeToPar`, `overallFormattedScore`, `overallScoreColor` for summary row

- [ ] Task 3: Create `PlayerHoleBreakdownView` (AC: 1, 2, 3, 4)
  - [ ] 3.1 Create `HyzerApp/Views/History/PlayerHoleBreakdownView.swift` — scrollable list of hole rows
  - [ ] 3.2 Each row: hole number (H3), par (caption), stroke count (score font, score color), +/- par text (body, score color)
  - [ ] 3.3 Summary footer row: totals with overall score formatting
  - [ ] 3.4 Navigation title shows player name
  - [ ] 3.5 Accessibility: combine each row as single element with label "[Hole X], par [Y], scored [Z], [relative] par"

- [ ] Task 4: Wire navigation from `HistoryRoundDetailView` (AC: 4)
  - [ ] 4.1 Wrap `HistoryPlayerRow` in `NavigationLink` pushing to `PlayerHoleBreakdownView`
  - [ ] 4.2 Pass `round.id`, player ID, and player name from the `SummaryPlayerRow` data

- [ ] Task 5: Tests (AC: 1, 2, 3)
  - [ ] 5.1 `HoleScoreTests` in `HyzerKitTests/Domain/` — formatting and color for all 4 score states (under, at, over, way over)
  - [ ] 5.2 `PlayerHoleBreakdownViewModelTests` in `HyzerAppTests/ViewModels/` — breakdown computation, empty holes, summary totals, guest player support, superseded score resolution

## Dev Notes

### Architecture & Patterns

**View hierarchy (progressive disclosure level 3 of 4):**
```
HomeView -> Tab "History" -> HistoryListView (level 1)
                              -> HistoryRoundDetailView (level 2)
                                  -> PlayerHoleBreakdownView (level 3, THIS STORY)
```
Level 3 completes the progressive disclosure: history list -> round detail -> player breakdown -> hole-by-hole scores. No further drill-down is specified — this is the terminal view.

**View mode:** Inspection only. No editing, no scoring, no sync. Pure SwiftData read path.

**Emotional register:** Off-course = warm, unhurried, nostalgic. This is a scrapbook detail view, not a competition view. Use comfortable typography weights.

**ViewModel pattern:** `@MainActor @Observable final class`. Constructor injection of `ModelContext` and identifiers (never `AppServices`). See `HistoryListViewModel` for the exact pattern established in Story 8.1.

**@Query is NOT used here** — unlike `HistoryListView` where `@Query` drives the list, this view displays a fixed set of data for one player in one round. The ViewModel fetches once via `ModelContext` on appear. This matches `HistoryRoundDetailView` which also uses direct `ModelContext` fetch (not `@Query`).

### Score Resolution — Amendment A7

Per-hole scores MUST be resolved using `resolveCurrentScore(for:hole:in:)` from `HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift`. This function returns the leaf-node `ScoreEvent` (the one not superseded by any other event). Never use timestamp-based "most recent" resolution.

The function signature:
```swift
public func resolveCurrentScore(for playerID: String, hole: Int, in events: [ScoreEvent]) -> ScoreEvent?
```

Pattern from `StandingsEngine.computeStandings()`:
```swift
let scoredHoles = Set(allEvents.filter { $0.playerID == playerID }.map(\.holeNumber))
for holeNumber in scoredHoles {
    guard let leaf = resolveCurrentScore(for: playerID, hole: holeNumber, in: allEvents) else { continue }
    totalStrokes += leaf.strokeCount
}
```

### Per-Hole Score Color — 4-Tier vs 3-Tier

`Standing.scoreColor` uses 3 tiers (under/at/over) for aggregate standings. For **individual hole scores**, use 4 tiers per the UX spec:

| Condition | Color Token | Meaning |
|-----------|-------------|---------|
| strokes < par | `Color.scoreUnderPar` (#34C759) | Birdie or better |
| strokes == par | `Color.scoreAtPar` (#F5F5F7) | Par |
| strokes == par + 1 | `Color.scoreOverPar` (#FF9F0A) | Bogey |
| strokes >= par + 2 | `Color.scoreWayOver` (#FF453A) | Double bogey+ |

This is the same color scheme used in the active scoring view (`HoleCardView`). The `scoreWayOver` token already exists in the design system.

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| `resolveCurrentScore(for:hole:in:)` | `HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift` | Call per hole per player to get leaf ScoreEvent |
| `Standing` + `Standing+Formatting` | `HyzerKit/Sources/HyzerKit/Domain/Standing.swift`, `Standing+Formatting.swift` | Reference for `.formattedScore` pattern; use for summary row |
| `StandingsEngine` | `HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift` | Reference `computeStandings()` for fetch-and-resolve pattern; DO NOT call `recompute()` in this view |
| `HistoryRoundDetailView` | `HyzerApp/Views/History/HistoryRoundDetailView.swift` | Modify to add NavigationLink from player rows |
| `RoundSummaryViewModel` + `SummaryPlayerRow` | `HyzerApp/ViewModels/RoundSummaryViewModel.swift` | Player name and ID from `SummaryPlayerRow` for navigation |
| `ScoreEvent`, `Round`, `Hole`, `Course` | `HyzerKit/Sources/HyzerKit/Models/` | SwiftData models for fetching |
| All design tokens | `HyzerKit/Sources/HyzerKit/Design/` | `ColorTokens`, `TypographyTokens`, `SpacingTokens` |
| Test fixtures | `HyzerKit/Tests/HyzerKitTests/Fixtures/` | `ScoreEvent+Fixture`, `Round+Fixture`, `Hole+Fixture`, `Player+Fixture`, `Course+Fixture` |

### HoleScore Design

Create as a lightweight `Sendable` struct in HyzerKit (analogous to `Standing`):

```swift
public struct HoleScore: Identifiable, Sendable, Equatable {
    public let holeNumber: Int
    public let par: Int
    public let strokeCount: Int
    public let relativeToPar: Int  // strokeCount - par

    public var id: Int { holeNumber }
}
```

With a formatting extension (analogous to `Standing+Formatting`):
```swift
extension HoleScore {
    public var formattedRelativeToPar: String { ... }  // "-1", "E", "+1"
    public var scoreColor: Color { ... }  // 4-tier per-hole color
}
```

### PlayerHoleBreakdownViewModel Design

```swift
@MainActor @Observable final class PlayerHoleBreakdownViewModel {
    let playerName: String
    private(set) var holeScores: [HoleScore] = []
    private(set) var totalStrokes: Int = 0
    private(set) var totalPar: Int = 0
    // ... computed: overallRelativeToPar, overallFormattedScore, overallScoreColor

    init(modelContext: ModelContext, roundID: UUID, playerID: String, playerName: String)
    func computeBreakdown()  // Called from .onAppear
}
```

The `computeBreakdown()` method:
1. Fetch `Round` by `roundID` to get `courseID`
2. Fetch `Hole`s by `courseID`, build `parByHole: [Int: Int]` dictionary
3. Fetch all `ScoreEvent`s for the `roundID`
4. For each hole 1...round.holeCount:
   - Call `resolveCurrentScore(for: playerID, hole: holeNumber, in: allEvents)`
   - If resolved: create `HoleScore(holeNumber:, par:, strokeCount:, relativeToPar:)`
   - If no score event: skip (hole not played — shouldn't happen for completed rounds, but handle gracefully)
5. Sort by holeNumber ascending
6. Compute totals from the holeScores array

### Navigation Wiring

`HistoryRoundDetailView` currently renders `HistoryPlayerRow` as a non-interactive view. To wire navigation:

1. Wrap the `ForEach` in `standingsSection` with `NavigationLink` for each row
2. The `HistoryPlayerRow` becomes the label of the `NavigationLink`
3. The destination is `PlayerHoleBreakdownView` initialized with `round.id`, `row.id` (playerID), `row.playerName`, and `modelContext`
4. Add a chevron or other tap affordance to indicate interactivity

Important: `HistoryRoundDetailView` is already inside a `NavigationStack` (via `HistoryListView`'s `NavigationStack`), so `NavigationLink` will push correctly.

### File Structure

**New files to create:**
```
HyzerKit/Sources/HyzerKit/Domain/HoleScore.swift                # Value type + formatting
HyzerApp/Views/History/PlayerHoleBreakdownView.swift             # Hole-by-hole display
HyzerApp/ViewModels/PlayerHoleBreakdownViewModel.swift           # Data fetching + transformation
```

**Files to modify:**
```
HyzerApp/Views/History/HistoryRoundDetailView.swift              # Add NavigationLink from player rows
```

**Test files to create:**
```
HyzerKitTests/Domain/HoleScoreTests.swift                       # Formatting and color tests
HyzerAppTests/ViewModels/PlayerHoleBreakdownViewModelTests.swift # ViewModel computation tests
```

**Update `project.yml`?** No — XcodeGen auto-discovers `.swift` files in the target directories.

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test` macros) — NOT XCTest
- **Naming:** `test_{method}_{scenario}_{expectedBehavior}`
- **Structure:** Given / When / Then
- **SwiftData tests:** `ModelConfiguration(isStoredInMemoryOnly: true)`
- **Test placement:** Domain tests in `HyzerKitTests/Domain/`, ViewModel tests in `HyzerAppTests/ViewModels/`

**Key test cases for `HoleScoreTests`:**
1. `formattedRelativeToPar` returns "-1" for birdie, "E" for par, "+1" for bogey, "+2" for double bogey
2. `scoreColor` returns `scoreUnderPar` for strokes < par
3. `scoreColor` returns `scoreAtPar` for strokes == par
4. `scoreColor` returns `scoreOverPar` for strokes == par + 1
5. `scoreColor` returns `scoreWayOver` for strokes >= par + 2

**Key test cases for `PlayerHoleBreakdownViewModelTests`:**
1. Single player, 3 holes — correct hole scores, totals, and overall relative-to-par
2. Player with corrected score (superseded ScoreEvent) — resolved to leaf node correctly
3. Guest player (playerID starts with "guest:") — breakdown works identically
4. Summary totals match sum of individual hole scores
5. Holes are returned sorted by hole number ascending
6. All 4 score color states appear correctly in the breakdown

### Concurrency

Swift 6 strict concurrency is enforced (`SWIFT_STRICT_CONCURRENCY = complete`). The ViewModel is `@MainActor`. The `computeBreakdown()` method is synchronous (same as `StandingsEngine.recompute`). All `ModelContext` access happens on the main actor. No `DispatchQueue`.

### Scope Boundaries — Do NOT Implement

- Editing scores from history (read-only view)
- Stats, trends, or analytics across rounds
- Sharing individual player breakdowns (share is on the round detail view only)
- Any CloudKit sync changes (history reads local SwiftData only)
- Comparison between players (this shows one player at a time)
- Hole detail beyond par/strokes (no metadata, no notes)

### Previous Story Intelligence (8.1)

**Patterns established in Story 8.1 to follow:**
- `HistoryRoundDetailView` creates `StandingsEngine` and `RoundSummaryViewModel` in a `buildViewModel()` private method called from `.onAppear` — use the same pattern for `PlayerHoleBreakdownViewModel`
- `HistoryPlayerRow` is a private struct in `HistoryRoundDetailView.swift` — it uses `SummaryPlayerRow` data. When adding `NavigationLink`, the player ID and name come directly from `SummaryPlayerRow.id` and `.playerName`
- `ShareSheetRepresentable` was re-implemented as private in `HistoryRoundDetailView` (not extracted) — same isolation pattern applies here
- Course name resolution pattern: `FetchDescriptor<Course>(predicate: #Predicate { $0.id == courseIDLocal })` — use a local `let` for the UUID to satisfy `#Predicate` capture rules
- Date formatting uses `DateFormatter` with `.dateStyle = .medium, .timeStyle = .none` — stored as instance property, not recreated per call
- Score colors stored directly from `Standing.scoreColor` at computation time, not re-derived from strings in the view

**Review fixes from 8.1 (already applied, for awareness):**
- H1: Lazy per-card computation via `onAppear` instead of bulk precompute — same approach needed here (compute on appear, not eagerly)
- M2: Score colors from `Standing.scoreColor` directly, not from string parsing — the new `HoleScore.scoreColor` should follow this pattern

### Project Structure Notes

- New `HoleScore.swift` in `HyzerKit/Sources/HyzerKit/Domain/` follows the convention of domain value types (like `Standing.swift`, `StandingsChange.swift`)
- `PlayerHoleBreakdownView.swift` in `HyzerApp/Views/History/` follows the feature-grouping convention established by Story 8.1
- `PlayerHoleBreakdownViewModel.swift` in `HyzerApp/ViewModels/` (flat — no subdirectory, matches `HistoryListViewModel`, `RoundSummaryViewModel`)
- Test file `HoleScoreTests.swift` goes in `HyzerKitTests/Domain/` alongside `StandingsEngineTests.swift`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 8, Story 8.2] — AC, scope, user story
- [Source: _bmad-output/planning-artifacts/architecture.md#History (FR58-62)] — file paths, view hierarchy, progressive disclosure
- [Source: _bmad-output/planning-artifacts/architecture.md#Amendment A7] — leaf-node score resolution (supersession chain, not timestamp)
- [Source: _bmad-output/planning-artifacts/architecture.md#Derived State] — StandingsEngine pattern
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 8: Browsing History] — progressive disclosure 4 levels
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Score-State Color Tokens] — 4-tier color coding including wayOver
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Typography Scale] — SF Mono for scores, off-course browsing weights
- [Source: HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift] — `resolveCurrentScore(for:hole:in:)` function
- [Source: HyzerKit/Sources/HyzerKit/Domain/Standing+Formatting.swift] — `.formattedScore`, `.scoreColor` pattern
- [Source: HyzerApp/Views/History/HistoryRoundDetailView.swift] — navigation entry point, player row structure
- [Source: HyzerApp/ViewModels/HistoryListViewModel.swift] — ViewModel pattern reference
- [Source: _bmad-output/implementation-artifacts/8-1-history-list-and-round-detail.md] — previous story implementation details and review findings

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
