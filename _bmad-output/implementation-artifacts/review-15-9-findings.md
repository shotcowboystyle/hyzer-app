# Story 15.9 Code Review — VoiceOver-Friendly Score Formatter

**Reviewer:** code-reviewer subagent
**Date:** 2026-05-18
**Branch:** feature/15-9-verbose-score-formatter
**Diff:** 12 files, +111/-151; 1 new HyzerKit formatter (31 LOC) in `Standing+Formatting.swift`, 1 new test file (8 tests), 7 view/VM call-site migrations
**Spec:** 15-9-voiceover-friendly-score-formatter.md
**Review mode:** full

## Summary
The `verboseScore(relativeToPar:)` helper itself is clean, well-documented, correctly placed in `Standing+Formatting.swift`, and ships the spec's exact 8 tests (even par, ±1, ±20, ±21, mid-range +7). However the AC #5 migration scope is incomplete: `HistoryRoundCard` (HistoryListView), `PlayerTrendView` per-point chart annotations, `WatchLeaderboardView`, and `PlayerHoleBreakdownView` still ship their own divergent or compact-form a11y phrasings, so a VoiceOver user still hears "E", "1 under par" (digits), or "at par" (instead of "even par") in surfaces the spec explicitly named.

## Findings

### [HIGH] [patch] AC #5 — `HistoryRoundCard` accessibility label not migrated
- **Source:** Acceptance Auditor — AC #5 explicitly enumerates `HistoryRoundCard`
- **Location:** `hyzer-wt-15-9/HyzerApp/Views/History/HistoryListView.swift:162-175` (`accessibilityLabel(data:)`)
- **AC violated:** AC #5
- **Detail:** The label "You won at \(data.winnerFormattedScore)" interpolates the compact form from `HistoryListViewModel.swift:99,102`. On an even-par win it speaks "You won at E" — the literal defect this story targets. `HistoryRoundCardData` exposes `winnerFormattedScore` only; the migration also needs `scoreRelativeToPar` plumbed through (parallel to the `RoundSummaryViewModel` change in this PR).
- **Suggested fix:** Add `winnerScoreRelativeToPar: Int?` (and `userScoreRelativeToPar: Int?`) to `HistoryRoundCardData`; populate from `winner?.scoreRelativeToPar` in `HistoryListViewModel.swift:93-105`; use `verboseScore(relativeToPar:)` in `accessibilityLabel(data:)`. Visual rendering unchanged.

### [HIGH] [patch] AC #5 — `PlayerTrendView` per-point chart still uses `Standing.formatScore`
- **Source:** Acceptance Auditor — AC #5 enumerates `PlayerTrendView`
- **Location:** `hyzer-wt-15-9/HyzerApp/Views/History/PlayerTrendView.swift:195` (`.annotation(label: Standing.formatScore(point.scoreRelativeToPar))`), plus the visible stats text at `:200-202`
- **AC violated:** AC #5
- **Detail:** The `vm.accessibilityChartSummary` is correctly migrated, but each `PointMark`'s annotation label is `Standing.formatScore(...)`. When a VoiceOver user navigates the chart points (Swift Charts surfaces them as a11y elements by default), each point reads as "E" / "+3" — same defect. The axis label at `:185` is visual-only (tick label, not a11y) so leave it.
- **Suggested fix:** Wrap the chart in `.accessibilityElement(children: .ignore)` so only `vm.accessibilityChartSummary` is spoken (simplest, matches the HoleCardView pattern), OR replace the annotation label with `verboseScore(relativeToPar:)`.

