# Story 15.7: Extract Shared `TestSupport` SPM Target (`ValueCollector`, `MockNotificationService`, `MockNearbyDiscoveryClient`)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer maintaining a test suite that has grown across Stories 12.1, 13.x, 14.1, 14.2,
I want `ValueCollector`, `MockNotificationService`, and `MockNearbyDiscoveryClient` consolidated into a single `HyzerKit/Tests/TestSupport/` shared target,
So that the three known duplications called out in CLAUDE.md "Known Technical Debt" and the deferred-work entries from Stories 12.1, 13.2, 14.1 are eliminated, and the test suite has one canonical source for each helper.

## Acceptance Criteria

1. **Given** `HyzerKit/Package.swift` is read, **when** the target list is inspected, **then** a new `TestSupport` target exists with `path: "Tests/TestSupport"` and is listed as a test-dependency of `HyzerKitTests`. The HyzerApp side's `HyzerAppTests` target in `project.yml` lists `TestSupport` as a Swift package dependency. The new target compiles cleanly on both iOS and macOS hosts.

2. **Given** `HyzerKit/Tests/TestSupport/Sources/TestSupport/ValueCollector.swift` is created (per SwiftPM target-source-layout convention) AND `MockNotificationService.swift`, `MockNearbyDiscoveryClient.swift` are co-located, **when** the file tree is inspected, **then** the old duplicate locations are deleted in the same commit:
   - `HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift` (deleted)
   - `HyzerAppTests/Mocks/MockNotificationService.swift` (deleted)
   - `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift` (deleted if it exists; verify the exact path via `find HyzerKit HyzerAppTests -name "Mock*"`)
   - `HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift` (deleted)
   - Any `ValueCollector.swift` duplicate across `HyzerKit/Tests/HyzerKitTests/` and `HyzerAppTests/` (deleted; expected at least 2 copies per CLAUDE.md "Known Technical Debt")
   The consolidated content is the union of the most-recent versions; semantic differences resolved by picking the most-permissive implementation. Any per-call-site customizations remain — see Task 3 for the merge methodology.

3. **Given** `HyzerKitTests` and `HyzerAppTests` are re-run via the Story 15.2 canonical command, **when** the test count is compared to the Story 15.2 reconciled baseline, **then** the count is identical — no tests added, no tests removed; the same green status. Test files that previously imported `@testable import HyzerKit` and used local-relative paths now `import TestSupport` and consume the shared helpers.

4. **Given** `swiftlint lint` runs after the consolidation, **when** the output is read, **then** zero warnings appear at the existing rule levels — including on the new `TestSupport` source files. The 160-character line limit and 100-line function-body limit apply to the consolidated helpers as well; if a duplicate carried a long line that violates limits, that's a hidden tech-debt item to address in this same story (the consolidation is the right moment to fix it).

5. **Given** a future story adds a new `Mock<Service>` helper or a new `ValueCollector`-style utility, **when** the dev agent reads `CLAUDE.md`, **then** a new line in the "Known Technical Debt" / "Test Infrastructure" section documents `TestSupport` as the canonical location for shared test helpers. The line replaces the existing CLAUDE.md mention of `ValueCollector` duplication (which is now resolved by this story).

6. **Given** the migration is complete, **when** the deferred-work bullets specifically about mock/test-helper duplication are reviewed (Story 12.1 line 65, Story 13.2 line 22, Story 14.1 lines 99, 103), **then** those bullets are removed from `_bmad-output/implementation-artifacts/deferred-work.md` — replaced (if needed) by a single line confirming TestSupport extraction. Story 15.7 closure resolves the entire test-mock-duplication thread.

## Tasks / Subtasks

