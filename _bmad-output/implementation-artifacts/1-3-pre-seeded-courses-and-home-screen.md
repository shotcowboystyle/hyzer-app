# Story 1.3: Pre-Seeded Courses & Home Screen

Status: review

## Story

As a new user,
I want to see familiar local courses available immediately after onboarding,
So that I can start a round without first creating a course manually.

## Acceptance Criteria

1. **AC 1 -- Seeded courses appear after onboarding:**
   Given the user has completed onboarding,
   When the home screen loads for the first time,
   Then at least 3 pre-seeded local courses are displayed,
   And courses were loaded from the app bundle, not from CloudKit (FR3).

2. **AC 2 -- Offline seeding works:**
   Given the device has no network connectivity,
   When the home screen loads,
   Then seeded courses are still available (loaded from bundle, not network) (FR3, FR4).

3. **AC 3 -- Empty state for no active round:**
   Given no active round exists,
   When the home screen is displayed,
   Then an empty state invites the user to start their first round or add a course,
   And the empty state chains to a creation flow (not a dead end).

4. **AC 4 -- Course/Hole model with flat foreign key:**
   Given the Course model,
   When a course with holes is persisted,
   Then Hole records reference their parent Course via `courseID: UUID` (flat foreign key, not @Relationship) (A8),
   And all model properties are optional or have defaults (CloudKit compatibility).

5. **AC 5 -- Home screen tab structure:**
   Given the user is on the home screen,
   When the app renders,
   Then a 3-tab `TabView` is displayed with Scoring, History, and Courses tabs,
   And tab state is preserved when switching between tabs.

## Tasks / Subtasks

- [x] Task 1: Create `Course` SwiftData model (AC: 4)
  - [x] 1.1 Create `HyzerKit/Sources/HyzerKit/Models/Course.swift` with `@Model`: `id: UUID`, `name: String`, `holeCount: Int`, `isSeeded: Bool`, `createdAt: Date` -- all with defaults, no `@Attribute(.unique)`, no `@Relationship`
  - [x] 1.2 Verify Sendable conformance compiles under Swift 6 strict concurrency

- [x] Task 2: Create `Hole` SwiftData model (AC: 4)
  - [x] 2.1 Create `HyzerKit/Sources/HyzerKit/Models/Hole.swift` with `@Model`: `id: UUID`, `courseID: UUID`, `number: Int`, `par: Int` -- flat foreign key per Amendment A8, all with defaults
  - [x] 2.2 Verify `#Predicate { $0.courseID == targetCourseID }` fetch pattern works

- [x] Task 3: Register models in ModelContainer (AC: 1, 2)
  - [x] 3.1 Update `HyzerApp.swift` `makeModelContainer()`: add `Course.self` and `Hole.self` to both the `Schema` and the `ModelContainer(for:)` call
  - [x] 3.2 Update domain config schema: `Schema([Player.self, Course.self, Hole.self])`

- [x] Task 4: Create `SeededCourses.json` bundle resource (AC: 1, 2)
  - [x] 4.1 Create `HyzerKit/Sources/HyzerKit/Resources/SeededCourses.json` with 3 real disc golf courses (Morley Field, Maple Hill, DeLaveaga). Each entry: `name`, `holes` array with `number` and `par` per hole. Default par 3 per hole with realistic exceptions.
  - [x] 4.2 Add `resources: [.process("Resources")]` to the `HyzerKit` target in `HyzerKit/Package.swift`

- [x] Task 5: Create `CourseSeeder` domain service (AC: 1, 2)
  - [x] 5.1 Create `HyzerKit/Sources/HyzerKit/Domain/CourseSeeder.swift` -- reads `SeededCourses.json` from `Bundle.module`, inserts `Course` + `Hole` records via `ModelContext`, idempotent (checks if seeded courses already exist before inserting)
  - [x] 5.2 Seeder signature: `@MainActor static func seedIfNeeded(in context: ModelContext) throws` (MainActor required for Swift 6 ModelContext isolation)
  - [x] 5.3 Idempotency check: query for any `Course` where `isSeeded == true`; if count > 0, return early