### [HIGH] [patch] Watch-side conditional triggered but skipped — `WatchLeaderboardView` ships divergent phrasing
- **Source:** Blind Hunter — spec "No Watch-side changes (unless the Watch surfaces score VoiceOver labels — verify via grep in HyzerWatch; if absent, skip)"; CLAUDE.md "Accessibility first"
- **Location:** `hyzer-wt-15-9/HyzerWatch/Views/WatchLeaderboardView.swift:117-131` (`accessibilityLabel(for:)`)
- **AC violated:** AC #5 (implicit — watch leaderboard is a score-displaying surface)
- **Detail:** WatchLeaderboardView surfaces a score a11y label inline: "1 under par" (digits, not "one"), "at par" (not "even par"), "1 over par" (not "one over par"). A VoiceOver user navigating between phone and watch hears two different phrasings for the same standing. The conditional in the spec was triggered; should have been migrated.
- **Suggested fix:** Replace lines 121-129 with `let scoreDesc = verboseScore(relativeToPar: rel)`. `verboseScore` is already public in HyzerKit which HyzerWatch imports.

### [HIGH] [patch] `PlayerHoleBreakdownView` ships divergent ad-hoc phrasing
- **Source:** Acceptance Auditor — AC #5 (history surfaces) + CLAUDE.md "Accessibility first"
- **Location:** `hyzer-wt-15-9/HyzerApp/Views/History/PlayerHoleBreakdownView.swift:163-167` (`accessibilityRelativeToPar`) and `:212-219` (`accessibilitySummary`)
- **AC violated:** AC #5
- **Detail:** Both helpers say "X under" / "even with" / "X over" using digits, then concatenate " par" at the call site (line 160: "scored 4, 1 under par"). Inconsistent with `verboseScore` ("one under par") and ships the literal-digit problem the spec rejects for the ±1..±20 range.
- **Suggested fix:** Replace `accessibilityRelativeToPar(_:)` with a one-liner calling `verboseScore(relativeToPar:)`; drop trailing ` par` at call site. Same for `accessibilitySummary`.

### [LOW] [defer] `HoleCardView.relativeToParPhrase` duplicates the new helper
- **Source:** Edge Case Hunter
- **Location:** `hyzer-wt-15-9/HyzerApp/Views/Scoring/HoleCardView.swift:172-181`
- **Detail:** Already says "one under par" / "even par" correctly but stops at ±1/0 and falls back to digits at ±2 (so spoken "two under par" → "2 under par" here). With `verboseScore` shipped, this 10-line helper is dead duplication and silently disagrees beyond ±1.
- **Suggested fix:** `private func relativeToParPhrase(strokes: Int, par: Int) -> String { verboseScore(relativeToPar: strokes - par) }`.

### [LOW] [defer] Free function vs static-on-Standing
- **Source:** Blind Hunter (style)
- **Location:** `hyzer-wt-15-9/HyzerKit/Sources/HyzerKit/Domain/Standing+Formatting.swift:36`
- **Detail:** Spec recommended free function and it works, but `Standing.verboseScore(relativeToPar:)` would mirror the existing `Standing.formatScore(_:)` static. `cardinalWord` is correctly file-private. Acceptable as-is.
- **Suggested fix:** Optional — wrap as a static on `Standing` for symmetry with `formatScore`.

## Triage Counts

- decision_needed: 0
- patch: 4
- defer: 2
- dismissed: 2

## Dismissed (noise log)

- **Rounding `-0.4` differential to `0` reads as "even par"** — Consistent with the visual `Standing.formatScore` path, so no regression; interaction is intentional.
- **No test for mid-range negative (e.g., `-7`)** — Implementation is symmetric by construction (`absValue` + `direction`); ±1, ±20, ±21 + mid-range +7 cover the matrix. A single asymmetric bug would surface in `oneUnder`/`twentyUnder`.

## Verdict

🟡 **Patch and ship.** Formatter and unit tests are correct and well-placed. Verdict held by AC #5 completeness: four named/implied surfaces (HistoryRoundCard, PlayerTrendView chart points, WatchLeaderboardView, PlayerHoleBreakdownView) still expose the defect this story exists to eliminate. Recommend a patch pass on at least the first three before marking done.