- [ ] **Task 1: Inventory existing test helpers and identify duplicates** (AC: 2)
  - [ ] 1.1 Run `find HyzerKit HyzerAppTests -name "ValueCollector*" -o -name "Mock*.swift"` to enumerate all current helper locations. Expected output: at least 6 files (2× ValueCollector, 2× MockNotificationService, 2× MockNearbyDiscoveryClient).
  - [ ] 1.2 Read each duplicated pair (e.g., `HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift` vs. `HyzerAppTests/Mocks/MockNotificationService.swift`) and compare. Note the differences — likely the iOS-side version has more conformances (UIKit-backed protocols) and the HyzerKit-side version is host-only.
  - [ ] 1.3 For each duplicated pair, decide the consolidation strategy:
    - **Identical content:** Pick either copy; consolidate to one in TestSupport.
    - **Subset/superset:** Pick the superset (more conformances, more methods); consolidate.
    - **Divergent:** Investigate why. If genuine divergence is required (e.g., one consumer needs a different return value), keep both with disambiguating names (e.g., `MockNotificationService_iOS` vs. `MockNotificationService_HostOnly`). The deferred-work entries do NOT suggest divergence; expected to be subset/superset.
  - [ ] 1.4 Document the merge decisions in a temporary scratch file or in this story's Completion Notes for traceability.

- [ ] **Task 2: Add the `TestSupport` target to `HyzerKit/Package.swift`** (AC: 1)
  - [ ] 2.1 Read the current `HyzerKit/Package.swift`. Find the targets array.
  - [ ] 2.2 Add a new `.target` definition for `TestSupport`:
    ```swift
    .target(
        name: "TestSupport",
        dependencies: ["HyzerKit"],
        path: "Tests/TestSupport/Sources/TestSupport",
        swiftSettings: [
            .enableUpcomingFeature("StrictConcurrency"),
            .enableExperimentalFeature("StrictConcurrency"),
        ]
    ),
    ```
    The target depends on `HyzerKit` because the mocks conform to `HyzerKit` protocols. `SWIFT_STRICT_CONCURRENCY = complete` is enforced project-wide per CLAUDE.md "Concurrency"; mirror it here.
  - [ ] 2.3 Update `HyzerKitTests` target dependencies to include `TestSupport`:
    ```swift
    .testTarget(
        name: "HyzerKitTests",
        dependencies: ["HyzerKit", "TestSupport"],
        path: "Tests/HyzerKitTests"
    ),
    ```
  - [ ] 2.4 Create the directory structure: `mkdir -p HyzerKit/Tests/TestSupport/Sources/TestSupport`. Add a placeholder `.swift` file (e.g., `Marker.swift` with `import Foundation`) so SwiftPM sees the directory; this will be deleted in Task 3 once real files are added.
  - [ ] 2.5 Run `swift build --package-path HyzerKit` to verify the package compiles. Expected: `Build complete!`. If errors, the most likely cause is incorrect path string — match the directory layout exactly.

- [ ] **Task 3: Migrate helpers to `TestSupport`** (AC: 2, 4)
  - [ ] 3.1 Move `ValueCollector.swift` (the chosen authoritative copy from Task 1.3) into `HyzerKit/Tests/TestSupport/Sources/TestSupport/`. Mark the type `public` (it was likely `internal`/`fileprivate` when colocated inside a test target; now it must be `public` to cross the SwiftPM module boundary into HyzerKitTests / HyzerAppTests).
  - [ ] 3.2 Move `MockNotificationService.swift` similarly. Public-ize the type and all its methods/properties. Verify the type still conforms to the protocol it claims (`NotificationService` from HyzerKit) — the import of `HyzerKit` is what makes the protocol visible.
  - [ ] 3.3 Move `MockNearbyDiscoveryClient.swift` similarly. Public-ize.
  - [ ] 3.4 Delete the old duplicate files. The git diff for this task is high-touch — many file deletions plus three new files. Be exact about what stays and what goes; do NOT leave both copies in place.
  - [ ] 3.5 Delete the `Marker.swift` placeholder from Task 2.4.

- [ ] **Task 4: Update test imports** (AC: 3)
  - [ ] 4.1 Find every test file that currently imports `@testable import HyzerKit` AND references `ValueCollector`, `MockNotificationService`, or `MockNearbyDiscoveryClient` by name. Use `grep -rn "ValueCollector\|MockNotificationService\|MockNearbyDiscoveryClient" HyzerKit/Tests HyzerAppTests`.
  - [ ] 4.2 In each matching file, add `import TestSupport` after the existing `import` statements. The existing `@testable import HyzerKit` stays — those tests still exercise HyzerKit internals.
  - [ ] 4.3 Add the iOS-side `HyzerAppTests` dependency on `TestSupport` in `project.yml`. The exact YAML stanza depends on the existing target structure; refer to how HyzerAppTests currently lists its Swift package dependencies. Run `xcodegen generate` after the edit.
  - [ ] 4.4 Run `swift test --package-path HyzerKit` and confirm same count + green. Then run `xcodebuild test ...` (if simulator available) and confirm same count + green.

