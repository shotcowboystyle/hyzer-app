# Story 4.2: Offline Queue & Sync Recovery

Status: ready-for-dev

## Story

As a user,
I want scores I enter without connectivity to sync automatically when I'm back online,
so that no scores are ever lost, even on courses with no signal.

## Acceptance Criteria (BDD)

### AC1: Offline scoring creates pending sync entries

**Given** the device has no network connectivity
**When** a score is entered
**Then** the ScoreEvent saves to SwiftData and a `SyncMetadata` entry is created as `.pending` (FR45)
**And** scoring functions identically to the online case (NFR10)

### AC2: Connectivity restoration triggers sync flush

**Given** network connectivity returns after an offline period
**When** the `SyncEngine` detects connectivity via `NetworkMonitor`
**Then** all `.pending` and `.failed` entries are pushed to CloudKit (FR46)
**And** all entries sync successfully without data loss or duplication (NFR8, NFR11)

### AC3: Periodic fallback timer during active rounds

**Given** an active round is in progress
**When** the periodic fallback timer fires (30-60s)
**Then** `SyncEngine.pushPending()` flushes outbound entries
**And** `SyncEngine.pullRecords()` fetches any missed remote updates
**And** the timer stops when the round completes or the app backgrounds

### AC4: Sync indicator displays offline state

**Given** the device is offline
**When** the scoring view is displayed
**Then** a subtle sync indicator (cloud-slash icon) is visible in the toolbar
**And** the indicator clears when sync completes after connectivity returns

### AC5: App-foreground round discovery

**Given** the app enters foreground outside an active round
**When** the home screen loads
**Then** a single CKQuery fetches active rounds where the current user's ID is in `playerIDs` (FR16b enhancement)
**And** this covers missed CKSubscription notifications

### AC6: CKSubscription push notifications for real-time sync

**Given** the app has an active CKSubscription per record type
**When** a remote device saves a new ScoreEvent to CloudKit
**Then** the local device receives a silent push notification
**And** `SyncEngine.pullRecords()` is triggered to fetch the new data
**And** the leaderboard updates within 5 seconds on normal connectivity (NFR2)

### AC7: Extended offline recovery

**Given** the device has been offline for up to 4 hours during a round
**When** connectivity is restored
**Then** all locally-saved scores sync to CloudKit without data loss or duplication (NFR11)
**And** scores entered by other devices during the offline period are pulled and merged

## Tasks / Subtasks

