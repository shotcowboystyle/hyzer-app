# HyzerApp — Development Guide

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Xcode | 26+ | Build, test, deploy |
| Swift | 6.0 | Language (strict concurrency) |
| XcodeGen | 2.44+ | Generate `.xcodeproj` from `project.yml` |
| SwiftLint | Latest | Code linting (pre-build script) |

Install tools:
```sh
brew install xcodegen swiftlint
```

---

## Project Setup

### 1. Generate Xcode Project

The `.xcodeproj` is generated from `project.yml`. Run this after cloning or after any `project.yml` changes:

```sh
xcodegen generate
```

### 2. Open in Xcode

```sh
open HyzerApp.xcodeproj
```

Select the `HyzerApp` scheme for iOS development or `HyzerWatch` for watchOS.

---

## Build Commands

### iOS App (Full Build)

```sh
xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### watchOS App

```sh
xcodebuild -project HyzerApp.xcodeproj -scheme HyzerWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2' build
```

### HyzerKit Package Only

```sh
swift build --package-path HyzerKit
```

---

## Test Commands

### All Tests (iOS Simulator Required)

```sh
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### HyzerKit Tests Only (No Simulator — Fastest)

```sh
swift test --package-path HyzerKit
```

This is the recommended way to run domain, sync, voice, and communication tests during development. It runs on macOS directly without needing a simulator.

### Run a Specific Test Suite

```sh
swift test --package-path HyzerKit --filter SyncEngineTests
```

### macOS 15 Note

iOS 26 Simulator requires macOS 26 (Tahoe) to launch apps. On macOS 15, the simulator build compiles but cannot run. Use `swift test --package-path HyzerKit` for all HyzerKit/domain tests during development.

---

## Linting

### Run SwiftLint

```sh
swiftlint lint
```

SwiftLint also runs automatically as a pre-build script on the `HyzerApp` target in Xcode.

### Key Lint Rules

| Rule | Warning | Error |
|------|---------|-------|
| Line length | 120 | 160 |
| Function body length | 50 lines | 100 lines |
| File length | 400 lines | 600 lines |
| `force_cast` | Warning | — |
| `force_try` | Warning | — |
| `force_unwrapping` | Warning | — |
| `unused_import` | Warning | — |
| Identifier name | min 2, max 60 | — |

Excluded identifiers: `id`, `db`. Included paths: `HyzerApp`, `HyzerWatch`, `HyzerKit/Sources`. Test files are excluded from linting.

### Configuration

SwiftLint config: `.swiftlint.yml` at project root.

---

## Project Structure Conventions

### Adding New Files

1. Add the `.swift` file to the appropriate directory
2. Run `xcodegen generate` to update the `.xcodeproj`
3. XcodeGen auto-discovers files based on the `sources` configuration in `project.yml`

### Adding a New SwiftData Model

1. Create `@Model` class in `HyzerKit/Sources/HyzerKit/Models/`
2. All properties must be optional or have defaults (CloudKit constraint)
3. No `@Attribute(.unique)` (CloudKit constraint)
4. No `@Relationship` — use flat UUID foreign keys
5. No Swift enums as stored properties — use raw `String` values
6. Add to `ModelContainer` schema in `HyzerApp.swift` (domain or operational store)
7. Create fixture in `HyzerKitTests/Fixtures/`
8. Use `ModelConfiguration(isStoredInMemoryOnly: true)` in tests

### Adding a New ViewModel

1. Create in `HyzerApp/ViewModels/`
2. Must be `@MainActor @Observable final class`
3. Inject individual services — never `AppServices` directly
4. Create test file in `HyzerAppTests/`
5. Use Swift Testing macros (`@Suite`, `@Test`) — not XCTest

### Adding a New View

1. Create in the appropriate subdirectory of `HyzerApp/Views/`
2. Use design tokens from `HyzerKit/Design/` — never hardcode colors, fonts, spacing, or durations
3. Receive ViewModel via environment or initializer

### Adding a New Service Protocol

1. Create protocol in `HyzerKit/Sync/` or `HyzerKit/Communication/`
2. Must be `Sendable`
3. Create live implementation in `HyzerApp/Services/`
4. Create mock in `HyzerKitTests/Mocks/` or `HyzerAppTests/Mocks/`
5. Wire in `AppServices.swift`

---