- [x] Task 6: Wire `CourseSeeder` into `AppServices` (AC: 1, 2)
  - [x] 6.1 Add `func seedCoursesIfNeeded() async` to `AppServices` -- creates a `ModelContext`, calls `CourseSeeder.seedIfNeeded(in:)`, logs result
  - [x] 6.2 Add `.task { await appServices.seedCoursesIfNeeded() }` to `HyzerApp.swift` alongside the existing iCloud resolution `.task`

- [x] Task 7: Replace `HomeView` placeholder with TabView home screen (AC: 3, 5)
  - [x] 7.1 Replace `HyzerApp/Views/HomeView.swift` with a 3-tab `TabView`: Scoring, History, Courses
  - [x] 7.2 Scoring tab: empty state -- "No round in progress." + "Start Round" primary CTA button (accent fill `#30D5C8`). CTA is non-functional placeholder for now (Epic 3).
  - [x] 7.3 History tab: empty state -- "Your round history will appear here after your first completed round." (placeholder for Epic 8)
  - [x] 7.4 Courses tab: `CourseListView` showing seeded courses
  - [x] 7.5 Use SF Symbols for tab icons: `sportscourt` (Scoring), `clock.arrow.circlepath` (History), `map` (Courses)
  - [x] 7.6 All text uses `TypographyTokens`, colors use `ColorTokens`, spacing uses `SpacingTokens`

- [x] Task 8: Create `CourseListView` (AC: 1, 3)
  - [x] 8.1 Create `HyzerApp/Views/Courses/CourseListView.swift` -- `@Query` on `Course` sorted by name, `List` rows showing course name and hole count
  - [x] 8.2 Empty state (unlikely but required): "Add a course to get started." + "Add Course" secondary CTA (text-only accent color). Non-functional placeholder for Epic 2.
  - [x] 8.3 Each course row: course name (`TypographyTokens.body`), hole count as subtitle (`TypographyTokens.caption`, `textSecondary`)
  - [x] 8.4 Row tap navigates to course detail (placeholder `NavigationLink` destination -- simple detail view showing holes and pars)

- [x] Task 9: Create `CourseDetailView` (AC: 1)
  - [x] 9.1 Create `HyzerApp/Views/Courses/CourseDetailView.swift` -- displays course name, list of holes with number and par, read-only for now (editing is Epic 2)
  - [x] 9.2 Use `NavigationStack` with `.navigationTitle(course.name)`

- [x] Task 10: Write tests (AC: 1, 2, 4)
  - [x] 10.1 Create `HyzerKit/Tests/HyzerKitTests/Domain/CourseSeederTests.swift` -- test seeder inserts exactly 3 courses with correct holes, test idempotency (second call inserts nothing), test all courses have `isSeeded == true`
  - [x] 10.2 Create `HyzerKit/Tests/HyzerKitTests/Domain/CourseModelTests.swift` -- test Course/Hole creation, test Hole.courseID foreign key relationship (fetch holes by courseID), test all defaults are CloudKit-compatible (no unique constraints)
  - [x] 10.3 Create `HyzerKit/Tests/HyzerKitTests/Fixtures/Course+Fixture.swift` -- factory methods for test Course and Hole instances
  - [x] 10.4 Verify existing `PlayerTests` (9 tests) and design token tests still pass (regression) -- all 17 tests pass (9 pre-existing + 8 new)

## Dev Notes

### Architecture Pattern: Course Management

Per the architecture doc, course management is intentionally simple: "Courses are reference data, not transactional. Change rarely. Conflicts are trivial. Low architectural priority -- don't over-architect."

