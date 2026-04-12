# HyzerApp Knowledgebase

Accumulated patterns, gotchas, and conventions from Epics 1-8. Update this file whenever a new lesson is learned so future work doesn't repeat the same discovery.

---

## SwiftData Patterns

### Predicate Capture Requirement

`#Predicate` closures cannot reference method parameters or `self` members directly. Always capture into a local constant first.

```swift
// BAD: Compiler error — cannot capture method parameter in #Predicate
func fetchRound(id: UUID) throws -> Round? {
    let descriptor = FetchDescriptor<Round>(
        predicate: #Predicate { $0.id == id }
    )
    return try context.fetch(descriptor).first
}

// GOOD: Capture into local let before the predicate
func fetchRound(id: UUID) throws -> Round? {
    let localID = id
    let descriptor = FetchDescriptor<Round>(
        predicate: #Predicate { $0.id == localID }
    )
    return try context.fetch(descriptor).first
}
```

### In-Memory Containers for Tests

Every SwiftData test must use an in-memory store to avoid disk I/O, state bleed between tests, and CI flakiness.

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: Round.self, configurations: config)
```

Use `TestContainerFactory.makeSyncContainer()` (defined in `HyzerKitTests/Fixtures/`) rather than constructing containers inline — it keeps the schema list synchronized automatically.

### CloudKit-Compatible Model Rules

The app uses CloudKit's public database, not SwiftData's built-in `.cloudKit` sync. CloudKit imposes constraints that must be respected at the model level:

- All stored properties must be optional or have a default value.
- `@Attribute(.unique)` is forbidden — CloudKit cannot enforce uniqueness.
- Relationships must be optional on both ends.

```swift
// BAD
@Model final class Course {
    @Attribute(.unique) var id: UUID    // forbidden
    var name: String                   // non-optional, no default
}

// GOOD
@Model final class Course {
    var id: UUID = UUID()
    var name: String = ""
}
```

### Dual Store Configuration

Two `ModelConfiguration` instances are wired in `HyzerApp.swift`:

| Store | Models | CloudKit | Notes |
|-------|--------|----------|-------|
| Domain store | `Player`, `Round`, `Course`, `Hole`, `ScoreEvent` | Yes (public DB) | Shared between all players in a round |
| Operational store | `SyncMetadata` | No | Local bookkeeping only — never synced |

Pass the correct store name when constructing a `ModelConfiguration` so SwiftData routes each model to the right file.

### ModelActor Custom Init Incompatibility

The `@ModelActor` macro generates an `init(modelContainer:)` and a `DefaultSerialModelExecutor`. If you need a custom initializer (e.g., to inject additional dependencies), you cannot use the macro. Instead, conform to `ModelActor` manually.

```swift
// BAD: @ModelActor + custom init causes compiler error
@ModelActor
actor ScoreRepository {
    init(modelContainer: ModelContainer, logger: Logger) { ... } // compile error
}

// GOOD: Implement ModelActor protocol directly
actor ScoreRepository: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor
    private let logger: Logger

    init(modelContainer: ModelContainer, logger: Logger) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.logger = logger
    }
}
```

---

## Swift 6 Concurrency

### Strict Concurrency Is Non-Negotiable

`SWIFT_STRICT_CONCURRENCY = complete` is set on all targets. There are no exceptions. Every concurrency warning is a build error. Do not downgrade this setting.

### UUIDs Cross Actor Boundaries Safely

`UUID` conforms to `Sendable`. It is safe to pass between actors, store in `@MainActor` ViewModels, or use inside `Task { }` closures without `@Sendable` annotation gymnastics.

### Nonisolated Pure Computed Properties

Computed properties on value types that do not access actor-isolated state should be marked `nonisolated` to prevent spurious isolation warnings.

```swift
struct ScoreEntry: Sendable {
    var strokes: Int
    var par: Int

    nonisolated var relativeToPar: Int { strokes - par }
}
```

### @Observable + NSObject Incompatibility

`@Observable` (the Observation framework macro) cannot be applied to a class that also inherits from `NSObject`. This conflicts with delegate patterns (e.g., `CLLocationManagerDelegate`, `WCSessionDelegate`).

Pattern: Use a separate, `NSObject`-inheriting delegate class. The `@Observable` class holds a reference to it and the delegate forwards calls back.

```swift
// Separate delegate class — no @Observable
final class SessionDelegate: NSObject, WCSessionDelegate {
    var onReceiveMessage: ((Message) -> Void)?
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        onReceiveMessage?(Message(message))
    }
}

// Observable class holds the delegate
@Observable final class WatchConnectivityService {
    private let delegate = SessionDelegate()
    var lastMessage: Message?

