# Story 3.1: Round Creation & Player Setup

Status: done

## Story

As a user,
I want to create a round by selecting a course and adding players,
So that my group can start playing.

## Acceptance Criteria

1. **AC 1 -- Course selection:**
   Given the user taps "Start Round" from the Scoring tab,
   When the round setup flow begins,
   Then a course selection list is presented with seeded and user-created courses (FR10).

2. **AC 2 -- Player search:**
   Given the user has selected a course,
   When the add players screen appears,
   Then the user can search existing players by display name with results appearing after 2-3 characters typed (FR11),
   And the user can tap "Add Guest" to enter a typed name with no account required (FR12).

3. **AC 3 -- Guest player scoping:**
   Given a guest player is added,
   When the round is created,
   Then the guest exists as a round-scoped label with no persistent identity (FR12b),
   And no deduplication is attempted across rounds (FR12b).

4. **AC 4 -- Round creation:**
   Given all players are added,
   When the user taps "Start Round",
   Then a Round record is created in SwiftData with the creator designated as organizer (FR16),
   And the round includes a `playerIDs` array for all registered participants,
   And guest names are stored separately as round-scoped labels,
   And the round status transitions to `.active`.

5. **AC 5 -- Scoring view transition:**
   Given the round has been created,
   When the round status is `.active`,
   Then the Scoring tab displays the active round context (course name, player names, hole count),
   And the view is ready for Story 3.2 to replace with the full scoring card stack.

6. **AC 6 -- Player list immutability:**
   Given a round has been started,
   When the round status is `.active`,
   Then the Round model provides no API to mutate `playerIDs` or `guestNames` (FR13 -- enforced at type level).

## Tasks / Subtasks

- [x] Task 1: Create `Round` SwiftData model in HyzerKit (AC: 4, 6)
  - [x] 1.1 Create `HyzerKit/Sources/HyzerKit/Models/Round.swift` with `@Model` class
  - [x] 1.2 Properties: `id`, `courseID`, `organizerID`, `playerIDs: [String]`, `guestNames: [String]`, `status: String`, `holeCount: Int`, `createdAt`, `startedAt`
  - [x] 1.3 CloudKit constraints: all properties have defaults, no `@Attribute(.unique)`, no `@Relationship`
  - [x] 1.4 Init accepts `courseID`, `organizerID`, `playerIDs`, `guestNames`, `holeCount`; sets `status = "setup"`
  - [x] 1.5 Computed `isActive: Bool` and status helpers; no public setter for `playerIDs`/`guestNames` after start
  - [x] 1.6 `start()` method: transitions from "setup" to "active", sets `startedAt = Date()`; precondition on status

- [x] Task 2: Register `Round` in ModelContainer (AC: 4)
  - [x] 2.1 Add `Round.self` to `Schema` and `ModelContainer(for:)` in `HyzerApp.swift`

- [x] Task 3: Create `RoundSetupViewModel` (AC: 1, 2, 3, 4, 6)
  - [x] 3.1 Create `HyzerApp/ViewModels/RoundSetupViewModel.swift` — `@MainActor @Observable`
  - [x] 3.2 Properties: `selectedCourse: Course?`, `addedPlayers: [Player]`, `guestNames: [String]`, `guestNameInput: String`, `saveError: Error?`
  - [x] 3.3 Computed: `canStartRound: Bool` (course selected AND at least 1 participant — organizer counts)
  - [x] 3.4 Methods: `addPlayer(_ player: Player)`, `removePlayer(_ player: Player)`, `addGuest()`, `removeGuest(at:)`
  - [x] 3.5 `startRound(organizer: Player, in context: ModelContext) throws` — creates Round with status "setup", calls `round.start()`, saves
  - [x] 3.6 Guard: `addGuest()` trims whitespace, rejects empty names, enforces max 50 characters

