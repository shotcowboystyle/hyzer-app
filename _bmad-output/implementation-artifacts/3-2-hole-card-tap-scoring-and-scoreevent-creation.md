# Story 3.2: Hole Card Tap Scoring & ScoreEvent Creation

Status: done

## Story

As a user,
I want to tap a player's row on a hole card to enter their score,
So that I can record scores quickly and accurately during a round.

## Acceptance Criteria

1. **AC 1 -- Tap to score:**
   Given an active round on a hole card,
   When the user taps a player row,
   Then an inline score picker appears with values 1-10, defaulting to par for the current hole (FR17, FR18).

2. **AC 2 -- Score entry creates immutable ScoreEvent:**
   Given the user selects a score from the picker,
   When the selection is made,
   Then the picker collapses, the score displays on the player row, and a haptic confirmation fires,
   And an immutable ScoreEvent is created and saved to SwiftData (FR36),
   And the response completes in <100ms (NFR3).

3. **AC 3 -- Distributed scoring:**
   Given any participant in the round,
   When they tap any other participant's row,
   Then they can enter a score for that player (FR35).

4. **AC 4 -- Card stack layout:**
   Given the scoring view,
   When it is displayed,
   Then hole cards are arranged in a horizontal swipeable card stack (TabView page style),
   And each card shows hole number, par, and all player rows with scores or dashes for unscored.

5. **AC 5 -- Scoring view replaces placeholder:**
   Given an active round exists,
   When the Scoring tab is displayed,
   Then `ScorecardContainerView` replaces the `ActiveRoundView` placeholder from Story 3.1.

6. **AC 6 -- Guest player scoring:**
   Given guests were added to the round,
   When the hole card is displayed,
   Then guest players appear as scoreable rows alongside registered players,
   And their scores create ScoreEvents with a guest-prefixed playerID.

## Tasks / Subtasks

- [x] Task 1: Create `ScoreEvent` SwiftData model in HyzerKit (AC: 2, 6)
  - [x] 1.1 Create `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift` with `@Model` class
  - [x] 1.2 Properties: `id`, `roundID`, `holeNumber`, `playerID` (String), `strokeCount`, `supersedesEventID` (UUID?), `reportedByPlayerID`, `deviceID` (String), `createdAt`
  - [x] 1.3 CloudKit constraints: all properties have defaults, no `@Attribute(.unique)`, no `@Relationship`
  - [x] 1.4 NO public update or delete API surface (type-level invariant for NFR19 append-only)
  - [x] 1.5 Init accepts `roundID`, `holeNumber`, `playerID`, `strokeCount`, `reportedByPlayerID`, `deviceID`

- [x] Task 2: Register `ScoreEvent` in ModelContainer (AC: 2)
  - [x] 2.1 Add `ScoreEvent.self` to `Schema` and `ModelContainer(for:)` in `HyzerApp.swift`

- [x] Task 3: Create `ScoringService` in HyzerKit (AC: 2)
  - [x] 3.1 Create `HyzerKit/Sources/HyzerKit/Domain/ScoringService.swift`
  - [x] 3.2 Constructor: `init(modelContext: ModelContext, deviceID: String)`
  - [x] 3.3 Method: `createScoreEvent(roundID:holeNumber:playerID:strokeCount:reportedByPlayerID:) throws -> ScoreEvent`
  - [x] 3.4 Creates ScoreEvent with `supersedesEventID: nil` (corrections are Story 3.3)
  - [x] 3.5 Inserts into modelContext and saves; throws on failure (never `try?`)

- [x] Task 4: Add `ScoringService` to `AppServices` (AC: 2)
  - [x] 4.1 Add `let scoringService: ScoringService` to `AppServices`
  - [x] 4.2 Construct with main ModelContext and device ID (`UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString`)

- [x] Task 5: Create `ScorecardViewModel` (AC: 1, 2, 3, 6)
  - [x] 5.1 Create `HyzerApp/ViewModels/ScorecardViewModel.swift` -- `@MainActor @Observable`
  - [x] 5.2 Constructor: `init(scoringService: ScoringService, roundID: UUID, reportedByPlayerID: UUID)`
  - [x] 5.3 Method: `enterScore(playerID: String, holeNumber: Int, strokeCount: Int) throws`
  - [x] 5.4 Property: `saveError: Error?` for error alert binding

