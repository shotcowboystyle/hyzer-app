# HyzerApp — Data Models

## SwiftData Schema

HyzerApp uses two separate SwiftData stores configured in `HyzerApp.swift`:

### Domain Store (CloudKit-synced)

Contains all user-facing data. Synced to CloudKit public database via manual push/pull (`SyncEngine`).

**CloudKit constraints:** All `@Model` properties must be optional or have defaults. No `@Attribute(.unique)`. No Swift enums as stored properties (use raw `String`).

---

#### Player

**File:** `HyzerKit/Sources/HyzerKit/Models/Player.swift`

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key (auto-generated) |
| `displayName` | `String` | Max 50 chars, trimmed |
| `iCloudRecordName` | `String?` | Links to CKRecord user identity |
| `aliases` | `[String]` | Alternative names for voice recognition |
| `createdAt` | `Date` | Auto-set at creation |

**Referenced by:** `Round.playerIDs` (as UUID string), `ScoreEvent.playerID` (as UUID string), `ScoreEvent.reportedByPlayerID` (as UUID)

---

#### Course

**File:** `HyzerKit/Sources/HyzerKit/Models/Course.swift`

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key |
| `name` | `String` | Max 100 chars |
| `holeCount` | `Int` | Denormalized count (9 or 18) |
| `isSeeded` | `Bool` | True for pre-loaded courses |
| `createdAt` | `Date` | Auto-set |

**Relationship:** No `@Relationship` — `Hole` references `Course` via flat `courseID` FK (Amendment A8).

---

#### Hole

**File:** `HyzerKit/Sources/HyzerKit/Models/Hole.swift`

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key |
| `courseID` | `UUID` | Flat FK to `Course.id` |
| `number` | `Int` | 1-based hole number |
| `par` | `Int` | Par value (2-6, default 3) |

---

#### Round

**File:** `HyzerKit/Sources/HyzerKit/Models/Round.swift`

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key |
| `courseID` | `UUID` | Flat FK to `Course.id` |
| `organizerID` | `UUID` | Player who created the round |
| `playerIDs` | `[String]` | Registered player UUID strings |
| `guestNames` | `[String]` | Round-scoped guest names |
| `status` | `String` | Lifecycle state (see state machine) |
| `holeCount` | `Int` | Denormalized from Course |
| `createdAt` | `Date` | Auto-set |
| `startedAt` | `Date?` | Set on `start()` |
| `completedAt` | `Date?` | Set on `complete()` |

**State Machine:**
```
setup → active → awaitingFinalization → completed
                → completed (force finish)
```

**Status constants** defined in standalone `enum RoundStatus` (NOT as static properties on `@Model` — SwiftData treats class-level statics as schema members).

---

#### ScoreEvent (Event-Sourced)

**File:** `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift`

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key |
| `roundID` | `UUID` | Flat FK to `Round.id` |
| `holeNumber` | `Int` | 1-based |
| `playerID` | `String` | UUID string or `"guest:{name}"` |
| `strokeCount` | `Int` | 1-10 |
| `supersedesEventID` | `UUID?` | Points to replaced event (corrections) |
| `reportedByPlayerID` | `UUID` | Who entered this score |
| `deviceID` | `String` | Originating device for conflict detection |
| `createdAt` | `Date` | Auto-set |

**Invariants:**
- **Append-only** (NFR19) — no UPDATE or DELETE operations ever
- Corrections create new events with `supersedesEventID` set
- Current score = leaf node in supersession chain (Amendment A7)
- Multiple leaf nodes (silent merge) → earliest `createdAt` wins (NFR20)
- Guest players use `"guest:{name}"` convention in `playerID`

---

#### Discrepancy

**File:** `HyzerKit/Sources/HyzerKit/Models/Discrepancy.swift`

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key |
| `roundID` | `UUID` | Flat FK to `Round.id` |
| `playerID` | `String` | Player with conflicting scores |
| `holeNumber` | `Int` | Hole with conflict |
| `eventID1` | `UUID` | First conflicting ScoreEvent |
| `eventID2` | `UUID` | Second conflicting ScoreEvent |
| `status` | `DiscrepancyStatus` | `.unresolved` or `.resolved` |
| `resolvedByEventID` | `UUID?` | Authoritative resolution event |
| `createdAt` | `Date` | Auto-set |

**Created by:** `SyncEngine.pullRecords()` via `ConflictDetector` when cross-device score conflicts are detected.

---

### Operational Store (Local-Only)

Contains sync tracking metadata. Never synced to CloudKit. Safely recoverable by deletion (SyncEngine will re-pull from CloudKit).

#### SyncMetadata

**File:** `HyzerKit/Sources/HyzerKit/Sync/SyncMetadata.swift`

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key |
| `recordID` | `String` | CloudKit record name |
| `recordType` | `String` | CKRecord type string |
| `syncStatus` | `SyncStatus` | State machine position |
| `lastAttempt` | `Date?` | Last push attempt timestamp |
| `createdAt` | `Date` | Auto-set |

**State Machine:** `pending → inFlight → synced` or `inFlight → failed`

---

## Relationship Diagram

```
Player ─── playerIDs ───→ Round ←── courseID ─── Course
  │                         │                      │
  │ playerID                │ roundID              │ courseID
  ↓                         ↓                      ↓
ScoreEvent ←── eventID1/2 ─ Discrepancy          Hole
  │
  │ supersedesEventID (self-referencing chain)
  ↓
ScoreEvent (correction)
```

**Key design notes:**
- All relationships use flat UUID foreign keys (no `@Relationship` decorators)
- This is intentional per Amendment A8 for CloudKit compatibility
- Child deletion (e.g., Holes when deleting a Course) is manual
- `#Predicate` queries require captured locals: `let courseID = course.id` before the predicate closure

## CloudKit DTO Layer

Only `ScoreEventRecord` is fully implemented (`HyzerKit/Sources/HyzerKit/Sync/DTOs/ScoreEventRecord.swift`). `CourseRecord`, `PlayerRecord`, and `RoundRecord` are stubs with identity-only CKRecord serialization.

**ScoreEventRecord mapping:** All UUID properties stored as `String` in CKRecord. Record ID = `id.uuidString` for idempotent upserts. `supersedesEventID` omitted from CKRecord when `nil`.