## Testing Conventions

### Framework

All tests use **Swift Testing** (`@Suite`, `@Test` macros) — not XCTest. Import `Testing`, not `XCTest`.

```swift
import Testing
@testable import HyzerKit

@Suite("ScoringService Tests")
struct ScoringServiceTests {
    @Test("Creates a valid score event")
    func createScoreEvent() throws {
        // arrange, act, assert
    }
}
```

### SwiftData in Tests

Always use in-memory containers:

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
    configurations: config
)
let context = container.mainContext
```

### Protocol Mocking

Use the protocol abstractions for external dependencies:

- `MockCloudKitClient` — configurable success/failure responses
- `MockNetworkMonitor` — controllable connectivity state + stream
- `MockWatchConnectivityClient` — records sent messages
- `MockVoiceRecognitionService` — returns predefined transcripts

### Test Organization

```
HyzerKitTests/
  ├── Domain/          # Model + domain logic tests
  ├── Communication/   # Watch messaging + VM tests
  ├── Voice/           # Voice parser + matcher tests (if separate)
  ├── Integration/     # Cross-system integration tests
  ├── Fixtures/        # 6 factory extensions
  └── Mocks/           # Protocol test doubles

HyzerAppTests/
  ├── ViewModels/      # ViewModel-specific subdirectory
  ├── Mocks/           # App-level mocks
  └── *.swift          # ViewModel test files
```

---

## Git Workflow

### Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<name>` | `feature/voice-scoring` |
| Release | `release/v<MAJOR>.<MINOR>.<PATCH>` | `release/v1.0.0` |
| Hotfix | `hotfix/<name>` | `hotfix/sync-crash` |

Direct push to `main` or `develop` is blocked.

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

feat(scoring): add voice-activated score entry
fix(sync): handle CKError.serverRecordChanged during push
test(standings): add position-change delta tests
chore(deps): update SwiftLint to 0.55
docs(readme): add CloudKit setup instructions
```

---

## Design System Usage

### Colors

```swift
Text("Score")
    .foregroundStyle(.scoreUnderPar)  // green for under par

Rectangle()
    .fill(.backgroundElevated)       // card background
```

### Typography

```swift
Text("Leaderboard")
    .font(TypographyTokens.h2)

Text("-3")
    .font(TypographyTokens.score)    // monospaced bold
```

### Spacing

```swift
VStack(spacing: SpacingTokens.sm) {  // 8pt
    // content
}
.padding(SpacingTokens.md)           // 16pt
```

### Animation

```swift
withAnimation(AnimationTokens.springStiff) {
    // state change
}

// Reduce-motion aware:
withAnimation(AnimationCoordinator.animation(
    AnimationTokens.springGentle,
    reduceMotion: accessibilityReduceMotion
)) {
    // state change
}
```

### Touch Targets

```swift
Button(action: { }) {
    // content
}
.frame(minWidth: SpacingTokens.minimumTouchTarget,
       minHeight: SpacingTokens.minimumTouchTarget)  // 44pt

// For scoring buttons:
.frame(minWidth: SpacingTokens.scoringTouchTarget,
       minHeight: SpacingTokens.scoringTouchTarget)  // 52pt
```

---

## CloudKit Setup

The app uses the **CloudKit public database** with container `iCloud.com.shotcowboystyle.hyzerapp`.

1. Enable iCloud capability in Xcode (CloudKit)
2. Enable Push Notifications capability
3. The container and record types are created automatically on first use
4. `CKQuerySubscription` is set up by `SyncScheduler` for push-based sync

---

## Troubleshooting

### `xcodegen generate` fails

Ensure XcodeGen is installed: `brew install xcodegen`. Check `project.yml` syntax.

### SwiftLint not running

SwiftLint is a pre-build script. Install via `brew install swiftlint`. Check `.swiftlint.yml` paths.

### `swift test` fails with actor isolation errors

Ensure you're using Swift 6.0 toolchain. Check that test types are properly isolated.

### ModelContainer initialization fails

The app has 3-level recovery in `makeModelContainer()`. If all fail, delete the app and reinstall. CloudKit holds the event history, so no data is lost.

### SwiftData `#Predicate` issues

Capture local variables before the predicate closure:
```swift
let courseID = course.id
let predicate = #Predicate<Hole> { $0.courseID == courseID }
```
