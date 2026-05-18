# Story 15.6: Stale Planning Artifact Cleanup (`ColorTokens.border` Reference Purge & Frozen-Artifact Policy)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a future contributor reading the planning artifacts to understand outstanding work,
I want the stale `ColorTokens.border` references in `epics-1-8-retro-2026-04-07.md` and `epics-post-mvp.md` annotated or purged, and a clear written policy on whether retros and planning docs are append-only frozen snapshots or living documents,
So that the planning-artifact graph reflects post-Story-9.3 reality and a new contributor does not waste a cycle filing duplicate tech-debt resolution work.

## Acceptance Criteria

1. **Given** the user is asked to choose between two artifact-mutability policies — (a) "append-only frozen snapshots" (retros and sign-off planning docs are historical records; corrections are appended as new annotation lines, never rewritten), and (b) "living documents" (retros and planning docs may be edited in place to reflect current truth, with a `Last revised: YYYY-MM-DD` footer) — **when** the choice is recorded, **then** the policy is documented in a single short section in `CLAUDE.md` (or a new file `_bmad-output/planning-artifacts/artifact-policy.md` if the user prefers a separate location), and the policy applies to all future deferred-work cleanup cycles.

2. **Given** `_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md:97` is opened, **when** the line referencing `ColorTokens.border` is read, **then** the line carries a resolution annotation under the chosen policy: either appended `_Resolved by Story 9.3 — Path A retained. ColorTokens.border defined and documented at HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51. (Story 15.6, 2026-MM-DD)_` (Policy A, append-only) OR rewritten/removed if Policy B (living document) is chosen — in which case the line and any other 9.3-resolved entries are updated to match current truth.

3. **Given** `_bmad-output/planning-artifacts/epics-post-mvp.md` is opened and the three locations referencing `ColorTokens.border` are read (lines 81, 120, 156 per Story 9.3 review-findings), **when** each location is inspected, **then** each carries the same annotation pattern from AC #2 (Policy A — append-only) OR is rewritten/removed (Policy B). Each annotation is identical in wording for consistency.

4. **Given** the canonical regression check (`swift test --package-path HyzerKit` + simulator run if available) is performed after the cleanup, **when** the test count is read, **then** the count matches the Story 15.2 reconciled baseline (no Swift edits — this is doc-only work).

5. **Given** the cleanup is complete, **when** `_bmad-output/implementation-artifacts/deferred-work.md` is read, **then** the two Story 9.3-deferred bullets covered by this story (lines 57-58 referencing stale retro entry and stale epic narrative) are removed.

6. **Given** a new contributor reads `CLAUDE.md` or the `artifact-policy.md` file, **when** they encounter the policy section, **then** the section answers the practical question: "If I find an outdated statement in a retro or sign-off planning doc, what do I do?" The answer is unambiguous — annotate (Policy A) or revise (Policy B) — and includes a one-line rationale for the choice.

## Tasks / Subtasks

- [ ] **Task 1: User elicitation — Policy A vs. Policy B** (AC: 1)
  - [ ] 1.1 Before any edits, **ask the user** the policy question: "Should retros and sign-off planning docs be (a) append-only frozen snapshots — corrections go in as annotation lines that reference resolving stories without rewriting history, OR (b) living documents — content may be rewritten in place to reflect current truth, with a `Last revised: YYYY-MM-DD` footer at the top?" Default recommendation: **Policy A (append-only)**, because (i) retros document a point-in-time team consensus that is valuable as a historical record even after parts are resolved, (ii) sign-off planning docs are referenced by other artifacts (other stories, GitHub issues, retros) and rewriting them creates broken-reference risk, (iii) Policy A is the convention used in software engineering RFC archives (IETF, Python PEPs, OpenJDK JEPs) and is well-understood.
  - [ ] 1.2 Record the user's choice. If Policy B is chosen, prepare to do the rewriting in Tasks 2-3; if Policy A (recommended), prepare the annotation lines.
  - [ ] 1.3 If the user wants a hybrid policy (e.g., retros = frozen, planning docs = living), document the distinction in the policy section and apply accordingly. The recommended pure-Policy-A path is simpler and is what these tasks assume.

- [ ] **Task 2: Document the policy** (AC: 1, 6)
  - [ ] 2.1 If the user chooses Policy A, add a new section to `CLAUDE.md` (likely under "BMAD Project Management"). The section title: `### Frozen Artifact Policy`. Body (one paragraph + one bullet list):
    > Retrospectives and sign-off planning artifacts (e.g., `_bmad-output/implementation-artifacts/epics-*-retro-*.md`, `_bmad-output/planning-artifacts/epics*.md`, `_bmad-output/planning-artifacts/prd.md`, `_bmad-output/planning-artifacts/architecture.md`) are **append-only historical snapshots**. They document a point-in-time team consensus. When you find an outdated claim in one of these documents:
    >
    > - Append a single italicized annotation line under the outdated claim referencing the resolving story (format: `_Resolved by Story X.Y — <one-line summary>. (Story <cleanup-story>, YYYY-MM-DD)_`).
    > - Do NOT rewrite the original text or remove the outdated claim.
    > - Story files themselves (`_bmad-output/implementation-artifacts/<n>-<m>-*.md`) and `sprint-status.yaml` are NOT frozen — they are status records that should reflect current reality.
    >
    > The intent: preserve the historical record AND surface current truth via cross-references, without destructive edits.
  - [ ] 2.2 If the user chooses Policy B, document it analogously: living documents may be rewritten in place; add a `Last revised: YYYY-MM-DD by Story X.Y` line at the top of each rewritten doc; commit message must reference the rewriting cleanup story.
  - [ ] 2.3 If a hybrid is chosen, document the per-file-type rule clearly.

