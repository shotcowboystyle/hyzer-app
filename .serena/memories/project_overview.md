# HyzerApp — Project Overview

**Purpose:** iOS 18 + watchOS 11 disc golf scoring app with voice entry, live leaderboards, and CloudKit sync.

**Tech Stack:**
- Swift 6.0 (strict concurrency enforced)
- SwiftUI (no UIKit)
- SwiftData (two-store config: domain + operational)
- CloudKit public database (manual sync API, NOT SwiftData built-in)
- WatchConnectivity (Phone ↔ Watch communication)
- XcodeGen (`project.yml` → `HyzerApp.xcodeproj`)
- Swift Testing (`@Suite`, `@Test` — not XCTest)
- SwiftLint

**Targets:**
- `HyzerApp` — iOS app (Views + ViewModels)
- `HyzerWatch` — watchOS companion (Views only)
- `HyzerKit` — local Swift Package, shared models + design tokens + service protocols
- `HyzerAppTests` — iOS ViewModel unit tests
- `HyzerKitTests` — domain model unit tests (runs on macOS, no simulator needed)

**Platform:** Darwin (macOS), Xcode build system.