- [x] Task 6: Create `ScorecardContainerView` (AC: 4, 5)
  - [x] 6.1 Create `HyzerApp/Views/Scoring/ScorecardContainerView.swift`
  - [x] 6.2 Receives `Round` object; queries ScoreEvents, Holes, Players via `@Query`
  - [x] 6.3 `TabView(selection: $currentHole)` with `.tabViewStyle(.page)` for horizontal paging
  - [x] 6.4 One `HoleCardView` per hole (1...round.holeCount), each tagged by hole number
  - [x] 6.5 Client-side filter for scores/holes matching this round (small dataset, no dynamic predicate needed)

- [x] Task 7: Create `HoleCardView` (AC: 1, 3, 4, 6)
  - [x] 7.1 Create `HyzerApp/Views/Scoring/HoleCardView.swift`
  - [x] 7.2 Card header: hole number (H2), par value (caption), course name (caption, secondary)
  - [x] 7.3 Player rows: name, score (or dash if unscored), running +/- par not required yet (Story 3.4)
  - [x] 7.4 Both registered players and guest players appear as rows
  - [x] 7.5 Tapping an unscored row expands inline `ScoreInputView`
  - [x] 7.6 Scored rows display the stroke count with score-state color coding
  - [x] 7.7 Accessibility: card labeled "Hole [n], Par [n]"; rows labeled "[name], score [n] or no score"

- [x] Task 8: Create `ScoreInputView` (AC: 1, 2)
  - [x] 8.1 Create `HyzerApp/Views/Scoring/ScoreInputView.swift`
  - [x] 8.2 Inline picker with values 1-10, defaulting to par for the current hole (FR18)
  - [x] 8.3 On selection: collapse picker, fire haptic (`UIImpactFeedbackGenerator(.light)`), call enterScore
  - [x] 8.4 Touch targets: minimum 44pt (NFR14), scoring targets 52pt (`SpacingTokens.scoringTouchTarget`)
  - [x] 8.5 Accessibility: labeled "Select score for [name]"

- [x] Task 9: Update `HomeView` to use `ScorecardContainerView` (AC: 5)
  - [x] 9.1 Replace `ActiveRoundView` placeholder in `ScoringTabView` with `ScorecardContainerView`
  - [x] 9.2 Pass the active `Round` object to `ScorecardContainerView`

- [x] Task 10: Create `ScoreEvent+Fixture.swift` (AC: all)
  - [x] 10.1 Create `HyzerKit/Tests/HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift`
  - [x] 10.2 `ScoreEvent.fixture()` with customizable defaults matching existing fixture pattern

- [x] Task 11: Write `ScoreEventModelTests` in HyzerKitTests (AC: 2)
  - [x] 11.1 Create `HyzerKit/Tests/HyzerKitTests/Domain/ScoreEventModelTests.swift`
  - [x] 11.2 Test: init creates ScoreEvent with correct properties and nil supersedesEventID
  - [x] 11.3 Test: ScoreEvent persists and fetches in SwiftData (in-memory)
  - [x] 11.4 Test: CloudKit compatibility -- all properties have defaults
  - [x] 11.5 Test: Multiple ScoreEvents for same {round, hole, player} coexist (append-only)

- [x] Task 12: Write `ScoringServiceTests` in HyzerKitTests (AC: 2, 3)
  - [x] 12.1 Create `HyzerKit/Tests/HyzerKitTests/Domain/ScoringServiceTests.swift`
  - [x] 12.2 Test: `createScoreEvent` persists event with correct roundID, holeNumber, playerID, strokeCount
  - [x] 12.3 Test: `createScoreEvent` sets reportedByPlayerID and deviceID correctly
  - [x] 12.4 Test: `createScoreEvent` sets supersedesEventID to nil
  - [x] 12.5 Test: `createScoreEvent` returns the created ScoreEvent
  - [x] 12.6 Test: multiple events for same {round, hole, player} all persist (no uniqueness constraint)