- [ ] **Task 3: Apply the policy to the three known stale references** (AC: 2, 3)
  - [ ] 3.1 Open `_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md`. Locate line 97 (per Story 9.3 review-findings: "`epics-1-8-retro-2026-04-07.md:97` still lists `ColorTokens.border` as open debt"). Under Policy A, append an annotation line immediately below the existing line:
    `_Resolved by Story 9.3 — Path A retained. ColorTokens.border defined and documented at HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51. (Story 15.6, 2026-MM-DD)_`
    Replace `2026-MM-DD` with the actual story-close date. Under Policy B, edit the line itself to remove the open-debt claim and reflect the resolved state.
  - [ ] 3.2 Open `_bmad-output/planning-artifacts/epics-post-mvp.md`. Locate the three references (lines 81, 120, 156 per Story 9.3 review-findings — first verify these line numbers are still correct given the Epic 15 additions from this current cycle). Apply the same annotation pattern at each location. The three annotations should be word-identical for consistency.
  - [ ] 3.3 Run `grep -n "ColorTokens\.border\|Color\.border\b" _bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md _bmad-output/planning-artifacts/epics-post-mvp.md`. Expected output: 4 matches (1 in retro + 3 in epics-post-mvp), each with an adjacent annotation line (Policy A) or replaced text (Policy B). No bare unmarked references remain.

- [ ] **Task 4: Regression check** (AC: 4)
  - [ ] 4.1 Run `swift test --package-path HyzerKit`. Expect the same count as Story 15.2's reconciled baseline. No Swift was edited; the count must be identical.
  - [ ] 4.2 Run `xcodebuild test ...` if simulator available — same count.
  - [ ] 4.3 Run `swiftlint lint`. Expected: zero warnings (no Swift was edited).

- [ ] **Task 5: Update deferred-work and close** (AC: 5)
  - [ ] 5.1 Remove the two Story 9.3-deferred bullets from `_bmad-output/implementation-artifacts/deferred-work.md` (currently lines 57-58 referencing stale retro entry and stale epic narrative). The bullets are now closed by this story.
  - [ ] 5.2 Stage and commit. The commit message under Policy A: `chore(docs): annotate resolved ColorTokens.border references + establish frozen-artifact policy (Story 15.6)`. Under Policy B: `docs: rewrite stale ColorTokens.border references and establish living-document policy (Story 15.6)`.
  - [ ] 5.3 Update `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 15.6 → `done`.

## Dev Notes

### Why this story exists

Story 9.3 closed `ColorTokens.border` tech debt via Path A (keep + document). The token is now defined and doc-commented at `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51`. Yet four references across two planning artifacts (`epics-1-8-retro-2026-04-07.md:97` and `epics-post-mvp.md:81, 120, 156`) still describe the token as open debt. Story 9.3's review found this but deferred it because the team had not agreed on whether retros and sign-off planning docs are append-only or living.

This story forces that policy decision — it is small enough to be a one-PR story that produces both the policy and the immediate cleanup. Future deferred-work cycles will know what to do without re-debating.

The work is doc-only. Zero Swift. Zero test additions. The risk profile is low; the value is preventing duplicated effort in the future.

### Current state — what is already correct (do NOT redo)

- **`ColorTokens.border` IS resolved at the code level.** Story 9.3 Task 4.2 (Path A) added the doc comment. The token is defined and available; CLAUDE.md's "Known Technical Debt" entry was removed (Story 9.3 Task 4.4).
- **The four planning-artifact references are stale**, not wrong-at-original-writing-time. At the time those documents were written (April 7 retro; pre-Story-9.3 epics-post-mvp), the token WAS open debt. Story 9.3 changed the truth; the docs didn't auto-update.
- **No other tech-debt items have this stale-reference profile** as of 2026-05-18. The `ValueCollector` extraction (Story 15.7) is still genuinely open; same for `Task.sleep` flaky timing (Story 15.8). Don't expand scope into those.

### What this story changes

| Change | File | Notes |
|---|---|---|
| Add policy section | `CLAUDE.md` | New `### Frozen Artifact Policy` (Policy A) or analogous |
| Annotate retro | `_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md` | Append annotation at line 97 |
| Annotate epics-post-mvp | `_bmad-output/planning-artifacts/epics-post-mvp.md` | Append annotations at lines 81, 120, 156 (re-verify line numbers post-Epic-15 additions) |
| Remove deferred bullets | `_bmad-output/implementation-artifacts/deferred-work.md` | Remove lines 57-58 |
| Sprint state | `_bmad-output/implementation-artifacts/sprint-status.yaml` | 15.6 → done |

