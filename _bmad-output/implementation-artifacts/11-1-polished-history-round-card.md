# Story 11.1: Polished History Round Card

Status: done

## Story

As a user browsing past rounds,
I want each round to appear as a polished memory card,
so that I can scan my history at a glance and recognize the rounds I want to revisit.

## Acceptance Criteria

1. **Given** the user navigates to the history feed with at least one completed round, **when** the list renders, **then** each round is displayed as a card with: course name in H3 typography, date in caption-tier text, player count ("6 players"), winner attribution ("[name] won at [score]"), and the current user's position attribution ("You finished [nth] at [score]") (PMVP-FR6), **and** the cards use the off-course warm visual register (UX-PMVP-DR2).

2. **Given** the standard iPhone width (390pt), **when** the history feed is scrolled, **then** 3-4 cards are visible on screen at a time (UX-PMVP-DR2), **and** scroll performance maintains <16ms frame time at 250+ rounds (PMVP-NFR3).

3. **Given** the current user is the winner of a round, **when** the card is displayed, **then** the winner attribution and the user attribution collapse into a single line ("You won at [score]").

4. **Given** VoiceOver is active and focused on a history card, **when** the card is announced, **then** the announcement matches the UX spec: "[Course], [date]. [Winner] won. You finished [position]." (UX spec §1146).

## Tasks / Subtasks

- [ ] Task 1: Audit the existing card baseline (AC: 1)
  - [ ] 1.1 Read `HyzerApp/Views/History/HistoryListView.swift` lines 77–159 — the `HistoryRoundCard` private struct already renders course/date/player count/winner/user-position. Inventory which AC #1 elements already render correctly and which need style/layout adjustments
  - [ ] 1.2 Document any deltas against the UX spec component #8 (warm register, spacing, ordinal formatting) so the diff is small and intentional

- [ ] Task 2: Apply the off-course warm visual register (AC: 1, 2)
  - [ ] 2.1 Confirm card container uses `Color.backgroundElevated` with `cornerRadius: SpacingTokens.md` (currently correct)
  - [ ] 2.2 Add subtle warm-register treatment per UX-PMVP-DR2: increase vertical inner padding to `SpacingTokens.lg`, tighten line spacing on the body lines, lift the course-name row with a slightly heavier weight via the design token (do NOT introduce a new hex color or font — only token-driven adjustments allowed per CLAUDE.md)
  - [ ] 2.3 Verify 3–4 cards fit on a 390pt-wide screen at standard Dynamic Type (use Xcode previews at iPhone 15 / iPhone 17 with Watch sizes)

- [ ] Task 3: Winner/user-position collapse logic (AC: 3)
  - [ ] 3.1 In `HistoryListViewModel.ensureCardData(for:)` (where `HistoryRoundCardData` is populated), add a `userIsWinner: Bool` flag — `true` when the winner's `playerID == currentPlayerID`
  - [ ] 3.2 In `HistoryRoundCard.cardContent`, when `data.userIsWinner == true`: render a single line `"You won at \(data.userFormattedScore ?? data.winnerFormattedScore)"` using the winner's score color
  - [ ] 3.3 When `data.userIsWinner == false`: render both lines as today (winner line + "You finished N at score" line)

