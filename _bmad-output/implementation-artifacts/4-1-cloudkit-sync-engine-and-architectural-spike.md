# Story 4.1: CloudKit Sync Engine & Architectural Spike

Status: ready-for-dev

## Story

As a user,
I want scores I enter to appear on my friends' devices,
so that the group shares a live leaderboard during the round.

## Acceptance Criteria (BDD)

### AC1: Push ScoreEvent to CloudKit

**Given** a ScoreEvent is created on device A
**When** `SyncEngine.pushPending()` executes
**Then** the ScoreEvent is translated to a `ScoreEventRecord` DTO and saved to CloudKit public database (FR44)
**And** a `SyncMetadata` entry tracks the sync status through `.pending` -> `.inFlight` -> `.synced`

### AC2: Pull ScoreEvents from CloudKit

**Given** device B is running the app
**When** `SyncEngine.pullRecords()` executes
**Then** new ScoreEvents from CloudKit are translated from DTOs, saved to local SwiftData, and reflected in the leaderboard
**And** `StandingsEngine.recompute(for:trigger:.remoteSync)` is called to update standings

### AC3: Local-first writes

**Given** a ScoreEvent is created locally
**When** it is saved to SwiftData
**Then** the local write completes before any sync attempt (FR45)
**And** the UI updates immediately from local data

### AC4: Actor reentrancy protection

**Given** `SyncEngine` is an `actor`
**When** `pushPending()` suspends at `await CloudKitClient.save()`
**Then** `.inFlight` status prevents duplicate pushes from actor reentrancy (Amendment A1)
**And** failed pushes revert to `.failed` for retry

### AC5: Dual ModelConfiguration

**Given** the `ModelContainer` is constructed
**When** the dual `ModelConfiguration` is created
**Then** domain models and `SyncMetadata` use separate backing stores (Amendment A3)
**And** operational store corruption is recoverable by deletion and reconstruction

## Tasks / Subtasks