- [ ] Task 1: Create `NetworkMonitor` protocol and implementations (AC: #2)
  - [ ] 1.1 Define `NetworkMonitor` protocol in `HyzerKit/Sources/HyzerKit/Sync/NetworkMonitor.swift` with `var isConnected: Bool`, `var pathUpdates: AsyncStream<Bool>` — must be `Sendable`
  - [ ] 1.2 Create `LiveNetworkMonitor` in `HyzerApp/Services/LiveNetworkMonitor.swift` wrapping `NWPathMonitor` — uses `AsyncStream` to publish connectivity changes
  - [ ] 1.3 Create `MockNetworkMonitor` in `HyzerKit/Tests/HyzerKitTests/Mocks/MockNetworkMonitor.swift` with controllable `isConnected` and `AsyncStream<Bool>` via continuation
  - [ ] 1.4 Write unit tests for `MockNetworkMonitor` stream behavior

- [ ] Task 2: Extend `CloudKitClient` protocol for subscriptions (AC: #6)
  - [ ] 2.1 Add `subscribe(to recordType: CKRecord.RecordType, predicate: NSPredicate) async throws -> CKSubscription.ID` to `CloudKitClient` protocol
  - [ ] 2.2 Add `deleteSubscription(_ subscriptionID: CKSubscription.ID) async throws` to `CloudKitClient` protocol
  - [ ] 2.3 Implement subscription methods in `LiveCloudKitClient` using `CKQuerySubscription` on public database (silent push, `shouldSendContentAvailable = true`)
  - [ ] 2.4 Update `MockCloudKitClient` with `subscribedRecordTypes: [CKRecord.RecordType]` tracking and test helpers
  - [ ] 2.5 Register for remote notifications in `HyzerApp.swift` (UIApplication delegate method or SwiftUI equivalent)

- [ ] Task 3: Create `SyncScheduler` coordinator (AC: #2, #3, #6)
  - [ ] 3.1 Define `SyncScheduler` as an `actor` in `HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift`
  - [ ] 3.2 Dependencies: `SyncEngine`, `NetworkMonitor` — injected via constructor
  - [ ] 3.3 Implement `startActiveRoundPolling()` — starts periodic timer (every 45s) calling `syncEngine.pushPending()` + `syncEngine.pullRecords()`. Timer uses `Task.sleep(for:)` in a loop, NOT `Timer` or `DispatchQueue`
  - [ ] 3.4 Implement `stopActiveRoundPolling()` — cancels the polling task
  - [ ] 3.5 Implement connectivity listener: observe `networkMonitor.pathUpdates`, on reconnection call `syncEngine.pushPending()` to flush pending/failed entries
  - [ ] 3.6 Implement `handleRemoteNotification()` — called when a CKSubscription silent push arrives, triggers `syncEngine.pullRecords()`
  - [ ] 3.7 Write tests for timer start/stop lifecycle, connectivity-triggered flush, and notification-triggered pull

- [ ] Task 4: Update `SyncEngine` for retry and network awareness (AC: #2, #7)
  - [ ] 4.1 Modify `pushPending()` to also pick up `.failed` entries (currently only `.pending` — verify this is already the case from 4.1, fix if not)
  - [ ] 4.2 Add `retryFailed()` method: fetches all `.failed` SyncMetadata, resets to `.pending`, then calls `pushPending()` — triggered by `SyncScheduler` on connectivity restore
  - [ ] 4.3 Verify deduplication in `pullRecords()` handles extended offline scenarios: many remote events, local events that already synced from other paths
  - [ ] 4.4 Write tests for retry-after-failure scenarios and extended offline recovery (4-hour simulation)

- [ ] Task 5: Create observable `SyncState` bridge to UI (AC: #4)
  - [ ] 5.1 Add `@Observable` `syncStatePublisher` property to `AppServices` that mirrors `SyncEngine.syncState` — updated via a `.task` that periodically reads or streams from the actor
  - [ ] 5.2 Alternative approach: Add `syncStateStream: AsyncStream<SyncState>` to `SyncEngine` that emits on every state change, consumed by a `.task` in the root view that sets an `@Observable` property on `AppServices`
  - [ ] 5.3 Ensure the bridge is `@MainActor`-safe — `SyncState` is read on main thread, written on SyncEngine's background actor
  - [ ] 5.4 Write tests verifying state propagation from SyncEngine actor to the observable property

- [ ] Task 6: Build `SyncIndicatorView` (AC: #4)
  - [ ] 6.1 Create `HyzerApp/Views/Components/SyncIndicatorView.swift` — reads `appServices.syncState` from environment
  - [ ] 6.2 States: `.idle`/`.synced` → no indicator (silence = success). `.syncing` → subtle `ProgressView` in toolbar. `.offline` → `cloud.slash` SF Symbol in toolbar. `.error` → `exclamationmark.icloud` SF Symbol
  - [ ] 6.3 Use `ColorTokens`, `TypographyTokens`, `SpacingTokens` for all styling — never hardcode values
  - [ ] 6.4 Respect `AccessibilitySettings` — reduce-motion aware animations via `AnimationTokens`
  - [ ] 6.5 Add VoiceOver labels: "Syncing scores", "Offline — scores saving locally", "Sync error"
  - [ ] 6.6 Integrate into scoring view toolbar (and optionally home screen)
  - [ ] 6.7 Write ViewModel tests (if separate VM) or snapshot-style tests for state rendering

- [ ] Task 7: Implement CKSubscription lifecycle management (AC: #6)
  - [ ] 7.1 Create subscription setup in `SyncScheduler.setupSubscriptions()` — subscribes to `ScoreEventRecord` type (and optionally `RoundRecord` for round discovery)
  - [ ] 7.2 Use `CKQuerySubscription` with `NSPredicate(value: true)` for all records of the type (public DB doesn't support zone subscriptions)
  - [ ] 7.3 Set `notificationInfo.shouldSendContentAvailable = true` for silent push
  - [ ] 7.4 Handle `application(_:didReceiveRemoteNotification:)` → parse `CKNotification` → call `syncScheduler.handleRemoteNotification()`
  - [ ] 7.5 Idempotent subscription creation: check for existing subscription before creating (avoid duplicates on each app launch)
  - [ ] 7.6 Write tests with MockCloudKitClient verifying subscription creation and deduplication

- [ ] Task 8: Implement app-foreground round discovery (AC: #5)
  - [ ] 8.1 In `HyzerApp.swift` or root view, observe `ScenePhase` changes
  - [ ] 8.2 On `.active` (foreground): if no round is currently active locally, execute a CKQuery for `RoundRecord` where `playerIDs CONTAINS currentUserID AND status == "active"`
  - [ ] 8.3 If matching rounds found, pull all ScoreEvents for those rounds
  - [ ] 8.4 This covers missed CKSubscription silent pushes (iOS throttles them in Low Power Mode, background-killed app)
  - [ ] 8.5 Guard: skip if last foreground discovery was < 30s ago (prevent rapid scene phase flapping)
  - [ ] 8.6 Write tests for foreground discovery with mock CloudKit containing active rounds

- [ ] Task 9: Wire into AppServices and app lifecycle (AC: #2, #3, #5, #6)
  - [ ] 9.1 Add `NetworkMonitor` and `SyncScheduler` to `AppServices` — construction order: `ModelContainer` → `StandingsEngine` → `RoundLifecycleManager` → `CloudKitClient` → `NetworkMonitor` → `SyncEngine` → `SyncScheduler` → `ScoringService`
  - [ ] 9.2 Add `.task` for `syncScheduler.start()` in `HyzerApp.swift` (calls `setupSubscriptions()` + starts connectivity listener)
  - [ ] 9.3 Connect round lifecycle to timer: when `RoundLifecycleManager` starts a round → call `syncScheduler.startActiveRoundPolling()`. When round completes → call `syncScheduler.stopActiveRoundPolling()`
  - [ ] 9.4 Add `syncState` observable property to `AppServices` with bridge task
  - [ ] 9.5 Register for remote notifications and wire to `syncScheduler.handleRemoteNotification()`
  - [ ] 9.6 Update `project.yml` for any new files if needed, run `xcodegen generate`

- [ ] Task 10: Comprehensive test suite (AC: #1-7)
  - [ ] 10.1 Offline → online recovery test: create ScoreEvents offline → simulate connectivity restore → verify all pushed to MockCloudKitClient
  - [ ] 10.2 Extended offline test: simulate 4-hour offline period with many local events → restore → verify count and content match
  - [ ] 10.3 Periodic timer test: verify timer fires and calls push/pull within expected interval
  - [ ] 10.4 CKSubscription trigger test: simulate remote notification → verify pullRecords() called
  - [ ] 10.5 Foreground discovery test: simulate app foreground with active remote rounds → verify CKQuery executed and events pulled
  - [ ] 10.6 Deduplication under concurrent sync: events arrive via both timer pull and subscription pull → verify no duplicates in SwiftData
  - [ ] 10.7 SyncState bridge test: verify state transitions propagate from SyncEngine actor to observable property on main thread

## Dev Notes

### Architecture Constraints (MUST follow)

**CloudKit Configuration (unchanged from 4.1):**
- Container: `iCloud.com.shotcowboystyle.hyzerapp`
- Database: Public (NOT private — SwiftData auto-sync only supports private DB, which is why we use manual CloudKit APIs)
- Zone: Default
- CKSubscription: Must use `CKQuerySubscription` (public DB doesn't support `CKRecordZoneSubscription`)

**Concurrency Model (Swift 6 strict):**
- `SyncScheduler` must be an `actor` — coordinates timer, network listener, and notification handler
- Timer implementation: `Task.sleep(for:)` in a loop inside a detached/child `Task` — NOT `Timer` or `DispatchQueue`
- `NetworkMonitor` protocol must be `Sendable` — live implementation wraps `NWPathMonitor` which runs on its own queue; use `AsyncStream` to bridge to Swift concurrency
- Cross-isolation pattern: `SyncScheduler` (actor) → `SyncEngine` (actor) calls are `await` crossings
- Observable bridge: `SyncState` written on `SyncEngine` actor, read on `@MainActor` — use `AsyncStream` or polling task to bridge safely

**Offline-First Invariants (FR45, NFR10):**
- All SwiftData writes complete before any sync attempt — this is already enforced by 4.1
- No code path may block on CloudKit availability or network state
- UI updates immediately from local data — sync is always background
- Scoring functions identically offline and online — only difference is the sync indicator

**Event Sourcing (unchanged):**
- ScoreEvent is append-only and immutable (NFR19)
- `pullRecords()` deduplication by `ScoreEvent.id` already implemented in 4.1
- Extended offline may produce many duplicate pushes from `.failed` retries — dedup on pull side handles this

**Design System (for SyncIndicatorView):**
- Use `ColorTokens` for all colors (dark-first theme, 4.5:1 contrast minimum)
- Use `TypographyTokens` for any text (caption level for indicator labels)
- Use `SpacingTokens` for layout (8pt grid)
- Use `AnimationTokens` for transitions — respect reduce-motion preferences
- SF Symbols: `cloud.slash` (offline), `exclamationmark.icloud` (error), `arrow.triangle.2.circlepath.icloud` (syncing)

### Existing Code to Reuse (DO NOT reinvent)

| Component | Location | How to use |
|---|---|---|
| `SyncEngine` actor | `HyzerKit/Sync/SyncEngine.swift` | Extend — add retry logic, connect to SyncScheduler |
| `SyncState` enum | `HyzerKit/Sync/SyncState.swift` | Already defined: `.idle`, `.syncing`, `.offline`, `.error(Error)` — drive SyncIndicatorView |
| `SyncMetadata` model | `HyzerKit/Sync/SyncMetadata.swift` | Four-state machine already complete (`.pending`/`.inFlight`/`.synced`/`.failed`) |
| `SyncError` enum | `HyzerKit/Sync/SyncError.swift` | Has `.networkUnavailable` case — SyncEngine already maps network errors |
| `CloudKitClient` protocol | `HyzerKit/Sync/CloudKitClient.swift` | Extend with `subscribe`/`deleteSubscription` methods |
| `LiveCloudKitClient` | `HyzerApp/Services/LiveCloudKitClient.swift` | Extend — add subscription method implementations |
| `MockCloudKitClient` | `HyzerKitTests/Mocks/MockCloudKitClient.swift` | Extend — add subscription tracking for tests |
| `ICloudIdentityProvider` | `HyzerKit/Sync/ICloudIdentityProvider.swift` | Pattern reference for `NetworkMonitor` protocol design (protocol in HyzerKit, impl in HyzerApp) |
| `LiveICloudIdentityProvider` | `HyzerApp/Services/LiveICloudIdentityProvider.swift` | Pattern reference for `LiveNetworkMonitor` |
| `AppServices` | `HyzerApp/App/AppServices.swift` | Composition root — add `NetworkMonitor`, `SyncScheduler`, `syncState` property |
| `HyzerApp.swift` | `HyzerApp/App/HyzerApp.swift` | Add remote notification registration, `.task` for SyncScheduler, ScenePhase observation |
| `RoundLifecycleManager` | `HyzerKit/Domain/RoundLifecycleManager.swift` | Connect round start/complete to SyncScheduler timer lifecycle |
| `ColorTokens` | `HyzerKit/Design/ColorTokens.swift` | Styling for SyncIndicatorView |
| `AnimationTokens` | `HyzerKit/Design/AnimationTokens.swift` | Reduce-motion aware transitions |
| `ScoreEvent+Fixture` | `HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift` | Reuse for sync recovery test data |
| `SyncMetadata+Fixture` | `HyzerKitTests/Fixtures/SyncMetadata+Fixture.swift` | Created in 4.1 — use for timer and retry tests |
| `StandingsEngine` | `HyzerKit/Domain/StandingsEngine.swift` | Already supports `.recompute(for:trigger:.remoteSync)` — no changes needed |

### File Structure

**New files to create:**

```
HyzerKit/Sources/HyzerKit/Sync/
├── NetworkMonitor.swift           # Protocol (Sendable)
└── SyncScheduler.swift            # Actor — timer, connectivity, notifications

HyzerApp/Services/
└── LiveNetworkMonitor.swift       # NWPathMonitor wrapper

HyzerApp/Views/Components/
└── SyncIndicatorView.swift        # Toolbar sync state indicator

HyzerKit/Tests/HyzerKitTests/
├── Mocks/
│   └── MockNetworkMonitor.swift   # Controllable test double
├── SyncSchedulerTests.swift       # Timer, connectivity, notification tests
└── SyncRecoveryTests.swift        # Extended offline recovery scenarios
```

**Files to modify:**

```
HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift   # Add subscribe/deleteSubscription methods
HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift       # Add retryFailed(), verify .failed pickup
HyzerApp/Services/LiveCloudKitClient.swift             # Implement subscription methods
HyzerApp/App/AppServices.swift                         # Add NetworkMonitor, SyncScheduler, syncState
HyzerApp/App/HyzerApp.swift                            # Remote notifications, ScenePhase, SyncScheduler task
HyzerKit/Tests/HyzerKitTests/Mocks/MockCloudKitClient.swift  # Add subscription tracking
project.yml                                             # Add new files to targets
```

### AppServices Constructor Dependency Graph (After This Story)

```
ModelContainer
├── ModelContext (main, @MainActor)
├── ModelContext (background, for SyncEngine)
│
StandingsEngine(modelContext: main)
RoundLifecycleManager(modelContext: main)
NetworkMonitor = LiveNetworkMonitor()               ← NEW
CloudKitClient = LiveCloudKitClient(container:)
SyncEngine(cloudKitClient:, standingsEngine:, modelContext: background)
SyncScheduler(syncEngine:, networkMonitor:)          ← NEW
ScoringService(standingsEngine:, modelContext: main, deviceID:)
```

### SyncScheduler State Machine

```
App Launch
  └─→ setupSubscriptions() — create CKQuerySubscription per record type (idempotent)
  └─→ startConnectivityListener() — observe NetworkMonitor.pathUpdates
         │
         ├── connectivity lost → syncEngine.syncState = .offline
         │
         └── connectivity restored → syncEngine.retryFailed() + pushPending()

Active Round Started (from RoundLifecycleManager)
  └─→ startActiveRoundPolling()
         └── every 45s: pushPending() + pullRecords()

Active Round Completed / App Backgrounds
  └─→ stopActiveRoundPolling()

Remote Notification Received (CKSubscription)
  └─→ handleRemoteNotification() → pullRecords()

App Foreground (no active round)
  └─→ foregroundDiscovery() — CKQuery for rounds where user is a player
```

### SyncIndicatorView State Mapping

| SyncState | Visual | VoiceOver | Notes |
|---|---|---|---|
| `.idle` | Nothing | — | Silence = success |
| `.syncing` | Subtle `ProgressView` in toolbar | "Syncing scores" | Non-blocking, background |
| `.offline` | `cloud.slash` SF Symbol, `ColorTokens.textSecondary` | "Offline — scores saving locally" | Persistent while offline |
| `.error(_)` | `exclamationmark.icloud` SF Symbol, `ColorTokens.warning` | "Sync error — will retry automatically" | Auto-clears on next successful sync |

### NWPathMonitor Implementation Notes

`NWPathMonitor` requires `import Network` and runs on a dispatch queue. The `LiveNetworkMonitor` must:
1. Create `NWPathMonitor()` on init
2. Start on a dedicated `DispatchQueue` (this is the ONE acceptable DispatchQueue use — required by Network framework API)
3. Bridge `pathUpdateHandler` to an `AsyncStream<Bool>` via continuation
4. Expose `isConnected: Bool` as a synchronous check (read `currentPath.status == .satisfied`)
5. Cancel the monitor on `deinit`

### CKSubscription Implementation Notes

Public database subscriptions use `CKQuerySubscription`:
```swift
let subscription = CKQuerySubscription(
    recordType: "ScoreEventRecord",
    predicate: NSPredicate(value: true),
    options: [.firesOnRecordCreation]
)
let info = CKSubscription.NotificationInfo()
info.shouldSendContentAvailable = true  // Silent push
subscription.notificationInfo = info
```

Silent push requires:
1. `UIApplication.shared.registerForRemoteNotifications()` at app launch
2. Background Modes capability: "Remote notifications" in `project.yml`
3. Handle in `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` or SwiftUI equivalent

**Idempotent subscription creation**: On each launch, fetch all subscriptions via `CKDatabase.fetchAllSubscriptions()`. Only create if not already present. This prevents subscription accumulation across launches.

### Previous Story Intelligence (from Story 4.1)

**Key patterns established in 4.1:**
- `SyncEngine` manually conforms to `ModelActor` protocol (NOT `@ModelActor` macro) — custom init with injected dependencies
- `pushPending()` marks entries `.inFlight` BEFORE `await CloudKitClient.save()` — reentrancy guard (Amendment A1)
- `pullRecords()` deduplicates by `ScoreEvent.id` before inserting — prevents duplicates from concurrent pulls
- Network error detection: `isNetworkError(_ error: CKError) -> Bool` checks `.networkUnavailable` and `.networkFailure`
- `LiveCloudKitClient` has `maxFetchRecords = 2000` safety cap — comment says "Story 4.2 will implement incremental sync"
- All CloudKit operations use modern async/await APIs — no completion handlers

**4.1 review issues (all fixed):**
- H1: Non-ScoreEvent SyncMetadata entries were stuck `.inFlight` — fixed with batch-first approach
- H2: N+1 fetch in `pushPending()` — fixed with hoisted fetch + Dictionary lookup
- H3: Unbounded `pullRecords()` — fixed with `maxFetchRecords` cap
- H4: Silent `try?` exception swallowing — replaced with `do/try/catch` + `logger.error()`

**4.1 remaining items (relevant to 4.2):**
- L2: `SyncState` not directly `@Observable` — 4.2 builds the bridging view
- The `start()` method does a single push/pull cycle — 4.2 makes it continuously reactive via SyncScheduler

**Current test count:** 97 total (71 HyzerKit + 26 sync from 4.1)

### Testing Standards

- Use **Swift Testing** (`@Suite`, `@Test`, `#expect`) — NOT XCTest
- Test naming: `test_{method}_{scenario}_{expectedBehavior}`
- Test structure: Given/When/Then
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` for all SwiftData tests
- Use `MockCloudKitClient` for all sync tests — never hit real CloudKit
- Use `MockNetworkMonitor` for all connectivity tests — never use real NWPathMonitor
- Fixture pattern: `ScoreEvent.fixture(...)`, `SyncMetadata.fixture(...)`
- For timer tests: use short intervals (e.g., 100ms) and verify call counts within tolerance

### Project Structure Notes

- `NetworkMonitor` protocol follows the same split pattern as `ICloudIdentityProvider` and `CloudKitClient`: protocol in HyzerKit, live implementation in HyzerApp target
- `SyncScheduler` lives in HyzerKit (no framework imports needed — it only calls protocol methods)
- `SyncIndicatorView` lives in HyzerApp (it's a View, app target only)
- `LiveNetworkMonitor` requires `import Network` — only available in HyzerApp target (not macOS test host for `swift test`)
- Background Modes entitlement may need to be added to `project.yml` for remote notifications

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Sync Architecture section, Amendments A1, A3, A5, A6, A9, A10]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.2]
- [Source: _bmad-output/planning-artifacts/prd.md — FR44, FR45, FR46, FR16b, NFR2, NFR8, NFR10, NFR11]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Sync Feedback table, Error States & Recovery, Offline Design Principle]
- [Source: _bmad-output/implementation-artifacts/4-1-cloudkit-sync-engine-and-architectural-spike.md — Previous story patterns, file structure, test patterns, review issues]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
