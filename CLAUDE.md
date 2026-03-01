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
xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Run all tests:**
```sh
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17'
```

> **Note (Xcode 26 + macOS 15):** iOS 26 Simulator requires macOS 26 (Tahoe) to launch apps. On macOS 15, the simulator build compiles but cannot run. Use `swift test --package-path HyzerKit` for all HyzerKit/domain tests during development.

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
- **Domain store** — `Player`, `Round`, `Course`, `Hole`, `ScoreEvent` — synced to CloudKit
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

### BMAD Project Management

Stories, epics, and sprint state live in `_bmad-output/`. The canonical architecture document is `_bmad-output/planning-artifacts/architecture.md` — read it before making significant architectural decisions. Story files are in `_bmad-output/implementation-artifacts/`. GitHub issues (via `github-issue-map.json`) are the source of truth for story completion status.