- [ ] Task 4: Ordinal formatting for user position (AC: 1, 4)
  - [ ] 4.1 Replace the raw integer position in the "You finished N" line with an ordinal ("1st", "2nd", "3rd", "4th", …). Add a small private helper `ordinal(_ n: Int) -> String` on `HistoryListViewModel` (or extract to `HyzerKit/Sources/HyzerKit/Domain/IntFormatting.swift` if you want reuse — at your discretion, but do not create a new file unless reused)
  - [ ] 4.2 `NumberFormatter` with `.numberStyle = .ordinal` is the standard path; cache the formatter on the ViewModel (don't recreate per call). Match the date-formatter pattern from Story 8.1

- [ ] Task 5: Accessibility (AC: 4)
  - [ ] 5.1 Update `HistoryRoundCard.accessibilityLabel(data:)` to match the UX spec exactly: `"[Course], [date]. [Winner] won. You finished [position]."`
  - [ ] 5.2 When `userIsWinner`, collapse to: `"[Course], [date]. You won at [score]."`
  - [ ] 5.3 Keep `.accessibilityElement(children: .combine)` on the card so the announcement is one element

- [ ] Task 6: Scroll performance (AC: 2)
  - [ ] 6.1 Verify lazy per-card computation is intact (`onAppear` → `ensureCardData(for:)`). Do NOT eagerly precompute card data for all rounds in the ViewModel initializer
  - [ ] 6.2 Validate frame time on the 250+ rounds case — seed `n = 250` completed rounds in a dev fixture, run on an iPhone 17 simulator, scroll the feed, and confirm no dropped frames. Capture a brief note in the Completion Notes — quantify, don't guess (CLAUDE.md "measurement over estimation")

- [ ] Task 7: Tests (AC: 1, 3, 4)
  - [ ] 7.1 Extend `HistoryListViewModelTests` (or create it) — assert `HistoryRoundCardData.userIsWinner == true` when current user is the round winner
  - [ ] 7.2 Assert ordinal formatting: 1 → "1st", 2 → "2nd", 3 → "3rd", 4 → "4th", 11 → "11th", 21 → "21st"
  - [ ] 7.3 Snapshot or label-assertion test on `HistoryRoundCard` for the collapsed-winner case and the non-winner case
  - [ ] 7.4 Accessibility label assertions for both cases

## Dev Notes

### Architecture & Patterns

- **View layer:** `HistoryListView` owns the `@Query` for completed rounds and a `LazyVStack` of cards. The `HistoryRoundCard` private struct is a pure render. No SwiftData inside `HistoryRoundCard`.
- **ViewModel:** `HistoryListViewModel` (`@MainActor @Observable final class`) owns the per-round card-data cache (`cardDataCache: [UUID: HistoryRoundCardData]`). Cards self-trigger their data computation via `.onAppear { vm.ensureCardData(for: round) }` — this is the lazy pattern established in Story 8.1.
- **`HistoryRoundCardData`** lives inside `HistoryListViewModel.swift` today. Add the `userIsWinner: Bool` field to it. Keep it a value type, `Sendable`-clean.

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| `HistoryRoundCard` layout | `HyzerApp/Views/History/HistoryListView.swift:77` | Modify in-place — adjust spacing, add the collapse path |
| `HistoryListViewModel.ensureCardData(for:)` | `HyzerApp/ViewModels/HistoryListViewModel.swift` | Extend to compute `userIsWinner` |
| `Standing.scoreColor`, `Standing.formattedScore` | `HyzerKit/Sources/HyzerKit/Domain/Standing*.swift` | Reuse for color/format (don't reformat) |
| Design tokens | `HyzerKit/Sources/HyzerKit/Design/` | `ColorTokens`, `TypographyTokens`, `SpacingTokens` |

### File Structure

**Files to modify:**
```
HyzerApp/Views/History/HistoryListView.swift             # HistoryRoundCard layout + collapsed-winner branch + a11y label
HyzerApp/ViewModels/HistoryListViewModel.swift           # HistoryRoundCardData adds userIsWinner; add ordinal helper
```

**Test files to add or extend:**
```
HyzerAppTests/ViewModels/HistoryListViewModelTests.swift # New or extended — userIsWinner + ordinal
```

**Update `project.yml`?** No.

### Scope Boundaries — Do NOT Implement

- No new card thumbnail / hero image (the "generative visual signature" is Epic 14's Story 14.2 — out of scope here).
- No filtering / sorting controls — the feed remains reverse-chronological completed rounds only.
- No swipe-to-delete / context menu — read-only feed.
- No infinite scroll pagination — the bounded `@Query` plus lazy card computation already meets PMVP-NFR3 at 250 rounds.

### Previous Story Intelligence (8.1)

- **Lazy card computation:** Story 8.1 explicitly avoided eager bulk precomputation after review feedback (issue H1). The same lazy pattern is required here. Do not regress to eager computation.
- **Score color directly from `Standing.scoreColor`:** Story 8.1 issue M2 — do not derive color from formatted-string parsing. Plumb `Color` through `HistoryRoundCardData` directly.
- **DateFormatter cached as instance property:** Established in Story 8.1; mirror with `NumberFormatter` for the ordinal helper.
- **`#Predicate` UUID capture:** Use a local `let` for any UUID inside a `#Predicate` closure (still applicable if you add new fetches).

### UX Spec Compliance

- **Typography:** Course name = `TypographyTokens.h3`. Date and player count = `TypographyTokens.caption`. Winner/user lines = `TypographyTokens.body`. Score values = `TypographyTokens.body` rendered in the appropriate score-state color (not `TypographyTokens.score` — body sized to match the line; the prominent score type is reserved for the round summary per UX-PMVP-DR1).
- **Spacing:** 8pt grid. Card inner padding `SpacingTokens.lg`. Inter-card spacing `SpacingTokens.md`.
- **Color:** Backgrounds via `Color.backgroundElevated` / `Color.backgroundPrimary`. Score colors via existing 3-tier `Standing.scoreColor`. No new tokens.

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test`).
- **Setup:** `ModelConfiguration(isStoredInMemoryOnly: true)`. Use existing fixtures.
- **Performance check (AC #2):** Not a unit test — capture via simulator timing using Instruments or `signpost` during a manual scroll, and record findings in Completion Notes. Do NOT make up numbers (CLAUDE.md "measurement over estimation"). If you cannot measure in this story, mark the AC as "needs measurement" rather than claiming success.

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Epic 11, Story 11.1] — user story, scope, ACs
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#PMVP-FR6, UX-PMVP-DR2] — feature requirement, design register
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#§1146] — VoiceOver announcement format
- [Source: HyzerApp/Views/History/HistoryListView.swift] — modification target
- [Source: HyzerApp/ViewModels/HistoryListViewModel.swift] — modification target
- [Source: _bmad-output/implementation-artifacts/8-1-history-list-and-round-detail.md] — lazy pattern, review fixes to preserve
- [Source: CLAUDE.md#Coding Standards] — design tokens only, measurement over estimation

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Patch] Winner Determination Bug in Ties [HistoryListViewModel.swift]
- [x] [Review][Patch] Inaccurate Ordinal Fallback [HistoryListViewModel.swift]
- [x] [Review][Defer] Fixed-Width Snapshot Constraints [RoundSummaryView.swift] — deferred, pre-existing
- [x] [Review][Defer] Duplicate ShareSheetRepresentable [RoundSummaryView.swift] — deferred, pre-existing
- [x] [Review][Defer] Stringly-Typed Lifecycle State [HyzerKit/Sources/HyzerKit/Models/Round.swift] — deferred, pre-existing
- [x] [Review][Patch] Fixed locale staleness for ordinal/date formatters [HistoryListViewModel.swift]
- [x] [Review][Patch] Added "Tie for 1st" winner label for multi-way ties [HistoryListViewModel.swift]
- [x] [Review][Patch] Applied semibold weight and tightened spacing for card content [HistoryListView.swift]