    init() {
        delegate.onReceiveMessage = { [weak self] msg in
            self?.lastMessage = msg
        }
    }
}
```

### DispatchQueue Is Banned

Never use `DispatchQueue.main.async`, `DispatchQueue.global()`, or any GCD API. All dispatch must go through:
- `@MainActor` isolation for UI work
- Custom actors for background serialization
- `async/await` with `Task` for concurrency

### ViewModel and AppServices Isolation

All ViewModels and `AppServices` are `@MainActor`. Do not add `nonisolated` to ViewModel methods that touch `@Published`-equivalent `@Observable` state.

---

## Design Token Rules

All visual constants live in `HyzerKit/Sources/HyzerKit/Design/`. Never hardcode any of the values below.

### Colors — `ColorTokens`

- 11 named semantic colors, dark-first palette, `#0A0A0C` base background.
- Minimum contrast ratio: 4.5:1 (WCAG AA). Verified by design token definitions — do not introduce new colors without checking contrast.
- Score colors: use `Color.scoreColor(strokes:par:)` — do not derive score-relative colors inline.

```swift
// BAD
Text("Eagle").foregroundStyle(.green)

// GOOD
Text("Eagle").foregroundStyle(Color.scoreColor(strokes: score, par: par))
```

### Typography — `TypographyTokens`

- 8 levels: `hero`, `title`, `headline`, `subheadline`, `body`, `callout`, `caption`, `score`.
- All sizes use `@ScaledMetric` — text scales with the user's Dynamic Type / Accessibility size (AX3 verified).
- Apply via view modifiers defined in `TypographyTokens`, not via raw `.font()` calls with literal sizes.

### Spacing — `SpacingTokens`

- 8pt grid: `xs=4`, `sm=8`, `md=16`, `lg=24`, `xl=32`, `xxl=48`.
- Touch targets: `minimumTouchTarget=44`, `scoringTouchTarget=52`.
- Corner radii: `cornerRadiusCard=16`, `cornerRadiusInline=8`.

```swift
// BAD
.padding(12)
.cornerRadius(10)

// GOOD
.padding(SpacingTokens.md)
.cornerRadius(SpacingTokens.cornerRadiusCard)
```

### Animations — `AnimationTokens` + `AnimationCoordinator`

- All durations, spring parameters, and easing curves are tokens.
- `AnimationCoordinator` checks `UIAccessibility.isReduceMotionEnabled` and substitutes instant/fade transitions when needed.
- Never hard-code `.animation(.spring(duration: 0.3))` or equivalent.

---

## Error Handling

### No Silent try? Without Justification

`try?` discards the error entirely. Every use must have an explanatory comment.

```swift
// BAD
let result = try? riskyOperation()

// GOOD
// Safe to discard: this cache miss is non-fatal; we fall through to network fetch
let cached = try? cache.fetch(key)
```

### catch Block Requirements

Every `catch` must do one of the following — no empty or swallowed catches.

```swift
// BAD
do { try save() } catch { }

// GOOD — log and rethrow
do {
    try save()
} catch {
    logger.error("Save failed: \(error)")
    throw error
}

// GOOD — explicit safe-continuation comment
do {
    try analyticsTracker.record(event)
} catch {
    // Safe to continue: analytics failure does not affect core scoring flow
}
```

### Logging

Use `os.log` `Logger` instances scoped to a subsystem and category. Never use `print()`.

```swift
private let logger = Logger(subsystem: "com.hyzerapp", category: "ScoreRepository")

logger.info("Round \(roundID) saved")
logger.error("Failed to fetch scores: \(error)")
```

---

## Testing

### Framework: Swift Testing (Not XCTest)

All new tests use Swift Testing macros.

```swift
import Testing

@Suite("ScoreEvent resolution")
struct ScoreEventResolutionTests {
    @Test("leaf node is returned when chain has one supersession")
    func leafNodeResolution() throws {
        // ...
        #expect(resolved?.id == leaf.id)
    }
}
```

### Async Polling — awaitCondition()

Never use bare `Task.sleep` inside test assertions to wait for async state changes. Use the `awaitCondition()` helper from the test utilities.

```swift
// BAD
try await Task.sleep(for: .seconds(0.5))
#expect(viewModel.isLoaded)

// GOOD
await awaitCondition(timeout: .seconds(2)) { viewModel.isLoaded }
#expect(viewModel.isLoaded)
```

### TestContainerFactory

Use `TestContainerFactory.makeSyncContainer()` for any test that needs a SwiftData container. Do not construct `ModelContainer` inline — the factory keeps the model schema list in sync with the app.

### ValueCollector for Async Streams

Use the `ValueCollector<T>` actor (in test utilities) to accumulate values emitted by `AsyncSequence` or Combine publishers during tests.

