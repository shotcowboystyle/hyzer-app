# Architecture

## Layer Boundaries
```
HyzerApp  (Views + ViewModels only)
  └── HyzerKit  (Models, Design System, Service protocols)
HyzerWatch  (Views only)
  └── HyzerKit
```

## Dependency Injection
- `AppServices` (`HyzerApp/App/AppServices.swift`) is the composition root — `@MainActor @Observable final class`.
- Injected at startup via `.environment(appServices)`.
- ViewModels receive individual services, never the full container.

## Data / Persistence
- **Two SwiftData stores:** domain store (synced to CloudKit) + operational store (local-only, e.g. SyncMetadata).
- **CloudKit:** Manual public DB sync. SwiftData's built-in `.cloudKit` sync is NOT used (only supports private DB). All CloudKit models must have optional/defaulted properties and no `@Attribute(.unique)`.
- **Event sourcing:** `ScoreEvent` is append-only/immutable. No UPDATE/DELETE. Conflicts produce a new authoritative ScoreEvent.

## Sync
- Phone is the sole CloudKit node. Watch never contacts CloudKit directly.
- Watch → Phone: WatchConnectivity (score events, voice results).
- Phone → Watch: leaderboard standings via WatchConnectivity.
- `CloudKitClient` and `WatchConnectivityClient` are protocol abstractions — always mock in tests.

## Concurrency
- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`).
- ViewModels and AppServices are `@MainActor`.
- All async work uses `async/await`. No `DispatchQueue`.

## Design System (HyzerKit/Sources/HyzerKit/Design/)
- `ColorTokens` — 11 tokens, dark-first (#0A0A0C), 4.5:1 contrast min.
- `TypographyTokens` — 8 levels, `@ScaledMetric` Dynamic Type AX3.
- `SpacingTokens` — 8pt grid, minimumTouchTarget=44, scoringTouchTarget=52.
- `AnimationTokens` + `AnimationCoordinator` — reduce-motion aware.
- **Always use tokens. Never hardcode colors, sizes, spacing, or durations.**