- [ ] **Task 5: Update `CLAUDE.md` Known Technical Debt and Test Infrastructure docs** (AC: 5)
  - [ ] 5.1 Read `CLAUDE.md`'s "Known Technical Debt" section. Remove the bullet `- ValueCollector test helper duplicated across multiple test files — needs extraction to shared utility`. The thread is closed.
  - [ ] 5.2 Add a new bullet in the same area (or a new "Test Infrastructure" sub-section): `**Shared test helpers** live in HyzerKit/Tests/TestSupport/. New mocks, value-collectors, and similar utilities go there. Both HyzerKitTests and HyzerAppTests depend on this target.`
  - [ ] 5.3 If CLAUDE.md mentions `MockNotificationService` or `MockNearbyDiscoveryClient` duplication explicitly, remove those too. Otherwise leave well-enough alone.

- [ ] **Task 6: Update deferred-work.md and close** (AC: 6)
  - [ ] 6.1 Remove from `_bmad-output/implementation-artifacts/deferred-work.md`:
    - Line 65 (Story 12.1: `MockNotificationService` duplication)
    - Line 22 (Story 13.2: ValueCollector test-helper extraction debt mention)
    - Line 99 (Story 14.1: ValueCollector test helper thread)
    - Line 103 (Story 14.1: mock duplication retroactive append)
  - [ ] 6.2 Stage and commit. Suggested Conventional Commits split: `feat(tests): extract TestSupport SPM target for shared mocks and ValueCollector (Story 15.7)`. Reference closure of the four deferred-work bullets in the commit body.
  - [ ] 6.3 Update `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 15.7 → `done`.

## Dev Notes

### Why this story exists

Across Stories 12.1, 13.2, 13.3, 14.1, 14.2, the same three test helpers keep getting duplicated across `HyzerKit/Tests/HyzerKitTests/Mocks/` and `HyzerAppTests/Mocks/`:
- `ValueCollector` (a SendableValueCollector-style helper for capturing async-pipeline outputs)
- `MockNotificationService` (UNUserNotificationCenter mock per Story 12.1)
- `MockNearbyDiscoveryClient` (MultipeerConnectivity mock per Story 14.1)

CLAUDE.md "Known Technical Debt" calls out `ValueCollector` explicitly. The deferred-work file calls out `MockNotificationService` (Story 12.1 line 65) and `MockNearbyDiscoveryClient` (Story 14.1 lines 99, 103). All three are the same pattern: a test helper exists in a private mocks folder, gets needed by both targets, and gets copy-pasted rather than extracted because no shared TestSupport module exists.

This story creates that module. One-time investment, ongoing payoff.

### Current state — what is already correct (do NOT redo)

- **`HyzerKit/Package.swift` already declares HyzerKit and HyzerKitTests targets.** Adding `TestSupport` is an additive change.
- **`project.yml` already declares HyzerAppTests target with its dependencies.** Adding `TestSupport` as a dependency is additive.
- **Existing helpers compile correctly in their current dual-location form.** Tests pass. This story changes WHERE the helpers live, not WHAT they do.
- **SwiftPM target naming conventions** are consistent — the path `Tests/TestSupport/Sources/TestSupport/` matches SwiftPM's nested-Sources layout. Some teams use flat `Tests/TestSupport/` without the inner `Sources/TestSupport/`; check existing conventions in the repo before deciding. The nested form is what SwiftPM uses by default; the flat form requires explicit `path:` declaration.

### What this story changes

| Change | File / Path | Notes |
|---|---|---|
| Add target | `HyzerKit/Package.swift` | New `.target(name: "TestSupport", ...)` |
| Add test dependency | `HyzerKit/Package.swift` | HyzerKitTests gets `dependencies: ["HyzerKit", "TestSupport"]` |
| Move ValueCollector | `HyzerKit/Tests/TestSupport/Sources/TestSupport/ValueCollector.swift` | NEW location; types made `public` |
| Move MockNotificationService | same dir | NEW location; types made `public` |
| Move MockNearbyDiscoveryClient | same dir | NEW location; types made `public` |
| Delete duplicates | `HyzerKit/Tests/HyzerKitTests/Mocks/*` and `HyzerAppTests/Mocks/*` | All Mock* and ValueCollector* files |
| Add `import TestSupport` | every test file using the migrated helpers | ~10-20 files affected |
| Add HyzerAppTests dependency | `project.yml` | iOS test target depends on TestSupport |
| Regenerate project | `HyzerApp.xcodeproj/project.pbxproj` | Auto via xcodegen generate |
| Update CLAUDE.md | "Known Technical Debt" section | Remove ValueCollector bullet, add TestSupport mention |
| Clean up deferred-work | `_bmad-output/implementation-artifacts/deferred-work.md` | Remove 4 bullets |

### What this story must NOT touch

- **No production code changes.** Only test code is moved.
- **No new tests added.** This is a refactor, not a new-feature story.
- **No new helpers added.** Stick to ValueCollector + 2 mocks. If you find a fourth duplicate during the inventory in Task 1.1, surface it and decide with the user whether to include in scope.
- **No production-API changes to the protocols being mocked.** `NotificationService` and `NearbyDiscoveryClient` protocols stay as they are; only the mock implementations move.
- **No HyzerWatch test target changes** (if a watch test target exists). The mocks being moved are iOS/host-only.

### Architecture compliance

- **CLAUDE.md "Concurrency":** Swift 6 strict concurrency is enforced. The new TestSupport target must compile under `SWIFT_STRICT_CONCURRENCY = complete`. The mocks are likely already compliant; verify.
- **CLAUDE.md "No silent `try?`":** Verify on the migrated helpers; any silent `try?` gets a justifying comment.
- **CLAUDE.md "Git Workflow":** Branch `feature/15-7-testsupport-extraction`. Conventional commit `feat(tests): extract TestSupport SPM target for shared mocks and ValueCollector`.
- **Architecture §Layer Boundaries:** The new target is iOS/macOS/watchOS-compatible (it's a HyzerKit-side test target). Verify by checking `Package.swift` platforms array.

### Library / framework requirements

- **SwiftPM** — already the build tool for HyzerKit.
- **XcodeGen** — already manages `HyzerAppTests`. Adding a Swift package dependency to a XcodeGen-managed target uses `dependencies: - package: HyzerKit` syntax. Refer to existing usage in `project.yml`.
- **No new third-party packages.**

### File-structure requirements

```
HyzerKit/Package.swift                                                                                    [EDIT — Tasks 2.2, 2.3]
HyzerKit/Tests/TestSupport/Sources/TestSupport/ValueCollector.swift                                       [NEW — Task 3.1]
HyzerKit/Tests/TestSupport/Sources/TestSupport/MockNotificationService.swift                              [NEW — Task 3.2]
HyzerKit/Tests/TestSupport/Sources/TestSupport/MockNearbyDiscoveryClient.swift                            [NEW — Task 3.3]
HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift                                          [DELETE — Task 3.4]
HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift                                        [DELETE — Task 3.4 if exists]
HyzerAppTests/Mocks/MockNotificationService.swift                                                         [DELETE — Task 3.4]
HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift                                                       [DELETE — Task 3.4]
<every test file using these helpers — verify via grep>                                                   [EDIT — add `import TestSupport`]
project.yml                                                                                               [EDIT — Task 4.3, add HyzerAppTests TestSupport dep]
HyzerApp.xcodeproj/project.pbxproj                                                                        [AUTO-REGEN — via xcodegen generate]
CLAUDE.md                                                                                                 [EDIT — Task 5.1, 5.2]
_bmad-output/implementation-artifacts/deferred-work.md                                                    [EDIT — Task 6.1]
_bmad-output/implementation-artifacts/sprint-status.yaml                                                  [EDIT — Task 6.3]
```

### Testing requirements

- **No new tests added.** The existing test suites that use the migrated helpers must continue to pass (AC #3).
- **Regression check:** `swift test --package-path HyzerKit` AND `xcodebuild test ...` (if simulator) — same count as Story 15.2 baseline.

### Previous-story intelligence

**Story 12.1 deferred-work (line 65):** "`MockNotificationService` duplicated across `HyzerAppTests/Mocks/` and `HyzerKit/Tests/HyzerKitTests/Mocks/` — same class name, near-identical shape. Matches the `ValueCollector` shared-test-helper debt called out in CLAUDE.md 'Known Technical Debt'. Pick up alongside the `ValueCollector` extraction into a shared `TestSupport` SPM target."

This is the explicit instruction. Story 15.7 IS the "Pick up alongside" referenced.

**Story 13.2 deferred-work (line 22):** "Test helper `insertRound(... completedAt: Date(timeIntervalSinceNow: -1) ...)` produces near-identical timestamps for sibling inserts in the same test. SortDescriptor on identical `completedAt` can shuffle insertion order non-deterministically. Pre-existing test pattern; audit alongside the `ValueCollector` shared-test-helper extraction debt called out in CLAUDE.md 'Known Technical Debt'."

The `insertRound` audit is NOT in scope for Story 15.7 — only the helper extraction is. The audit-recommendation phrase is what scopes that part for a follow-up story.

**Story 14.1 deferred-work (line 99):** "Tests use `for _ in 0..<20 { await Task.yield() }` and `try? await Task.sleep(for: .milliseconds(20))` to wait for async pipeline propagation — CLAUDE.md known flaky-timing tech debt, authorized by Story 14.1 spec line 390. Needs deterministic-wait helper."

This is Story 15.8's concern, NOT 15.7's. The flaky-timing thread is closed in 15.8.

**Story 14.1 deferred-work (line 103):** "New tech-debt entries discovered during Story 14.1 implementation (mock duplication, flaky timing) were noted in Completion Notes but not appended to this file at PR time — retroactively captured above. Future stories: append in the same PR."

The "mock duplication" half of this bullet is Story 15.7's scope; the "flaky timing" half is Story 15.8's.

### Latest tech information

- **SwiftPM TestSupport target pattern** is well-established in the iOS open-source ecosystem (e.g., `swift-async-algorithms`, `swift-collections`, `swift-foundation` all use this pattern).
- **XcodeGen Swift package dependencies** are declared via `dependencies: - package: <package-name>` under each target. Existing usage in `project.yml` (the HyzerApp target depends on HyzerKit) is the template.
- **`public` visibility for test helpers** is required when they cross SwiftPM module boundaries. There is no SwiftPM equivalent of `@testable` for non-test-target dependencies — the helpers must be genuinely `public` in their home module.

### Open questions — pre-answered

**Pre-answered:**
- Target name → `TestSupport` (per Story 12.1 deferred-work line 65 explicit naming)
- Target path → `HyzerKit/Tests/TestSupport/Sources/TestSupport/` (SwiftPM nested convention)
- Visibility → `public` (required for cross-module test access)
- Strategy for divergent duplicates → pick superset; surface to user only if genuine divergence appears
- HyzerAppTests integration → via XcodeGen `dependencies: - package: HyzerKit` syntax, target sub-dependency `TestSupport`

**Still requires elicitation:** none — all decisions pre-answered.

### Project Structure Notes

The committed diff is substantial in line count (many small file moves and import additions) but conceptually simple (refactor; no behavior change). The post-state is cleaner: one canonical location for each shared helper.

### References

- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:65` — Story 12.1 MockNotificationService duplication]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:22` — Story 13.2 ValueCollector audit reference]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:99, 103` — Story 14.1 ValueCollector + mock duplication]
- [Source: `CLAUDE.md` "Known Technical Debt" — ValueCollector duplication thread]
- [Source: `HyzerKit/Package.swift` — current package declaration; will receive new target]
- [Source: `project.yml` — current HyzerAppTests target; will receive new Swift package dependency]
- [Source: `HyzerKit/Tests/HyzerKitTests/Mocks/` — current duplicate location 1]
- [Source: `HyzerAppTests/Mocks/` — current duplicate location 2]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Story-15.7` — this story's epic-level scope]

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
