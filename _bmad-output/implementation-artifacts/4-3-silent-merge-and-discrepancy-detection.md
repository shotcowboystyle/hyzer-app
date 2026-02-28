# Story 4.3: Silent Merge & Discrepancy Detection

Status: ready-for-dev

## Story

As a user,
I want matching scores from multiple devices to merge silently and conflicting scores to be flagged,
so that the leaderboard stays accurate without unnecessary alerts.

## Acceptance Criteria (BDD)

### AC1: Silent merge of identical scores from different devices

**Given** two devices submit ScoreEvents for the same {player, hole} with the same `strokeCount` and no `supersedesEventID`
**When** the sync engine processes both events via `pullRecords()`
**Then** the scores merge silently with no user notification (FR47)
**And** the leaderboard reflects a single score — `resolveCurrentScore()` returns deterministically
**And** no discrepancy is stored (NFR20)

### AC2: Discrepancy detection for conflicting scores from different devices

**Given** two devices submit ScoreEvents for the same {player, hole} with different `strokeCount` values and no `supersedesEventID`
**When** the sync engine processes both events via `pullRecords()`
**Then** a discrepancy is detected and flagged (FR48)
**And** a `Discrepancy` record is persisted in SwiftData for later resolution (Epic 6)
**And** the `reportedByPlayerID` and `deviceID` from both events are preserved for attribution

### AC3: Same-device corrections treated as corrections, not conflicts

**Given** a ScoreEvent has `supersedesEventID` pointing to an event from the same `deviceID`
**When** the conflict detector processes it
**Then** it is treated as a correction (leaf-node resolution handles it)
**And** no discrepancy is created

### AC4: Cross-device supersession treated as discrepancy

**Given** a ScoreEvent has `supersedesEventID` pointing to an event from a different `deviceID`
**When** the conflict detector processes it
**Then** it is treated as a discrepancy requiring resolution
**And** a `Discrepancy` record is created with both events for resolution in Epic 6

### AC5: ConflictDetector integration with SyncEngine.pullRecords()

