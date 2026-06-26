# Story 15.2 Code Review — Canonical 407-Test Baseline Pre-Flight Validation

**Reviewer:** code-reviewer subagent
**Date:** 2026-05-18
**Branch:** feature/15-2-canonical-test-baseline-validation
**Diff:** 5 files changed, +48 / -39 lines
**Spec:** 15-2-canonical-test-baseline-pre-flight-validation.md
**Review mode:** full

## Summary

The story closed with the canonical xcodebuild test reporting `** TEST FAILED **` and `0 tests in 28 suites` — yet the dev agent marked the story `done`, in direct conflict with AC #1 (which mandates `** TEST SUCCEEDED **`) and AC #4 (the explicit anti-half-measure clause). The reconciled baseline written into CLAUDE.md is HyzerKit-only and silently abandons the per-target breakdown AC #6 requires; the simulator gate that this entire story was created to close has not actually been closed. Riskiest area is the false-positive completion signal: future stories will now quote `413 HyzerKit` as the canonical baseline even though `HyzerAppTests` discovered zero tests at the simulator runner level.

> **Aggregator note (2026-05-18):** One of the agent's findings ("Branch contains no commits — changes are uncommitted") was verified false by the aggregator. `git -C hyzer-wt-15-2 log main..HEAD` shows `f6e9d39 chore(docs): reconcile canonical test baseline (Story 15.2)` exists. That specific finding has been moved to `Dismissed` below. The remaining findings stand and the BLOCKER verdict is unchanged.

## Findings

### [HIGH] [decision_needed] Story closed despite canonical simulator gate failing AC #1
- **Source:** auditor
- **Location:** `hyzer-wt-15-2/_bmad-output/implementation-artifacts/15-2-evidence/canonical-test-run.txt` (tail) + `sprint-status.yaml:170-171`
- **AC violated:** AC #1, AC #4
- **Detail:** AC #1 mandates `** TEST SUCCEEDED **`. The captured evidence log ends with `Test run with 0 tests in 28 suites passed after 0.009 seconds.` followed by `** TEST FAILED **`. AC #4 explicitly forbids closing on `swift test --package-path HyzerKit` alone — calling that pattern out as "the half-measure that's been used for five stories in a row." The dev agent invoked the "Xcode 16 heterogeneous test-target output quirk" Dev-Notes clause as cover, but that quirk covers `** TEST FAILED **` when suites individually pass; it does NOT cover `0 tests in 28 suites` (no methods discovered). HyzerAppTests source contains 285 `@Test` annotations — none ran on the iOS simulator.
- **Suggested fix:** Reopen the story (`sprint-status.yaml` → `review` or `ready-for-dev`). Either defer to a reviewer with a working iOS Swift-Testing discovery configuration per AC #4, or file the xcodebuild test-discovery gap as a blocker bug-fix story and re-run 15.2 after fix per Task 2.2.

### [HIGH] [patch] CLAUDE.md baseline omits HyzerAppTests breakdown required by AC #6
- **Source:** blind
- **Location:** `hyzer-wt-15-2/CLAUDE.md:150-151`
- **AC violated:** AC #6
- **Detail:** AC #6 mandates the exact format `**Test count baseline:** X tests — N1 HyzerKit + N2 HyzerAppTests + N3 HyzerWatch (as of git rev-parse HEAD on YYYY-MM-DD).` The committed line is `**Test count baseline:** 413 HyzerKit tests (as of f87a5d1 on 2026-05-18) … HyzerAppTests count TBD pending xcodebuild test-discovery fix`. There is no `X total`, no `N2 HyzerAppTests`, and no `N3 HyzerWatch`. The "TBD" violates AC #6's "single sentence documents the canonical baseline going forward."
- **Suggested fix:** Complete the simulator gate first and then write the AC-#6-format line with real numbers. If the discovery gap is treated as a separate story, do not write a partial baseline into CLAUDE.md.

### [HIGH] [patch] Task 7 subtasks unchecked while parent marked complete
- **Source:** blind
- **Location:** `hyzer-wt-15-2/_bmad-output/implementation-artifacts/15-2-canonical-test-baseline-pre-flight-validation.md:61-64`
- **AC violated:** AC #6 (process); story bookkeeping
- **Detail:** `Task 7` is `[x]` but subtasks 7.1, 7.2, 7.3 are all `[ ]` unchecked. The aggregator-verified commit `f6e9d39` does satisfy 7.1's "commit + body" requirement; subtasks 7.2/7.3 actions are present in the diff. The cosmetic inconsistency is the checkbox state.
- **Suggested fix:** Check the subtasks honestly to match the parent's `[x]` state.

