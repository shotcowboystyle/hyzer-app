# Story 8.1: History List & Round Detail

Status: ready-for-dev

## Story

As a user,
I want to browse my past rounds and see who won each one,
so that I can revisit competitive memories and settle friendly debates.

## Acceptance Criteria

1. **Given** the user navigates to the History tab, **when** the round history loads, **then** completed rounds are displayed in reverse chronological order as a card feed (FR59), **and** each card shows: course name, date, player count, winner and their score, the user's finishing position and score.

2. **Given** the user taps a round card, **when** the round detail view loads, **then** full final standings are displayed with all players, their +/- par scores, and finishing positions (FR60), **and** round metadata is visible: date, course name, who organized.

3. **Given** no completed rounds exist, **when** the history tab is shown, **then** the empty state reads "Your round history will appear here after your first completed round." with `Color.textSecondary`, centered.

4. **Given** rounds accumulate over time (~50 rounds/year), **when** the history list is scrolled, **then** performance remains smooth — SwiftData `@Query` handles all filtering/sorting natively (FR62, NFR21: 250+ rounds, <50MB over 5 years).

5. **Given** the round detail view is showing, **when** the user taps the share button, **then** a screenshot-optimized image is shared via the system share sheet (reuse existing `RoundSummaryViewModel.shareSnapshot`).

## Tasks / Subtasks

- [ ] Task 1: Create `HistoryListView` + `HistoryListViewModel` (AC: 1, 3)
  - [ ] 1.1 Create `HyzerApp/Views/History/HistoryListView.swift` with `@Query` for completed rounds
  - [ ] 1.2 Create `HyzerApp/ViewModels/HistoryListViewModel.swift` — resolves course names, computes winner/user position for each round card
  - [ ] 1.3 Create `HistoryRoundCard` subview inside `HistoryListView.swift` — compact card showing course, date, player count, winner, user position
  - [ ] 1.4 Implement empty state when `completedRounds.isEmpty`
- [ ] Task 2: Wire History tab in `HomeView.swift` (AC: 1)
  - [ ] 2.1 Replace placeholder `HistoryTabView` body with `HistoryListView` inside `NavigationStack`
- [ ] Task 3: Create `HistoryRoundDetailView` for full standings on tap (AC: 2, 5)
  - [ ] 3.1 Create `HyzerApp/Views/History/HistoryRoundDetailView.swift` — reuse `RoundSummaryViewModel` to display final standings
  - [ ] 3.2 Wire `NavigationLink` from `HistoryRoundCard` to `HistoryRoundDetailView`
  - [ ] 3.3 Include share button using existing `RoundSummaryViewModel.shareSnapshot(displayScale:)`
- [ ] Task 4: Tests (AC: 1, 2, 3, 4)
  - [ ] 4.1 `HistoryListViewModelTests` in `HyzerAppTests/ViewModels/` — card data derivation, empty state, reverse-chronological ordering
  - [ ] 4.2 SwiftData integration test: query returns only `status == "completed"` rounds sorted by `completedAt` descending

## Dev Notes

### Architecture & Patterns

**View hierarchy (progressive disclosure levels 1-2 of 4):**
```
HomeView → Tab "History" → HistoryListView (level 1)
                            └→ NavigationLink → HistoryRoundDetailView (level 2)
```
Level 3 (player hole-by-hole breakdown) is Story 8.2 scope — do NOT implement it here.

**@Query lives in the View, not the ViewModel** — this is the established codebase pattern (see `ScoringTabView` in `HomeView.swift`). The ViewModel handles data transformation only.

**`@Query` for completed rounds:**
```swift
@Query(
    filter: #Predicate<Round> { $0.status == "completed" },
    sort: \Round.completedAt,
    order: .reverse
) private var completedRounds: [Round]
```

**ViewModel pattern** — `@MainActor @Observable final class`. Constructor injection of individual services (never `AppServices`). See `RoundSummaryViewModel` for the exact pattern.

**`HistoryListViewModel` responsibilities:**
- Receive a `ModelContext` to query `Course` (for course name by `round.courseID`), `ScoreEvent` + `Hole` + `Player` (for winner/user standings per card)
- For each round card: derive winner name, winner score, user's position and score using `StandingsEngine.recompute(for:trigger:)` or a lighter-weight standalone computation
- Player count = `round.playerIDs.count + round.guestNames.count`
- Performance note: computing standings for every card in a long list is expensive. Consider lazy computation — only compute for visible cards, or compute on-demand when the list row appears. `StandingsEngine` requires `ModelContext`, so pass it through.

**Reuse `RoundSummaryViewModel`** for the detail view — it already formats standings, date, course name, organizer, and share snapshot. Create it with the round's final standings (computed via `StandingsEngine`), the resolved course name, hole count, and course par sum.

**Date formatting:** Use `DateFormatter` with `.dateStyle = .medium, .timeStyle = .none` — same as `RoundSummaryViewModel`.

