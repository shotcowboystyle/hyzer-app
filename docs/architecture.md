# HyzerApp — Architecture

## System Overview

HyzerApp follows **MVVM + Services** with protocol-based dependency injection. All shared logic lives in **HyzerKit** (a local Swift Package), while platform-specific implementations live in the app targets.

```
┌─────────────────────────────────────────────────────────┐
│                    HyzerApp (iOS 18+)                   │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │  Views    │→ │  ViewModels  │→ │  Live Services    │  │
│  │ (SwiftUI)│  │ (@Observable)│  │ (implementations) │  │
│  └──────────┘  └──────────────┘  └───────────────────┘  │
│         │              │                   │             │
│         └──────────────┴───────────────────┘             │
│                        ↓                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │                  HyzerKit                         │   │
│  │  Models │ Domain │ Sync │ Voice │ Comms │ Design  │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────┐
│       HyzerWatch (watchOS 11+)  │
│  Views → ViewModels (HyzerKit)  │
│         → WatchConnectivity     │
└─────────────────────────────────┘
```

---

## Layer Boundaries

### HyzerApp (iOS Target)

| Layer | Contents | Rules |
|-------|----------|-------|
| **App** | `HyzerApp.swift` (entry point), `AppServices.swift` (composition root), embedded `AppDelegate` | Only place that wires concrete implementations |
| **Views** | ~25 SwiftUI views organized by feature | Receive ViewModels via environment or init; never import services directly |
| **ViewModels** | 10 `@MainActor @Observable final class` types | Receive individual services — never the full `AppServices` container |
| **Services** | 5 live implementations (`LiveCloudKitClient`, `LiveNetworkMonitor`, `LiveICloudIdentityProvider`, `PhoneConnectivityService`, `VoiceRecognitionService`) | Conform to HyzerKit protocols; contain all platform dependencies (CloudKit, WatchConnectivity, Speech, Network) |
| **Protocols** | `VoiceRecognitionServiceProtocol` | Internal protocol for mocking voice in tests |

### HyzerKit (Shared Package)

| Layer | Contents | Rules |
|-------|----------|-------|
| **Models** | 6 `@Model` classes (Player, Course, Hole, Round, ScoreEvent, Discrepancy) | No `@Relationship`; flat UUID FKs; all properties optional or defaulted for CloudKit |
| **Domain** | `ScoringService`, `StandingsEngine`, `RoundLifecycleManager`, `ConflictDetector`, `ScoreResolution`, `CourseSeeder`, value types (`Standing`, `HoleScore`, `StandingsChange`) | Pure business logic; no platform imports |
| **Sync** | `SyncEngine` (actor), `SyncScheduler` (actor), protocols (`CloudKitClient`, `NetworkMonitor`, `ICloudIdentityProvider`), `SyncMetadata`, DTOs | Manual CloudKit sync; protocol abstractions for all external dependencies |
| **Voice** | `VoiceParser`, `TokenClassifier`, `FuzzyNameMatcher`, result/error types | Platform-independent NLP pipeline; no Speech framework dependency |
| **Communication** | `WatchMessage`, `WatchConnectivityClient` protocol, `StandingsSnapshot`, `WatchCacheManager`, Watch ViewModels | Shared between iOS and watchOS; protocol abstraction for WCSession |
| **Design** | `ColorTokens`, `TypographyTokens`, `SpacingTokens`, `AnimationTokens`, `AnimationCoordinator` | Single source of truth for all visual tokens |

### HyzerWatch (watchOS Target)

Contains only Views and a single service (`WatchConnectivityService`). All ViewModels live in HyzerKit for testability. The watch never talks to CloudKit directly.

---

## Composition Root

`AppServices` (`HyzerApp/App/AppServices.swift`) is the single composition root — a `@MainActor @Observable final class` injected at startup via `.environment(appServices)`.

**Construction order:**

```
ModelContainer
  → StandingsEngine
    → RoundLifecycleManager
      → SyncEngine (actor, background ModelContext)
        → SyncScheduler (actor)
          → ScoringService
            → VoiceRecognitionService
              → PhoneConnectivityService (post-init property injection)
```

`PhoneConnectivityService` receives late-bound dependencies via property injection: `scoringService`, `localPlayerID`, `voiceRecognitionService`. This breaks the circular dependency between scoring and connectivity.

---

## Data Flow

### Score Entry (Local)

```
User taps score → ScoreInputView
  → ScorecardViewModel.enterScore()
    → ScoringService.createScoreEvent()
      → SwiftData insert + save
      → SyncMetadata created (.pending)
    → StandingsEngine.recompute()
      → LeaderboardViewModel updates (pill pulse)
    → SyncScheduler picks up pending metadata
      → SyncEngine.pushPending()
        → LiveCloudKitClient.save()
```