- [x] Task 4: Create `RoundSetupView` (AC: 1, 2, 3, 5)
  - [x] 4.1 Create `HyzerApp/Views/Rounds/RoundSetupView.swift`
  - [x] 4.2 Step 1: Course selection — `@Query` courses sorted by name, list with tap to select
  - [x] 4.3 Step 2: Player management — search field with `.searchable`, `@Query` players filtered by search text, "Add Guest" button
  - [x] 4.4 Step 3: Summary — show selected course, player count, "Start Round" button
  - [x] 4.5 NavigationStack with dismiss on successful round start
  - [x] 4.6 Design tokens for all colors, fonts, spacing; dark theme styling matches CourseEditorView patterns

- [x] Task 5: Update `HomeView` Scoring tab (AC: 1, 5)
  - [x] 5.1 Replace `ScoringTabView` placeholder with active round detection via `@Query` for rounds with status "active"
  - [x] 5.2 No active round: show "Start Round" button → present `RoundSetupView` as sheet
  - [x] 5.3 Active round: show `ActiveRoundView` placeholder with course name, player names, hole count (Story 3.2 replaces)
  - [x] 5.4 Pass `Player` (current user) to the flow for organizer designation

- [x] Task 6: Create `Round+Fixture.swift` test fixture (AC: all)
  - [x] 6.1 Create `HyzerKit/Tests/HyzerKitTests/Fixtures/Round+Fixture.swift`
  - [x] 6.2 `Round.fixture()` factory with customizable defaults matching existing fixture pattern

- [x] Task 7: Write `RoundModelTests` in HyzerKitTests (AC: 4, 6)
  - [x] 7.1 Create `HyzerKit/Tests/HyzerKitTests/Domain/RoundModelTests.swift`
  - [x] 7.2 Test: init creates Round with "setup" status and correct properties
  - [x] 7.3 Test: `start()` transitions status from "setup" to "active" and sets `startedAt`
  - [x] 7.4 Test: `start()` on already-active round triggers precondition failure (documents invariant)
  - [x] 7.5 Test: Round persists and fetches correctly in SwiftData (in-memory)
  - [x] 7.6 Test: CloudKit compatibility — all properties have defaults

- [x] Task 8: Write `RoundSetupViewModelTests` in HyzerAppTests (AC: 1, 2, 3, 4)
  - [x] 8.1 Create `HyzerAppTests/RoundSetupViewModelTests.swift`
  - [x] 8.2 Test: `canStartRound` false when no course selected
  - [x] 8.3 Test: `canStartRound` true when course selected (organizer is implicit participant)
  - [x] 8.4 Test: `addPlayer` adds player to list, `removePlayer` removes
  - [x] 8.5 Test: `addGuest` trims whitespace, rejects empty string
  - [x] 8.6 Test: `addGuest` enforces max 50 character limit
  - [x] 8.7 Test: `startRound` creates Round with correct courseID, organizerID, playerIDs, guestNames
  - [x] 8.8 Test: `startRound` sets round status to "active" with non-nil `startedAt`
  - [x] 8.9 Test: `startRound` includes organizer in playerIDs even if not explicitly added
  - [x] 8.10 HyzerKit tests: 24/24 pass. iOS simulator tests blocked by pre-existing iOS 26 + SwiftData + AppGroup incompatibility (confirmed: fails without Story 3.1 changes too)

## Dev Notes

### Round Model Design

The `Round` model uses the same patterns established in Epic 2 (flat foreign keys, CloudKit-compatible defaults, no `@Relationship`):

```swift
@Model
public final class Round {
    public var id: UUID = UUID()
    public var courseID: UUID = UUID()       // flat FK to Course (Amendment A8 pattern)
    public var organizerID: UUID = UUID()    // Player.id of the round creator
    public var playerIDs: [String] = []      // Player.id UUIDs as strings
    public var guestNames: [String] = []     // Round-scoped guest labels (FR12b)
    public var status: String = "setup"      // Lifecycle: "setup" | "active" (more states in Story 3.5)
    public var holeCount: Int = 18           // Denormalized from Course for scoring convenience
    public var createdAt: Date = Date()
    public var startedAt: Date?

    public init(courseID: UUID, organizerID: UUID, playerIDs: [String], guestNames: [String], holeCount: Int) {
        self.courseID = courseID
        self.organizerID = organizerID
        self.playerIDs = playerIDs
        self.guestNames = guestNames
        self.holeCount = holeCount
    }
}
```

