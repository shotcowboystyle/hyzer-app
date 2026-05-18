# Story 15.10: Centralize History-Service Constants (`ScoreEvent.maxEventsPerRound`, `RoundStatus.completed`)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a future contributor refactoring `PlayerTrendService`, `PersonalBestService`, or `HeadToHeadService`,
I want the `fetchLimit = maxRounds * 20` magic multiplier promoted to a single named constant `ScoreEvent.maxEventsPerRound = 20` and the string-literal predicate `$0.status == "completed"` replaced with a type-safe symbol (e.g., `RoundStatus.completed.rawValue` or a dedicated enum case),
So that future tweaks to scoring-event-cap or round-status comparison do not require three-service touch-points and a manual cross-grep.

## Acceptance Criteria

1. **Given** `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift` is read, **when** the type is inspected, **then** a new declaration appears: `public static let maxEventsPerRound: Int = 20`. A one-line doc comment above the declaration explains the multiplier's origin (Story 13.x history services; per-round upper bound of strokes + corrections per player, accounting for the worst-case 18-hole round with multiple score corrections plus discrepancy resolution events).

2. **Given** `PlayerTrendService.swift`, `PersonalBestService.swift`, and `HeadToHeadService.swift` are inspected (paths: `HyzerKit/Sources/HyzerKit/Domain/`), **when** every `fetchLimit` initialization referencing `* 20` is grep'd, **then** every match uses `ScoreEvent.maxEventsPerRound` instead of the raw `20` literal. Zero raw `* 20` patterns remain in the three files. Validation: `grep -rn 'maxRounds \* 20\|\* 20' HyzerKit/Sources/HyzerKit/Domain/` returns empty.

3. **Given** the same three service files plus any other call site using the string literal `"completed"` to compare `Round.status` (per Story 13.1 deferred-work line 92), **when** the predicates are inspected, **then** the comparison uses the type-safe form. The exact form depends on `Round.status`' type:
   - If `Round.status` is a `String` field: introduce `enum RoundStatus: String { case active, completed, … }` in `HyzerKit/Sources/HyzerKit/Models/Round.swift` or `RoundStatus.swift`. Update `Round.status` to use the enum. Update predicates to `$0.status == RoundStatus.completed.rawValue`.
   - If `Round.status` is an existing enum (`RoundStatus`, `Round.LifecycleState`): the comparison already has a type-safe form. Update the predicates to use it.
   - If `Round.lifecycleState` is the canonical field (CLAUDE.md mentions `lifecycleState`): use `$0.lifecycleState == .completed` and reconcile the file's apparent dual-naming (`status` vs. `lifecycleState`) — surface to the user before committing.

4. **Given** the canonical test command runs after the refactor, **when** the test count is compared to the Story 15.2 reconciled baseline (post-Stories-15.7, 15.8, 15.9 increments if those merged first), **then** the count is identical — this story is a behavior-preserving refactor with no test additions and no test removals. Existing tests must continue to pass; SwiftLint zero warnings.

5. **Given** a new SwiftData service is added in a future story (e.g., `PersonalStreakService` or `CourseHistoryService`), **when** the dev agent reads the doc comments on `ScoreEvent.maxEventsPerRound` and the type-safe `RoundStatus.completed`, **then** the doc comments are sufficient to discover and reuse the constants. No new magic multipliers or string literals enter the codebase.

6. **Given** the deferred-work bullets specifically about magic multipliers and string-literal predicates (Story 13.1 line 92, Story 13.2 line 19, Story 13.3 lines 7-8) are reviewed, **when** the refactor is complete, **then** those bullets are removed or updated to reflect the new state.

## Tasks / Subtasks

- [ ] **Task 1: Confirm pre-state and reconcile `status` vs. `lifecycleState`** (AC: 3)
  - [ ] 1.1 Read `HyzerKit/Sources/HyzerKit/Models/Round.swift`. Find the canonical field name for round state — likely `lifecycleState` (per CLAUDE.md "Data & Persistence" mention) but the deferred-work bullets reference `status`. There may be drift between the model and the predicate strings.
  - [ ] 1.2 If `status` and `lifecycleState` are different fields, surface to the user — the deferred-work bullets may reference an outdated field name. The dev agent should NOT silently rename either field.
  - [ ] 1.3 If only one field exists (`lifecycleState` is canonical, `status` was the old name, or vice-versa), use it consistently in Task 3.
  - [ ] 1.4 Check if `RoundStatus` (or `Round.LifecycleState`) is already an enum. If yes, this AC is partially trivial — only update the predicates. If no, the enum needs to be introduced as a sub-task (see Task 3.2 sub-decision).

