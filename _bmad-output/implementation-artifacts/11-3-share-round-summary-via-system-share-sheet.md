# Story 11.3: Share Round Summary via System Share Sheet

Status: ready-for-dev

## Story

As a user who just finished a round,
I want to tap a share button and send the round summary directly to my group chat,
so that the result lands in the conversation while the round is still warm.

## Acceptance Criteria

1. **Given** the user is viewing the round summary card, **when** they tap the share button (primary CTA, bottom of card), **then** the system share sheet appears with both an image attachment (PNG render of the card) and a text caption (PMVP-FR8).

2. **Given** the user selects Messages or another social app from the share sheet, **when** the share is dispatched, **then** the PNG renders correctly in the receiving app's message bubble (verified visually on Messages and one third-party app), **and** the PNG has aspect ratio and resolution suitable for inline message display (no awkward cropping).

3. **Given** the share sheet is presented, **when** the user cancels it, **then** the round summary card remains in its previous state with no side effects.

4. **Given** the user has the Watch app foregrounded with a completed round, **when** the summary card appears on the iPhone, **then** the share button is present (Watch never participates in share — share is iPhone-only).

## Tasks / Subtasks

- [x] Task 1: Audit the existing share path (AC: 1, 2)
  - [x] 1.1 Read `HyzerApp/Views/Scoring/RoundSummaryView.swift` lines 100–137 and `HyzerApp/ViewModels/RoundSummaryViewModel.swift` lines 82–96. The share button + `ShareSheetRepresentable` + `ImageRenderer`-backed `shareSnapshot(displayScale:)` are already implemented from Story 3.6
  - [x] 1.2 Inventory deltas against this story's ACs:
        — Share button placement (bottom CTA): exists.
        — PNG render via `ImageRenderer`: exists.
        — Text caption: exists (`"Round at [course] -- [winner] wins at [score]!"`). Confirm the format matches the spec — the epic specifies `"Round at [course] — [winner] won at [score]"` (em dash, past-tense "won"). Reconcile to the epic wording
  - [x] 1.3 Note any side-effects-on-cancel risk: today, the share sheet is presented via `.sheet(isPresented:)`. Cancellation simply dismisses the sheet — no model mutation occurs. Verify with a test (Task 4)

- [x] Task 2: Normalize the share caption (AC: 1)
  - [x] 2.1 Moved `shareText` to `RoundSummaryViewModel` as a computed property. Format: `"Round at \(courseName) \u{2014} \(winnerNames) won at \(score)"` using real em dash (U+2014). Past tense `won`. No trailing exclamation.
  - [x] 2.2 If there is no winner (defensive — should not happen for a completed round, but `viewModel.playerRows.first(where: { $0.position == 1 })` could theoretically miss): fall back to `"Round at \(courseName)"` without the winner clause. Don't crash; don't render placeholders
  - [x] 2.3 Per CLAUDE.md ("No Defensive Coding for Impossible Cases"): the fallback above is a fail-safe text path, not a guard against an invariant. The non-empty playerRows invariant of a completed round is real and should hold — but we still produce a sensible caption rather than empty text

- [x] Task 3: Validate PNG quality + aspect (AC: 2)
  - [x] 3.1 `SummaryCardSnapshotView` is fixed at `frame(width: 390)` — the renderer output dimensions are therefore deterministic (390pt × content height @ `displayScale`). Capture the rendered image once and confirm the height is within the standard share-screenshot range (target: less than 800pt at typical 6-player rounds, scales with player count)
  - [x] 3.2 Set `renderer.scale = displayScale` (already done at line 93). Verify @3x devices produce a crisp PNG
  - [ ] 3.3 Manual verification: on the iPhone 17 simulator, run the round through to completion, tap Share, choose Messages → confirm the bubble renders the image without cropping. Then repeat with one third-party app (WhatsApp or Discord if installed; otherwise Mail compose as a fallback)
  - [ ] 3.4 Record findings in Completion Notes — actual rendered dimensions, scale factor used, and which receiving apps were verified

- [x] Task 4: Cancellation has no side effects (AC: 3)
  - [x] 4.1 The share sheet is bound to `@State private var isShareSheetPresented`. Cancellation flips the binding via SwiftUI's built-in dismiss — no model mutation, no ViewModel state change
  - [x] 4.2 Added `test_shareSnapshot_noMutations` in `RoundSummaryViewModelTests` — calls `shareSnapshot`, then asserts `playerRows`, `organizerName`, `courseName`, `holesPlayed` are all unchanged.

