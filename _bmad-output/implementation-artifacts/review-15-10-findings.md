# Story 15.10 Code Review — Centralize History-Service Constants

**Reviewer:** code-reviewer subagent
**Date:** 2026-05-18
**Branch:** feature/15-10-centralize-history-constants
**Diff:** 7 files changed, 81 insertions(+), 59 deletions(-); source-code changes limited to 4 files (`ScoreEvent.swift`, `PlayerTrendService.swift`, `PersonalBestService.swift`, `HeadToHeadService.swift`).
**Spec:** 15-10-centralize-history-service-constants.md
**Review mode:** full

## Summary
The diff cleanly promotes the `* 20` literal to `ScoreEvent.maxEventsPerRound` across all three history services (5 sites) and replaces every `$0.status == "completed"` predicate inside `HyzerKit/Domain/` with the existing `RoundStatus.completed` static constant (4 sites). Behavior is preserved, `fetchLimit` boundedness is intact, doc comments are accurate, and the local-variable capture pattern (`let completedStatus = RoundStatus.completed`) is a correct `#Predicate` workaround for static-member references. However, Task 4.1 explicitly required surfacing any remaining `status == "completed"` literal anywhere in `HyzerKit`/`HyzerApp`/`HyzerWatch`, and one such call site (`HistoryListView.swift:14`) was missed — surfacing this miss is the dev agent's documented obligation, not a silent acceptance.

## Findings

### [MAJOR] [completeness] Untouched `status == "completed"` literal in `HistoryListView`
- **Source:** Blind Hunter + Edge Case Hunter cross-grep.
- **Location:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-wt-15-10/HyzerApp/Views/History/HistoryListView.swift:14`
- **AC violated:** AC #3 ("any other call site using the string literal `"completed"` to compare `Round.status`… the comparison uses the type-safe form") and Task 4.1 ("Surface any remaining match to the user — it indicates a service or test file the dev missed").
- **Detail:** The `@Query` filter `#Predicate<Round> { $0.status == "completed" }` is a verbatim instance of the pattern this story exists to eliminate. The spec scopes the type-safe predicate replacement to "the three service files plus **any other call site** using the string literal `"completed"`" (AC #3 introduction). Task 4.1's grep is intentionally scoped to `HyzerKit HyzerApp HyzerWatch`, and the completion note for Task 4.1 ("Verified via code inspection: zero `* 20` or `status == "completed"` string literals remain in the three service files") narrowed the verification scope to the three service files only — contradicting the AC. The miss is not load-bearing for runtime correctness (the literal still works), but it leaves the very anti-pattern the story closes alive in a high-traffic top-level view, and it invalidates the completion-notes claim. The Story 13.1 deferred-work bullet that was removed in this diff explicitly described the concern as "pattern used codebase-wide; not story-specific. Would benefit from a type-safe wrapper across all `Round.status` comparisons" — i.e., the deferred-work removal is premature unless `HistoryListView` is also updated.
- **Suggested fix:** Either (a) update `HistoryListView.swift:14` to use the same `let completedStatus = RoundStatus.completed` capture pattern used in the three services, or (b) reopen a narrower deferred-work bullet pointing at `HistoryListView.swift:14` so the closure of Story 13.1's bullet is accurate.

### [MINOR] [scope-creep / honesty] Task 4.1 completion note narrows AC scope without flagging
- **Source:** Acceptance Auditor.
- **Location:** Spec file (`15-10-centralize-history-service-constants.md`) Dev Agent Record → Completion Notes, plus Task 4.1 in the diff (`- [x] 4.1 Verified via code inspection: zero `* 20` or `status == "completed"` string literals remain in the three service files.`).
- **AC violated:** AC #6 indirectly (deferred-work-bullet removal contingent on AC #3 holding codebase-wide).
- **Detail:** The original Task 4.1 instruction was a grep across `HyzerKit HyzerApp HyzerWatch`. The completed checkbox rephrases that as "in the three service files," silently collapsing the project-wide scope to the three Domain files. This is the mechanism by which the `HistoryListView` miss above stayed invisible. The Dev Agent Record otherwise meets the documentation bar (file list, completion notes, agent model, change log).
- **Suggested fix:** Rerun the literal grep with the original scope and update Task 4.1 completion note to either list zero matches across all three modules or surface the `HistoryListView.swift:14` site to the user as the spec mandates.