- [ ] **Task 2: Add `ScoreEvent.maxEventsPerRound`** (AC: 1)
  - [ ] 2.1 Edit `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift`. Add inside the type declaration (above any instance properties):
    ```swift
    /// Upper bound on the number of ScoreEvent rows per Round per Player.
    ///
    /// Origin: Story 13.x history services bound `fetchLimit = maxRounds * 20`.
    /// The multiplier `20` covers the worst-case 18-hole round with several
    /// score corrections plus discrepancy resolution events (each appending
    /// a new immutable event per event-sourcing semantics — see
    /// CLAUDE.md "Data & Persistence" event-sourcing invariant).
    ///
    /// Used by `PlayerTrendService`, `PersonalBestService`,
    /// `HeadToHeadService` to size SwiftData fetch limits. Centralize here
    /// rather than duplicating the literal across services.
    public static let maxEventsPerRound: Int = 20
    ```
  - [ ] 2.2 Run `swift build --package-path HyzerKit` to verify clean compilation.

- [ ] **Task 3: Refactor the three history services** (AC: 2, 3)
  - [ ] 3.1 Edit `HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift`:
    - Find every `* 20` literal. Replace with `* ScoreEvent.maxEventsPerRound`.
    - Find every `$0.status == "completed"` predicate (per Story 13.1 deferred-work line 92). Replace with the type-safe form from Task 1.
    - Reading: `fetchLimit = maxRounds * 20` → `fetchLimit = maxRounds * ScoreEvent.maxEventsPerRound`.
    - Predicate: `#Predicate { $0.status == "completed" }` → `#Predicate { $0.lifecycleState == .completed }` (or whatever the type-safe form is — verify with Task 1).
  - [ ] 3.2 Edit `HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift` — same pattern.
  - [ ] 3.3 Edit `HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift` — same pattern.
  - [ ] 3.4 If Task 1 revealed `RoundStatus` is NOT an enum and needs to be introduced, this is the moment. Add to `HyzerKit/Sources/HyzerKit/Models/Round.swift` or a new `RoundStatus.swift`:
    ```swift
    public enum RoundStatus: String, Codable, Sendable, CaseIterable {
        case active
        case completed
        case abandoned  // include any other statuses currently used
    }
    ```
    The `rawValue: String` conformance preserves backward compatibility with CloudKit (which stores the string). Existing `Round` instances with `status: String` field migrate via SwiftData property type change — verify Swift Data tolerates this without an explicit migration. CLAUDE.md "Data & Persistence" mentions CloudKit requires all properties to be optional/defaulted; the enum-with-rawValue-String form is compatible.

- [ ] **Task 4: Verify no other call sites slipped** (AC: 2, 5)
  - [ ] 4.1 Run `grep -rn 'maxRounds \* 20\|fetchLimit.*\* 20\|status == "completed"\|\.status == "completed"' HyzerKit HyzerApp HyzerWatch`. Expected: zero matches after Task 3 completes. Surface any remaining match to the user — it indicates a service or test file the dev missed.
  - [ ] 4.2 Run `grep -rn 'ScoreEvent\.maxEventsPerRound\|RoundStatus\.completed' HyzerKit HyzerApp HyzerWatch`. Expected: 3+ matches in services (Task 3) and possibly any test files that constructed fixtures using the literal.

- [ ] **Task 5: Run the full regression** (AC: 4)
  - [ ] 5.1 Run `swift test --package-path HyzerKit`. Expect same count as Story 15.2 reconciled baseline (modulo any additions from Stories 15.7, 15.8, 15.9 if those merged first). All green.
  - [ ] 5.2 Run `xcodebuild test ...` if simulator available — same count and green.
  - [ ] 5.3 SwiftLint zero warnings. The refactor introduces new declarations and modifies expressions, but all changes are within line-length and function-body limits.

