# Story 15.9: VoiceOver-Friendly Score Formatter (`"E"` → `"even par"`)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a VoiceOver user reading a leaderboard, head-to-head record, trend chart, or round summary card,
I want relative-to-par scores like `"E"`, `"+3"`, `"-1"` announced as `"even par"`, `"three over par"`, `"one under par"`,
So that the announcements are intelligible — current behavior reads `"E"` as the letter "E" (per Story 13.3 review-findings) which is meaningless to a screen-reader user.

## Acceptance Criteria

1. **Given** a new computed property `verboseScoreFormatter: String` (or equivalent — see Task 1 for naming finalization) is added to `Standing` (or a free function colocated with the existing `Standing.formatScore`), **when** invoked with `relativeToPar == 0`, **then** the output is exactly `"even par"` (Story 13.3 review-findings deferred bullet). The compact visual form `"E"` is unchanged — only the accessibility surface gets the verbose form.

2. **Given** `verboseScoreFormatter` is invoked with positive `relativeToPar` values, **when** the string is read, **then**:
   - `relativeToPar == 1` returns `"one over par"` (singular)
   - `relativeToPar == 2` returns `"two over par"`
   - `relativeToPar == 3` returns `"three over par"`
   - ... up through `relativeToPar == 20` returning `"twenty over par"`
   - `relativeToPar == 21+` returns digit form `"21 over par"` (fall back to numeric to avoid an unbounded English-number ladder)

3. **Given** `verboseScoreFormatter` is invoked with negative `relativeToPar` values, **when** the string is read, **then** the same cardinal pattern applies with `"under par"`:
   - `relativeToPar == -1` returns `"one under par"`
   - `relativeToPar == -2` returns `"two under par"`
   - ... through `relativeToPar == -20` returning `"twenty under par"`
   - `relativeToPar == -21-` returns digit form `"-21 under par"` or `"21 under par"` (decide which reads more naturally — recommend `"21 under par"` without the sign)

4. **Given** a `HeadToHeadView` is rendered with VoiceOver active, **when** the player score cell or any score-displaying element receives focus, **then** the accessibility label uses `verboseScoreFormatter` — never the raw compact form. Verified by manual VoiceOver verification on simulator (capture spoken utterance in Completion Notes).

5. **Given** the live leaderboard pill, expanded leaderboard, round summary card (live and screenshot), `PlayerTrendView`, `PersonalBestView`, and `HistoryRoundCard` are rendered with VoiceOver active, **when** each score-displaying element receives focus, **then** every accessibility label uses `verboseScoreFormatter`. Migrate the existing `accessibilityLabel` call sites in this same story. Visual rendering (the compact `"E"`/`"+3"` form via `formatScore` or its equivalent) is NOT changed.

6. **Given** the canonical test command runs after the migration, **when** the test count is compared to the Story 15.2 reconciled baseline, **then** the count increases by exactly the number of new unit tests for `verboseScoreFormatter` (expected: 8 new tests covering even par, ±1, ±2, ±20, ±21, mid-range positive, mid-range negative). Existing tests pass without modification — the `accessibilityLabel` changes are not directly asserted by unit tests (they would be by UI tests, which are not in scope per CLAUDE.md "Testing Standards").

## Tasks / Subtasks

- [ ] **Task 1: Decide naming and placement** (AC: 1)
  - [ ] 1.1 Read `HyzerKit/Sources/HyzerKit/Domain/Standing.swift` (or wherever `Standing` lives — confirm via `find HyzerKit -name "Standing.swift"`). Find the existing `formatScore` (or equivalent). Note the public API surface.
  - [ ] 1.2 Decide: add `verboseScoreFormatter` as a computed property on `Standing` OR a free function `verboseScore(relativeToPar:Int) -> String` colocated. Recommended: **free function**, because (a) the formatter doesn't need access to other `Standing` properties, (b) it's reusable for non-Standing contexts (e.g., raw scores from trend chart data points), (c) free functions are more testable in isolation. Place it in `HyzerKit/Sources/HyzerKit/Domain/ScoreFormatter.swift` (new file) or extend an existing formatter file if one exists.
  - [ ] 1.3 Confirm the choice with the user if there is any ambiguity — minor decisions like this can be made by the dev agent if pre-answered; the recommendation above is pre-answered.