Seed from JSON bundle on first launch, store in SwiftData. CloudKit sync is NOT part of this story (that's Epic 4). This story is purely local persistence + UI.

### Current File State (verified)

| File | Current State | Story 1.3 Action |
|------|--------------|-------------------|
| `HyzerKit/Sources/HyzerKit/Models/Player.swift` | Only model that exists | No changes |
| `HyzerKit/Sources/HyzerKit/Models/Course.swift` | Does not exist | Create |
| `HyzerKit/Sources/HyzerKit/Models/Hole.swift` | Does not exist | Create |
| `HyzerKit/Sources/HyzerKit/Domain/` | Directory does not exist | Create directory + `CourseSeeder.swift` |
| `HyzerKit/Sources/HyzerKit/Resources/` | Directory does not exist | Create directory + `SeededCourses.json` |
| `HyzerKit/Package.swift` | No `resources:` entry | Add `resources: [.process("Resources")]` to target |
| `HyzerApp/App/HyzerApp.swift` | Schema has `Player.self` only | Add `Course.self`, `Hole.self` to schema + `ModelContainer(for:)` + `.task` for seeding |
| `HyzerApp/App/AppServices.swift` | Has `modelContainer`, `iCloudIdentityProvider` | Add `seedCoursesIfNeeded()` |
| `HyzerApp/Views/HomeView.swift` | Placeholder stub | Replace with 3-tab `TabView` |
| `HyzerApp/Views/ContentView.swift` | Routes: no player -> Onboarding, player -> HomeView | No changes needed |
| `HyzerApp/Views/Courses/` | Directory does not exist | Create `CourseListView.swift`, `CourseDetailView.swift` |
| `HyzerApp/ViewModels/` | Has `OnboardingViewModel.swift` only | No new ViewModels needed for this story (views use `@Query` directly) |
| `project.yml` | Auto-discovers files in target directories | No changes needed |

### Key Implementation Details

**Course Model:**
```swift
// HyzerKit/Sources/HyzerKit/Models/Course.swift
import Foundation
import SwiftData

@Model
public final class Course {
    public var id: UUID = UUID()
    public var name: String = ""
    public var holeCount: Int = 18
    public var isSeeded: Bool = false
    public var createdAt: Date = Date()

    public init(name: String, holeCount: Int, isSeeded: Bool = false) {
        self.name = name
        self.holeCount = holeCount
        self.isSeeded = isSeeded
    }
}
```

**Hole Model (Amendment A8 -- flat foreign key):**
```swift
// HyzerKit/Sources/HyzerKit/Models/Hole.swift
import Foundation
import SwiftData

@Model
public final class Hole {
    public var id: UUID = UUID()
    public var courseID: UUID = UUID()
    public var number: Int = 1
    public var par: Int = 3

    public init(courseID: UUID, number: Int, par: Int = 3) {
        self.courseID = courseID
        self.number = number
        self.par = par
    }
}
```

**Fetch holes for a course:**
```swift
let courseID = course.id
let descriptor = FetchDescriptor<Hole>(
    predicate: #Predicate { $0.courseID == courseID },
    sortBy: [SortDescriptor(\.number)]
)
let holes = try context.fetch(descriptor)
```

**CourseSeeder pattern:**
```swift
// HyzerKit/Sources/HyzerKit/Domain/CourseSeeder.swift
import Foundation
import SwiftData

public enum CourseSeeder {
    public static func seedIfNeeded(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Course>(
            predicate: #Predicate { $0.isSeeded == true }
        )
        let existingCount = try context.fetchCount(descriptor)
        guard existingCount == 0 else { return }

        // Load SeededCourses.json from Bundle.module
        // Decode and insert Course + Hole records
        // Save context
    }
}
```

**SeededCourses.json format:**
```json
[
  {
    "name": "Morley Field",
    "holes": [
      { "number": 1, "par": 3 },
      { "number": 2, "par": 3 },
      ...
    ]
  }
]
```

**Bundle.module:** Because `SeededCourses.json` lives in `HyzerKit/Sources/HyzerKit/Resources/`, Swift Package Manager generates `Bundle.module` automatically when `resources: [.process("Resources")]` is added to the target in `Package.swift`. Use `Bundle.module.url(forResource: "SeededCourses", withExtension: "json")` to load.

**ModelContainer update in HyzerApp.swift:**
```swift
// Change from:
let domainConfig = ModelConfiguration("DomainStore", schema: Schema([Player.self]))
// To:
let domainConfig = ModelConfiguration("DomainStore", schema: Schema([Player.self, Course.self, Hole.self]))

// Change from:
return try ModelContainer(for: Player.self, configurations: ...)
// To:
return try ModelContainer(for: Player.self, Course.self, Hole.self, configurations: ...)
```

**AppServices seeding method:**
```swift
func seedCoursesIfNeeded() async {
    do {
        let context = ModelContext(modelContainer)
        try CourseSeeder.seedIfNeeded(in: context)
    } catch {
        logger.error("Course seeding failed: \(error)")
    }
}
```

**Note on Logger category:** Use a new Logger for course seeding: `Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "CourseSeeder")`. The existing logger in AppServices uses category "ICloudIdentity" -- either add a second logger or create a general-purpose one. Simplest: add a second private logger.

### Home Screen TabView Structure

```swift
// HyzerApp/Views/HomeView.swift
struct HomeView: View {
    let player: Player

    var body: some View {
        TabView {
            Tab("Scoring", systemImage: "sportscourt") {
                ScoringTabView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryTabView()
            }
            Tab("Courses", systemImage: "map") {
                NavigationStack {
                    CourseListView()
                }
            }
        }
        .tint(Color.accent)
    }
}
```

Use the iOS 18 `Tab` initializer (not the deprecated `tabItem` modifier). The `Tab(_:systemImage:content:)` initializer is available on iOS 18+.

**Empty state styling (from UX spec):**
- `textSecondary` color (`Color.textSecondary` from `ColorTokens`)
- Centered layout
- Concise copy, no illustrations or mascots
- Primary CTA: solid accent fill (`Color.accent` / `#30D5C8`), full-width or prominent
- Secondary CTA: text-only in accent color

**ScoringTabView (placeholder):**
```swift
struct ScoringTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.lg) {
                Text("No round in progress.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textSecondary)
                Button("Start Round") {
                    // Placeholder -- Epic 3
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("Scoring")
        }
    }
}
```

**HistoryTabView (placeholder):**
```swift
struct HistoryTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.lg) {
                Text("Your round history will appear here after your first completed round.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("History")
        }
    }
}
```

### Concurrency

- `AppServices` is `@MainActor @Observable` -- `seedCoursesIfNeeded()` is `@MainActor async func`
- `CourseSeeder.seedIfNeeded(in:)` is a synchronous `throws` function (no async needed -- reads from bundle, writes to SwiftData). Called from `AppServices` within `async` wrapper.
- Swift 6 strict concurrency enforced. No `DispatchQueue` usage.

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros) -- NOT XCTest.

