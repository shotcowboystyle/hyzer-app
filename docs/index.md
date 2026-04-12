# HyzerApp — Project Documentation

> Native iOS 18 + watchOS 11 disc golf scoring application built with Swift 6.0, SwiftUI, SwiftData, and CloudKit.

---

## Documentation Index

| Document | Description |
|----------|-------------|
| [Project Overview](./project-overview.md) | Tech stack, targets, codebase metrics, and high-level classification |
| [Architecture](./architecture.md) | System architecture, layer boundaries, data flow, sync design, concurrency model |
| [Data Models](./data-models.md) | SwiftData schema, all 7 models, relationships, CloudKit constraints, event sourcing |
| [Source Tree Analysis](./source-tree-analysis.md) | Annotated directory structure with every file's purpose |
| [Component Inventory](./component-inventory.md) | Complete inventory of models, ViewModels, views, services, protocols, design tokens, and tests |
| [Development Guide](./development-guide.md) | Build, test, lint commands, conventions, design system usage, and troubleshooting |

## Quick Reference

**Build:** `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17' build`

**Test (fast):** `swift test --package-path HyzerKit`

**Test (full):** `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17'`

**Regenerate project:** `xcodegen generate`

**Lint:** `swiftlint lint`

## Codebase at a Glance

- **~88 source files** across 3 targets (HyzerApp, HyzerWatch, HyzerKit)
- **407 tests** across 39 test files using Swift Testing
- **6 SwiftData models** + 1 operational model
- **10 iOS ViewModels** + 3 watchOS ViewModels
- **~25 SwiftUI views** (iOS) + 4 watchOS views
- **6 service implementations** with protocol abstractions
- **0 third-party dependencies** — Apple frameworks only

## Related Resources

- [CLAUDE.md](../CLAUDE.md) — AI development context and conventions
- [Architecture (Planning)](../_bmad-output/planning-artifacts/architecture.md) — Canonical architecture decisions
- [Sprint Status](../_bmad-output/implementation-artifacts/sprint-status.yaml) — Story completion tracking
- [Retrospective](../_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md) — Full project retrospective