```swift
let collector = ValueCollector<LeaderboardEntry>()
await collector.collect(from: viewModel.leaderboardStream, count: 3)
#expect(collector.values.count == 3)
```

### Protocol-Based Mocks

All external boundaries have protocol abstractions. Always use mocks in tests — never the real implementations.

| Protocol | Real implementation | Used for |
|----------|--------------------|----|
| `CloudKitClient` | `LiveCloudKitClient` | CloudKit record I/O |
| `WatchConnectivityClient` | `LiveWatchConnectivityClient` | Watch/Phone messaging |
| `NetworkMonitor` | `LiveNetworkMonitor` | Reachability |
| `VoiceRecognitionService` | `LiveVoiceRecognitionService` | Speech recognition |

---

## Accessibility

### Label Requirement

Every interactive element — `Button`, `Toggle`, tappable `Label`, gesture-enabled view — must have an explicit `.accessibilityLabel`. Do not rely on SwiftUI's inference; be explicit.

```swift
Button(action: submitScore) {
    Image(systemName: "checkmark")
}
.accessibilityLabel("Submit score")
```

### VoiceOver and Auto-Commit Timers

Any feature that auto-commits after a delay (e.g., voice score entry) must pause when VoiceOver is active. Check `UIAccessibility.isVoiceOverRunning` before starting the timer and observe `UIAccessibility.voiceOverStatusDidChangeNotification` to cancel it if VoiceOver is activated mid-flow.

### Contrast

The `ColorTokens` palette maintains 4.5:1 minimum contrast. Do not introduce custom colors without verifying contrast with Xcode's Accessibility Inspector or a contrast checker.

### Dynamic Type

`TypographyTokens` uses `@ScaledMetric` so all text sizes respond to the user's preferred text size, up to AX3 (the largest accessibility size). Do not use fixed font sizes.

---

## Event Sourcing

### ScoreEvent Is Immutable and Append-Only

Never UPDATE or DELETE a `ScoreEvent`. Every score change creates a new `ScoreEvent`.

### Correction Chain

When a score is corrected, the new `ScoreEvent` sets `supersedesEventID` to the ID of the event it replaces. This creates a linked list from oldest to newest correction.

```
ScoreEvent(id: A, strokes: 4, supersedesEventID: nil)      ← original
ScoreEvent(id: B, strokes: 3, supersedesEventID: A)         ← correction
ScoreEvent(id: C, strokes: 3, supersedesEventID: B)         ← re-correction
```

### Resolving Current Score

`resolveCurrentScore(for:hole:in:)` finds the leaf node — the event not superseded by any other event in the set. Do not use the event with the latest timestamp; use the supersession chain.

### Discrepancy Resolution

When the Watch and Phone have conflicting scores, resolution produces a new authoritative `ScoreEvent` with `supersedesEventID = nil`. This is not a new original score — the `nil` supersession signals that the conflict was resolved externally and this value is authoritative.

---

## Architecture Gotchas

### Phone Is the Sole CloudKit Sync Node

The Watch never communicates with CloudKit. All CloudKit reads and writes happen on the Phone. The Watch sends score events to the Phone via `WatchConnectivity`; the Phone persists and syncs them.

### RoundStatus Enum Location

`RoundStatus` is defined in `HyzerKit`, not in the `HyzerApp` target. If you find yourself wanting to add status-related logic in the app target, move it to `HyzerKit` instead.

### Watch ViewModels Belong in HyzerKit

Watch ViewModels are placed in `HyzerKit` (not in `HyzerWatch`) so they can be tested on macOS without launching the iOS/watchOS simulator. The `HyzerWatch` target only contains SwiftUI Views.

### SyncScheduler Needs Injected UserDefaults

`SyncScheduler` accepts a `UserDefaults` instance in its initializer. Never access `UserDefaults.standard` inside `SyncScheduler` — always use the injected instance. This enables testing with an ephemeral `UserDefaults(suiteName: UUID().uuidString)` that doesn't persist between test runs.

### AppServices Is the Only Composition Root

`AppServices` (`HyzerApp/App/AppServices.swift`) is where concrete implementations are wired to protocols. ViewModels receive individual service protocols — never a reference to the full `AppServices` container. This keeps ViewModels testable in isolation.

```swift
// BAD: ViewModel receives the whole container
init(services: AppServices) { ... }

// GOOD: ViewModel receives only what it needs
init(scoreRepository: ScoreRepository, cloudKitClient: CloudKitClient) { ... }
```

---

## Updating This File

When a story surfaces a new pattern, gotcha, or overrides a previous convention:

1. Add it to the relevant section above with a concrete code example.
2. Note the story number in a comment if context is useful (e.g., `<!-- discovered in Story 6.3 -->`).
3. Remove or correct any entry that is no longer accurate.

This file is the team memory. Keep it accurate.