### Score Entry (Watch → Phone)

```
Watch Digital Crown → WatchScoringViewModel.confirmScore()
  → WCSession.transferUserInfo (guaranteed delivery)
    → Phone: PhoneConnectivityService.handleWatchScoreEvent()
      → ScoringService.createScoreEvent()
      → StandingsEngine.recompute()
      → Updated standings sent back to Watch
```

### Voice Score Entry

```
User taps mic → VoiceOverlayViewModel.startListening()
  → VoiceRecognitionService.recognize() (on-device SFSpeechRecognizer)
    → Transcript string
      → VoiceParser.parse(transcript:players:)
        → Tokenize → Classify → Assemble → FuzzyNameMatch
          → VoiceParseResult (.success/.partial/.failed)
            → VoiceOverlayView shows confirmation
              → Auto-commit after 1.5s or manual confirm
                → ScorecardViewModel.enterScore() per candidate
```

### CloudKit Sync (Pull)

```
Remote notification / polling timer / foreground discovery
  → SyncScheduler
    → SyncEngine.pullRecords()
      → LiveCloudKitClient.fetch() (paginated)
        → Deduplicate by ScoreEvent.id
        → Insert new events + SyncMetadata(.synced)
        → ConflictDetector.check() per event
          → Discrepancy created if cross-device conflict
        → StandingsEngine.recompute()
```

---

## Persistence Architecture

### Dual SwiftData Stores

```
┌─────────────────────────────────────┐
│          Domain Store               │
│  (CloudKit-synced SQLite)           │
│                                     │
│  Player, Course, Hole, Round,       │
│  ScoreEvent, Discrepancy            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│        Operational Store            │
│  (Local-only SQLite)                │
│                                     │
│  SyncMetadata                       │
│  (pending/inFlight/synced/failed)   │
└─────────────────────────────────────┘
```

**Why two stores?** SyncMetadata is a local concern (tracking which records have been pushed). It must never sync to CloudKit, as each device has its own sync state. The domain store contains all user-facing data that should be shared across devices.

**Recovery strategy** (3-level in `makeModelContainer()`):
1. Normal initialization of both stores
2. Delete operational store, retry (safe — SyncEngine will re-pull)
3. Delete both stores, start fresh (safe — CloudKit holds event history)

### CloudKit Design Decisions

- **Public database** (not private) — enables shared rounds between users
- **Manual sync** (not SwiftData `.cloudKit`) — SwiftData's built-in sync only supports private DB
- **No `@Relationship`** — flat UUID foreign keys per Amendment A8 for CloudKit compatibility
- **No `@Attribute(.unique)`** — CloudKit doesn't support unique constraints
- **All properties optional/defaulted** — CloudKit requires this for schema evolution

---

## Event Sourcing

`ScoreEvent` is the core of the scoring system, following an **append-only, immutable** event log:

- **No UPDATE or DELETE** operations ever (NFR19)
- **Corrections** create a new `ScoreEvent` with `supersedesEventID` pointing to the replaced event
- **Current score** = leaf node in the supersession chain (no event supersedes it)
- **Conflict resolution**: `ConflictDetector` classifies incoming events as `noConflict`, `correction`, `silentMerge` (same stroke count from different devices), or `discrepancy` (different strokes)
- **Multiple leaves** (silent merge from different devices): earliest `createdAt` wins (NFR20)

```
ScoreEvent A (original, Device 1)
  ← ScoreEvent B (correction, Device 1, supersedesEventID = A)
  ← ScoreEvent C (same score, Device 2, silent merge with A)

Current score = B (leaf node, latest correction)
```

---

## Sync Architecture

### Phone as Sole Sync Node

```
         CloudKit Public DB
              ↕ (push/pull)
         iPhone (SyncEngine)
              ↕ (WatchConnectivity)
         Apple Watch
```

The Watch never communicates with CloudKit directly. All sync goes through the phone. This simplifies conflict resolution and avoids the need for CloudKit on watchOS.

### Sync Components

| Component | Type | Responsibility |
|-----------|------|----------------|
| `SyncEngine` | `actor` | Push pending records, pull remote records, conflict detection, SwiftData writes (background context) |
| `SyncScheduler` | `actor` | Orchestrates when sync happens: polling (45s during active round), remote notifications, foreground discovery (throttled 30s), connectivity restore |
| `CloudKitClient` | `protocol` | Abstracts all CloudKit API calls for testability |
| `NetworkMonitor` | `protocol` | Abstracts `NWPathMonitor` for connectivity state and change stream |
| `SyncMetadata` | `@Model` | Per-record sync tracking: `pending → inFlight → synced` or `→ failed` |
| `ConflictDetector` | `struct` | Stateless, pure-function conflict classification |
| `ScoreEventRecord` | DTO | Maps `ScoreEvent` ↔ `CKRecord` (all UUIDs stored as strings) |

