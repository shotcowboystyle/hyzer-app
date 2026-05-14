# Story 10.2: Scoring Attribution on Hole Card

Status: done

## Story

As a player in a round,
I want to see who entered each score on the hole card,
so that I can verify scores socially and resolve any "did you record this?" questions without opening discrepancy resolution.

## Acceptance Criteria

1. **Given** a hole card with a player who has been scored, **when** the row is displayed, **then** the player's score is shown in the primary score-state color, **and** below the score in caption-tier typography (`Color.textSecondary`), the text "Scored by [name]" appears, where `[name]` is the display name of the player referenced by `ScoreEvent.reportedByPlayerID` of the current authoritative event for this {player, hole} (PMVP-FR10).

2. **Given** a player has corrected their own (or another player's) score (the previous event has been superseded), **when** the row is displayed, **then** the attribution shows the name from the authoritative (leaf) `ScoreEvent`, not the superseded one (Amendment A7 + NFR19 supersession chain respected).

3. **Given** the score was entered via Watch (`reportedByPlayerID` resolves to the Watch user), **when** the row is displayed, **then** the attribution renders identically (no "via Watch" suffix; attribution is by person, not device).

4. **Given** VoiceOver is active and focused on a scored player row, **when** the row is announced, **then** the attribution is included in the announcement after the score (e.g., "Mike, 3, one under par. Scored by Jake.").

5. **Given** the hole card is rendered at Dynamic Type AX3, **when** the attribution line is laid out, **then** the row height grows to accommodate without truncating the score or the attribution name (NFR16).

## Tasks / Subtasks

- [ ] Task 1: Extend `HoleCardView` with a name lookup for attribution (AC: 1, 3)
  - [ ] 1.1 Add a new input to `HoleCardView`: `let scorerNamesByID: [String: String]` — keyed on `Player.id.uuidString` (registered players only; Watch attribution uses the same registered player ID — no device suffix per AC #3)
  - [ ] 1.2 In `playerRow(player:score:)`, when `score != nil`, look up `scorerNamesByID[score!.reportedByPlayerID.uuidString]` — fall back to `nil` (do not render the attribution) when the lookup misses
  - [ ] 1.3 Wrap the existing score `Text` in a `VStack(alignment: .trailing, spacing: SpacingTokens.xs)`; underneath, render `"Scored by \(name)"` using `TypographyTokens.caption` and `Color.textSecondary` when `name != nil`

- [ ] Task 2: Wire the lookup from `ScorecardContainerView` (AC: 1)
  - [ ] 2.1 `ScorecardContainerView` already builds `playerNamesByID: [String: String]` (see line 73) — pass it as `scorerNamesByID:` to every `HoleCardView` instantiation
  - [ ] 2.2 Verify the dictionary covers every plausible `reportedByPlayerID` — the only `reportedByPlayerID` values produced are the round participants' `Player.id` (organizer + added players). The dictionary is built from `roundPlayers` which already contains all of these
  - [ ] 2.3 Guest scorers: `reportedByPlayerID` is `UUID` (a registered `Player.id`), NEVER a guest. Guests can have scores recorded against them, but a guest never *records* a score. No special-casing required

- [ ] Task 3: Supersession chain resolution (AC: 2)
  - [ ] 3.1 `HoleCardView.playerRow` already calls `resolveCurrentScore(for:hole:in:)` (Amendment A7 leaf-node resolver) — the resulting `ScoreEvent` is the authoritative one, and its `reportedByPlayerID` is therefore the most recent attribution. No additional logic needed; verify with a test
  - [ ] 3.2 Do NOT introduce timestamp-based "most recent" resolution. The leaf-node resolver is the only correct path

- [ ] Task 4: AX3 / Dynamic Type layout (AC: 5)
  - [ ] 4.1 The right-aligned `VStack` containing score + attribution must not constrain the row height (no fixed `frame(height:)`)
  - [ ] 4.2 Allow `Text("Scored by \(name)")` to wrap to 2 lines (`.lineLimit(2)`, `.minimumScaleFactor(0.9)`) and `.fixedSize(horizontal: false, vertical: true)` to prevent truncation at AX3
  - [ ] 4.3 The row's `minHeight: SpacingTokens.minimumTouchTarget` (44pt) remains, but the row should grow taller when content demands

- [ ] Task 5: Accessibility (AC: 4)
  - [ ] 5.1 Update the scored-row `accessibilityLabel` to: `"\(player.displayName), score \(score.strokeCount)\(relativeToParPhrase). Scored by \(name)."` where `relativeToParPhrase` is computed from `score.strokeCount - par` (e.g., "one under par", "even par", "one over par", "two over par"). Add a small private helper on `HoleCardView` for the phrase
  - [ ] 5.2 If the attribution name is missing (lookup miss), drop the trailing "Scored by …" sentence — do not say "Scored by Unknown"
  - [ ] 5.3 Confirm the existing `.accessibilityElement(children: .combine)` is preserved so the row is announced as one element

- [ ] Task 6: Tests (AC: 1, 2, 3, 4)
  - [ ] 6.1 `HoleCardViewTests` (new snapshot or view-state tests) covering: scored row renders attribution; unscored row does NOT render attribution
  - [ ] 6.2 ViewModel-level test in `ScorecardViewModelTests` (or a new `ScorecardContainerTests` if needed): given a superseded score chain, the attribution surfaces the leaf event's `reportedByPlayerID` (NOT the original)
  - [ ] 6.3 Accessibility-label test asserting "Scored by Jake" appears in the combined label when a scorer is known, and is absent when the lookup misses

## Dev Notes

### Architecture & Patterns

- **Data flow:** `ScorecardContainerView` owns the `@Query` for `Player` records and is the right layer to build the `[String: String]` name map. `HoleCardView` remains a pure render with inputs — no SwiftData access from views nested inside the page TabView.
- **`ScoreEvent.reportedByPlayerID` is a non-optional `UUID`** (see `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift:34`). Every existing event has a real value. There is no migration concern.
- **Leaf-node resolution (Amendment A7):** `resolveCurrentScore(for:hole:in:)` at `HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift` returns the event in a chain that is NOT pointed to by any other event's `supersedesEventID`. This is the authoritative event. Its `reportedByPlayerID` is therefore the authoritative attribution.
- **Concurrency:** No new concurrency surface — `HoleCardView` is a SwiftUI `View`, rendered on the main thread. No `@MainActor` annotation needed (SwiftUI views are implicitly main-actor when used from `body`).
- **No data-model changes.** `reportedByPlayerID` already exists on `ScoreEvent` (Story 3.2) and is already populated by `ScoringService` and `DiscrepancyViewModel.resolveDiscrepancy` (audit trail).

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| `ScoreEvent.reportedByPlayerID` | `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift:34` | Read directly from the leaf event |
| `resolveCurrentScore(for:hole:in:)` | `HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift` | Already called inside `HoleCardView.playerRow` — do not duplicate |
| `playerNamesByID` dictionary | `HyzerApp/Views/Scoring/ScorecardContainerView.swift:73-75` | Pass through to `HoleCardView` as `scorerNamesByID:` |
| `TypographyTokens.caption`, `Color.textSecondary` | `HyzerKit/Sources/HyzerKit/Design/` | Attribution typography |
| `Color.scoreColor(strokes:par:)` | Existing helper used in `HoleCardView` | Unchanged |

### File Structure

**Files to modify:**
```
HyzerApp/Views/Scoring/HoleCardView.swift                # Add scorerNamesByID input + attribution layout + a11y label
HyzerApp/Views/Scoring/ScorecardContainerView.swift      # Pass playerNamesByID to HoleCardView
```

**Test files to add or extend:**
```
HyzerAppTests/Views/HoleCardViewTests.swift              # New — attribution render + a11y label
HyzerAppTests/ViewModels/ScorecardViewModelTests.swift   # Extend — superseded event resolves to leaf attribution
```

**Update `project.yml`?** No — XcodeGen auto-discovers `.swift` files.

### UX Spec Compliance

- **Typography tier:** Attribution uses caption tier (`TypographyTokens.caption`), color `Color.textSecondary` (UX-PMVP-DR3 — de-emphasized typography). Never use a custom font size or hex color.
- **Score remains primary.** Visual hierarchy: player name (H3) ▸ score (TypographyTokens.score / SF Mono / score-state color) ▸ attribution (caption / secondary). The attribution must not compete with the score.
- **No icons** next to "Scored by" — text-only per UX-PMVP-DR1 ("confident weight differential, no confetti, no illustrations").

### Edge Cases

| Case | Behavior |
|------|----------|
| Score exists, scorer's `Player` was deleted | Lookup miss → render only the score, drop the attribution line. Do NOT show "Scored by Unknown" or the raw UUID. |
| Score from the Watch user | `reportedByPlayerID` is the Watch user's `Player.id` (same identity as their iPhone). Lookup hits the same entry; no special handling. |
| Discrepancy resolution event | `DiscrepancyViewModel.resolveDiscrepancy` sets `reportedByPlayerID = currentPlayerID` (the organizer). The attribution will surface the organizer's name on resolved scores — this is the intended audit-trail surface. |
| Multiple corrections in chain (A → B → C) | Leaf event = C. Attribution shows C's `reportedByPlayerID`. Verified by `resolveCurrentScore` returning the leaf. |
| Unscored row | No score, no attribution. Existing `Text("—")` path is unchanged. |

### Scope Boundaries — Do NOT Implement

- No "via Watch" or "via Phone" device suffix (AC #3 explicit).
- No tappable attribution chip / hover state — caption text only.
- No change to `ScoreEvent` data model.
- No change to `ScoringService` or `DiscrepancyViewModel` — they already write `reportedByPlayerID`.
- No history-view attribution (the round summary and history detail views are out of scope for this story).

### Previous Story Intelligence (3.2, 3.3, 6.1)

- Story 3.2 introduced `reportedByPlayerID` on `ScoreEvent` for audit trail.
- Story 3.3 introduced the supersession chain (`supersedesEventID`) and the leaf-node resolver.
- Story 6.1 (`DiscrepancyViewModel`) sets `reportedByPlayerID` on the organizer-authored resolution event — code-review noted this is the correct audit-trail behavior.
- Pattern from Story 8.2 — derive a presentation-only value (here: `attributionName`) inside the view via a tight lookup rather than adding a field to the model.

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test`).
- **Setup:** Build a small in-memory `ModelConfiguration(isStoredInMemoryOnly: true)`; seed a round, two `Player`s, and a chain of `ScoreEvent`s where event B supersedes event A. Assert the leaf is B and the attribution renders B's scorer.
- **Naming:** `test_{method}_{scenario}_{expectedBehavior}`.
- **No simulator dependency** — these are view-state and lookup-table tests, not UI snapshot tests against the device. (A separate `setup-visual-testing` pass can capture snapshots later if desired.)

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Epic 10, Story 10.2] — user story, scope, ACs
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#PMVP-FR10] — feature requirement
- [Source: HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift:34] — `reportedByPlayerID` field
- [Source: HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift] — `resolveCurrentScore`
- [Source: HyzerApp/Views/Scoring/HoleCardView.swift] — extension target
- [Source: HyzerApp/Views/Scoring/ScorecardContainerView.swift:72-75] — `playerNamesByID`
- [Source: _bmad-output/planning-artifacts/architecture.md#Amendment A7] — leaf-node resolution
- [Source: CLAUDE.md#Coding Standards] — design tokens only, no hardcoded colors/fonts

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Defer] Localization/Grammar (Hardcoded Par Phrases) [HoleCardView.swift] — deferred, pre-existing
- [x] [Review][Patch] Added layout priority to player name to prevent Dynamic Type truncation [HoleCardView.swift]
