# Story 15.3 Code Review — Generative Signature Ship-Gate Verification

**Reviewer:** code-reviewer subagent
**Date:** 2026-05-18
**Branch:** feature/15-3-story-14-2-manual-verification
**Diff:** 3 files changed, 19 insertions(+), 14 deletions(-) — spec markdown, deferred-work.md, sprint-status.yaml. Evidence dir (gitignored) contains README.md + contrast-report.md only.
**Spec:** 15-3-generative-signature-ship-gate-verification.md
**Review mode:** full

## Summary

Story 15.3 is correctly marked `in-progress` (not `done`) because 4 of the 6 ACs (live render, PNG export, VoiceOver, Reduce Motion) require human simulator interaction that the non-interactive dev agent cannot perform. The automatable portion (AC #2 palette contrast) was attempted but its conclusion contains a material factual error: the contrast-report.md asserts `backgroundTertiary` is "background-layer / sub-layer only" and therefore safe to fail at 1.21:1, but `RoundSignature.swift:114-117` actually includes `backgroundTertiary` directly in the 8-color foreground palette used for ring strokes and gradient flourishes. The "expected by design" framing in the report and Completion Notes understates the regression risk and could lead a reviewer to wave the finding through without the audit the spec explicitly demands.

## Findings

### [HIGH] [accuracy] contrast-report.md mischaracterizes `backgroundTertiary` as sub-layer-only when it is actively used as a foreground stroke/fill
- **Source:** Blind Hunter + Edge Case Hunter
- **Location:** `_bmad-output/implementation-artifacts/15-3-evidence/contrast-report.md:28-50`; cross-ref `HyzerApp/Views/Components/RoundSignature.swift:114-117, 56, 76-85`
- **AC violated:** AC #2 (spec line 17) — every palette entry below 4.5:1 must be flagged 🟥 FAIL with a follow-up issue proposing replacement or outline-only constraint. The bullet in deferred-work.md was REPLACED rather than augmented with a concrete follow-up for the failing token.
- **Detail:** The report's "Notes" section claims `backgroundTertiary` is "a background-layer token, not a foreground/stroke token" and that "its near-zero contrast against backgroundElevated is expected by design." That assertion is wrong: in `RoundSignature.swift` the palette array `[.scoreUnderPar, .scoreAtPar, .scoreOverPar, .scoreWayOver, .accentPrimary, .textPrimary, .textSecondary, .backgroundTertiary]` is the source for `primaryColor`/`secondaryColor`/`accentColor`, which are used as (a) 1.5pt `Circle().stroke(...)` colors in `concentricRings` and (b) `AngularGradient` stops at opacity 0.6 in `flourish`. When the hash bytes select `backgroundTertiary` for any of the three slots (~37.5% of rounds for at least one slot, by 3/8 selection probability), those rings/flourish stops will be effectively invisible against `backgroundElevated`. This is the exact failure mode the Story 14.2 review-finding flagged (line 425 spec: "Do NOT proceed past Task 4 without checking this") and is a real regression in roughly one third of generated signatures — not "expected by design."
- **Suggested fix:** Update contrast-report.md "Notes" to state that `backgroundTertiary` IS used as a foreground stroke/gradient stop in `RoundSignature.swift` and therefore the 1.21:1 ratio is a real AC #3 failure affecting an estimated 37.5%+ of rounds. File a concrete follow-up issue (per spec line 17 and Story 14.2 deferred bullet) proposing replacement of `backgroundTertiary` in the palette array (line 116 of RoundSignature.swift) with a higher-contrast alternative (e.g., re-using `accentInk`, `warning`, or simply dropping it to a 7-color palette). Update Completion Notes accordingly. Restore the deferred-work.md entry with the follow-up issue link instead of the vague "in-progress" replacement currently committed.

### [MEDIUM] [completeness] Completion Notes claim "Tasks 1/3/4/5 deferred to human simulator verification" but the spec's exit criterion requires those tasks to run before the story closes
- **Source:** Acceptance Auditor
- **Location:** Spec lines 25 (AC #6), 71-75 (Task 6), and the in-progress story's Completion Notes/Change Log
- **AC violated:** AC #6 — Completion Notes must summarize the result with a single sentence covering all four ACs (#3/#4/#5/#6) and the deferred-work bullet must be removed (not just edited) only when the four ACs are satisfied.
- **Detail:** The current status `in-progress` is honest and correct, but the partial commit creates ambiguity: (1) the deferred-work.md bullet was REPLACED with a Story 15.3 placeholder instead of LEFT IN PLACE pending completion, which weakens the trail of unresolved 14.2 risk if someone audits deferred-work alone; (2) the spec at Task 6.3 instructed "REPLACE the bullet with a new entry naming the failure" only IF contrast failures were found AND the story closes — the current edit replaces it before closure, partially executing Task 6.3 mid-flight; (3) sprint-status flipped to in-progress is fine, but no human handoff plan is recorded in the story (who picks this up, against which simulator, by when).
- **Suggested fix:** Either (a) revert the deferred-work.md edit until Story 15.3 actually closes, or (b) keep the edit but make it explicit that the original 14.2 risk is still unresolved AND add a "Pending Handoff" section to the spec naming the simulator owner and target date. Prefer (a) for hygiene — the spec's Task 6.3 is a CLOSE-the-story action, not an in-progress action.

### [MEDIUM] [methodology] Automated WCAG calculation substituted for the spec-mandated tool without acknowledging the trade-off
- **Source:** Acceptance Auditor
- **Location:** Spec line 37 (Task 2.1: "Open Apple's Color Contrast Analyzer…or another 4.5:1-validating tool"); evidence README.md line 7; contrast-report.md lines 6-9
- **AC violated:** None directly — AC #2 permits "any 4.5:1-validating tool of equivalent rigor" — but the diff marks Task 2.1 as `[~]` (partial) without explaining how a programmatic WCAG 2.1 calculation is equivalent-rigor to Color Contrast Analyzer (which also performs a profile-aware sRGB sampling). Since these tokens are defined as plain sRGB `Color(hex:)` in `ColorTokens.swift:5-16` with no extended-range color profile, the math IS in fact equivalent — but the report doesn't say so.
- **Detail:** A reviewer can't tell from the artifact whether the substitution is rigorous or expedient. The numbers themselves are correct: spot-checked `scoreAtPar #F5F5F7` vs `backgroundElevated #1C1C1E` produces ~15.5:1 per the WCAG formula, matching the report. But "equivalent rigor" needs one explicit sentence.
- **Suggested fix:** Add one paragraph to contrast-report.md noting that ColorTokens are defined via plain `Color(.sRGB, …)` (HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:14), so the WCAG 2.1 sRGB formula is mathematically identical to Color Contrast Analyzer's reading. This converts the "automated" choice from a shortcut into a justified-equivalent.

### [LOW] [doc-link] Spec line 153 references "Story 14.2 line 455" but that line is in the 14.2 spec, not the 15.3 spec
- **Source:** Blind Hunter
- **Location:** Spec line 39 ("expected: `#1C1C1E` per Story 14.2 dev notes line 455")
- **AC violated:** None
- **Detail:** Minor doc-link nit — the reference is correct (verified by reading 14.2 spec line 455), but a future reader navigating 15-3-*.md alone may briefly look for line 455 in the wrong file. Not worth fixing.
- **Suggested fix:** Dismiss — readable in context.

### [LOW] [consistency] `[~]` checkbox character is non-standard and may not render in some markdown viewers
- **Source:** Blind Hunter
- **Location:** Spec lines 36, 37 (Task 2 and 2.1 marked `[~]`)
- **AC violated:** None
- **Detail:** GFM checkboxes are `[ ]` / `[x]`. `[~]` renders as literal text. Intent (partial-complete) is clear enough in the diff context.
- **Suggested fix:** Dismiss — internal artifact, intent is clear.

## Triage Counts
- decision_needed: 1 | patch: 2 | defer: 0 | dismissed: 2

## Dismissed (noise log)
- Spec line 39 line-reference ambiguity — readable in context, not worth churn.
- `[~]` checkbox character — internal-artifact, intent obvious from surrounding strikethrough/marks.

## Verdict
🟡

The story is correctly held in `in-progress` and the partial automated work is real (contrast numbers verified accurate). However, the contrast-report's conclusion about `backgroundTertiary` is factually wrong against the actual `RoundSignature.swift` palette usage, and that misframing — if accepted at story close — would re-bury the exact AC #3 risk Story 14.2's review-finding flagged. Patch the report's Notes section and file the concrete follow-up before treating the AC #2 portion as complete; the remaining human-only tasks (1, 3, 4, 5) need a named owner before this story can be closed.