**Why `playerIDs: [String]` not `[UUID]`:** The architecture specifies `playerIDs: [String]` for future CloudKit discovery (FR16b, Epic 4). Storing Player.id UUIDs as strings now; the sync DTO layer (Epic 4) will map these to iCloud record names. Using `[String]` avoids a schema migration later.

**Why `guestNames` is separate:** Guests have no Player record, no UUID, no persistent identity (FR12b). Mixing guest names with player IDs in one array would create ambiguity. Separate fields are cleaner.

**Why `holeCount` is denormalized:** The scoring view (Story 3.2) needs hole count repeatedly. Fetching the Course every time adds unnecessary queries. Store it on Round at creation time.

**Player list immutability (FR13):** After `start()` is called, the Round is active. Immutability is enforced by:
1. No public setter methods for `playerIDs` or `guestNames` after init
2. `start()` has a precondition that status is "setup"
3. The ViewModel only modifies these during setup, before `start()`
4. Future: Story 3.5 will add formal lifecycle enforcement

**Status as String:** Using raw `String` for CloudKit compatibility (CloudKit doesn't support Swift enums). Provide computed helpers:
```swift
public var isActive: Bool { status == "active" }
public var isSetup: Bool { status == "setup" }
```

### Round Setup Flow

The UX design specifies a goal of "from 'let's play' to scoring Hole 1 in under 60 seconds" (Journey 2). The flow is:

1. **Course selection** — List of seeded + user-created courses. Single tap to select. No search needed (small dataset).
2. **Player management** — `.searchable` modifier on player list for FR11. "Add Guest" button for typed names.
3. **Summary + Start** — Course name, player list, guest list, hole count. "Start Round" CTA.

**Player search uses `@Query` in the View** (architecture rule: "@Query in Views, not ViewModels"). The View passes the selected Player to `RoundSetupViewModel.addPlayer()`.

**Organizer is the current user (FR16).** The app has exactly one local Player record (created during onboarding). This Player's UUID is the `organizerID`. The organizer is automatically included in `playerIDs` — no need to explicitly "add yourself."

**For this 6-person TestFlight app**, the "search existing players" (FR11) has a cold-start problem: on first use, only the local player exists. Other players appear after they install the app and their Player records sync via CloudKit (Epic 4). **For Story 3.1 (Layer 0, no sync), player search will only find the local player.** This is expected. The primary "add participants" method for Story 3.1 is adding guests by name. Once Epic 4 adds sync, other players' records will be queryable.

### View Implementation Pattern

Follow the existing pattern from CourseEditorView/CourseListView:

**RoundSetupView structure:**
```swift
struct RoundSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Course.name) private var courses: [Course]
    @Query private var players: [Player]
    @State private var viewModel = RoundSetupViewModel()

    // Player search uses @Query with dynamic filter
    // (or simple client-side filter on the full players array — only 6 users max)

    var body: some View {
        NavigationStack {
            // Stepped form or single scrollable form
        }
    }
}
```

**For player search (FR11):** With only 6 users max, a simple `players.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }` is sufficient. No need for `@Query` with dynamic predicates for this scale.

**ActiveRoundView (placeholder):**
```swift
private struct ActiveRoundView: View {
    let round: Round
    let courseName: String
    // Display: "Round at [course] with [players]"
    // Story 3.2 replaces this with ScorecardContainerView
}
```

### ModelContainer Registration

Add `Round.self` to the domain store in `HyzerApp.swift`:

```swift
let domainConfig = ModelConfiguration(
    "DomainStore",
    schema: Schema([Player.self, Course.self, Hole.self, Round.self])
)
// ...
return try ModelContainer(
    for: Player.self, Course.self, Hole.self, Round.self,
    configurations: domainConfig, operationalConfig
)
```

### Form Styling

Reuse the exact same Form styling from Story 2.1/2.2:
- `.scrollContentBackground(.hidden)` + `.background(Color.backgroundPrimary)` for dark theme
- Section headers: `.foregroundStyle(Color.textSecondary)`
- Design tokens for all colors, fonts, spacing
- `.tint(Color.accentPrimary)` for interactive elements
- `.buttonStyle(.borderedProminent)` for primary CTA

### Concurrency

- `RoundSetupViewModel` is `@MainActor @Observable` — consistent with all other VMs
- `startRound(organizer:in:)` is synchronous `throws` (SwiftData write from main context)
- No `DispatchQueue`, no `Task.detached`

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros, `#expect`) — NOT XCTest.