- [x] Task 13: Write `ScorecardViewModelTests` in HyzerAppTests (AC: 1, 2, 3)
  - [x] 13.1 Create `HyzerAppTests/ScorecardViewModelTests.swift`
  - [x] 13.2 Test: `enterScore` creates ScoreEvent via ScoringService
  - [x] 13.3 Test: `enterScore` passes correct roundID and reportedByPlayerID from init
  - [x] 13.4 Test: `enterScore` with different playerIDs creates separate events (distributed scoring)

## Dev Notes

### ScoreEvent Model Design

The `ScoreEvent` model follows the same patterns as `Round` (flat foreign keys, CloudKit-compatible defaults, no `@Relationship`):

```swift
@Model
public final class ScoreEvent {
    public var id: UUID = UUID()
    public var roundID: UUID = UUID()           // flat FK to Round
    public var holeNumber: Int = 1              // 1-based hole number
    public var playerID: String = ""            // Player UUID string OR "guest:{name}" for guests
    public var strokeCount: Int = 0             // The score (1-10)
    public var supersedesEventID: UUID?         // nil for initial scores; points to replaced event for corrections (Story 3.3)
    public var reportedByPlayerID: UUID = UUID() // Who entered this score (the device owner)
    public var deviceID: String = ""            // Originating device ID (for conflict detection, Epic 4)
    public var createdAt: Date = Date()

    public init(roundID: UUID, holeNumber: Int, playerID: String, strokeCount: Int,
                reportedByPlayerID: UUID, deviceID: String) {
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.playerID = playerID
        self.strokeCount = strokeCount
        self.reportedByPlayerID = reportedByPlayerID
        self.deviceID = deviceID
    }
}
```

**Why `playerID: String` not `UUID`:** Registered players use their `Player.id.uuidString`. Guest players use `"guest:{name}"` (e.g., `"guest:Dave"`). This matches `Round.playerIDs: [String]` format. Guest name uniqueness within a round is guaranteed by Story 3.1's duplicate guard.

**Why `supersedesEventID` is included now but always nil:** The field must exist from day one for CloudKit schema evolution (add-only, never remove fields). Story 3.3 adds the correction flow that uses it. For Story 3.2, all ScoreEvents have `supersedesEventID = nil`.

**Append-only invariant (NFR19):** ScoreEvent has NO public methods to update or delete. No `update()`, no `delete()`, no mutating methods. The model is immutable after creation. This is enforced at the type level.

**Current score resolution (Amendment A7):** The "current score" for a {player, hole} is the ScoreEvent that no other ScoreEvent points to via `supersedesEventID` (the leaf node). For Story 3.2 with no corrections, every ScoreEvent is a leaf node. But the View's score display logic should still use this pattern so it works correctly when Story 3.3 adds corrections:

```swift
// Find current score for a player on a hole
func currentScore(for playerID: String, hole: Int, in events: [ScoreEvent]) -> ScoreEvent? {
    let holeEvents = events.filter { $0.playerID == playerID && $0.holeNumber == hole }
    let supersededIDs = Set(holeEvents.compactMap(\.supersedesEventID))
    return holeEvents.first { !supersededIDs.contains($0.id) }
}
```

### ScoringService Design

ScoringService is a simple domain service in HyzerKit. For Story 3.2, it only needs `modelContext` and `deviceID`:

```swift
public final class ScoringService {
    private let modelContext: ModelContext
    private let deviceID: String

    public init(modelContext: ModelContext, deviceID: String) {
        self.modelContext = modelContext
        self.deviceID = deviceID
    }

    public func createScoreEvent(
        roundID: UUID, holeNumber: Int, playerID: String,
        strokeCount: Int, reportedByPlayerID: UUID
    ) throws -> ScoreEvent {
        let event = ScoreEvent(
            roundID: roundID, holeNumber: holeNumber,
            playerID: playerID, strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID, deviceID: deviceID
        )
        modelContext.insert(event)
        try modelContext.save()
        return event
    }
}
```