Tiny diff; explicit policy decision.

### What this story must NOT touch

- **No Swift source.** Doc-only.
- **No new test files.**
- **No other tech-debt items.** Stay focused on the four `ColorTokens.border` references.
- **No rewriting of unrelated content** in the retro or planning docs, even if you notice other staleness in passing.

### Architecture compliance

- **CLAUDE.md "Git Workflow":** Branch `feature/15-6-stale-artifact-cleanup`. Conventional commit per Task 5.2.
- **CLAUDE.md "BMAD Project Management":** Story 15.6 adds the missing policy section. Aligns the documentation surface to the actual practice.

### Library / framework requirements

- **No new dependencies.** Doc-only work.

### File-structure requirements

```
CLAUDE.md                                                                            [EDIT — Task 2.1, add policy section]
_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md                  [EDIT — Task 3.1, annotation at line 97]
_bmad-output/planning-artifacts/epics-post-mvp.md                                    [EDIT — Task 3.2, annotations at 3 lines]
_bmad-output/implementation-artifacts/deferred-work.md                               [EDIT — Task 5.1, remove 2 bullets]
_bmad-output/implementation-artifacts/sprint-status.yaml                             [EDIT — Task 5.3]
```

Files that must NOT appear in the diff: any Swift source, any test file, `ColorTokens.swift` (Story 9.3 already touched it), `prd.md`, `architecture.md` (no staleness mentioned in those for this cycle).

### Testing requirements

- **No automated tests added.** Doc-only.
- **Regression check (AC #4):** Same count as Story 15.2 baseline, zero SwiftLint warnings.

### Previous-story intelligence

**Story 9.3 review-findings (Story 9.3 file, lines 332-334):**
> [Review][Defer] Stale retro entry — `epics-1-8-retro-2026-04-07.md:97` still lists `ColorTokens.border` as open debt — deferred, pre-existing. Retros are historical snapshots; needs explicit "frozen" policy decision rather than ad-hoc patching.
> [Review][Defer] Stale epic narrative — `epics-post-mvp.md:81, 120, 156` still describes border token as an open blocker — deferred, pre-existing. Planning artifacts are typically frozen at sign-off; surface for policy decision.

Story 15.6 IS the policy decision that closes these deferrals.

**Story 9.3 dev notes (lines 99-100):** "Story 9.3 is the **first user-visible deliverable** of Epic 9... It also resolves the **last unresolved tech-debt item from the Epics 1–8 retrospective** by either confirming or removing `ColorTokens.border`, completing the 'stabilization phase' framing in CLAUDE.md 'Project Status'."

Story 9.3 was AS clear as it could be that the resolution was complete. The staleness in the retros + planning docs is purely a documentation-hygiene issue.

### Latest tech information

- **The Internet's convention for historical-doc treatment is overwhelmingly Policy A (append-only).** IETF RFCs, Python PEPs, OpenJDK JEPs, ECMAScript proposals — all retain the historical text and add `Updated by RFC YYYY` notes rather than rewriting. The pattern is so ubiquitous that adopting it for this project requires only a one-paragraph policy section.
- **The alternative (Policy B, living docs) is common in wiki-style knowledge bases** (Notion, Confluence, MediaWiki) but those have version-history infrastructure that BMAD/git does not directly surface in story files.

### Open questions — pre-answered

**Requires elicitation (Task 1.1):**
- Policy choice: A (append-only, recommended), B (living docs), or hybrid (per-file-type).

**Pre-answered:**
- Annotation format → `_Resolved by Story X.Y — <one-line summary>. (Story <cleanup-story>, YYYY-MM-DD)_` (italicized, single line)
- Policy section location → `CLAUDE.md` (default) or `_bmad-output/planning-artifacts/artifact-policy.md` (alternative, user-chooseable)
- Scope → only the 4 `ColorTokens.border` references. No scope creep into other stale items.

### Project Structure Notes

This is a documentation-policy story. The committed footprint is minimal: one CLAUDE.md edit (or a new `artifact-policy.md`), one retro annotation, three epics-post-mvp annotations, one deferred-work.md edit, one sprint-status.yaml edit. Acceptance is the policy decision being recorded and the four references annotated.

### References

- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:57-58` — Story 9.3 review deferrals]
- [Source: `_bmad-output/implementation-artifacts/9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md:332-334` — Story 9.3 review-finding text]
- [Source: `_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md:97` — stale retro reference (Task 3.1)]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md:81, 120, 156` — stale planning references (Task 3.2)]
- [Source: `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51` — current resolved state of `ColorTokens.border`]
- [Source: `CLAUDE.md` "BMAD Project Management" — adjacent section for new policy block]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Story-15.6` — this story's epic-level scope]

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