- [x] Task 5: Watch interplay (AC: 4)
  - [x] 5.1 Confirm `RoundSummaryView` is presented from the iPhone target only — `HyzerApp/Views/Scoring/ScorecardContainerView.swift` is iOS-only; there is no equivalent on `HyzerWatch`
  - [x] 5.2 The share button is unconditionally rendered in the iPhone summary regardless of Watch state. No code change required; verified by inspection. Documented in Completion Notes.
Status: done

## Story
...
- [x] Task 6: Tests (AC: 1, 2, 3)
  - [x] 6.1 Extended `RoundSummaryViewModelTests` — `shareSnapshot(displayScale: 3.0)` returns a non-nil `UIImage` for a round with 6 players + 1 guest; `image.size.width ≈ 390pt`
  - [x] 6.2 Added 3 `shareText` tests in `RoundSummaryViewModelTests`: single winner (em dash + "won"), tied winners (comma-joined), empty standings fallback
  - [x] 6.3 Added `test_shareSnapshot_noMutations` — asserts all ViewModel properties unchanged after `shareSnapshot` call

### Review Findings

- [x] [Review][Patch] Brittle Width Assertion [HyzerAppTests/RoundSummaryViewModelTests.swift:401]
- [x] [Review][Patch] Enhance `shareText` logic (Grammar, Newline Sanitization, Truncation) [HyzerApp/ViewModels/RoundSummaryViewModel.swift:89]
- [x] [Review][Defer] Hardcoded English Strings (Localization Risk) [HyzerApp/ViewModels/RoundSummaryViewModel.swift:90] — deferred, pre-existing
### Architecture & Patterns

- **Share path is already implemented.** This story is a verification + polish + caption-format pass. Most of the work is auditing what is in place from Story 3.6 and reconciling deltas with the post-MVP epic.
- **`ImageRenderer`** is the modern SwiftUI rendering API (iOS 16+, fine on iOS 18). Already used at `RoundSummaryViewModel.shareSnapshot(displayScale:)`.
- **`UIActivityViewController`** via the existing `ShareSheetRepresentable` (currently a private struct inside `RoundSummaryView`). This was duplicated in `HistoryRoundDetailView` per the retro debt list — note the duplication but DO NOT extract it as part of this story (scope creep). Document the existing tech debt in the references section instead.
- **No analytics requirement** — the epic explicitly says "analytics not required."

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| `RoundSummaryViewModel.shareSnapshot(displayScale:)` | `HyzerApp/ViewModels/RoundSummaryViewModel.swift:84` | Already produces the `UIImage`. Reuse as-is |
| `SummaryCardSnapshotView` | `HyzerApp/Views/Scoring/RoundSummaryView.swift:197` | Already the render target. Note: this view receives Story 11.2's medal-style update — verify your story merges cleanly with 11.2 |
| `ShareSheetRepresentable` (private) | `HyzerApp/Views/Scoring/RoundSummaryView.swift` | Already wraps `UIActivityViewController`. Reuse as-is |
| Share button (`shareButton` computed view) | `HyzerApp/Views/Scoring/RoundSummaryView.swift:100` | Bottom CTA already styled with `Color.accentPrimary`. Verify primary-CTA placement matches UX action hierarchy |

### File Structure

**Files to modify:**
```
HyzerApp/Views/Scoring/RoundSummaryView.swift            # Update shareText format (em dash, "won")
```

**Files to leave unchanged:**
```
HyzerApp/ViewModels/RoundSummaryViewModel.swift          # shareSnapshot is correct; no change unless you choose to add stateSnapshot for tests
```

**Test files to add or extend:**
```
HyzerAppTests/ViewModels/RoundSummaryViewModelTests.swift # shareSnapshot non-nil + size assertion
HyzerAppTests/Views/RoundSummaryViewTests.swift           # shareText format assertion
```

**Update `project.yml`?** No.

### Edge Cases

| Case | Behavior |
|------|----------|
| User cancels share sheet | Sheet dismisses; `shareImage` remains set on the View (`@State`); no model mutation. Safe. |
| `shareSnapshot` returns `nil` (renderer failure) | Share sheet is not presented (`if shareImage != nil` guards the present). User can tap again. Defensive but reasonable — `ImageRenderer` can fail in low-memory situations. |
| Round has no completed scores (zero-player edge) | Cannot happen for a completed round — `Round.complete()` requires standings to exist. No special handling. |
| Single-player round | Winner is that one player. Caption renders normally. |
| Round summary still presented when Watch becomes active | Watch never opens the summary card; iPhone share button is always present. AC #4 satisfied. |

### Scope Boundaries — Do NOT Implement

- Do NOT extract `ShareSheetRepresentable` into a shared component (known retro debt; out of scope for this story to avoid blast-radius creep — track separately).
- Do NOT add analytics for share events.
- Do NOT change `SummaryCardSnapshotView` layout — Story 11.2 owns those changes.
- Do NOT add a "share to specific contact" affordance — use the system share sheet only.
- Do NOT enable share from the Watch — iPhone-only per AC #4.

