# HyzerApp — Project Overview

**Purpose:** iOS 18 + watchOS 11 disc golf scoring app with voice entry, live leaderboards, and CloudKit sync.

**Tech Stack:**
- Swift 6.0 (strict concurrency enforced, `SWIFT_STRICT_CONCURRENCY = complete`)
- SwiftUI (no UIKit)
- SwiftData (two-store config: domain + operational)
- CloudKit public database (manual sync API, NOT SwiftData built-in)
- WatchConnectivity (Phone ↔ Watch communication)
- XcodeGen (`project.yml` → `HyzerApp.xcodeproj`)
- Swift Testing (`@Suite`, `@Test` — not XCTest)
- SwiftLint (`.swiftlint.yml`)

**Targets:**

| Target | Platform | Purpose |
|--------|----------|---------|
| `HyzerApp` | iOS 18+ | Main app — Views + ViewModels only |
| `HyzerWatch` | watchOS 11+ | Companion watch app — Views + WatchConnectivityService |
| `HyzerKit` | iOS/watchOS/macOS | Local Swift Package: shared models, design tokens, service protocols, domain logic |
| `HyzerAppTests` | iOS | ViewModel unit tests (requires iOS Simulator) |
| `HyzerKitTests` | macOS/iOS | Domain model unit tests (fast, no simulator: `swift test --package-path HyzerKit`) |

**Project Status (as of 2026-04-12):**
- Epics 1–8 complete — 23/23 stories, 407+ tests (269 HyzerKit + HyzerApp)
- CI pipeline added (GitHub Actions)
- Not yet deployed — no TestFlight or App Store builds
- Stabilization phase — code review, test audit, tech debt cleanup

**Platform:** Darwin (macOS), Xcode 26.2, Swift 6.2.3 toolchain.