**Given** `SyncEngine.pullRecords()` receives new remote ScoreEvents
**When** events are inserted into SwiftData
**Then** `ConflictDetector.check()` is called for each affected {roundID, playerID, holeNumber} group
**And** silent merges produce no side effects beyond normal standings recomputation
**And** discrepancies trigger `StandingsEngine.recompute(for:trigger:.remoteSync)` (not `.conflictResolution` — that's for Epic 6 resolution)

### AC6: Deterministic merge behavior

**Given** 20+ concurrent identical ScoreEvents from multiple devices for the same {player, hole}
**When** all events are processed
**Then** zero false discrepancy alerts are produced (NFR20)
**And** `resolveCurrentScore()` returns a deterministic result (earliest `createdAt` wins among tied leaves)

## Tasks / Subtasks

- [ ] Task 1: Create `ConflictDetector` with four-case mechanical detection (AC: #1, #2, #3, #4)
  - [ ] 1.1 Create `HyzerKit/Sources/HyzerKit/Domain/ConflictDetector.swift` as a `nonisolated` struct (pure logic, no mutable state, no actor isolation needed)
  - [ ] 1.2 Define `ConflictResult` enum: `.silentMerge`, `.correction`, `.discrepancy(existing: ScoreEvent, incoming: ScoreEvent)`, `.noConflict`
  - [ ] 1.3 Implement `check(newEvent:existingEvents:) -> ConflictResult` with four-case logic:
    - **Case 1: No conflict** — `newEvent` is the only event for this {playerID, holeNumber} → `.noConflict`
    - **Case 2: Same-device correction** — `newEvent.supersedesEventID != nil` AND target event has same `deviceID` → `.correction`
    - **Case 3: Silent merge** — another event exists for same {playerID, holeNumber} from a different `deviceID`, same `strokeCount`, both have `supersedesEventID == nil` → `.silentMerge`
    - **Case 4: Discrepancy** — another event exists from a different `deviceID` with different `strokeCount` (both `supersedesEventID == nil`), OR `newEvent.supersedesEventID` points to an event from a different `deviceID` → `.discrepancy`
  - [ ] 1.4 `check()` accepts `[ScoreEvent]` for the same {roundID, playerID, holeNumber} — filters internally

- [ ] Task 2: Create `Discrepancy` SwiftData model (AC: #2, #4)
  - [ ] 2.1 Create `HyzerKit/Sources/HyzerKit/Models/Discrepancy.swift` as `@Model` class
  - [ ] 2.2 Fields: `id: UUID`, `roundID: UUID`, `playerID: String`, `holeNumber: Int`, `eventID1: UUID`, `eventID2: UUID`, `status: DiscrepancyStatus` (`.unresolved`, `.resolved`), `resolvedByEventID: UUID?`, `createdAt: Date`
  - [ ] 2.3 All properties optional or defaulted (CloudKit compatibility constraints)
  - [ ] 2.4 `DiscrepancyStatus` as String-backed enum (same pattern as `SyncStatus`)
  - [ ] 2.5 Add `Discrepancy.swift` to HyzerKit's domain model schema — register in `ModelContainer` under the **domain store** (this is domain data that syncs to CloudKit, not operational data)

- [ ] Task 3: Update `resolveCurrentScore()` for deterministic tie-breaking (AC: #1, #6)
  - [ ] 3.1 Modify `resolveCurrentScore(for:hole:in:)` in `ScoreResolution.swift`: when multiple leaf nodes exist (silent merge scenario), sort by `createdAt` ascending and return the earliest — deterministic resolution per NFR20
  - [ ] 3.2 This is a single-line change: replace `.first` with `.sorted(by: { $0.createdAt < $1.createdAt }).first` on the leaf-node filter
  - [ ] 3.3 Write test verifying deterministic selection when two leaves exist with different `createdAt`

- [ ] Task 4: Integrate `ConflictDetector` into `SyncEngine.pullRecords()` (AC: #5)
  - [ ] 4.1 Add `ConflictDetector` as a dependency of `SyncEngine` — inject via constructor (not a stored property; it's a value type with no state — can be created inline or injected)
  - [ ] 4.2 After inserting new ScoreEvents in `pullRecords()`, group all events by {roundID, playerID, holeNumber}
  - [ ] 4.3 For each group with newly-inserted events, call `conflictDetector.check(newEvent:existingEvents:)`
  - [ ] 4.4 For `.silentMerge` results: log at `.debug` level, no further action (standings recompute handles it)
  - [ ] 4.5 For `.discrepancy` results: create a `Discrepancy` model instance, insert into SwiftData, log at `.info` level
  - [ ] 4.6 For `.correction` and `.noConflict` results: no action needed
  - [ ] 4.7 Existing `StandingsEngine.recompute(for:trigger:.remoteSync)` call remains unchanged — discrepancy detection is additive, not disruptive to the existing pull flow

- [ ] Task 5: Create `Discrepancy+Fixture.swift` for tests (AC: #1-6)
  - [ ] 5.1 Create `HyzerKit/Tests/HyzerKitTests/Fixtures/Discrepancy+Fixture.swift` following existing fixture pattern
  - [ ] 5.2 Include parameters for `roundID`, `playerID`, `holeNumber`, `eventID1`, `eventID2`, `status`

- [ ] Task 6: Create `ConflictDetectorTests.swift` (AC: #1, #2, #3, #4, #6)
  - [ ] 6.1 Create `HyzerKit/Tests/HyzerKitTests/ConflictDetectorTests.swift`
  - [ ] 6.2 Test: `test_check_singleEvent_returnsNoConflict` — only one event for {player, hole}
  - [ ] 6.3 Test: `test_check_sameDeviceCorrection_returnsCorrection` — `supersedesEventID` set, same `deviceID`
  - [ ] 6.4 Test: `test_check_differentDeviceSameScore_returnsSilentMerge` — different `deviceID`, same `strokeCount`, both `supersedesEventID == nil`
  - [ ] 6.5 Test: `test_check_differentDeviceDifferentScore_returnsDiscrepancy` — different `deviceID`, different `strokeCount`, both `supersedesEventID == nil`
  - [ ] 6.6 Test: `test_check_crossDeviceSupersession_returnsDiscrepancy` — `supersedesEventID` points to event from different `deviceID`
  - [ ] 6.7 Test: `test_check_twentyConcurrentIdenticalEvents_zeroDiscrepancies` — NFR20 verification with 20+ events from different devices, same score
  - [ ] 6.8 Test: `test_check_mixedScoresMultipleDevices_detectsCorrectDiscrepancies` — complex scenario with merges and discrepancies in same batch

- [ ] Task 7: Create `SyncEngineConflictTests.swift` (AC: #5)
  - [ ] 7.1 Create `HyzerKit/Tests/HyzerKitTests/SyncEngineConflictTests.swift`
  - [ ] 7.2 Test: `test_pullRecords_identicalRemoteScore_silentMerge_noDiscrepancy` — pull identical score from MockCloudKitClient, verify no `Discrepancy` model created
  - [ ] 7.3 Test: `test_pullRecords_conflictingRemoteScore_createsDiscrepancy` — pull conflicting score, verify `Discrepancy` created with correct fields
  - [ ] 7.4 Test: `test_pullRecords_correctionFromSameDevice_noDiscrepancy` — pull correction with same `deviceID`, verify no discrepancy
  - [ ] 7.5 Test: `test_pullRecords_crossDeviceSupersession_createsDiscrepancy` — pull correction with different `deviceID`, verify discrepancy

- [ ] Task 8: Update `resolveCurrentScore` tests (AC: #6)
  - [ ] 8.1 Add test in existing `ScoreResolutionTests.swift` (or create if not present): `test_resolveCurrentScore_multipleLeaves_returnsDeterministicResult` — two leaf nodes, verify earliest `createdAt` wins
  - [ ] 8.2 Add test: `test_resolveCurrentScore_twentyLeaves_returnsDeterministicResult` — 20 leaves from different devices, verify consistent result

- [ ] Task 9: Register `Discrepancy` model in ModelContainer and update project.yml (AC: #2)
  - [ ] 9.1 Add `Discrepancy.self` to the domain store schema in `HyzerApp.swift` (alongside `Player`, `Round`, `Course`, `Hole`, `ScoreEvent`)
  - [ ] 9.2 Update `project.yml` to include new source files if needed
  - [ ] 9.3 Run `xcodegen generate` to regenerate the Xcode project

## Dev Notes

### Four-Case Conflict Detection Matrix

The architecture defines four mechanically determined cases using `supersedesEventID` and `deviceID`:

| # | `supersedesEventID` | Same `deviceID`? | Same `strokeCount`? | Result | Example |
|---|---|---|---|---|---|
| 1 | `nil` (initial) | N/A (only event) | N/A | `.noConflict` | First score for this player+hole |
| 2 | Set (correction) | Yes | N/A | `.correction` | Player corrects their own score |
| 3 | `nil` (initial) | No | Yes | `.silentMerge` | Jake's phone and Sarah's phone both record "Mike got a 3" |
| 4a | `nil` (initial) | No | No | `.discrepancy` | Jake's phone says 3, Sarah's phone says 4 |
| 4b | Set (correction) | No | N/A | `.discrepancy` | Sarah "corrects" a score that Jake's phone recorded — cross-device supersession |

### Architecture Constraints (MUST follow)

**ConflictDetector Design:**
- Lives in `HyzerKit/Sources/HyzerKit/Domain/ConflictDetector.swift` (Domain layer per architecture)
- Must be `nonisolated` — pure logic, no mutable state, no actor isolation
- Operates on `[ScoreEvent]` arrays passed in — does NOT query SwiftData itself
- `SyncEngine` calls it with the relevant event groups after inserting pulled records
- `ConflictResult` is a `Sendable` enum (crosses `SyncEngine` actor boundary)

**Discrepancy Model Design:**
- `@Model` class in `HyzerKit/Sources/HyzerKit/Models/Discrepancy.swift`
- Domain store (syncs to CloudKit) — NOT operational store
- All properties optional/defaulted per CloudKit constraints
- `DiscrepancyStatus` uses String-backed `RawRepresentable` enum (same as `SyncStatus`)
- Epic 6 will build the resolution UI that reads and updates these records

**Event Sourcing Invariants:**
- ScoreEvent is append-only and immutable (NFR19) — `ConflictDetector` NEVER mutates or deletes events
- Discrepancy resolution (Epic 6) creates a NEW authoritative ScoreEvent with `supersedesEventID` — not handled in this story
- `resolveCurrentScore()` leaf-node resolution is the ONLY way to determine the "current" score

**Concurrency Model (Swift 6 strict):**
- `ConflictDetector` is `nonisolated` (no state) — called from `SyncEngine` actor without isolation crossing
- `SyncEngine` is an `actor` — `pullRecords()` runs inside actor isolation
- `Discrepancy` model inserts happen on `SyncEngine`'s background `ModelContext`
- No new isolation boundaries introduced in this story

### Existing Code to Reuse (DO NOT reinvent)

| Component | Location | How to use |
|---|---|---|
| `SyncEngine` actor | `HyzerKit/Sync/SyncEngine.swift` | Modify `pullRecords()` to call `ConflictDetector.check()` after inserting events |
| `resolveCurrentScore()` | `HyzerKit/Domain/ScoreResolution.swift` | Fix determinism: sort leaves by `createdAt` |
| `ScoreEvent` model | `HyzerKit/Models/ScoreEvent.swift` | Read `supersedesEventID`, `deviceID`, `strokeCount`, `playerID`, `holeNumber` |
| `SyncMetadata` model | `HyzerKit/Sync/SyncMetadata.swift` | Pattern reference for String-backed enum (`DiscrepancyStatus`) |
| `SyncError.recordConflict` | `HyzerKit/Sync/SyncError.swift` | Already defined but unused — this story does NOT need it (detection is domain-level, not CKRecord-level) |
| `StandingsChangeTrigger.conflictResolution` | `HyzerKit/Domain/StandingsChangeTrigger.swift` | Already defined — NOT used in this story (used in Epic 6 resolution) |
| `ScoreEvent+Fixture` | `HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift` | Use for conflict test data — pass explicit `deviceID` and `supersedesEventID` |
| `SyncMetadata+Fixture` | `HyzerKitTests/Fixtures/SyncMetadata+Fixture.swift` | Pattern reference for `Discrepancy+Fixture` |
| `MockCloudKitClient` | `HyzerKitTests/Mocks/MockCloudKitClient.swift` | Use for SyncEngine integration tests |

### File Structure

**New files to create:**

```
HyzerKit/Sources/HyzerKit/Domain/
├── ConflictDetector.swift            # nonisolated struct, four-case detection logic
└── ConflictResult.swift              # Sendable enum result type (or inline in ConflictDetector.swift)

HyzerKit/Sources/HyzerKit/Models/
└── Discrepancy.swift                 # @Model, domain store, syncs to CloudKit

HyzerKit/Tests/HyzerKitTests/
├── ConflictDetectorTests.swift       # Pure logic tests (no SwiftData needed)
├── SyncEngineConflictTests.swift     # Integration tests with SwiftData + MockCloudKitClient
└── Fixtures/
    └── Discrepancy+Fixture.swift     # Test factory
```

**Files to modify:**

```
HyzerKit/Sources/HyzerKit/Domain/ScoreResolution.swift   # Deterministic tie-breaking
HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift          # Call ConflictDetector in pullRecords()
HyzerApp/App/HyzerApp.swift                               # Add Discrepancy.self to ModelContainer schema
project.yml                                                # Add new files if needed
```

### What This Story Does NOT Do (Scope Boundary)

- **NO resolution UI** — Epic 6 (Story 6.1) builds `DiscrepancyAlertView` and `DiscrepancyResolutionView`
- **NO organizer-only alerting** — Epic 6 handles FR49-FR52
- **NO CKSubscription changes** — already implemented in Story 4.2
- **NO `StandingsChangeTrigger.conflictResolution` usage** — that's for Epic 6 when a discrepancy is resolved
- **NO modification of `SyncError.recordConflict`** — detection is domain-level, not CloudKit-record-level
- **NO Watch-related changes** — conflict detection is phone-only (phone is sole sync node)

### Previous Story Intelligence (from Story 4.2)

**Key patterns from 4.2:**
- `SyncEngine.pullRecords()` fetches all ScoreEvent CKRecords, deduplicates by `ScoreEvent.id` (exact UUID match), inserts new events, creates `.synced` SyncMetadata entries, then calls `standingsEngine.recompute(for:trigger:.remoteSync)` per affected roundID
- `pullRecords()` currently has NO semantic deduplication — two events with different UUIDs for same {player, hole} are both inserted without conflict awareness
- Network framework uses `AsyncStream` for connectivity state bridging
- Test count after 4.2: 120 HyzerKit tests
- `LiveNetworkMonitor` is the ONE acceptable `DispatchQueue` use (required by Network framework API)

**4.2 deferred items relevant to 4.3:**
- M3: `ValueCollector` test helper duplicated — still deferred, not blocking
- H2: `foregroundDiscovery()` simplified pull-all approach — not impacted by conflict detection

### Testing Standards

- Use **Swift Testing** (`@Suite`, `@Test`, `#expect`) — NOT XCTest
- Test naming: `test_{method}_{scenario}_{expectedBehavior}`
- Test structure: Given/When/Then
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData tests
- Use `MockCloudKitClient` for sync integration tests
- Fixture pattern: `ScoreEvent.fixture(...)`, `Discrepancy.fixture(...)`
- `ConflictDetector` tests need NO SwiftData — pure logic on `[ScoreEvent]` arrays
- `SyncEngineConflict` tests need SwiftData (in-memory) + MockCloudKitClient

### Project Structure Notes

- `ConflictDetector` lives in `HyzerKit/Domain/` — it's domain logic, not sync infrastructure
- `ConflictResult` can be in the same file or a separate file — keep it simple
- `Discrepancy` model lives in `HyzerKit/Models/` alongside `ScoreEvent`, `Round`, etc.
- `Discrepancy` goes in the domain store schema (not operational store) — it represents domain state that should sync to CloudKit
- All new types must be `public` (HyzerKit is a separate module)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Core Architectural Decisions: "Conflict detection strategy (on-write in sync engine, four mechanically defined cases using supersedesEventID)"]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Architecture: supersedesEventID, reportedByPlayerID, deviceID field definitions]
- [Source: _bmad-output/planning-artifacts/architecture.md — Sync Architecture: architectural spike boundary, conflict detection after spike]
- [Source: _bmad-output/planning-artifacts/architecture.md — Project Structure: Domain/ConflictDetector.swift, ConflictDetectorTests.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Flow: "ConflictDetector.check() → silent merge or discrepancy"]
- [Source: _bmad-output/planning-artifacts/architecture.md — NFR20: "Deterministic merge: identical {player, hole, score} from two+ devices always merges silently"]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 4, Story 4.3: four AC scenarios]
- [Source: _bmad-output/planning-artifacts/prd.md — FR47, FR48, NFR20]
- [Source: _bmad-output/implementation-artifacts/4-2-offline-queue-and-sync-recovery.md — SyncEngine patterns, test patterns, file structure]
- [Source: _bmad-output/planning-artifacts/architecture.md — Amendment A7: leaf-node resolution, not timestamp]
- [Source: _bmad-output/planning-artifacts/architecture.md — Simplification Opportunity: Organizer Role deviation]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