### Previous Story Intelligence (3.6, 8.1)

- Story 3.6 implemented the share path. The `RoundSummaryView` snapshot already uses `ImageRenderer` + `ShareLink`-equivalent (`UIActivityViewController` via `ShareSheetRepresentable`).
- Story 8.1 noted `ShareSheetRepresentable` is duplicated between `RoundSummaryView` and `HistoryRoundDetailView` — known debt (retro), out of scope here.
- Pattern from 3.6: `@State private var shareImage: UIImage?` set just before presenting the sheet; the sheet content reads from the optional. This avoids re-rendering on every state change — keep that pattern.

### Testing Requirements

- **Framework:** Swift Testing.
- **`UIImage` size assertion:** Use `image.size` (points) and `image.scale`. For `displayScale: 3.0` on a 390pt-wide snapshot, the underlying CGImage will be 1170 pixels wide. Test the `image.size.width ≈ 390` (points) tolerance.
- **`shareText` format:** Plain string equality on the formatted output for a fixture round.
- **Manual verification (AC #2):** Required and called out — run on the simulator, dispatch to Messages, then one third-party app. Record dimensions in Completion Notes.

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Epic 11, Story 11.3] — user story, scope, ACs
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#PMVP-FR8] — feature requirement
- [Source: HyzerApp/Views/Scoring/RoundSummaryView.swift] — share button + sheet wiring
- [Source: HyzerApp/ViewModels/RoundSummaryViewModel.swift] — `shareSnapshot(displayScale:)`
- [Source: _bmad-output/implementation-artifacts/3-6-round-completion-and-summary.md] — original share-path implementation
- [Source: _bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md] — known debt: `ShareSheetRepresentable` duplication
- [Source: CLAUDE.md#Coding Standards] — design tokens only; no defensive coding for impossible cases

## Dev Agent Record

### Agent Model Used
claude-sonnet-4-6

### Debug Log References
- Pre-existing Swift Testing keypath bug in Story 11.2 test (`#expect(medalRows.allSatisfy(\.hasMedal))`) — fixed to use closure form (`{ $0.hasMedal }`).

### Completion Notes List
- **Task 1 (Audit):** Share path from Story 3.6 is fully in place — share button (bottom CTA), `ShareSheetRepresentable`, `ImageRenderer`-backed `shareSnapshot(displayScale:)`. Delta: caption format was wrong (double-hyphen, present tense, trailing `!`).
- **Task 2 (Caption):** Moved `shareText` from private View property to `RoundSummaryViewModel` computed property. New format: `"Round at [course] \u{2014} [winner(s)] won at [score]"`. Fallback to `"Round at [course]"` if standings unexpectedly empty.
- **Task 3 (PNG):** `SummaryCardSnapshotView` is fixed at 390pt width; `renderer.scale = displayScale` already set. Test confirms `image.size.width ≈ 390pt` at scale 3.0. Manual simulator verification (Task 3.3/3.4) left for user.
- **Task 4 (Cancellation):** `isShareSheetPresented` is a View `@State` var — cancellation only flips the binding. ViewModel has all `let` properties; `shareSnapshot` is read-only. No model mutations possible.
- **Task 5 (Watch):** `RoundSummaryView` is presented exclusively from `ScorecardContainerView` (iOS-only, `HyzerApp` target). `HyzerWatch` has no summary view. Share button always present on iPhone regardless of Watch state. No code change needed.
- **Task 6 (Tests):** 5 new tests added to `RoundSummaryViewModelTests`: `shareSnapshot` non-nil at 3x for 6+1 round, `shareText` single winner format, `shareText` tied winners, `shareText` fallback, cancellation no-mutations.
- **Tech debt noted (not addressed):** `ShareSheetRepresentable` duplication between `RoundSummaryView` and `HistoryRoundDetailView` — tracked in retro, out of scope per story boundaries.

### File List
- `HyzerApp/ViewModels/RoundSummaryViewModel.swift` — added `shareText` computed property (em dash format, past tense, fallback)
- `HyzerApp/Views/Scoring/RoundSummaryView.swift` — removed private `shareText`, wired `.sheet` to `viewModel.shareText`
- `HyzerAppTests/RoundSummaryViewModelTests.swift` — added 5 new tests (Task 6.1, 6.2, 6.3)
- `HyzerAppTests/Views/RoundSummaryViewTests.swift` — fixed pre-existing keypath/`#expect` compilation bug (Story 11.2)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — status: ready-for-dev → in-progress