**Guest player identification:** `playerID` strings starting with `"guest:"` are guests. See `ScoreEvent.swift` and `Standing.swift`.

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| `RoundSummaryViewModel` | `HyzerApp/ViewModels/RoundSummaryViewModel.swift` | Instantiate for detail view with computed standings |
| `RoundSummaryView` | `HyzerApp/Views/Scoring/RoundSummaryView.swift` | Reference layout patterns; detail view can reuse or adapt |
| `SummaryPlayerRow` | Inside `RoundSummaryViewModel.swift` | Value type for player row display data |
| `Standing` + `Standing+Formatting` | `HyzerKit/Sources/HyzerKit/Domain/Standing.swift`, `Standing+Formatting.swift` | `.formattedScore`, `.scoreColor` for +/- par display |
| `StandingsEngine` | `HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift` | `.recompute(for:trigger:)` to derive final standings |
| `Round.isCompleted` | `HyzerKit/Sources/HyzerKit/Models/Round.swift` | Computed property checking `status == "completed"` |
| All design tokens | `HyzerKit/Sources/HyzerKit/Design/` | `ColorTokens`, `TypographyTokens`, `SpacingTokens`, `AnimationTokens` |
| `AnimationCoordinator` | `HyzerKit/Sources/HyzerKit/Design/AnimationCoordinator.swift` | Reduce-motion-aware animation helper |
| Fixtures | `HyzerKit/Tests/HyzerKitTests/Fixtures/` | `Round+Fixture`, `ScoreEvent+Fixture`, `Player+Fixture`, `Course+Fixture`, `Hole+Fixture` |

### Design System Requirements

**Emotional register:** Off-course = warm, unhurried, nostalgic. NOT competitive intensity. History is a scrapbook, not a spreadsheet.

**History Round Card anatomy (from UX spec):**
- Course name (`TypographyTokens.h3`, left-aligned)
- Date (`TypographyTokens.caption`, `Color.textSecondary`)
- Player count ("6 players", `TypographyTokens.caption`)
- Winner: "[name] won at [score]" (`TypographyTokens.body`, score in `standing.scoreColor`)
- User position: "You finished [nth] at [score]" (`TypographyTokens.body`, score in `standing.scoreColor`)
- Tap affordance (chevron or card elevation)
- Background: `Color.backgroundElevated` card on `Color.backgroundPrimary`

**Card sizing:** Compact enough for 3-4 visible per screen. Target heights per device class:
- 375pt width (SE): 3 cards visible
- 390pt width (standard): 3.5 cards (peek)
- 430pt width (Plus/Max): 4 cards visible

**Accessibility:**
- Each card: `.accessibilityLabel("[Course name], [date]. [Winner] won at [score]. You finished [position].")`
- Use `.accessibilityElement(children: .combine)` on each card
- All typography via `TypographyTokens` (auto-scales with Dynamic Type/AX3)

**Animation:** Minimal for history. If any transition is used, respect `@Environment(\.accessibilityReduceMotion)` via `AnimationCoordinator`. No animations > 0.5s.

**Score colors (universal):**
- Under par → `Color.scoreUnderPar` (#34C759)
- At par → `Color.scoreAtPar` (#F5F5F7)
- Over par → `Color.scoreOverPar` (#FF9F0A)
- Double bogey+ → `Color.scoreWayOver` (#FF453A)

### File Structure

**New files to create:**
```
HyzerApp/Views/History/HistoryListView.swift       # List + card subview
HyzerApp/Views/History/HistoryRoundDetailView.swift # Detail with full standings
HyzerApp/ViewModels/HistoryListViewModel.swift      # Card data derivation
```

**Files to modify:**
```
HyzerApp/Views/HomeView.swift                       # Replace HistoryTabView placeholder
```

**Test files to create:**
```
HyzerAppTests/ViewModels/HistoryListViewModelTests.swift
```

**Update `project.yml`?** No — XcodeGen auto-discovers `.swift` files in the target directories.

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test` macros) — NOT XCTest
- **Naming:** `test_{method}_{scenario}_{expectedBehavior}`
- **Structure:** Given / When / Then
- **SwiftData tests:** `ModelConfiguration(isStoredInMemoryOnly: true)`
- **ViewModel tests:** Mock any service protocols. `HistoryListViewModel` needs `ModelContext` — create in-memory container in test setup.
- **Test placement:** `HyzerAppTests/ViewModels/HistoryListViewModelTests.swift`

**Key test cases:**
1. Empty history returns no cards
2. Single completed round produces correct card data (course name, winner, user position)
3. Multiple rounds are ordered by `completedAt` descending
4. Guest players display correctly in standings (playerID starts with `"guest:"`)
5. Rounds with status != "completed" are excluded from history

### Concurrency

Swift 6 strict concurrency is enforced (`SWIFT_STRICT_CONCURRENCY = complete`). All ViewModels are `@MainActor`. Use `async/await` for any async work. No `DispatchQueue`.

### Scope Boundaries — Do NOT Implement

- Player hole-by-hole breakdown (Story 8.2)
- Stats/trends/analytics (explicitly out of scope per PRD)
- Search or filtering of history
- Deletion of past rounds
- Any CloudKit sync changes (history reads local SwiftData only)

### Project Structure Notes

- New `History/` directory under `HyzerApp/Views/` follows the architecture's feature-grouping convention (matches `Scoring/`, `Courses/`, `Leaderboard/`, `Onboarding/`)
- `HistoryListViewModel` goes in `HyzerApp/ViewModels/` (flat — no subdirectory, matches existing convention)
- No changes to `HyzerKit` — this story is Views + ViewModels only

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 8, Story 8.1] — AC, scope, user story
- [Source: _bmad-output/planning-artifacts/architecture.md#History (FR58-62)] — file paths, view hierarchy, performance envelope
- [Source: _bmad-output/planning-artifacts/architecture.md#SwiftData Configuration] — dual store, @Query in views
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Journey 8: Browsing History] — card anatomy, emotional register, progressive disclosure
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Custom Component: History Round Card] — card states, layout, accessibility
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Empty States] — history empty state text
- [Source: HyzerApp/Views/HomeView.swift] — existing HistoryTabView placeholder, @Query pattern in ScoringTabView
- [Source: HyzerApp/ViewModels/RoundSummaryViewModel.swift] — reusable for detail view
- [Source: HyzerApp/Views/Scoring/RoundSummaryView.swift] — reference layout and token usage

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