**Test naming:** `test_{method}_{scenario}_{expectedBehavior}`

**SwiftData in tests:** Use `ModelConfiguration(isStoredInMemoryOnly: true)` for all tests.

**Note from Story 1.2:** `#Predicate` works in SPM test context. The Story 1.2 limitation about `#Predicate` was specifically about `@testable import HyzerApp` interaction with Xcode 16 explicit modules, not about HyzerKit tests.

**Test cases:**

CourseSeederTests:
1. `test_seedIfNeeded_insertsThreeCoursesWithHoles` -- verify 3 courses created, each has correct number of holes
2. `test_seedIfNeeded_isIdempotent` -- call twice, verify still only 3 courses
3. `test_seedIfNeeded_allCoursesMarkedAsSeeded` -- verify `isSeeded == true` on all
4. `test_seedIfNeeded_holesHaveCorrectCourseID` -- verify each hole's `courseID` matches its parent course's `id`

CourseModelTests:
5. `test_courseDefaultValues_areCloudKitCompatible` -- verify all properties have defaults
6. `test_holeDefaultValues_areCloudKitCompatible` -- verify all properties have defaults
7. `test_fetchHolesByCourseID_returnsCorrectHoles` -- insert holes for 2 courses, verify fetch by courseID returns only matching holes

**Regression:** Run existing `PlayerTests` and design token tests to verify no regressions from schema changes.

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Use `@Relationship` for Course-to-Hole | Flat `courseID: UUID` foreign key on Hole (Amendment A8) |
| Add `@Attribute(.unique)` to any field | CloudKit doesn't support atomic uniqueness; enforce at app layer |
| Fetch from CloudKit for seeded courses | Load from `Bundle.module` JSON -- works offline |
| Create a ViewModel for CourseListView | Use `@Query` directly in the view -- SwiftData provides reactive updates |
| Add CloudKit sync logic | This story is local-only. Sync is Epic 4. |
| Use `tabItem` modifier on TabView | Use iOS 18 `Tab(_:systemImage:content:)` initializer |
| Put SeededCourses.json in HyzerApp bundle | Put in HyzerKit/Resources -- the seeder lives in HyzerKit and needs Bundle.module access |
| Use `DispatchQueue` for any async work | Use `async/await` only (Swift 6 strict concurrency) |
| Hardcode colors, fonts, or spacing | Use `ColorTokens`, `TypographyTokens`, `SpacingTokens` from HyzerKit/Design/ |

