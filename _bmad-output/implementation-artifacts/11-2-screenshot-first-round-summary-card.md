# Story 11.2: Screenshot-First Round Summary Card

Status: ready-for-dev

## Story

As a user finishing a round,
I want a polished summary screen designed to look good as a screenshot,
so that I can immediately share the round into the group chat.

## Acceptance Criteria

1. **Given** a round has been finalized, **when** the round summary appears, **then** the card displays: course name (H1, centered), date (caption, secondary, below course name), ranked player rows with position/medal/name/+/- par score/total strokes, divider, round metadata footer (PMVP-FR7, UX-PMVP-DR1), **and** all typography uses existing design tokens (SF Pro Rounded for text, SF Mono for scores).

2. **Given** the summary card is rendered, **when** evaluated for screenshot readability, **then** all text meets 4.5:1 contrast (NFR13) and 7:1 for the prominent score values (AAA), **and** no element relies on interaction (hover, expansion) to convey information.

3. **Given** positions 1-3, **when** the rows are rendered, **then** the position number receives a subtle medal-style typographic treatment (confident weight differential, no confetti, no illustrations per UX-PMVP-DR1).

4. **Given** the round had a guest player, **when** the summary is rendered, **then** the guest's name appears identically to registered players (consistent with FR12b — guests are first-class round participants in history).

5. **Given** the user is on a small screen device (iPhone SE at 375pt), **when** the summary card is rendered, **then** all rows fit without horizontal scroll, **and** card vertical extent fits within a standard share-screenshot height.

## Tasks / Subtasks

- [ ] Task 1: Replace emoji medals with subtle typographic treatment (AC: 3)
  - [ ] 1.1 In `RoundSummaryView.swift` (`PlayerSummaryRow.medalEmoji(for:)`), remove the 🥇 / 🥈 / 🥉 strings
  - [ ] 1.2 Render positions 1–3 with a heavier weight and the score-state-relative color treatment specified by UX-PMVP-DR1: position number in `TypographyTokens.h1` weight, color `Color.textPrimary` for #1, `Color.textPrimary.opacity(0.85)` for #2, `Color.textPrimary.opacity(0.70)` for #3 — confident weight differential, no chromatic medal coloring (gold/silver/bronze) and no emoji
  - [ ] 1.3 Positions 4+ remain `TypographyTokens.h2` in `Color.textSecondary` (already correct)
  - [ ] 1.4 If you find yourself needing a custom hex color or a custom font weight not in the design tokens, STOP and propose a token addition first (CLAUDE.md "design tokens only")

- [ ] Task 2: Reinforce H1-centered header per UX component #7 (AC: 1)
  - [ ] 2.1 Verify `headerSection` uses `TypographyTokens.h1` for course name with `.multilineTextAlignment(.center)` — already correct in `RoundSummaryView.swift:58`
  - [ ] 2.2 Same change in `SummaryCardSnapshotView` (the render target for `ImageRenderer`) — already correct at line 207
  - [ ] 2.3 Confirm date sits directly below in `TypographyTokens.caption` / `Color.textSecondary` — already correct

- [ ] Task 3: Player row layout — score, +/- par, total strokes (AC: 1, 4)
  - [ ] 3.1 Verify existing `PlayerSummaryRow` already shows: position label, `playerName` (H2), `formattedScore` (score font, score-state color), `totalStrokes` strokes (caption). The structure is correct
  - [ ] 3.2 Guests render identically to registered players — `RoundSummaryViewModel.playerRows` is built from `[Standing]` which already includes guests as first-class entries (FR12b). No change in `RoundSummaryView`, but add a guest test (Task 6.3)