- [ ] **Task 6: Update deferred-work and close** (AC: 6)
  - [ ] 6.1 Edit `_bmad-output/implementation-artifacts/deferred-work.md`. Remove or update the following bullets:
    - Line 7 (Story 13.3: SwiftData `#Predicate` IN-clause limits) — only the magic-multiplier sub-concern is closed by this story; the IN-clause concern itself remains open as a separate item. Update the bullet to remove the multiplier mention but keep the IN-clause concern.
    - Line 8 (Story 13.3: `fetchLimit = maxRounds * 20` magic multiplier) — REMOVED entirely (closed by 15.10).
    - Line 19 (Story 13.2: `fetchLimit = maxRounds * 20` multiplier under-bounds for multi-course users) — only the magic-number aspect is closed; the under-bounds concern remains open. Update the bullet to remove the literal `20` mention; keep the concern that the multiplier itself may be wrong.
    - Line 92 (Story 13.1: `$0.status == "completed"` string literal) — REMOVED entirely (closed by 15.10).
  - [ ] 6.2 Stage and commit: `refactor(services): centralize maxEventsPerRound and RoundStatus.completed constants (Story 15.10)`.
  - [ ] 6.3 Update `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 15.10 → `done`.

## Dev Notes

### Why this story exists

Three history services duplicate two patterns:
1. **`fetchLimit = maxRounds * 20`** — the literal `20` appears verbatim in `PlayerTrendService`, `PersonalBestService`, `HeadToHeadService` (Story 13.1, 13.2, 13.3 deferred-work entries). Tuning the multiplier (e.g., to support discrepancy-heavy rounds with more corrections) currently requires touching all three files and manually grep-checking.
2. **`$0.status == "completed"`** — string literal predicate (Story 13.1 deferred-work line 92). Identified as "codebase-wide pattern; not story-specific. Would benefit from a type-safe wrapper across all `Round.status` comparisons."

Both are obvious refactor targets but were deferred individually across three stories. Story 15.10 closes both threads in one PR.

The story is behavior-preserving: same fetch sizes, same predicate semantics. The intent is to centralize so future refactors are one-touch instead of three-touch.

### Current state — what is already correct (do NOT redo)

- **The three services are functionally correct** — Stories 13.1, 13.2, 13.3 closed with green tests. This story does NOT change the multiplier value or the predicate semantics.
- **`fetchLimit` is the correct boundedness mechanism** per CLAUDE.md "Bounded SwiftData queries". This story is centralizing the magic number, not removing the boundedness.
- **CloudKit synchronization tolerates `Round.status` as a `String`** (per CLAUDE.md "Data & Persistence" "CloudKit models must have all properties optional/defaulted"). If Task 3.4 introduces `RoundStatus` as `enum: String`, the rawValue stays a String — backward-compatible.
- **Existing tests cover the services' correctness.** The refactor must preserve all existing test pass/fail status (AC #4).

### What this story changes

| Change | File | Notes |
|---|---|---|
| Add maxEventsPerRound | `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift` | NEW static constant |
| Possibly introduce RoundStatus enum | `HyzerKit/Sources/HyzerKit/Models/Round.swift` or new `RoundStatus.swift` | Only if currently a String field |
| Replace literal 20 | `PlayerTrendService.swift`, `PersonalBestService.swift`, `HeadToHeadService.swift` | Use `ScoreEvent.maxEventsPerRound` |
| Replace string predicate | Same 3 files | Use `RoundStatus.completed.rawValue` or `.completed` per Task 1 |
| Deferred-work cleanup | `_bmad-output/implementation-artifacts/deferred-work.md` | Remove/update 4 bullets |
| Sprint state | `_bmad-output/implementation-artifacts/sprint-status.yaml` | 15.10 → done |

### What this story must NOT touch

- **No multiplier-value changes.** `20` stays `20`. If the multiplier is wrong (Story 13.2 line 19 concern), that is a SEPARATE story.
- **No predicate-semantics changes.** The set of "completed" rounds returned must be unchanged.
- **No service method signature changes.** Public APIs stay identical.
- **No test additions or removals.** Existing tests cover the behavior; the refactor must not change which tests pass.
- **No CloudKit-side schema changes.** If `RoundStatus` becomes an enum, the rawValue is still `String` — CloudKit format unchanged.

### Architecture compliance

- **CLAUDE.md "Bounded SwiftData queries":** Reaffirmed. The `fetchLimit` is now expressed via a named constant.
- **CLAUDE.md "No silent `try?`":** Inapplicable — refactor doesn't add or remove `try?` patterns.
- **CLAUDE.md "Design tokens only":** Inapplicable — no UI.
- **CLAUDE.md "Accessibility first":** Inapplicable — no UI.
- **CLAUDE.md "Git Workflow":** Branch `feature/15-10-centralize-history-constants`. Conventional commit `refactor(services): centralize maxEventsPerRound and RoundStatus.completed constants`.
- **Architecture §Data & Persistence:** Event-sourcing invariant preserved — `ScoreEvent.maxEventsPerRound` documents the upper bound but does not enforce it; enforcement is at fetch time via `fetchLimit`.

### Library / framework requirements

- **No new dependencies.** Pure refactor.

### File-structure requirements

```
HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift                                        [EDIT — Task 2.1]
HyzerKit/Sources/HyzerKit/Models/Round.swift                                             [EDIT — Task 3.4 only if RoundStatus enum is introduced]
HyzerKit/Sources/HyzerKit/Models/RoundStatus.swift                                       [NEW — alternative location for Task 3.4]
HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift                                [EDIT — Task 3.1]
HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift                               [EDIT — Task 3.2]
HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift                                 [EDIT — Task 3.3]
_bmad-output/implementation-artifacts/deferred-work.md                                   [EDIT — Task 6.1]
_bmad-output/implementation-artifacts/sprint-status.yaml                                 [EDIT — Task 6.3]
```

Files that must NOT appear in the diff: any test file (existing tests must pass without modification), any HyzerApp view, any HyzerWatch file, any CloudKit DTO files.

### Testing requirements

- **No new tests.** Existing tests fully cover service behavior; the refactor must preserve their outcomes (AC #4).
- **Regression check:** Test count unchanged. All green. SwiftLint zero warnings.

### Previous-story intelligence

**Story 13.1 deferred-work (line 92):**
> `$0.status == "completed"` string literal in `PlayerTrendService` predicate (line 77) rather than `RoundStatus.completed` constant — pattern used codebase-wide; not story-specific. Would benefit from a type-safe wrapper across all `Round.status` comparisons.

Story 15.10 implements that type-safe wrapper.

**Story 13.2 deferred-work (line 19):**
> `fetchLimit = maxRounds * 20` magic multiplier in `HeadToHeadService.computeRecord` / `findOpponentCandidates` — pre-existing PlayerTrendService/PersonalBestService pattern. Promote to a single shared, documented constant (e.g., `ScoreEvent.maxEventsPerRound = 20`).

Story 15.10 implements that promotion.

**Story 13.3 deferred-work (line 8):** Same pattern, referencing the same multiplier.

**Story 13.x ACs (PlayerTrend, PersonalBest, HeadToHead):** All three require explicit `fetchLimit` per CLAUDE.md "Bounded queries". The refactor must NOT remove or weaken the fetchLimit — only replace the literal with the named constant.

### Latest tech information (2026-05-18)

- **Swift Data `#Predicate` with enum comparison:** Works for `String`-backed enums; the predicate compiler can translate `==` against an enum case to the underlying string. Verify with a build after Task 3.
- **Swift Data property type changes:** Changing `Round.status: String` to `Round.status: RoundStatus` (where RoundStatus is `enum: String`) may or may not require an explicit migration step. Swift Data 2024+ versions tolerate this for `String`-backed enums; older versions may need explicit migration. Verify with a clean build + simulator run.

