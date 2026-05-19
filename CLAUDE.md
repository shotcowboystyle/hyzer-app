# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HyzerApp is an iOS 18 + watchOS 11 disc golf scoring app. The codebase is a native Swift project using XcodeGen (`project.yml` → `HyzerApp.xcodeproj`). All shared logic lives in **HyzerKit**, a local Swift Package.

## Build & Test Commands

**Regenerate Xcode project after `project.yml` changes:**
```sh
xcodegen generate
```

**Build (CLI):**
```sh
xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch' build
```

**Run all tests:**
```sh
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'
```

> **Note:** The paired simulator `iPhone 17 with Watch` enables testing both the iOS app and watchOS companion in a single session.

**Run HyzerKit tests only (faster, no simulator needed):**
```sh
swift test --package-path HyzerKit
```

**Lint:**
```sh
swiftlint lint
```

SwiftLint runs as a pre-build script on the HyzerApp target. Rules: max line length 160 (error), max function body 100 lines (error). Config in `.swiftlint.yml`.

## Architecture

### Targets

| Target | Platform | Purpose |
|--------|----------|---------|
| `HyzerApp` | iOS 18+ | Main app — Views + ViewModels only |
| `HyzerWatch` | watchOS 11+ | Companion watch app |
| `HyzerKit` | iOS/watchOS/macOS | Shared models, design tokens, business logic |
| `HyzerAppTests` | iOS | Unit tests for ViewModels |
| `HyzerKitTests` | macOS/iOS | Unit tests for domain models |

### Layer Boundaries

```
HyzerApp (Views + ViewModels)
    └── HyzerKit (Models + Design System + Services protocols)
HyzerWatch (Views)
    └── HyzerKit
```

ViewModels receive individual services — never the full `AppServices` container. Views receive ViewModels via the environment or direct injection.

### Dependency Injection

`AppServices` (`HyzerApp/App/AppServices.swift`) is the composition root — `@MainActor @Observable final class`. It is injected at startup via `.environment(appServices)` and is the only place where concrete service implementations are wired together.

### Data & Persistence

**Two SwiftData stores** configured in `HyzerApp.swift`:
- **Domain store** — `Player`, `Round`, `Course`, `Hole`, `ScoreEvent`, `Discrepancy` — synced to CloudKit
- **Operational store** — `SyncMetadata` — local-only, never synced

**CloudKit:** Manual sync via the CloudKit public database API. SwiftData's built-in `.cloudKit` sync is intentionally NOT used (it only supports private DB; this app needs the public DB for shared rounds). CloudKit models must have all properties optional/defaulted and no `@Attribute(.unique)`.

**Event sourcing:** `ScoreEvent` is append-only and immutable. No UPDATE or DELETE operations. Conflict resolution produces a new authoritative `ScoreEvent` (not a mutation).

### Sync Architecture

- **Phone is the sole CloudKit sync node.** Watch never talks to CloudKit directly.
- Watch → Phone: `WatchConnectivity` (score entry events, voice results)
- Phone → Watch: leaderboard standings updates via `WatchConnectivity`
- `CloudKitClient` and `WatchConnectivityClient` are protocol abstractions — always use these in tests (never the real implementations).

### Concurrency

Swift 6 strict concurrency is enforced (`SWIFT_STRICT_CONCURRENCY = complete`). All ViewModels and `AppServices` are `@MainActor`. All async operations use `async/await`. No `DispatchQueue` usage — use actors or `@MainActor` instead.

### Design System

All design tokens live in `HyzerKit/Sources/HyzerKit/Design/` and are shared between iOS and watchOS:

- `ColorTokens` — 11 named colors, dark-first (#0A0A0C base), 4.5:1 contrast minimum
- `TypographyTokens` — 8 levels (hero → caption, score), all with `@ScaledMetric` for Dynamic Type AX3
- `SpacingTokens` — 8pt grid (xs=4 → xxl=48), `minimumTouchTarget=44`, `scoringTouchTarget=52`
- `AnimationTokens` + `AnimationCoordinator` — reduce-motion aware, `springStiff`/`springGentle` presets

Always use tokens. Never hardcode colors, font sizes, spacing, or animation durations.

### Testing

Tests use **Swift Testing** (`@Suite`, `@Test` macros) — not XCTest syntax.

- `HyzerKitTests` — domain model tests, design token tests. Use `ModelConfiguration(isStoredInMemoryOnly: true)` for any SwiftData tests.
- `HyzerAppTests` — ViewModel tests. Use `CloudKitClient` mock protocol.
- Fixtures in `HyzerKit/Tests/HyzerKitTests/Fixtures/` (e.g., `Player+Fixture.swift`).

### Git Workflow

Branch protection enforces Git Flow. Branches must follow: `feature/<name>`, `release/v<MAJOR>.<MINOR>.<PATCH>`, `hotfix/<name>`. Direct push to `main` or `develop` is blocked. Commit messages must follow Conventional Commits (`type(scope): description`).

### Known Technical Debt

From the Epics 1–8 retrospective (`_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md`):

- `ValueCollector`, `MockNotificationService`, and `MockNearbyDiscoveryClient` consolidated into `HyzerKit/Tests/TestSupport/` (shared SPM target, resolved by Story 15.7). **New shared helpers go here.**
- `Task.sleep(for: .milliseconds(100))` flaky timing pattern in tests — replace with deterministic waits
- `ShareSheetRepresentable` duplicated in two History views — extract to shared component
- `ConflictResult` missing `Equatable` conformance
- `SyncScheduler` uses `UserDefaults.standard` directly — testability concern
- DTO stubs (`CourseRecord`, `PlayerRecord`, `RoundRecord`) — identity-only, deferred to future sync expansion

### Coding Standards (Enforce, Don't Review)

These patterns were caught repeatedly in code review across 8 epics. Treat violations as bugs:

- **No silent `try?`** — every `try?` must have a comment explaining why it's safe. Use `do/catch` with logging otherwise.
- **Bounded queries** — every SwiftData fetch must have `fetchLimit` or equivalent constraint.
- **Accessibility first** — every interactive element needs VoiceOver labels; every text needs Dynamic Type support.
- **Design tokens only** — never hardcode colors, fonts, spacing, or animation durations.

### BMAD Project Management

Stories, epics, and sprint state live in `_bmad-output/`. The canonical architecture document is `_bmad-output/planning-artifacts/architecture.md` — read it before making significant architectural decisions. Story files are in `_bmad-output/implementation-artifacts/`. GitHub issues (via `github-issue-map.json`) are the source of truth for story completion status.

### Frozen Artifact Policy

Retrospectives and sign-off planning artifacts (e.g., `_bmad-output/implementation-artifacts/epics-*-retro-*.md`, `_bmad-output/planning-artifacts/epics*.md`, `_bmad-output/planning-artifacts/prd.md`, `_bmad-output/planning-artifacts/architecture.md`) are **append-only historical snapshots**. They document a point-in-time team consensus. When you find an outdated claim in one of these documents:

- Append a single italicized annotation line under the outdated claim referencing the resolving story (format: `_Resolved by Story X.Y — <one-line summary>. (Story <cleanup-story>, YYYY-MM-DD)_`).
- Do NOT rewrite the original text or remove the outdated claim.
- Story files themselves (`_bmad-output/implementation-artifacts/<n>-<m>-*.md`) and `sprint-status.yaml` are NOT frozen — they are status records that should reflect current reality.

The intent: preserve the historical record AND surface current truth via cross-references, without destructive edits.

**Rationale.** Planning artifacts (PRDs, architecture docs, retrospectives, epic narratives) are point-in-time records that capture decisions made under specific constraints — scope, deadlines, known unknowns, and the team's understanding at that moment. Modifying them retroactively destroys the audit trail that explains *why* current code looks the way it does, and turns "decision archaeology" into guesswork. The append-only convention is the same one used by IETF RFCs, Python PEPs, and OpenJDK JEPs for the same reason.

**When violated.** If a frozen artifact is found to be misleading or actively harmful (e.g., the `ColorTokens.border` stale references that triggered Story 15.6), the remediation is annotation in-place with a reconciliation footnote AND a deferred-work bullet — never silent rewriting. The canonical pattern is the four `_Resolved by Story 9.3 — …_` italicized annotations applied in Story 15.6 (`epics-1-8-retro-2026-04-07.md:97`, `epics-post-mvp.md:81/121/164`). If you find an in-place rewrite that bypassed annotation, restore the original text from git history and add the annotation instead; open a new cleanup story if the misleading text is load-bearing for current contributors.

### Project Documentation

Comprehensive docs generated from deep scan live in `docs/`:

- [Index](docs/index.md) — documentation hub
- [Architecture](docs/architecture.md) — full system architecture, data flow, sync design
- [Data Models](docs/data-models.md) — all SwiftData models, relationships, constraints
- [Component Inventory](docs/component-inventory.md) — models, ViewModels, views, services, protocols, tokens
- [Source Tree](docs/source-tree-analysis.md) — annotated directory structure
- [Development Guide](docs/development-guide.md) — build, test, lint, conventions

### Project Status (as of 2026-04-08)

- **Epics 1–8 complete** — 23/23 stories, 407 tests
- **Not yet deployed** — no TestFlight or App Store builds
- **Stabilization phase** — code review, test audit, tech debt cleanup in progress