- [ ] **Task 2: Implement `verboseScoreFormatter` (or free function)** (AC: 1, 2, 3)
  - [ ] 2.1 Create or extend the chosen file. Implementation sketch (free-function form):
    ```swift
    /// VoiceOver-friendly verbose form of a relative-to-par score.
    ///
    /// Visual form: `formatScore(relativeToPar:)` returns "E" / "+3" / "-1".
    /// Audio form: `verboseScore(relativeToPar:)` returns "even par" /
    /// "three over par" / "one under par".
    ///
    /// Use this for `accessibilityLabel` and any other surface that will be
    /// read by a screen reader. The compact form is unchanged for visual display.
    public func verboseScore(relativeToPar: Int) -> String {
        if relativeToPar == 0 {
            return "even par"
        }

        let absValue = abs(relativeToPar)
        let direction = relativeToPar > 0 ? "over" : "under"

        let valueString: String
        if absValue <= 20 {
            valueString = cardinalWord(absValue)
        } else {
            // Fall back to digit form for unbounded counts to avoid an
            // English-number ladder. In practice, +21 / -21 on a single
            // round of disc golf is rare but possible (terrible round,
            // par-72 course, score of 93). VoiceOver reads "21" as
            // "twenty-one" via the system, which is fine.
            valueString = "\(absValue)"
        }

        return "\(valueString) \(direction) par"
    }

    /// 1...20 cardinal English words. Out-of-range values are an
    /// internal error — the caller must filter.
    private func cardinalWord(_ n: Int) -> String {
        precondition(n >= 1 && n <= 20, "cardinalWord supports 1...20")
        return [
            "one", "two", "three", "four", "five",
            "six", "seven", "eight", "nine", "ten",
            "eleven", "twelve", "thirteen", "fourteen", "fifteen",
            "sixteen", "seventeen", "eighteen", "nineteen", "twenty"
        ][n - 1]
    }
    ```
  - [ ] 2.2 If the property-on-`Standing` form was chosen instead, wrap the function in:
    ```swift
    extension Standing {
        public var verboseScoreFormatter: String {
            verboseScore(relativeToPar: relativeToPar)
        }
    }
    ```
    (Where `Standing.relativeToPar` is the existing computed field — verify it exists; if it doesn't, the wrap is on `Standing.totalStrokes - Standing.par` or whatever the canonical expression is.)
  - [ ] 2.3 Add a public visibility annotation. The function must be `public` for HyzerApp to consume from across the SwiftPM module boundary.

- [ ] **Task 3: Unit tests for the formatter** (AC: 1, 2, 3)
  - [ ] 3.1 Create `HyzerKit/Tests/HyzerKitTests/Domain/ScoreFormatterTests.swift` (or extend existing formatter test file):
    ```swift
    import Testing
    import HyzerKit

    @Suite("verboseScore")
    struct VerboseScoreTests {
        @Test func evenPar() {
            #expect(verboseScore(relativeToPar: 0) == "even par")
        }

        @Test func oneOver() {
            #expect(verboseScore(relativeToPar: 1) == "one over par")
        }

        @Test func oneUnder() {
            #expect(verboseScore(relativeToPar: -1) == "one under par")
        }

        @Test func twentyOver() {
            #expect(verboseScore(relativeToPar: 20) == "twenty over par")
        }

        @Test func twentyUnder() {
            #expect(verboseScore(relativeToPar: -20) == "twenty under par")
        }

        @Test func twentyOneOver_fallsBackToDigits() {
            #expect(verboseScore(relativeToPar: 21) == "21 over par")
        }

        @Test func twentyOneUnder_fallsBackToDigits() {
            #expect(verboseScore(relativeToPar: -21) == "21 under par")
        }

        @Test func midRangeOver() {
            #expect(verboseScore(relativeToPar: 7) == "seven over par")
        }
    }
    ```
    8 tests covering even par, ±1, ±20, ±21 (boundary), and mid-range.
  - [ ] 3.2 Run `swift test --package-path HyzerKit` — confirm 8 new tests pass.

- [ ] **Task 4: Migrate call sites** (AC: 4, 5)
  - [ ] 4.1 Find all current `accessibilityLabel(...)` calls that include `Standing.formatScore` or any relative-to-par score expression. Use `grep -rn "accessibilityLabel" HyzerApp/Views` and inspect each match.
  - [ ] 4.2 For each match where the score is part of the accessibility label, replace the `formatScore` reference with `verboseScore(relativeToPar:)`. Compose the label string to read naturally for VoiceOver. Example:
    
    Before:
    ```swift
    .accessibilityLabel("\(player.name), \(standing.formatScore), \(standing.totalStrokes) total")
    ```
    
    After:
    ```swift
    .accessibilityLabel("\(player.name), \(verboseScore(relativeToPar: standing.relativeToPar)), \(standing.totalStrokes) total")
    ```
    
    The visual rendering elsewhere (the Text view showing `"+3"`) is NOT touched.
  - [ ] 4.3 Confirm migration in each of the documented surfaces (AC #5 list): HeadToHeadView, leaderboard pill, expanded leaderboard, round summary card (live AND screenshot view), PlayerTrendView, PersonalBestView, HistoryRoundCard. Use `grep -l "Standing\|relativeToPar\|formatScore" HyzerApp/Views/` to enumerate files.

- [ ] **Task 5: Manual VoiceOver verification on simulator** (AC: 4, 5)
  - [ ] 5.1 Build debug, install on `iPhone 17 with Watch` simulator.
  - [ ] 5.2 Enable VoiceOver. Navigate to the leaderboard during an active round with at least 3 players with varied scores (one at par, one over, one under). Swipe through each score cell. Capture the spoken utterance verbatim for the at-par player. Confirm `"even par"` (not `"E"`).
  - [ ] 5.3 Repeat on `HeadToHeadView`, `PlayerTrendView`, `PersonalBestView`, `RoundSummaryView`, and `HistoryRoundCard`. Capture utterances. Record in Completion Notes.
  - [ ] 5.4 Disable VoiceOver and confirm visual rendering is unchanged — the on-screen score still reads `"E"` / `"+3"`. The visual change would be a regression.

- [ ] **Task 6: Update deferred-work and close** (AC: 6)
  - [ ] 6.1 Remove from `_bmad-output/implementation-artifacts/deferred-work.md`: the Story 13.3 bullet referencing "`Standing.formatScore`'s `"E"` is pronounced as the letter 'E' by VoiceOver" (line 14).
  - [ ] 6.2 Update CLAUDE.md if it references this debt anywhere (search for "VoiceOver" and "even par").
  - [ ] 6.3 Stage and commit: `feat(a11y): add verbose VoiceOver score formatter (Story 15.9)`.
  - [ ] 6.4 Update `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 15.9 → `done`.

## Dev Notes

### Why this story exists

Story 13.3 review-findings identified that `Standing.formatScore`'s `"E"` is read by VoiceOver as the letter "E" — meaningless to a screen-reader user. The recommendation was a separate `verboseScoreFormatter`. The same problem exists for `"+3"` (read as "plus three" if read as text, more often read literally as the characters) and `"-1"` (read as "minus one" similar story). CLAUDE.md and the accessibility-first principle make this a launch-relevant fix.

The implementation is straightforward — a single formatter function plus migrations at the call sites. The story is a single PR.

### Current state — what is already correct (do NOT redo)

- **The compact visual form `formatScore` exists and renders correctly.** This story does NOT change it.
- **`accessibilityLabel` is used throughout score-displaying views** (per Story 13.x and 14.x ACs). The infrastructure for accessibility labels is in place; only the formatter being passed in changes.
- **CLAUDE.md "Accessibility first" rule** mandates VoiceOver labels for every interactive element. This story extends that to: VoiceOver labels MUST be intelligible, not just present.

### What this story changes

| Change | File | Notes |
|---|---|---|
| Add formatter | `HyzerKit/Sources/HyzerKit/Domain/ScoreFormatter.swift` (new) or extend existing | Free function + cardinal helper |
| Add tests | `HyzerKit/Tests/HyzerKitTests/Domain/ScoreFormatterTests.swift` | 8 tests |
| Migrate call sites | Various HyzerApp views | accessibilityLabel only; visual unchanged |
| Deferred-work cleanup | `_bmad-output/implementation-artifacts/deferred-work.md` | Remove Story 13.3 bullet |
| Sprint state | `_bmad-output/implementation-artifacts/sprint-status.yaml` | 15.9 → done |

### What this story must NOT touch

- **No visual rendering changes.** Only `accessibilityLabel` calls are migrated. The Text views showing "E" / "+3" stay as-is.
- **No `formatScore` changes.** The compact form remains the same.
- **No Watch-side changes** (unless the Watch surfaces score VoiceOver labels — verify via `grep` in HyzerWatch; if absent, skip).
- **No new visual UI for "even par".** This is audio-only.

### Architecture compliance

- **CLAUDE.md "Accessibility first":** This story is the literal accessibility-first enforcement. Every score `accessibilityLabel` now uses the intelligible form.
- **CLAUDE.md "Design tokens only":** Inapplicable (no UI).
- **CLAUDE.md "Bounded queries":** Inapplicable (no SwiftData).
- **CLAUDE.md "No silent `try?`":** No try-anything in this story; pure synchronous formatting.
- **CLAUDE.md "Git Workflow":** Branch `feature/15-9-verbose-score-formatter`. Conventional commit per Task 6.3.

### Library / framework requirements

- **No new dependencies.** Pure string formatting.

### File-structure requirements

```
HyzerKit/Sources/HyzerKit/Domain/ScoreFormatter.swift                                   [NEW or extended — Task 2.1]
HyzerKit/Tests/HyzerKitTests/Domain/ScoreFormatterTests.swift                           [NEW — Task 3.1]
HyzerApp/Views/Scoring/*.swift                                                          [EDIT — Task 4, accessibilityLabel migrations]
HyzerApp/Views/History/*.swift                                                          [EDIT — Task 4]
HyzerApp/Views/Leaderboard/*.swift (verify path)                                        [EDIT — Task 4]
HyzerApp/Views/Trend/PlayerTrendView.swift (verify path)                                [EDIT — Task 4]
HyzerApp/Views/HeadToHead/HeadToHeadView.swift (verify path)                            [EDIT — Task 4]
_bmad-output/implementation-artifacts/deferred-work.md                                  [EDIT — Task 6.1]
_bmad-output/implementation-artifacts/sprint-status.yaml                                [EDIT — Task 6.4]
```

### Testing requirements

- **8 new tests** on the formatter itself (Task 3.1) — direct coverage of the new public API.
- **No UI tests on accessibilityLabel migrations.** UI tests for VoiceOver are out of scope per CLAUDE.md Testing Standards; manual verification (Task 5) is the closing evidence.
- **Regression check:** Existing tests pass unchanged.

### Previous-story intelligence

**Story 13.3 review-findings (in deferred-work.md line 14):**
> Standing.formatScore's "E" is pronounced as the letter "E" by VoiceOver in accessibilityLabel for HeadToHeadViewModel — pre-existing tech debt acknowledged in CLAUDE.md. Need a separate verboseScoreFormatter (e.g., "even par") for VoiceOver consumption.

Story 15.9 implements that separate formatter.

**Story 14.2 dev notes (line 526):** Reference `Standing+Formatting.swift`. Verify whether that file exists — if it does, the new `verboseScore` lives there as an extension method, and a separate `ScoreFormatter.swift` is unnecessary.

### Latest tech information

- **VoiceOver pronunciation rules:** iOS VoiceOver reads short uppercase strings (`"E"`, `"AC"`) as the letter(s); longer strings as words. There is no way to override pronunciation for `"E"` other than substituting different text — which is exactly this story's approach.
- **`accessibilityLabel(_:)`** accepts any string; the system reads it verbatim. No special markup needed.

### Open questions — pre-answered

**Pre-answered:**
- Function name → `verboseScore(relativeToPar:)` (free function preferred over property; Task 1.2 rationale)
- Cardinal range → 1–20 in word form; 21+ fall back to digits
- Negative handling → same cardinal pattern with "under par"; sign dropped for digit fallback ("21 under par", not "-21 under par")
- Migration scope → only `accessibilityLabel` call sites; no visual changes

**Still requires elicitation:** none.

### Project Structure Notes

The committed diff is moderate: one new HyzerKit file (or extension), one test file, ~5-10 view files with single-line `accessibilityLabel` edits. Logical complexity is low.

### References

- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:14` — Story 13.3 VoiceOver "E" debt]
- [Source: `HyzerKit/Sources/HyzerKit/Domain/Standing.swift` — existing `formatScore` and `Standing` definition]
- [Source: `CLAUDE.md` "Accessibility first" rule]
- [Source: HyzerApp views containing `accessibilityLabel` calls — to be enumerated in Task 4.1]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Story-15.9` — this story's epic-level scope]

## Dev Agent Record

### Agent Model Used

<!-- Filled by dev agent during execution -->

### Debug Log References

<!-- Filled by dev agent during execution -->

### Completion Notes List

<!-- Filled by dev agent during execution -->

### File List

<!-- Filled by dev agent during execution -->

### Change Log

<!-- Filled by dev agent during execution -->