### [MINOR] [doc-drift] `ScoreEvent.swift` doc comment omits `discrepancy resolution events` rationale precision
- **Source:** Blind Hunter (diff-only inspection).
- **Location:** `/Users/shotcowboystyle/www/shotcowboystyle/hyzer-wt-15-10/HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift:21-29`
- **AC violated:** None strictly; AC #1 requires a one-line doc comment explaining the multiplier's origin and the implemented doc comment is multi-line and substantively accurate.
- **Detail:** The implemented comment compresses the spec-template wording ("plus discrepancy resolution events (each appending a new immutable event per event-sourcing semantics — see CLAUDE.md \"Data & Persistence\" event-sourcing invariant)") to "plus discrepancy resolution events (each appending a new immutable event per event-sourcing semantics)." The CLAUDE.md cross-reference was dropped. AC #5 ("doc comments are sufficient to discover and reuse the constants") still holds — the comment names the three consumers — but the architectural cross-reference is mildly weaker than the spec template.
- **Suggested fix:** Optional; if accepted, restore the `CLAUDE.md "Data & Persistence" event-sourcing invariant` reference.

### [MINOR] [redundancy] Local-variable capture for static value is uniform across all four sites
- **Source:** Edge Case Hunter.
- **Location:** `HeadToHeadService.swift:124, 213`; `PersonalBestService.swift:82`; `PlayerTrendService.swift:79`.
- **AC violated:** None.
- **Detail:** Every predicate site introduces `let completedStatus = RoundStatus.completed` immediately above the `FetchDescriptor`. The Change Log notes this was required by the `#Predicate` macro's inability to reference a static member directly — this is a real Swift constraint, and the pattern is consistent. No DRY violation since each site is local to its `FetchDescriptor`. Worth noting only because it represents per-call-site boilerplate that a future helper (e.g., a `Round` predicate factory) could collapse — but explicitly out of scope per "no service method signature changes."
- **Suggested fix:** None; record as future refactor candidate if a fourth predicate site arrives.

## Triage Counts
- decision_needed: 1 | patch: 1 | defer: 1 | dismissed: 1

## Dismissed (noise log)
- `RoundLifecycleStateTests.swift:151` and `SyncSchedulerTests.swift:408` retain `"completed"` literals — dismissed: the first is a unit test asserting on the underlying string raw value (legitimate; testing the contract that `Round.complete()` produces the string `"completed"`); the second is a code comment, not a runtime literal.
- `SyncEngine+RoundCompletion.swift:10` and `SyncScheduler.swift:247` retain `"completed"` literals — dismissed: both are doc-comment strings describing CloudKit subscription predicates, not runtime predicates. Out of AC scope.
- Test count claim "413 tests, 1 known flake (WatchVoiceViewModel auto-commit timer)" — dismissed: dev agent acknowledges no Bash access for automated run; flake is pre-existing per Story 13/14 review notes; AC #4 is verifiable by maintainer before merge.

## Verdict
🟡 — Diff is correct and behavior-preserving for the three target services; the centralized constant is well-documented, properly access-controlled (`public static let`), Swift 6-safe (immutable static), and every previous `* 20` / `status == "completed"` site inside `HyzerKit/Domain/` is migrated. One AC-scoped call site (`HistoryListView.swift:14`) was not migrated and was not surfaced to the user per Task 4.1's contract, which weakens the closure of the Story 13.1 deferred-work bullet that this PR removed. Recommend a single follow-up commit to either migrate `HistoryListView.swift:14` or re-add a narrower deferred-work bullet before this story is treated as fully closed.
