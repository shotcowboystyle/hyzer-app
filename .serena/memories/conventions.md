# Code Style & Conventions

## Language
- Swift 6.0, strict concurrency enforced at compiler level.
- SwiftUI only (no UIKit unless last resort).
- `@Observable` macro for reactive state (iOS 17+).

## Naming
- Types: `UpperCamelCase`
- Properties/functions: `lowerCamelCase`
- Test suites: `@Suite("Description")` with `@Test("description")` functions

## MVVM Pattern
- Views are SwiftUI structs — no business logic.
- ViewModels are `@MainActor @Observable final class`.
- Models in HyzerKit, conform to SwiftData `@Model`.

## Testing (Swift Testing — NOT XCTest)
```swift
@Suite("MyFeature")
struct MyFeatureTests {
    @Test("does something")
    func doesSomething() async throws { ... }
}
```
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData tests.
- Use protocol mocks for CloudKitClient / WatchConnectivityClient.
- Fixtures in `HyzerKit/Tests/HyzerKitTests/Fixtures/` (Player, Course, Round, ScoreEvent, Discrepancy, SyncMetadata, TestContainerFactory, ValueCollector, TestPolling).
- HyzerAppTests mocks in `HyzerAppTests/Mocks/` (MockVoiceRecognitionService).

## SwiftLint Rules (`.swiftlint.yml`)
- Max line length: 120 (warning) / 160 (error)
- Max function body: 50 lines (warning) / 100 lines (error)
- Max file length: 400 lines (warning) / 600 lines (error)
- `force_unwrapping`: opt-in rule enabled (avoid `!`)
- Custom rules: `try_without_justification`, `hardcoded_colors`, `hardcoded_animation_duration`

## Coding Standards (Enforce, Don't Review)
- **No silent `try?`** — every `try?` must have a comment explaining why it's safe.
- **Bounded queries** — every SwiftData fetch must have `fetchLimit` or equivalent constraint.
- **Accessibility first** — every interactive element needs VoiceOver labels; every text needs Dynamic Type support.
- **Design tokens only** — never hardcode colors, fonts, spacing, or animation durations.

## Git / Commits
- Branch pattern enforced by hooks: `feature/<name>`, `release/v<x.y.z>`, `hotfix/<name>`
- Direct push to `main`/`develop` blocked.
- Conventional Commits required: `type(scope): description`
  - Types: feat, fix, docs, style, refactor, perf, test, chore, ci, build, revert