**Future expansion (Stories 3.4, 3.5):** ScoringService will later add `standingsEngine` and `lifecycleManager` dependencies. For Story 3.2, keep it simple -- just `modelContext` and `deviceID`. The dev agents for 3.4/3.5 will expand the constructor.

**NOT an actor:** ScoringService writes to the main ModelContext and is constructed by `@MainActor AppServices`. It does not need actor isolation -- all callers are already `@MainActor` (ViewModels). Keep it a plain class.

### Guest Player Scoring Convention

Guests have no `Player` record or UUID. Convention for `ScoreEvent.playerID`:
- **Registered players:** `player.id.uuidString` (matches `Round.playerIDs` entries)
- **Guest players:** `"guest:{name}"` (matches `Round.guestNames` entries with prefix)

The View must build a unified player row list combining:
1. Registered players from `@Query` filtered by `round.playerIDs`
2. Guest entries from `round.guestNames` mapped to `"guest:{name}"`

Example helper on the View or a local struct:

```swift
struct ScorecardPlayer: Identifiable {
    let id: String          // Player UUID string or "guest:{name}"
    let displayName: String // Player.displayName or guest name
    let isGuest: Bool
}
```

### View Architecture

**ScorecardContainerView:**
```swift
struct ScorecardContainerView: View {
    let round: Round

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Query private var allScoreEvents: [ScoreEvent]
    @Query(sort: \Hole.number) private var allHoles: [Hole]
    @Query private var allPlayers: [Player]
    @State private var currentHole: Int = 1
    @State private var viewModel: ScorecardViewModel?

    // Client-side filtering (small dataset: max ~108 events per round)
    private var roundScoreEvents: [ScoreEvent] {
        allScoreEvents.filter { $0.roundID == round.id }
    }
    private var courseHoles: [Hole] {
        allHoles.filter { $0.courseID == round.courseID }
    }

    var body: some View {
        TabView(selection: $currentHole) {
            ForEach(1...round.holeCount, id: \.self) { holeNumber in
                HoleCardView(...)
                    .tag(holeNumber)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .onAppear { initializeViewModel() }
    }
}
```

**Key pattern:** `@Query` returns all entities; client-side filter selects relevant ones. This is the correct approach for Story 3.2's data volume (max 6 players x 18 holes = 108 events, max 18 holes, ~6 players). No dynamic `#Predicate` needed.

**`@Query` in View, not ViewModel** (architecture rule). The View queries data and passes it to `HoleCardView`. The ViewModel handles the `enterScore` action.

**HoleCardView structure:**
```swift
struct HoleCardView: View {
    let holeNumber: Int
    let par: Int
    let courseName: String
    let players: [ScorecardPlayer]
    let scores: [ScoreEvent]  // filtered for this hole
    let onScore: (String, Int) -> Void  // (playerID, strokeCount)

    @State private var expandedPlayerID: String?  // which player's picker is open

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.md) {
                // Header: "Hole 3 · Par 4"
                // Player rows
                ForEach(players) { player in
                    PlayerScoreRow(...)
                }
            }
        }
    }
}
```

**ScoreInputView (inline picker):**
- Horizontal row of numbers 1-10
- Par value visually anchored/highlighted (FR18)
- Tap a number to select -- collapses picker, fires haptic, saves score
- Touch targets: 52pt (`SpacingTokens.scoringTouchTarget`) for primary scoring controls (NFR14)
- Use `UIImpactFeedbackGenerator(.light).impactOccurred()` for haptic tick

### ModelContainer Registration

Add `ScoreEvent.self` to the domain store in `HyzerApp.swift`:

```swift
let domainConfig = ModelConfiguration(
    "DomainStore",
    schema: Schema([Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self])
)
return try ModelContainer(
    for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
    configurations: domainConfig, operationalConfig
)
```

### AppServices Registration

Add ScoringService to `AppServices`:

