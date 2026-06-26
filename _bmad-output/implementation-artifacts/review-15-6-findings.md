# Story 15.6 Code Review — Stale Planning Artifact Cleanup (ColorTokens.border Purge & Frozen-Artifact Policy)

**Reviewer:** code-reviewer subagent
**Date:** 2026-05-18
**Branch:** feature/15-6-stale-artifact-cleanup
**Diff:** 6 files, +54 / -45 (CLAUDE.md +10; story file rewritten in place; deferred-work.md -5; retro +1; epics-post-mvp.md +3; sprint-status.yaml status flip)
**Spec:** 15-6-stale-planning-artifact-cleanup.md
**Review mode:** full

## Summary

Doc-only Story 15.6 cleanly applies Policy A (append-only) by annotating the four named stale `ColorTokens.border` references and codifying a Frozen Artifact Policy section in `CLAUDE.md`. No Swift was touched, no canonical docs (architecture.md, prd.md) were demoted, and the deferred-work bullets are removed. One minor wording inconsistency in the policy text and a few small enforceability gaps are the only material findings; overall the diff matches the spec.

## Findings

### [MINOR] [Policy clarity] Frozen Artifact Policy is silent on enforcement / violation remediation
- **Source:** Blind Hunter
- **Location:** `CLAUDE.md:135-143`
- **AC violated:** AC #6 ("answers the practical question: 'If I find an outdated statement in a retro or sign-off planning doc, what do I do?'")
- **Detail:** The policy tells future contributors *what to do* when they spot stale text (append an italicized annotation), but does not say *what to do if they discover someone has violated the policy by editing in place* (e.g., revert the rewrite, restore from git history, or escalate via a new cleanup story). It also gives no rationale for the choice — AC #6 says "includes a one-line rationale for the choice." The current text only has the intent sentence ("preserve the historical record AND surface current truth via cross-references"), which is close but not framed as a rationale for Policy A over Policy B.
- **Suggested fix:** Append one sentence to the policy block: "_Rationale: preserves the historical record without destructive edits, matching the convention used by IETF RFCs, Python PEPs, and OpenJDK JEPs. If you find a violation (in-place rewrite without annotation), restore the original text from git history and add the annotation instead._"