### Open questions — pre-answered

**Pre-answered:**
- Constant name → `ScoreEvent.maxEventsPerRound` (per Story 13.2 deferred-work line 19 explicit naming suggestion)
- Constant value → `20` (preserve current behavior)
- Type-safe predicate target → `RoundStatus.completed` enum case (introduce enum if not present)
- Refactor scope → only the three named services + their string-literal predicate sites

**Still requires elicitation (Task 1.2):** If `status` and `lifecycleState` are different fields, surface the field-naming ambiguity to the user before committing.

### Project Structure Notes

The committed diff is small but touches multiple files: one new constant declaration, possibly one new enum, ~10 line-touches across the three services. Logical complexity is low; the value is in the future when a new service is added and the dev agent finds the named constants instead of repeating the magic literals.

### References

- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:7-8` — Story 13.3 IN-clause limits + magic multiplier]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:19` — Story 13.2 magic multiplier under-bounds concern]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:92` — Story 13.1 string-literal predicate concern]
- [Source: `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift` — destination for new constant]
- [Source: `HyzerKit/Sources/HyzerKit/Models/Round.swift` — destination for RoundStatus enum]
- [Source: `HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift` — call site]
- [Source: `HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift` — call site]
- [Source: `HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift` — call site]
- [Source: `CLAUDE.md` "Bounded queries", "Data & Persistence" — relevant policies]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Story-15.10` — this story's epic-level scope]

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