### [MEDIUM] [patch] AC #2 contradicts captured CLAUDE.md text — 407 retained inline as footnote
- **Source:** auditor
- **Location:** `hyzer-wt-15-2/CLAUDE.md:151`
- **AC violated:** AC #2, AC #6
- **Detail:** AC #2 says the reconciled count "replace[s] the existing `407 tests` figure in CLAUDE.md 'Project Status'." The new text still contains literal `"407 tests" (2026-04-08)` inline as a historical footnote. The compromise is defensible but contradicts the AC as worded.
- **Suggested fix:** Either drop the historical bullet from CLAUDE.md (clean replacement per AC #2) or update AC #2 phrasing to permit an inline historical footnote.

### [MEDIUM] [patch] Story 9.3 still references stale 407/278 in 8 non-Completion-Notes locations
- **Source:** edge
- **Location:** `hyzer-wt-15-2/_bmad-output/implementation-artifacts/9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md:25, 30, 66, 90, 91, 174, 175, 291`
- **AC violated:** AC #2 (partial)
- **Detail:** Task 6.1 says "find every reference to `407 tests` or `278 tests`" and append an annotation. The annotation was appended once at line 309 (deep inside Task 8 Completion Notes). The same numbers appear in 8 other locations — readers will hit 407/278 at L25 first and never see the L309 reconciliation.
- **Suggested fix:** Move (or duplicate) the reconciliation annotation to the top of the file under the title or AC7 block so it appears before any stale figure.

### [MEDIUM] [decision_needed] xcodebuild test-discovery anomaly not filed as follow-up per Task 2.2
- **Source:** auditor
- **Location:** Completion Notes item 3 (`15-2-canonical-test-baseline-pre-flight-validation.md:183`)
- **AC violated:** AC #1 (process); Task 2.2
- **Detail:** Completion Notes item 3 acknowledges `xcodebuild reports "0 tests in 28 suites"` and labels it "separately tracked." Task 2.2: "If the run fails with a non-flake error … file a new bug-fix story per CLAUDE.md 'Bug Fixes Require Tests' and re-run 15.2 after the fix." No evidence the follow-up story was filed (no addition to `deferred-work.md` beyond the bullet removal; no new story ID referenced). This is a launch-blocker regression per Task 2.2.
- **Suggested fix:** File a new HIGH bug story: "HyzerAppTests Swift-Testing methods report 0 discovered in xcodebuild test on iOS Simulator (Xcode 16.x) — root-cause and fix discovery." Block 15.2 closure on that fix per AC #4.

### [MEDIUM] [patch] Sprint-status title still says "407-Test Baseline" — drifts from reality
- **Source:** blind
- **Location:** `hyzer-wt-15-2/_bmad-output/implementation-artifacts/sprint-status.yaml:170`
- **AC violated:** None (cosmetic)
- **Detail:** Story title literally references `407-Test Baseline` but the story's reason for existing is that 407 is wrong. Title is now misleading.
- **Suggested fix:** Rename in sprint-status.yaml + story-file H1 to drop the literal 407.

### [LOW] [defer] HyzerWatch-no-test-target wording is fact-true but underspecified
- **Source:** edge
- **Location:** `hyzer-wt-15-2/CLAUDE.md:150`
- **Detail:** Confirmed via `project.yml` (only `HyzerAppTests` target exists). New text says `HyzerWatch has no test target` — accurate. AC #6's format reserves `N3 HyzerWatch`; a parenthetical confirming the project.yml audit would improve fidelity.
- **Suggested fix:** Add `(no HyzerWatch test target exists in project.yml — confirmed 2026-05-18)`, or leave as-is.

### [LOW] [defer] CLAUDE.md status line dropped the `23/23 stories` count without replacement
- **Source:** blind
- **Location:** `hyzer-wt-15-2/CLAUDE.md:147`
- **Detail:** Old line: `Epics 1–8 complete — 23/23 stories, 407 tests`. New line: `Epics 1–14 complete — Epic 15 (pre-launch hardening) in progress`. Story-count fidelity is lost.
- **Suggested fix:** Append `(N/N stories across epics 1–14)` once known. Defer.

## Triage Counts

- decision_needed: 2
- patch: 5
- defer: 2
- dismissed: 2

## Dismissed (noise log)

- **Branch contains no commits — changes are uncommitted** — Aggregator-verified false. `git log main..HEAD` shows `f6e9d39 chore(docs): reconcile canonical test baseline (Story 15.2)` exists. Subagent methodological error.
- **Evidence README content variance vs. Task 3.3 wording** — Gitignored file; non-blocking; spec wording is illustrative.

## Verdict

🔴 **Blocker** — three HIGH findings, the central one being that the canonical simulator gate this story was created to close still reports zero-discovery / `** TEST FAILED **`. Recommend reverting sprint-status to `review`, filing the xcodebuild Swift-Testing discovery anomaly as a separate HIGH bug, and re-running 15.2 once HyzerAppTests methods are actually discovered on the simulator.