### [MINOR] [Scope coverage] Two additional `ColorTokens.border` stale-debt references inside Story 9.3's own epic narrative remain unannotated
- **Source:** Edge Case Hunter
- **Location:** `_bmad-output/planning-artifacts/epics-post-mvp.md:220` (Story 9.3 Scope) and `:239` (Story 9.3 Given/When AC paragraph)
- **AC violated:** None directly — the spec scoped the work to "the four `ColorTokens.border` references" named in Story 9.3 review-findings (1 retro + 3 in epics-post-mvp). The spec explicitly says "Stay focused on the four references."
- **Detail:** A grep of `epics-post-mvp.md` post-merge still shows 11 occurrences of `ColorTokens.border`. Of those, lines 220 and 239 sit inside Story 9.3's own scope/AC text and describe the token in language consistent with the pre-9.3 state ("defined but never referenced — define it now if any new component will use it, or remove the reference if dead code" / "**Then** either the token is defined and resolves to a hex value... or all stale references have been removed"). A future reader who lands on the Story 9.3 epic narrative will read the unresolved framing without an adjacent annotation. The spec told the dev agent to stay focused, so this is not a spec violation, but the cleanup is genuinely incomplete from the AC #6 "no contributor wastes a cycle filing duplicate work" perspective.
- **Suggested fix:** Either accept as-out-of-scope (defensible — these are Story 9.3's own AC text, not stale claims of *current* open debt) and document the decision in the Story 15.6 Completion Notes, or follow up with a one-line PR adding two more annotations. Recommend the former: those two lines are the *spec* of Story 9.3, not stale claims about the *state of the codebase*.

### [MINOR] [Drift] Story-spec text was rewritten in place rather than checkboxes simply checked
- **Source:** Blind Hunter
- **Location:** `_bmad-output/implementation-artifacts/15-6-stale-planning-artifact-cleanup.md` lines 27-61 (Tasks section)
- **AC violated:** None — story files are explicitly NOT frozen per the new policy ("Story files themselves... and `sprint-status.yaml` are NOT frozen").
- **Detail:** The dev agent collapsed the original Task 1 elicitation prompt (and subtasks 1.1-1.3) into a single line "Policy decision pre-made by user: Policy A. No elicitation needed." This is acceptable under the new policy because story files are status records, but it does erase the original Task 1.1 prompt text. If the user wants the historical record of "Task 1.1 was originally an elicitation step that we skipped," that nuance is now lost from the story file.
- **Suggested fix:** No action required. Acceptable per the policy. Flagging only because Task 1.1 collapse is the only meaningful narrative drift in the diff.

### [MINOR] [Acceptance audit] AC #4 regression check not executed
- **Source:** Acceptance Auditor
- **Location:** Story file lines 51-53, tasks 4.2 and 4.3
- **AC violated:** AC #4 ("the canonical regression check ... is performed after the cleanup")
- **Detail:** The dev agent recorded "No Swift was edited; HyzerKit test count is unchanged (doc-only story)" but did not actually run `swift test --package-path HyzerKit` or `swiftlint lint`. AC #4 specifically requires the regression check to be *performed* — its purpose is to catch surprise side effects (e.g., a stray edit in the agent's working tree). For a strictly doc-only diff this is low risk, but it is a literal AC miss.
- **Suggested fix:** Run `swift test --package-path HyzerKit` and `swiftlint lint` against the worktree before final merge; record counts in Completion Notes. If the diff is genuinely doc-only (verified by `git diff --stat` showing zero Swift files), this takes under a minute and removes the AC ambiguity.

### [MINOR] [Coverage gap] Policy lists `epics*.md` glob but not `epics-1-8-retro-*.md` retros explicitly clear
- **Source:** Edge Case Hunter
- **Location:** `CLAUDE.md:135` (policy file-glob list)
- **AC violated:** None
- **Detail:** The policy enumerates `epics-*-retro-*.md`, `epics*.md`, `prd.md`, `architecture.md`. The implementation-readiness-report (`_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-13.md`) — which itself contains two stale `ColorTokens.border` references at lines 316 and 385 framing 9.3 sizing as "scope creep" — is not covered by the glob. A strict reader would conclude this report is *not* a frozen artifact. Probably fine (it's a one-off report, not a recurring retro), but the policy does not address one-off planning reports.
- **Suggested fix:** Add a parenthetical to the policy glob: "(also: one-off planning reports such as implementation-readiness-report-YYYY-MM-DD.md)" — or explicitly call them out as out-of-scope so future contributors don't waste a cycle.

### [INFO] [Verification] Annotation lines correctly placed and word-identical across all 4 locations
- **Source:** Edge Case Hunter
- **Location:** retro line 97-98; epics-post-mvp.md lines 81-82, 121-122, 164-165
- **Detail:** Confirmed via grep: 4 stale references each followed by an italicized `_Resolved by Story 9.3 — Path A retained. ColorTokens.border defined and documented at HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51. (Story 15.6, 2026-05-18)_` annotation. Wording is identical across all four. Date placeholder `2026-MM-DD` correctly replaced with `2026-05-18`. Line-156 → line-162 shift (from Epic 15 additions) was correctly identified and applied to the actual current line.

### [INFO] [Cross-reference integrity] No canonical docs demoted; deferred-work.md correctly trimmed
- **Source:** Blind Hunter / Edge Case Hunter
- **Detail:** `architecture.md`, `prd.md`, and `docs/*` are untouched. `deferred-work.md` lines 57-58 (the two 9.3-deferred bullets) are removed cleanly with the section header also removed (which is correct — the section had only those two bullets). The Story 9.3 file (`9-3-*.md`) was not touched; its review-findings line 333 still describes the bullet as "deferred" but that's a frozen historical record and is exactly what the new policy says should stay frozen.

## Triage Counts

- decision_needed: 1 | patch: 4 | defer: 1 | dismissed: 0

(decision_needed = AC #4 regression run; patch = policy rationale, scope clarification, enforcement clause, implementation-readiness-report glob; defer = lines 220/239 inside Story 9.3 epic narrative)

## Dismissed (noise log)

- (none — all findings retained as actionable or informational)

## Verdict

🟡 — Spec intent achieved and policy is in place; recommend addressing the one decision-needed item (run the regression command per AC #4) and accepting or patching the minor policy-text gaps before considering the cleanup definitive. No blockers.