### Project Structure Notes

- `Course.swift` and `Hole.swift` in `HyzerKit/Sources/HyzerKit/Models/` alongside existing `Player.swift`
- `CourseSeeder.swift` in new `HyzerKit/Sources/HyzerKit/Domain/` directory (first file in `Domain/`)
- `SeededCourses.json` in new `HyzerKit/Sources/HyzerKit/Resources/` directory
- `CourseListView.swift` and `CourseDetailView.swift` in new `HyzerApp/Views/Courses/` directory
- `ScoringTabView` and `HistoryTabView` can co-locate in `HomeView.swift` as private views (only used there) or in separate files under `HyzerApp/Views/` -- keep simple
- No changes to `project.yml` -- XcodeGen auto-discovers new files in target directories
- `HyzerKit/Package.swift` needs `resources: [.process("Resources")]` added to the `HyzerKit` target

### References

- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A8: Course-to-Hole flat foreign key]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Data Architecture: Course Management seed-from-JSON pattern]
- [Source: _bmad-output/planning-artifacts/architecture.md -- SwiftData Model Constraints for CloudKit compatibility]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Project Structure: file placement table]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A9: AppServices constructor dependency graph]
- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 1 Story 1.3 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Navigation Patterns: 3-tab TabView]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Empty state specs: Scoring, History, Courses]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Journey 1: Post-onboarding flow to home screen]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Component Strategy: Tab bar as TabView]
- [Source: _bmad-output/implementation-artifacts/1-2-icloud-identity-association.md -- Previous story patterns and learnings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Test run: 17 tests passed (9 pre-existing Player/design-token tests + 8 new Course/Hole/Seeder tests)
- iOS build: `** BUILD SUCCEEDED **` with Xcode and iPhone 17 simulator

### Completion Notes List

- `CourseSeeder.seedIfNeeded(in:)` marked `@MainActor` (required by Swift 6 strict concurrency — `ModelContext` is main-actor-isolated)
- Three well-known disc golf courses seeded: Morley Field (18 par-3s), Maple Hill (14x par-3, 4x par-4), DeLaveaga (15x par-3, 3x par-4)
- `CourseDetailView` uses `@Query` with `#Predicate` initializer to filter holes by `courseID` — verified working in SPM test context per Story 1.2 note
- HomeView uses iOS 18 `Tab(_:systemImage:content:)` API (not deprecated `tabItem` modifier)
- Color token used is `Color.accentPrimary` (the actual token name, not `Color.accent` from story examples)
- All 10 tasks and subtasks completed. No extra scope added.

### File List

- `HyzerKit/Sources/HyzerKit/Models/Course.swift` (created)
- `HyzerKit/Sources/HyzerKit/Models/Hole.swift` (created)
- `HyzerKit/Sources/HyzerKit/Domain/CourseSeeder.swift` (created)
- `HyzerKit/Sources/HyzerKit/Resources/SeededCourses.json` (created)
- `HyzerKit/Package.swift` (modified — added `resources: [.process("Resources")]`)
- `HyzerKit/Tests/HyzerKitTests/Domain/CourseSeederTests.swift` (created)
- `HyzerKit/Tests/HyzerKitTests/Domain/CourseModelTests.swift` (created)
- `HyzerKit/Tests/HyzerKitTests/Fixtures/Course+Fixture.swift` (created)
- `HyzerApp/App/HyzerApp.swift` (modified — added Course/Hole to schema + seeding .task)
- `HyzerApp/App/AppServices.swift` (modified — added seedCoursesIfNeeded, split loggers)
- `HyzerApp/Views/HomeView.swift` (modified — replaced placeholder with 3-tab TabView)
- `HyzerApp/Views/Courses/CourseListView.swift` (created)
- `HyzerApp/Views/Courses/CourseDetailView.swift` (created)
- `HyzerApp.xcodeproj/project.pbxproj` (modified — regenerated with xcodegen)