- [ ] Task 1: Create `SyncMetadata` SwiftData model (AC: #5)
  - [ ] 1.1 Define `SyncMetadata` model in `HyzerKit/Sources/HyzerKit/Sync/SyncMetadata.swift`
  - [ ] 1.2 Define `SyncStatus` enum (`.pending`, `.inFlight`, `.synced`, `.failed`) as `String, Codable, Sendable`
  - [ ] 1.3 Properties: `id: UUID`, `recordID: String`, `recordType: String`, `syncStatus: SyncStatus`, `lastAttempt: Date?`, `createdAt: Date`
  - [ ] 1.4 All properties must have defaults (CloudKit constraint pattern)
  - [ ] 1.5 Write unit tests for SyncMetadata model and SyncStatus transitions

- [ ] Task 2: Create sync DTOs (AC: #1, #2)
  - [ ] 2.1 Define `ScoreEventRecord` struct in `HyzerKit/Sources/HyzerKit/Sync/DTOs/ScoreEventRecord.swift`
  - [ ] 2.2 Must be `Sendable` (crosses actor isolation boundaries)
  - [ ] 2.3 Implement `toCKRecord() -> CKRecord` and `init(from ckRecord: CKRecord)` conversions
  - [ ] 2.4 Define `RoundRecord`, `PlayerRecord`, `CourseRecord` DTO stubs (minimal, spike scope is ScoreEvent only)
  - [ ] 2.5 Write unit tests for DTO <-> CKRecord round-trip conversions

- [ ] Task 3: Define `CloudKitClient` protocol (AC: #1, #2)
  - [ ] 3.1 Create protocol in `HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift`
  - [ ] 3.2 Methods: `save(_ records: [CKRecord]) async throws -> [CKRecord]`, `fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord]`
  - [ ] 3.3 Protocol must be `Sendable` for cross-actor usage
  - [ ] 3.4 Define `SyncError` enum: `.networkUnavailable`, `.cloudKitFailure(CKError)`, `.recordConflict(...)`, `.quotaExceeded` — all `Error, Sendable`

- [ ] Task 4: Implement `LiveCloudKitClient` (AC: #1, #2)
  - [ ] 4.1 Create `HyzerApp/Services/LiveCloudKitClient.swift` (app target, not HyzerKit — depends on CloudKit framework)
  - [ ] 4.2 Wraps `CKDatabase` operations on `iCloud.com.shotcowboystyle.hyzerapp` public database, default zone
  - [ ] 4.3 All operations use `async/await` CloudKit APIs (no completion handlers)

- [ ] Task 5: Create `MockCloudKitClient` (AC: #4)
  - [ ] 5.1 Create `HyzerKit/Tests/HyzerKitTests/Mocks/MockCloudKitClient.swift`
  - [ ] 5.2 In-memory `[CKRecord.ID: CKRecord]` dictionary storage
  - [ ] 5.3 `savedRecords: [CKRecord]` inspection property for test assertions
  - [ ] 5.4 `shouldSimulateError: CKError?` — when set, all operations throw this error
  - [ ] 5.5 `simulatedLatency: Duration?` — when set, operations sleep before executing (for `.inFlight` timing tests)

- [ ] Task 6: Implement `SyncEngine` actor (AC: #1, #2, #3, #4)
  - [ ] 6.1 Create `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift` as `actor`
  - [ ] 6.2 Dependencies: `CloudKitClient`, `StandingsEngine`, background `ModelContext`
  - [ ] 6.3 `pushPending()`: fetch `.pending` SyncMetadata, mark `.inFlight`, push via CloudKitClient, mark `.synced` on success / `.failed` on error
  - [ ] 6.4 `pullRecords()`: fetch new CKRecords, convert DTOs to ScoreEvents, insert into SwiftData, create SyncMetadata as `.synced`, call `StandingsEngine.recompute(for:trigger:.remoteSync)`
  - [ ] 6.5 The `.inFlight` guard: mark entries `.inFlight` BEFORE `await`, revert to `.failed` on error — prevents duplicate pushes from actor reentrancy
  - [ ] 6.6 SyncEngine must use a background `ModelContext` (`@ModelActor` pattern), NOT the main context

- [ ] Task 7: Create `SyncState` observable enum (AC: #1, #2)
  - [ ] 7.1 Define in `HyzerKit/Sources/HyzerKit/Sync/SyncState.swift`
  - [ ] 7.2 Cases: `.idle`, `.syncing`, `.offline`, `.error(Error)` — must be `@Observable` compatible
  - [ ] 7.3 Will drive future `SyncIndicatorView` (Story 4.2 — not built in this spike)

- [ ] Task 8: Update `ModelContainer` for dual store (AC: #5)
  - [ ] 8.1 Modify `HyzerApp.swift` `makeModelContainer()` to add operational store config for `SyncMetadata`
  - [ ] 8.2 Domain store: `Player`, `Course`, `Hole`, `Round`, `ScoreEvent` (unchanged)
  - [ ] 8.3 Operational store: `SyncMetadata` with `isStoredInMemoryOnly: false`, local-only
  - [ ] 8.4 Add recovery path: if operational store fails to load, delete and recreate it
  - [ ] 8.5 Add recovery path: if domain store fails, delete BOTH stores and recreate (safe — CloudKit has full history)

- [ ] Task 9: Wire `SyncEngine` into `AppServices` (AC: #1, #2)
  - [ ] 9.1 Add `cloudKitClient: CloudKitClient` and `syncEngine: SyncEngine` properties to `AppServices`
  - [ ] 9.2 Construction order: `ModelContainer` -> `StandingsEngine` -> `RoundLifecycleManager` -> `CloudKitClient` -> `SyncEngine` -> `ScoringService`
  - [ ] 9.3 SyncEngine gets background `ModelContext` (via `ModelContext(modelContainer)` on background actor)
  - [ ] 9.4 Add `.task { await appServices.syncEngine.start() }` in `HyzerApp.swift` body

- [ ] Task 10: Write comprehensive tests (AC: #1, #2, #3, #4, #5)
  - [ ] 10.1 SyncEngine push tests: create ScoreEvent locally -> pushPending() -> verify MockCloudKitClient received correct CKRecord
  - [ ] 10.2 SyncEngine pull tests: populate MockCloudKitClient with CKRecords -> pullRecords() -> verify ScoreEvents created in SwiftData
  - [ ] 10.3 SyncMetadata state machine tests: verify `.pending` -> `.inFlight` -> `.synced` transitions and `.inFlight` -> `.failed` on error
  - [ ] 10.4 Concurrent push test: two `.pending` entries + `pushPending()` twice via `TaskGroup` -> assert each entry results in exactly one `save()` call
  - [ ] 10.5 Dual ModelConfiguration test: verify domain and operational stores are separate
  - [ ] 10.6 DTO round-trip test: ScoreEvent -> ScoreEventRecord -> CKRecord -> ScoreEventRecord -> verify all fields preserved

## Dev Notes

### Spike Scope — What's IN vs OUT

**IN scope (this story):**
- `CloudKitClient` protocol + `LiveCloudKitClient`
- `SyncEngine` actor with `pushPending()` and `pullRecords()`
- `SyncMetadata` model (local-only, separate `ModelConfiguration`)
- Sync DTOs: `ScoreEventRecord` (full), `RoundRecord`/`PlayerRecord`/`CourseRecord` (stubs)
- `SyncState` enum
- Dual `ModelContainer` configuration
- Happy path only: push ScoreEvent from device A, pull on device B

**OUT of scope (deferred to 4.2 and 4.3):**
- `CKSubscription` push notifications (Story 4.2)
- Periodic fallback timer (Story 4.2)
- `SyncIndicatorView` UI (Story 4.2)
- `ConflictDetector` / silent merge logic (Story 4.3)
- `SubscriptionManager` (Story 4.3)
- Passive round discovery via CKQuery (Story 4.2)
- App-foreground sync triggers (Story 4.2)

### Architecture Constraints (MUST follow)

**CloudKit Configuration:**
- Container: `iCloud.com.shotcowboystyle.hyzerapp`
- Database: Public (NOT private — SwiftData auto-sync only supports private DB, which is why we use manual CloudKit APIs)
- Zone: Default
- Expected peak: ~1,500 operations/round, ~8-12 ops/min — well within rate limits

**Concurrency Model (Swift 6 strict):**
- `SyncEngine` is an `actor` — serializes access to SyncMetadata and in-flight operations
- `StandingsEngine` is `@MainActor @Observable` — SyncEngine calls `recompute()` via `await` (cross-isolation)
- All sync DTOs must be `Sendable` (value types/structs)
- `SyncError` enum must be `Sendable`
- SyncEngine uses a **background** `ModelContext`, NOT the main context
- Cross-isolation call pattern: `await standingsEngine.recompute(for:trigger:.remoteSync)`

**Data Model Constraints (CloudKit compatibility):**
- No `@Attribute(.unique)` on any synced model
- All properties optional or defaulted
- No `@Relationship` — flat foreign keys (Amendment A8)
- Schema changes: add-only, no delete/rename in production
- `SyncMetadata` is local-only bookkeeping — NEVER syncs to CloudKit

**Event Sourcing Invariants:**
- ScoreEvent is append-only and immutable (NFR19)
- No UPDATE or DELETE operations on ScoreEvent
- "Current score" = leaf node in supersession chain (Amendment A7), NOT most-recent-by-timestamp
- `pullRecords()` must respect this: insert remote events, let `StandingsEngine.recompute()` resolve via leaf-node traversal

**Offline-First Persistence (FR45, NFR10):**
- All SwiftData writes complete before any sync attempt
- No code path may block on CloudKit availability
- UI updates immediately from local data

### Existing Code to Reuse (DO NOT reinvent)

| Component | Location | How to use |
|---|---|---|
| `ICloudIdentityProvider` protocol | `HyzerKit/Sync/ICloudIdentityProvider.swift` | Pattern reference for `CloudKitClient` protocol design |
| `LiveICloudIdentityProvider` | `HyzerApp/Services/LiveICloudIdentityProvider.swift` | Pattern reference for `LiveCloudKitClient` — same split: protocol in HyzerKit, implementation in HyzerApp |
| `StandingsEngine` | `HyzerKit/Domain/StandingsEngine.swift` | Call `.recompute(for:trigger:.remoteSync)` after pull — already supports `.remoteSync` trigger |
| `StandingsChangeTrigger.remoteSync` | `HyzerKit/Domain/StandingsChangeTrigger.swift` | Already defined, ready for use |
| `ScoreEvent` model | `HyzerKit/Models/ScoreEvent.swift` | Has `supersedesEventID`, `reportedByPlayerID`, `deviceID` — all fields needed for sync |
| `Round` model | `HyzerKit/Models/Round.swift` | Has `playerIDs` array for future round discovery |
| `ScoringService` | `HyzerKit/Domain/ScoringService.swift` | Reference for how ScoreEvents are created locally — SyncEngine must create events with same structure |
| `AppServices` | `HyzerApp/App/AppServices.swift` | Composition root — add `CloudKitClient` + `SyncEngine` here |
| `HyzerApp.swift` | `HyzerApp/App/HyzerApp.swift` | `makeModelContainer()` needs dual config. `.task` block for `syncEngine.start()` |
| Test fixtures | `HyzerKit/Tests/HyzerKitTests/Fixtures/` | Follow `+Fixture.swift` naming pattern |
| `ScoreEvent+Fixture` | Existing in Fixtures dir | Reuse for sync test data |

### File Structure

**New files to create:**

```
HyzerKit/Sources/HyzerKit/Sync/
├── CloudKitClient.swift          # Protocol (Sendable)
├── SyncEngine.swift              # Actor
├── SyncMetadata.swift            # @Model (local-only)
├── SyncState.swift               # @Observable enum
├── SyncError.swift               # Typed error enum (Sendable)
└── DTOs/
    ├── ScoreEventRecord.swift    # Full implementation
    ├── RoundRecord.swift         # Stub for future
    ├── PlayerRecord.swift        # Stub for future
    └── CourseRecord.swift        # Stub for future

HyzerApp/Services/
└── LiveCloudKitClient.swift      # CKDatabase wrapper (app target)

HyzerKit/Tests/HyzerKitTests/
├── Mocks/
│   └── MockCloudKitClient.swift  # In-memory test double
├── SyncMetadataTests.swift
├── SyncEngineTests.swift
└── ScoreEventRecordTests.swift
```

**Files to modify:**

```
HyzerApp/App/HyzerApp.swift       # Dual ModelContainer + .task for sync
HyzerApp/App/AppServices.swift    # Add CloudKitClient + SyncEngine
project.yml                        # Add new files to targets (xcodegen)
```

### AppServices Constructor Dependency Graph (After This Story)

```
ModelContainer
├── ModelContext (main, @MainActor)
├── ModelContext (background, for SyncEngine)
│
StandingsEngine(modelContext: main)
RoundLifecycleManager(modelContext: main)
CloudKitClient = LiveCloudKitClient(container:)
SyncEngine(cloudKitClient:, standingsEngine:, modelContext: background)
ScoringService(standingsEngine:, modelContext: main, deviceID:)
```

### Testing Standards

- Use **Swift Testing** (`@Suite`, `@Test`, `#expect`) — NOT XCTest
- Test naming: `test_{method}_{scenario}_{expectedBehavior}`
- Test structure: Given/When/Then
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` for all SwiftData tests
- Use `MockCloudKitClient` for all SyncEngine tests — never hit real CloudKit
- Fixture pattern: `ScoreEvent.fixture(...)` and new `SyncMetadata.fixture(...)`
- Chain fixtures for sync scenarios: create local event -> push -> verify remote -> pull on "other device" -> verify local

### Previous Story Intelligence (from Story 3.6)

**Patterns to follow:**
- ViewModel DI: services via constructor injection, never the AppServices container
- `@MainActor @Observable` for all ViewModels (SyncState will be observed by future views)
- Design tokens for any future UI work
- Decoupled presentation state via `.onChange(of:)` pattern
- `Standing.formattedScore` and `Standing.scoreColor` from `Standing+Formatting.swift`

**Key learnings:**
- H1 from 3.6: VoiceOver accessibility — always track current player correctly
- `RoundStatus` values are plain strings, NOT enums
- `Round.completedAt` guaranteed non-nil for completed rounds
- `@Query` must live in the View (SwiftUI lifecycle requirement)
- `ImageRenderer` is iOS 16+ native — no third-party needed

**Current test count:** 161 total (71 HyzerKit + 90 HyzerApp)

### ModelContainer Recovery Pattern (Amendment A6)

Startup sequence for `makeModelContainer()`:
1. Create domain + operational `ModelConfiguration`s
2. Attempt `ModelContainer` creation
3. If operational store fails: delete operational store file, recreate
4. If domain store fails: delete BOTH stores, recreate (safe: CloudKit has full event history, SyncEngine will re-pull)

### CloudKit Import Note

`CloudKit` framework is available in iOS/watchOS but NOT in macOS test targets when running `swift test`. The `CloudKitClient` protocol lives in HyzerKit (no CloudKit import needed — it uses `CKRecord` type aliases or abstractions). The `LiveCloudKitClient` implementation and `MockCloudKitClient` may need `import CloudKit`. For HyzerKitTests, if `CKRecord` types are needed in mocks, ensure the test target can access CloudKit on the test platform.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Sync Architecture section, Amendments A1, A3, A6, A7, A8, A9, A10]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.1]
- [Source: _bmad-output/planning-artifacts/prd.md — FR44-FR48, NFR2, NFR8, NFR10, NFR11, NFR20]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Offline Mode Strategy, Sync State Visual]
- [Source: _bmad-output/implementation-artifacts/3-6-round-completion-and-summary.md — Previous story patterns]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