```swift
@MainActor @Observable
final class AppServices {
    // ... existing properties ...
    let scoringService: ScoringService

    init(modelContainer: ModelContainer) throws {
        // ... existing init ...
        let mainContext = modelContainer.mainContext
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.scoringService = ScoringService(modelContext: mainContext, deviceID: deviceID)
    }
}
```

### Form & Card Styling

Follow existing dark-theme styling from Story 2.1/2.2 and Story 3.1:
- `.background(Color.backgroundPrimary)` for dark theme
- Design tokens for all colors, fonts, spacing
- `.tint(Color.accentPrimary)` for interactive elements
- Hole card background: use card styling (slight elevation/contrast against background)
- Score numbers: use `TypographyTokens.score` (SF Mono) for score display
- Hole number: `TypographyTokens.h2`
- Par value: `TypographyTokens.caption`
- Player name: `TypographyTokens.h3`

**Score-state color coding:**
- Unscored: dash in `Color.textSecondary`
- Birdie or better (under par): `Color.accentSuccess` or green-tinted token
- Par: `Color.textPrimary`
- Bogey or worse (over par): `Color.accentWarning` or appropriate token
- Check existing `ColorTokens` for available colors; add semantic score colors if not present

**Important:** Score state must be conveyed by color AND numeric context (NFR18 -- not color alone). The stroke count number is always visible.

### Concurrency

- `ScorecardViewModel` is `@MainActor @Observable` -- consistent with all VMs
- `ScoringService.createScoreEvent()` is synchronous `throws` (SwiftData write from main context)
- No `DispatchQueue`, no `Task.detached`

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros, `#expect`) -- NOT XCTest.

**ScoreEvent model tests in `HyzerKitTests/`** -- model is in HyzerKit. Use `ModelConfiguration(isStoredInMemoryOnly: true)`.

**ScoringService tests in `HyzerKitTests/`** -- service is in HyzerKit. Use in-memory ModelContainer.

**ViewModel tests in `HyzerAppTests/`** -- follow Story 3.1 test patterns.

**Test setup pattern:**
```swift
@Test("createScoreEvent persists event with correct properties")
func test_createScoreEvent_persistsCorrectly() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
        configurations: config
    )
    let context = ModelContext(container)

    let service = ScoringService(modelContext: context, deviceID: "test-device-1")
    let reporterID = UUID()

    let event = try service.createScoreEvent(
        roundID: UUID(), holeNumber: 3, playerID: "player-uuid-string",
        strokeCount: 4, reportedByPlayerID: reporterID
    )

    let fetched = try context.fetch(FetchDescriptor<ScoreEvent>())
    #expect(fetched.count == 1)
    #expect(fetched[0].holeNumber == 3)
    #expect(fetched[0].strokeCount == 4)
    #expect(fetched[0].supersedesEventID == nil)
    #expect(fetched[0].deviceID == "test-device-1")
}
```

**IMPORTANT:** Include `ScoreEvent.self` in the ModelContainer schema for ALL tests that use SwiftData. Failing to register the model causes runtime crashes.

### Current File State