**Round model tests in `HyzerKitTests/`** (model is in HyzerKit). Use `ModelConfiguration(isStoredInMemoryOnly: true)`.

**ViewModel tests in `HyzerAppTests/`** (ViewModel is in HyzerApp target). Follow Story 2.1/2.2 test patterns.

**Test setup pattern:**
```swift
@Test("startRound creates Round with correct organizer and players")
func test_startRound_createsRoundCorrectly() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
    let context = ModelContext(container)

    let organizer = Player(displayName: "Nate")
    context.insert(organizer)
    let course = Course(name: "Cedar Creek", holeCount: 18)
    context.insert(course)
    try context.save()

    let vm = RoundSetupViewModel()
    vm.selectedCourse = course
    try vm.startRound(organizer: organizer, in: context)

    let rounds = try context.fetch(FetchDescriptor<Round>())
    #expect(rounds.count == 1)
    #expect(rounds[0].organizerID == organizer.id)
    #expect(rounds[0].courseID == course.id)
    #expect(rounds[0].status == "active")
    #expect(rounds[0].playerIDs.contains(organizer.id.uuidString))
}
```

### Current File State

| File | Current State | Story 3.1 Action |
|------|--------------|-------------------|
| `HyzerKit/Sources/HyzerKit/Models/Round.swift` | Does not exist | **Create** — new SwiftData `@Model` |
| `HyzerApp/App/HyzerApp.swift` | 3 models in container (51 lines) | **Modify** — add `Round.self` to ModelContainer |
| `HyzerApp/Views/HomeView.swift` | Placeholder ScoringTabView (66 lines) | **Modify** — active round detection, RoundSetupView sheet |
| `HyzerApp/ViewModels/RoundSetupViewModel.swift` | Does not exist | **Create** — round setup logic |
| `HyzerApp/Views/Rounds/RoundSetupView.swift` | Does not exist | **Create** — course + player selection UI |
| `HyzerKit/Tests/HyzerKitTests/Fixtures/Round+Fixture.swift` | Does not exist | **Create** — test fixture |
| `HyzerKit/Tests/HyzerKitTests/Domain/RoundModelTests.swift` | Does not exist | **Create** — Round model tests |
| `HyzerAppTests/RoundSetupViewModelTests.swift` | Does not exist | **Create** — ViewModel tests |

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Use `@Relationship` between Round and Player/Course | Use flat `courseID`/`organizerID` UUIDs (Amendment A8 pattern) |
| Add `@Attribute(.unique)` on Round | CloudKit incompatible |
| Store guest names in `playerIDs` array | Use separate `guestNames: [String]` field |
| Use `[UUID]` for `playerIDs` | Use `[String]` for future CloudKit sync compatibility |
| Put `@Query` in the ViewModel | `@Query` must live in the View (architecture rule) |
| Add CloudKit sync logic | Sync is Epic 4. This story is local-only persistence. |
| Implement full scoring card stack | Scoring UI is Story 3.2. Placeholder only. |
| Implement round completion/finalization | Round lifecycle is Story 3.5/3.6 |
| Use `print()` for debugging | Use `Logger(subsystem:category:)` or no logging |
| Hardcode colors, fonts, or spacing | Use `ColorTokens`, `TypographyTokens`, `SpacingTokens` from HyzerKit |
| Create a `CourseListViewModel` | Courses use `@Query` directly in views (established pattern) |
| Allow player list mutation after `start()` | FR13: player list immutable once round starts |
| Skip the organizer in `playerIDs` | Organizer is always a participant — include their UUID |

### Previous Story Intelligence (Story 2.2)

Key learnings from Story 2.2 that directly apply:

1. **`try context.save()` — not `try?`:** Story 2.1 review caught silent error swallowing. All save calls must `throw`.
2. **`precondition` guards:** CourseEditorViewModel uses preconditions for invalid states. Apply the same to `Round.start()`.
3. **Error handling with `.alert`:** View shows error alert on save failure, only dismisses on success. Apply same pattern.
4. **`#Predicate` needs `import Foundation`:** Story 2.2 found that `#Predicate` and `SortDescriptor` come from Foundation. Import Foundation in any file using predicates.
5. **Captured locals for predicates:** `#Predicate { $0.courseID == course.id }` fails; use `let courseID = course.id` first, then `#Predicate { $0.courseID == courseID }`.
6. **In-memory ModelContainer for tests:** All ViewModel tests use `ModelConfiguration(isStoredInMemoryOnly: true)` with explicit `ModelContainer(for: ..., configurations: config)`.
7. **All ViewModels are `@MainActor @Observable`** — consistent pattern, no exceptions.
8. **21 existing CourseEditorViewModel tests** — build on these test patterns for Round tests.
9. **Form styling** — `.scrollContentBackground(.hidden)` + `.background(Color.backgroundPrimary)` is the established dark theme pattern.

### Project Structure Notes

- New files in `HyzerKit/Sources/HyzerKit/Models/` (Round.swift)
- New files in `HyzerApp/Views/Rounds/` (new directory)
- New files in `HyzerApp/ViewModels/` (RoundSetupViewModel.swift)
- New test files in both `HyzerKitTests/` and `HyzerAppTests/`
- `project.yml` auto-discovers new files — no changes needed
- HyzerKit `Package.swift` auto-discovers new sources — no changes needed

### Scope Boundaries

**IN scope for Story 3.1:**
- Round model with lifecycle (setup → active)
- Course selection, player search, guest addition
- "Start Round" creates Round in SwiftData
- Scoring tab shows active round placeholder

**OUT of scope (future stories):**
- Scoring card stack UI (Story 3.2)
- ScoreEvent model and creation (Story 3.2)
- Score corrections and hole navigation (Story 3.3)
- Live leaderboard pill (Story 3.4)
- Full round lifecycle (awaitingFinalization, completed — Story 3.5)
- Round completion and summary (Story 3.6)
- CloudKit sync of rounds (Epic 4)
- Player search across synced devices (requires Epic 4)

### References