- [ ] Task 4: Contrast + AAA on scores (AC: 2)
  - [ ] 4.1 Audit `Color.scoreUnderPar` (#34C759), `scoreAtPar` (#F5F5F7), `scoreOverPar` (#FF9F0A), `scoreWayOver` (#FF453A) against `Color.backgroundPrimary` (#0A0A0C) — record measured ratios in Completion Notes. The dark-first palette in the design system is intended to meet these targets; do not change tokens unless a real failure is found
  - [ ] 4.2 No interactive-only information (AC #2 second clause) — verify by inspection that nothing requires hover/tap to reveal data on the summary card

- [ ] Task 5: Small-screen fit (iPhone SE 375pt) (AC: 5)
  - [ ] 5.1 `SummaryCardSnapshotView.frame(width: 390)` is hardcoded for the renderer output — leave that as is (renderer needs a fixed canvas)
  - [ ] 5.2 The live `RoundSummaryView` is fluid — verify in an Xcode preview at 375pt that no row truncates horizontally. Add `.lineLimit(1).minimumScaleFactor(0.8)` to the `playerName` Text in `PlayerSummaryRow` if needed (do NOT scale below 0.8 — readability floor)
  - [ ] 5.3 Confirm the on-card content does NOT scroll for the typical 4–8 player round; for 12+ players (large groups), the parent `ScrollView` handles overflow — that's acceptable for the live screen, and the screenshot renderer captures the full content height regardless

- [ ] Task 6: Tests (AC: 1, 3, 4)
  - [ ] 6.1 Extend `RoundSummaryViewModelTests` — `playerRows` includes guest entries with non-empty `playerName` (no "Guest" placeholder; the actual guest name from `Round.guestNames`)
  - [ ] 6.2 New view-state assertion: `PlayerSummaryRow` for position 1 renders the position label in `TypographyTokens.h1`-equivalent weight (test by reading the rendered text + a public conformance hook on the row if needed; otherwise rely on an inspected snapshot)
  - [ ] 6.3 Visual regression: capture a baseline screenshot of `SummaryCardSnapshotView` with a 6-player + 1-guest round and confirm the medal treatment is text-only (no emoji glyphs). Use the existing visual-testing skill if set up
  - [ ] 6.4 NEW: `RoundSummaryView` shows no emoji glyph for positions 1–3 — assert the rendered position labels contain only ASCII digits

## Dev Notes

### Architecture & Patterns

- **Two views, one design.** `RoundSummaryView` is the live screen; `SummaryCardSnapshotView` is the static render target for `ImageRenderer`. Both must match the UX spec; both must use the same tokens; the snapshot view is fixed-width by design (renderer needs a deterministic canvas).
- **No data-model changes.** `Round`, `ScoreEvent`, `Standing`, `RoundSummaryViewModel`, `SummaryPlayerRow` are all in place from Story 3.6.
- **ViewModel is unchanged.** `RoundSummaryViewModel.playerRows` already exposes `position`, `playerName`, `formattedScore`, `totalStrokes`, `scoreColor`, `hasMedal`. The story is purely a polish on the rendering layer.
- **Concurrency:** No changes; views are main-actor-bound via SwiftUI.

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| `RoundSummaryView` + `PlayerSummaryRow` + `SummaryCardSnapshotView` | `HyzerApp/Views/Scoring/RoundSummaryView.swift` | Modification target — refine in place |
| `RoundSummaryViewModel.playerRows` | `HyzerApp/ViewModels/RoundSummaryViewModel.swift` | Unchanged — already feeds rows correctly including guests |
| `Standing.scoreColor`, `Standing.formattedScore` | `HyzerKit/Sources/HyzerKit/Domain/` | Source of truth for color + format |
| Design tokens | `HyzerKit/Sources/HyzerKit/Design/` | Used throughout |

### File Structure

**Files to modify:**
```
HyzerApp/Views/Scoring/RoundSummaryView.swift            # Medal treatment, small-screen fit, header re-check
```

**Test files to add or extend:**
```
HyzerAppTests/ViewModels/RoundSummaryViewModelTests.swift  # Guest entries assertion
HyzerAppTests/Views/RoundSummaryViewTests.swift            # New — medal treatment + no emoji assertion
```

**Update `project.yml`?** No.

### UX Spec Compliance (UX-PMVP-DR1)

- "Subtle medal indicator for 1st/2nd/3rd" → typographic weight differential. NO emoji, NO chromatic medal coloring, NO illustrations, NO confetti.
- Course name centered in H1; date in caption directly below. No timezone abbreviation in the date (use `.dateStyle = .medium`, `.timeStyle = .none` — already correct).
- Score = SF Mono (`TypographyTokens.score`) in the score-state color from `Standing.scoreColor`. Total strokes in caption tier (`TypographyTokens.caption`, `Color.textSecondary`) — secondary information.
- Round metadata footer (holes played, organizer name) in caption tier with a divider above.

### Scope Boundaries — Do NOT Implement

- The share button + share sheet are Story 11.3 — out of scope here.
- The generative visual signature is Story 14.2 — out of scope.
- No animation entry transition changes (AC #2 explicitly disallows interaction-dependent reveal).
- No history-card layout changes (that's Story 11.1).
- No additional metadata fields (weather, GPS, etc.).

### Previous Story Intelligence (3.6, 8.2)

- Story 3.6 introduced `RoundSummaryView`, `SummaryCardSnapshotView`, the `ImageRenderer` snapshot path, and the existing emoji-based position markers. This story SUPERSEDES the emoji approach with the typographic treatment from the UX spec.
- Story 8.2 established a precedent for 4-tier score color on individual hole rows; the round summary continues to use 3-tier `Standing.scoreColor` for aggregate standings — DO NOT mix the two.

### Testing Requirements

- **Framework:** Swift Testing.
- **Visual baselines:** If `setup-visual-testing` is in place, capture before/after snapshots of `SummaryCardSnapshotView` to make the medal-style change reviewable. If not, document the change with a note + screenshot in Completion Notes.
- **Contrast measurement (AC #2):** Use the design-token values + Color Contrast Analyzer (or any deterministic AA/AAA checker) and record measured ratios in Completion Notes. Don't guess.

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Epic 11, Story 11.2] — user story, scope, ACs
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#PMVP-FR7, UX-PMVP-DR1] — feature requirement, design register
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Component #7] — round summary card design
- [Source: HyzerApp/Views/Scoring/RoundSummaryView.swift] — modification target
- [Source: HyzerApp/ViewModels/RoundSummaryViewModel.swift] — unchanged
- [Source: _bmad-output/implementation-artifacts/3-6-round-completion-and-summary.md] — original implementation
- [Source: CLAUDE.md#Coding Standards] — design tokens only, no hardcoded values

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