| File | Current State | Story 3.2 Action |
|------|--------------|-------------------|
| `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift` | Does not exist | **Create** -- SwiftData `@Model` |
| `HyzerKit/Sources/HyzerKit/Domain/ScoringService.swift` | Does not exist | **Create** -- score creation service |
| `HyzerApp/App/HyzerApp.swift` | 4 models in container | **Modify** -- add `ScoreEvent.self` to ModelContainer |
| `HyzerApp/App/AppServices.swift` | No ScoringService | **Modify** -- add `scoringService` property |
| `HyzerApp/ViewModels/ScorecardViewModel.swift` | Does not exist | **Create** -- scoring ViewModel |
| `HyzerApp/Views/Scoring/ScorecardContainerView.swift` | Does not exist | **Create** -- card stack container |
| `HyzerApp/Views/Scoring/HoleCardView.swift` | Does not exist | **Create** -- single hole card |
| `HyzerApp/Views/Scoring/ScoreInputView.swift` | Does not exist | **Create** -- inline score picker |
| `HyzerApp/Views/HomeView.swift` | ActiveRoundView placeholder | **Modify** -- replace with ScorecardContainerView |
| `HyzerKit/Tests/HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift` | Does not exist | **Create** -- test fixture |
| `HyzerKit/Tests/HyzerKitTests/Domain/ScoreEventModelTests.swift` | Does not exist | **Create** -- model tests |
| `HyzerKit/Tests/HyzerKitTests/Domain/ScoringServiceTests.swift` | Does not exist | **Create** -- service tests |
| `HyzerAppTests/ScorecardViewModelTests.swift` | Does not exist | **Create** -- ViewModel tests |

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Add `update()` or `delete()` methods on ScoreEvent | ScoreEvent is append-only (NFR19). No mutation API. |
| Use `@Attribute(.unique)` on ScoreEvent | CloudKit incompatible |
| Use `@Relationship` between ScoreEvent and Round/Player | Use flat `roundID`/`playerID` (Amendment A8 pattern) |
| Store playerID as UUID | Use String for both registered players and guests |
| Use timestamps for "current score" resolution | Use supersession chain / leaf node (Amendment A7) |
| Put `@Query` in the ViewModel | `@Query` must live in the View (architecture rule) |
| Use `try?` for save operations | Always `try` and propagate or log errors |
| Add StandingsEngine or leaderboard logic | Standings are Story 3.4. This story is scoring only. |
| Implement score corrections / superseding flow | Corrections are Story 3.3. Set `supersedesEventID = nil`. |
| Implement auto-advance to next hole | Auto-advance is Story 3.3. Swipe navigation comes free with TabView. |
| Use `print()` for debugging | Use `Logger(subsystem:category:)` or no logging |
| Hardcode colors, fonts, or spacing | Use `ColorTokens`, `TypographyTokens`, `SpacingTokens` |
| Add CloudKit sync logic | Sync is Epic 4. This story is local-only. |
| Make ScoringService an actor | It uses the main ModelContext; all callers are @MainActor. Plain class. |
| Use dynamic `#Predicate` with captured variables | Client-side filter on @Query results (small dataset) |
| Forget to register ScoreEvent in ModelContainer | Will cause runtime crash. Add to both Schema and ModelContainer. |

### Previous Story Intelligence (Story 3.1)

Key learnings from Story 3.1 that directly apply:

1. **`try context.save()` -- not `try?`:** All save calls must throw. Never swallow errors.
2. **`precondition` guards:** Use preconditions for invariant violations (e.g., strokeCount out of range).
3. **Error handling with `.alert`:** View shows error alert on save failure. Apply same pattern for score entry errors.
4. **`#Predicate` needs `import Foundation`:** Import Foundation in any file using predicates.
5. **Captured locals for predicates:** `#Predicate { $0.roundID == round.id }` fails; use `let roundID = round.id` first.
6. **In-memory ModelContainer for tests:** All tests use `ModelConfiguration(isStoredInMemoryOnly: true)` with explicit `ModelContainer(for: ..., configurations: config)`.
7. **All ViewModels are `@MainActor @Observable`** -- no exceptions.
8. **`xcodegen generate` after adding new directories:** Run `xcodegen generate` after creating `HyzerApp/Views/Scoring/` directory.
9. **`Player.fixture()` NOT available in HyzerAppTests:** Fixture lives in HyzerKitTests. Use `Player(displayName:)` directly in HyzerAppTests.
10. **`TypographyTokens` names:** Use `.h2`, `.h3`, `.caption`, `.score` -- NOT `.title`. Check actual token names in `HyzerKit/Sources/HyzerKit/Design/TypographyTokens.swift`.
11. **iOS 26 + SwiftData + AppGroup simulator issue:** Pre-existing incompatibility causes `loadIssueModelContainer` crash on iOS 26 simulator. HyzerKit unit tests pass; simulator-dependent tests may fail due to this environment issue. Not a code issue.

### Project Structure Notes