### Sync State Machine

```
SyncMetadata per record:
  pending → inFlight → synced
                     → failed (retry on connectivity restore)

SyncEngine overall:
  idle → syncing → idle
       → offline (no network)
       → error (CloudKit failure)
```

---

## Concurrency Model

**Swift 6 strict concurrency** is enforced project-wide (`SWIFT_STRICT_CONCURRENCY = complete`).

| Isolation | Types |
|-----------|-------|
| `@MainActor` | All ViewModels, `AppServices`, `StandingsEngine`, `RoundLifecycleManager`, `ScoringService`, `PhoneConnectivityService` |
| `actor` | `SyncEngine` (background ModelContext), `SyncScheduler` |
| `Sendable struct` | `ConflictDetector`, `VoiceParser`, `TokenClassifier`, `FuzzyNameMatcher`, all DTOs, all value types |
| `@unchecked Sendable` | `LiveNetworkMonitor` (wraps `NWPathMonitor` with `DispatchQueue` — the single acceptable `DispatchQueue` use) |

**Rules:**
- All async operations use `async/await`
- No `DispatchQueue` usage except `LiveNetworkMonitor` (required by Network.framework API)
- `AsyncStream` for reactive data flow (`SyncEngine.syncStateStream`, `NetworkMonitor.pathUpdates`)
- `withObservationTracking` for push-based standings observation in `PhoneConnectivityService`

---

## Voice Pipeline

The voice system is split into platform-independent parsing (HyzerKit) and platform-specific recognition (HyzerApp):

```
                    HyzerApp                          HyzerKit
┌──────────────────────────────┐    ┌──────────────────────────────────┐
│ VoiceRecognitionService      │    │ VoiceParser                      │
│ (Speech.framework)           │    │                                  │
│                              │    │  Tokenize (split on whitespace)  │
│ SFSpeechRecognizer           │───→│  Classify (TokenClassifier)      │
│ requiresOnDeviceRecognition  │    │  Assemble (name+number pairs)    │
│ AVAudioEngine                │    │  Match (FuzzyNameMatcher)        │
│                              │    │    - Exact alias match           │
│ → transcript: String         │    │    - Exact display name match    │
│                              │    │    - Unique prefix match         │
└──────────────────────────────┘    │    - Levenshtein distance ≥0.8   │
                                    │                                  │
                                    │ → VoiceParseResult               │
                                    │   .success / .partial / .failed  │
                                    └──────────────────────────────────┘
```

**Watch voice flow:** Watch sends `.voiceRequest` → Phone runs `VoiceRecognitionService.recognize()` → runs `VoiceParser.parse()` → sends `.voiceResult` back to Watch.

---

## Navigation Architecture

```
ContentView
  ├── OnboardingView (if no Player exists)
  └── HomeView (TabView, 3 tabs)
       ├── Tab 1: Scoring
       │    └── ScorecardContainerView (horizontal paging)
       │         ├── HoleCardView × N (per hole)
       │         │    └── ScoreInputView (inline picker)
       │         ├── LeaderboardPillView (floating overlay)
       │         │    └── LeaderboardExpandedView (sheet)
       │         ├── VoiceOverlayView (translucent overlay)
       │         ├── DiscrepancyListView (sheet)
       │         │    └── DiscrepancyResolutionView
       │         └── RoundSummaryView (fullScreenCover on completion)
       │
       ├── Tab 2: History
       │    └── HistoryListView
       │         └── HistoryRoundDetailView (push)
       │              └── PlayerHoleBreakdownView (push)
       │
       └── Tab 3: Courses
            └── CourseListView
                 ├── CourseDetailView (push)
                 └── CourseEditorView (sheet)
```

Round setup is triggered from `HomeView` via sheet presentation of `RoundSetupView`.

---

## Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| Event sourcing for scores | Enables conflict-free merging, complete audit trail, no data loss |
| Manual CloudKit sync (not SwiftData `.cloudKit`) | SwiftData's sync only supports private DB; app needs public DB for shared rounds |
| Phone-only sync node | Simplifies conflict resolution; avoids CloudKit on watchOS |
| Flat UUID FKs (no `@Relationship`) | CloudKit compatibility (Amendment A8); manual cascade delete |
| Dual SwiftData stores | SyncMetadata is device-local; domain data is shared |
| Protocol abstractions for externals | Enables unit testing without CloudKit/Network/Speech framework |
| HyzerKit package boundary | Isolates shared logic; enables `swift test` without simulator |
| `@Observable` (not `ObservableObject`) | Modern Observation framework; cleaner SwiftUI integration |
| Design tokens in HyzerKit | Single source of truth shared between iOS and watchOS |
| `RoundStatus` as standalone enum | SwiftData treats class-level statics as schema members |