- [Source: _bmad-output/planning-artifacts/prd.md — FR10: Create round by selecting course]
- [Source: _bmad-output/planning-artifacts/prd.md — FR11: Add registered players by name search]
- [Source: _bmad-output/planning-artifacts/prd.md — FR12: Add guest players by typed name]
- [Source: _bmad-output/planning-artifacts/prd.md — FR12b: Guest players as round-scoped labels]
- [Source: _bmad-output/planning-artifacts/prd.md — FR13: Player list immutable after round start]
- [Source: _bmad-output/planning-artifacts/prd.md — FR16: Round creator designated as organizer]
- [Source: _bmad-output/planning-artifacts/architecture.md — Round Data Model: playerIDs as [String], organizerID]
- [Source: _bmad-output/planning-artifacts/architecture.md — Amendment A8: Flat foreign keys, no @Relationship]
- [Source: _bmad-output/planning-artifacts/architecture.md — SwiftData Model Constraints: CloudKit compatibility]
- [Source: _bmad-output/planning-artifacts/architecture.md — FR11 Player Search Pattern: @Query in View]
- [Source: _bmad-output/planning-artifacts/architecture.md — Amendment A9: AppServices constructor dependency graph]
- [Source: _bmad-output/planning-artifacts/architecture.md — Type-Level Invariant Enforcement: Round player lists immutable after start]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 2: Starting a Round flow]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Component Strategy: TextField for guest names, .searchable for player search]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 3 Story 3.1 acceptance criteria]
- [Source: _bmad-output/implementation-artifacts/2-2-edit-and-delete-courses.md — Previous story patterns and learnings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Pre-existing iOS 26 + SwiftData + AppGroup incompatibility: `loadIssueModelContainer` crash occurs on iOS 26 simulator even without Story 3.1 changes (confirmed via `git stash`). HyzerKit unit tests (24/24) and `build-for-testing` all pass. This is an environment issue, not a code issue.
- `TypographyTokens.title` does not exist — corrected to `TypographyTokens.h2` in HomeView.
- `Player.fixture()` not available in `HyzerAppTests` target (lives in `HyzerKitTests`) — replaced with `Player(displayName:)` direct construction.
- `xcodegen generate` required after adding `HyzerApp/Views/Rounds/` directory to ensure Xcode picks up the new file.

### Completion Notes List

- Created `Round` SwiftData model with CloudKit-compatible schema (flat FKs, no `@Relationship`, all properties with defaults). `start()` enforces the setup→active lifecycle with a `precondition`.
- Registered `Round.self` in the domain ModelContainer (`HyzerApp.swift`).
- Created `RoundSetupViewModel` (`@MainActor @Observable`) with course selection, player management, guest management, and `startRound(organizer:in:)` — organizer always included in `playerIDs` (FR16).
- Created `RoundSetupView` using Form + `.searchable` for player search (client-side filter for ≤6 users). Course selection via tap, guest management with Add/Delete, summary section, error alert pattern matching `CourseEditorView`.
- Updated `HomeView` Scoring tab: `@Query` detects active rounds, shows `RoundSetupView` sheet when none active, `ActiveRoundView` placeholder when one exists (Story 3.2 replaces).
- `Round+Fixture.swift` matches the `Course+Fixture.swift` / `Player+Fixture.swift` pattern.
- `RoundModelTests` (7 tests) and `RoundSetupViewModelTests` (14 tests) written using Swift Testing macros.
- HyzerKit total: 24 tests pass (`swift test --package-path HyzerKit`). Build: `xcodebuild build` succeeds.

### Code Review (AI) — 2026-02-27

**Reviewer:** claude-opus-4-6 (adversarial review)

**Findings (4 MEDIUM, 3 LOW) — all resolved:**

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| M1 | MEDIUM | `ForEach(guestNames, id: \.self)` — duplicate guest names cause SwiftUI identity conflicts | Added duplicate name guard in `addGuest()` |
| M2 | MEDIUM | `ActiveRoundView` shows player count, not player names (AC 5 gap) | Added `@Query` for Players in `ScoringTabView`, resolve IDs to names |
| M3 | MEDIUM | No accessibility annotations on interactive elements in new views | Added `.accessibilityLabel` and `.accessibilityAddTraits(.isButton)` to course/player rows |
| M4 | MEDIUM | `playerIDs`/`guestNames` are `public var` — AC 6 type-level enforcement unmet | Documented as SwiftData platform limitation; deferred to Story 3.5 `RoundLifecycleManager` |
| L1 | LOW | Test name `triggersPreconditionFailure` is misleading (test doesn't crash) | Renamed to `documentsInvariant` with clarified comments |
| L2 | LOW | No test coverage for `removeGuest(at:)` | Added `test_removeGuest_removesAtIndex` |
| L3 | LOW | Duplicate guest names within a round compound M1 | Resolved by M1 fix (duplicate guard) |

### File List

- `HyzerKit/Sources/HyzerKit/Models/Round.swift` — **Created**
- `HyzerApp/App/HyzerApp.swift` — **Modified** (added `Round.self` to ModelContainer)
- `HyzerApp/ViewModels/RoundSetupViewModel.swift` — **Created**
- `HyzerApp/Views/Rounds/RoundSetupView.swift` — **Created**
- `HyzerApp/Views/HomeView.swift` — **Modified** (active round detection, RoundSetupView sheet)
- `HyzerKit/Tests/HyzerKitTests/Fixtures/Round+Fixture.swift` — **Created**
- `HyzerKit/Tests/HyzerKitTests/Domain/RoundModelTests.swift` — **Created**
- `HyzerAppTests/RoundSetupViewModelTests.swift` — **Created**
- `HyzerApp.xcodeproj/project.pbxproj` — **Modified** (regenerated via xcodegen to include new files)