- New directory: `HyzerApp/Views/Scoring/` (3 new view files)
- New files in `HyzerKit/Sources/HyzerKit/Models/` (ScoreEvent.swift)
- New files in `HyzerKit/Sources/HyzerKit/Domain/` (ScoringService.swift)
- New files in `HyzerApp/ViewModels/` (ScorecardViewModel.swift)
- New test files in both `HyzerKitTests/` and `HyzerAppTests/`
- `project.yml` auto-discovers new files -- no changes needed
- HyzerKit `Package.swift` auto-discovers new sources -- no changes needed
- **Run `xcodegen generate`** after creating the new `Scoring/` directory

### Scope Boundaries

**IN scope for Story 3.2:**
- ScoreEvent model with all fields (including supersedesEventID, always nil for now)
- ScoringService with `createScoreEvent()` for initial scores
- ScorecardContainerView with TabView(.page) horizontal card stack
- HoleCardView with player rows showing scores or dashes
- ScoreInputView inline picker (1-10, par-anchored)
- ScorecardViewModel managing enterScore action
- Register ScoreEvent in ModelContainer and ScoringService in AppServices
- Replace ActiveRoundView placeholder
- Haptic feedback on score entry
- Guest player scoring
- FR17, FR18, FR35, FR36, NFR3, NFR14, NFR18

**OUT of scope (future stories):**
- Score corrections / tap scored row to reopen picker (Story 3.3 -- FR19, FR37)
- Auto-advance to next hole when all scored (Story 3.3 -- FR20)
- StandingsEngine / standings computation (Story 3.4)
- Floating leaderboard pill (Story 3.4)
- Running +/- par on player rows (Story 3.4 -- depends on StandingsEngine)
- RoundLifecycleManager / auto-completion detection (Story 3.5)
- Round completion / summary (Story 3.6)
- Voice input (Epic 5)
- CloudKit sync (Epic 4)
- Attribution text "Scored by [name]" (deferred to when sync makes it meaningful)

### References

