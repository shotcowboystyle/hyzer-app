# HyzerApp — Project Overview

**Type:** Native iOS 18 + watchOS 11 disc golf scoring application
**Language:** Swift 6.0 (strict concurrency)
**Architecture:** MVVM + Services with protocol-based dependency injection
**Build System:** XcodeGen 2.44+ (`project.yml` → `.xcodeproj`)
**Package Manager:** Swift Package Manager (HyzerKit local package)

---

## Purpose

HyzerApp is a disc golf scoring companion that enables real-time score tracking during rounds, with support for multiple players, guest scoring, voice-activated score entry, live leaderboard standings, Apple Watch companion scoring via Digital Crown and voice, and CloudKit-based cross-device synchronization.

## Tech Stack Summary

| Category | Technology | Version/Details |
|----------|-----------|-----------------|
| Language | Swift | 6.0, strict concurrency enabled |
| UI | SwiftUI | iOS 18 / watchOS 11 APIs |
| Persistence | SwiftData | Dual-store (domain + operational) |
| Cloud Sync | CloudKit | Manual sync, public database |
| Voice | Speech.framework | On-device SFSpeechRecognizer |
| Watch Comms | WatchConnectivity | Bidirectional WCSession |
| Networking | Network.framework | NWPathMonitor for connectivity |
| Observation | Observation framework | @Observable (not ObservableObject) |
| Logging | os.log | Structured OSLog |
| Linting | SwiftLint | Pre-build script, custom rules |
| Testing | Swift Testing | @Suite/@Test macros (not XCTest) |
| CI/CD | GitHub Actions | BMAD story sync workflow |

## Architecture Classification

- **Repository Type:** Monolith
- **Pattern:** MVVM + Services
- **Key Architectural Decisions:**
  - Event sourcing for scoring (`ScoreEvent` is append-only, immutable)
  - HyzerKit package boundary isolates shared logic from platform dependencies
  - Phone is the sole CloudKit sync node; Watch communicates only via WatchConnectivity
  - Dual SwiftData stores: domain (synced) + operational (local-only)
  - Protocol abstractions for all external dependencies (CloudKit, Network, iCloud, Voice)

## Targets

| Target | Platform | Purpose |
|--------|----------|---------|
| HyzerApp | iOS 18+ | Main app — Views, ViewModels, live service implementations |
| HyzerWatch | watchOS 11+ | Companion watch app — leaderboard, Crown/voice scoring |
| HyzerKit | iOS/watchOS/macOS | Shared models, domain logic, design tokens, sync engine |
| HyzerAppTests | iOS | Unit tests for ViewModels |
| HyzerKitTests | macOS/iOS | Unit tests for domain models, sync, voice, communication |

## Codebase Metrics

- **Source files:** ~90 Swift files (excluding tests and build artifacts)
- **Test files:** ~40 test files with 269 tests
- **SwiftData models:** 6 (Player, Course, Hole, Round, ScoreEvent, Discrepancy) + 1 operational (SyncMetadata)
- **ViewModels:** 10
- **Views:** ~25
- **Services:** 6 live implementations + 4 protocol abstractions
- **Design tokens:** 12 colors, 8 typography levels, 8 spacing values, 5 animation tokens

## Links to Detailed Documentation

- [Architecture](./architecture.md) — Full system architecture, layer boundaries, data flow
- [Data Models](./data-models.md) — SwiftData schema, relationships, CloudKit constraints
- [Source Tree Analysis](./source-tree-analysis.md) — Annotated directory structure
- [Component Inventory](./component-inventory.md) — UI components, ViewModels, services
- [Development Guide](./development-guide.md) — Build, test, lint, and development commands
- [Existing Planning Docs](../CLAUDE.md) — AI development context and conventions