- [Source: _bmad-output/planning-artifacts/prd.md -- FR17: Tap player row to score 1-10, defaulting to par]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR18: Score picker defaults to par for current hole]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR35: Any participant can score for any other]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR36: Each score creates immutable ScoreEvent]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR3: Tap score entry <100ms]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR14: 44pt+ touch targets, 48pt+ scoring]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR18: Score state by color AND numeric context]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR19: Event-sourced, no ScoreEvent mutated or deleted]
- [Source: _bmad-output/planning-artifacts/architecture.md -- ScoreEvent Data Model Fields: supersedesEventID, reportedByPlayerID, deviceID]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A7: Current score uses supersession chain, not timestamps]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A8: Flat foreign keys, no @Relationship]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A9: AppServices constructor dependency graph]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Score Entry Flow (Tap): HoleCardView -> ScorecardViewModel -> ScoringService -> SwiftData]
- [Source: _bmad-output/planning-artifacts/architecture.md -- File Placement Rules: ScoreEvent in HyzerKit/Models/, ScoringService in HyzerKit/Domain/]
- [Source: _bmad-output/planning-artifacts/architecture.md -- SwiftData Model Constraints: CloudKit compatibility]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Type-Level Invariant Enforcement: ScoreEvent no update/delete API]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Card Stack + Floating Pill: TabView(.page) horizontal paging]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Hole Scoring Card anatomy and states]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Tap Scoring Flow: inline picker, par-anchored, haptic confirmation]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Score picker anchored at par, one tap above/below for bogey/birdie]
- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 3 Story 3.2 scope and acceptance criteria]
- [Source: _bmad-output/implementation-artifacts/3-1-round-creation-and-player-setup.md -- Previous story patterns and learnings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Created `ScoreEvent` SwiftData model with append-only invariant (no public update/delete API), CloudKit-compatible (all properties have defaults, no @Attribute(.unique), no @Relationship, playerID as String for guest support).
- Created `ScoringService` — plain class (not actor) using main ModelContext; `createScoreEvent` always throws on failure (never try?). supersedesEventID set to nil for all Story 3.2 events.
- Registered `ScoreEvent.self` in domain ModelContainer schema in `HyzerApp.swift`.
- Added `scoringService: ScoringService` to `AppServices` composition root; device ID sourced from `UIDevice.current.identifierForVendor`.
- `ScorecardViewModel` is `@MainActor @Observable` with `enterScore` throwing method and `saveError` for alert binding.
- `ScorecardContainerView` uses `TabView(.page)` for horizontal hole card stack; client-side filters for ScoreEvents and Holes (max ~108 events per round); queries Courses for course name display; initializes ViewModel on appear.
- `ScorecardPlayer` struct unifies registered players (Player.id.uuidString) and guests ("guest:{name}") into a single identifiable list.
- `HoleCardView` implements Amendment A7 current-score resolution (leaf node in supersession chain); score-state color coding via ColorTokens (scoreUnderPar/scoreAtPar/scoreOverPar/scoreWayOver); animated inline picker expansion; full accessibility labels.
- `ScoreInputView` shows 1–10 scores with par visually anchored (accent color background); 52pt touch targets per NFR14; UIImpactFeedbackGenerator(.light) haptic on selection.
- Removed `ActiveRoundView` placeholder and its unused helper methods/queries from `HomeView`.
- HyzerKit tests (35/35 pass). iOS simulator tests blocked by pre-existing iOS 26 + SwiftData + AppGroup incompatibility (same as all prior stories — not a code issue).
- SwiftLint: no errors or warnings.

### Senior Developer Review (AI)

**Reviewer:** claude-opus-4-6 | **Date:** 2026-02-27

**Result: PASSED** (7 findings, all resolved)

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| H1 | HIGH | Scored rows tappable — allows re-scoring without supersession chain (Story 3.3 scope leak) | Added `guard score == nil` in `onTapGesture` to disable tap on scored rows |
| H2 | HIGH | ScoreInputView 10×52pt buttons overflow on all iPhones (NFR14 violation) | Wrapped HStack in horizontal `ScrollView` with `defaultScrollAnchor` centered on par |
| M1 | MEDIUM | Alert binding uses `.constant()` — non-writable, may not dismiss | Replaced with computed `Binding` via `showingErrorBinding` property |
| M2 | MEDIUM | Hardcoded `.spring()` animation instead of `AnimationTokens`/`AnimationCoordinator` | Switched to `AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion:)` with `@Environment(\.accessibilityReduceMotion)` |
| M3 | MEDIUM | Missing `precondition` for strokeCount range (1-10) in `ScoringService` | Added `precondition((1...10).contains(strokeCount))` and `precondition(holeNumber >= 1)` |
| L1 | LOW | `UIImpactFeedbackGenerator` instantiated per tap | Moved to stored property with `.onAppear { haptic.prepare() }` |
| L2 | LOW | Typo: `createsSeperateEvents` → `createsSeparateEvents` | Fixed method name |

### File List

- `HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift` — created
- `HyzerKit/Sources/HyzerKit/Domain/ScoringService.swift` — created (review: added preconditions)
- `HyzerApp/App/HyzerApp.swift` — modified (added ScoreEvent to ModelContainer)
- `HyzerApp/App/AppServices.swift` — modified (added scoringService, UIKit import)
- `HyzerApp/ViewModels/ScorecardViewModel.swift` — created
- `HyzerApp/Views/Scoring/ScorecardContainerView.swift` — created (review: fixed alert binding)
- `HyzerApp/Views/Scoring/HoleCardView.swift` — created (review: disabled scored-row tap, AnimationTokens, reduce-motion)
- `HyzerApp/Views/Scoring/ScoreInputView.swift` — created (review: ScrollView wrapper, haptic prepare, scroll anchor)
- `HyzerApp/Views/HomeView.swift` — modified (replaced ActiveRoundView with ScorecardContainerView, removed unused code)
- `HyzerKit/Tests/HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift` — created
- `HyzerKit/Tests/HyzerKitTests/Domain/ScoreEventModelTests.swift` — created
- `HyzerKit/Tests/HyzerKitTests/Domain/ScoringServiceTests.swift` — created
- `HyzerAppTests/ScorecardViewModelTests.swift` — created (review: fixed typo)
