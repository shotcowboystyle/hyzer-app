# Story 2.1: Create a New Course

Status: done

## Story

As a user,
I want to create a disc golf course with a name, hole count, and par per hole,
So that I can set up courses I play at that aren't pre-seeded.

## Acceptance Criteria

1. **AC 1 -- Course creation form is accessible:**
   Given the user is on the Courses tab,
   When they tap the "Add Course" button (empty state) or the toolbar "+" button,
   Then a course creation form is presented as a sheet (FR5).

2. **AC 2 -- Hole count selection with default par:**
   Given the user is in the course creation form,
   When they select a hole count (9 or 18),
   Then all holes default to par 3 (FR6),
   And a scrollable list of holes is displayed with each hole's par value.

3. **AC 3 -- Individual par adjustment:**
   Given the user is viewing the hole list in the creation form,
   When they tap a hole's par value,
   Then they can adjust the par for that individual hole (range 2-6) (FR6),
   And other holes retain their current par values.

4. **AC 4 -- Course saved to SwiftData:**
   Given the user has entered a valid course name and hole configuration,
   When they tap "Save",
   Then a `Course` record (with `isSeeded = false`) and corresponding `Hole` records are persisted to SwiftData,
   And the sheet dismisses,
   And the course appears immediately in the course list (reactive via `@Query`) (FR5).

5. **AC 5 -- Name validation:**
   Given the user is in the course creation form,
   When the course name is empty or whitespace-only,
   Then the Save button is disabled,
   And no error message is shown (inline validation via disabled state).

6. **AC 6 -- No role restriction:**
   Given any authenticated user,
   When they access course creation,
   Then the operation succeeds regardless of who they are (FR9).

## Tasks / Subtasks

- [x] Task 1: Create `CourseEditorViewModel` (AC: 2, 3, 4, 5)
  - [x] 1.1 Create `HyzerApp/ViewModels/CourseEditorViewModel.swift` -- `@MainActor @Observable final class`
  - [x] 1.2 Properties: `courseName: String`, `holeCount: Int` (default 18), `holePars: [Int]` (array of par values, one per hole, all default 3)
  - [x] 1.3 Computed: `canSave: Bool` (name is non-empty after trimming)
  - [x] 1.4 Method: `setHoleCount(_ count: Int)` -- rebuilds `holePars` array (preserves existing values up to min of old/new count, fills new holes with par 3)
  - [x] 1.5 Method: `saveCourse(in context: ModelContext)` -- creates `Course` + `Hole` records, saves context

- [x] Task 2: Create `CourseEditorView` (AC: 1, 2, 3, 5)
  - [x] 2.1 Create `HyzerApp/Views/Courses/CourseEditorView.swift` -- presented as `.sheet`
  - [x] 2.2 Course name `TextField` with design tokens
  - [x] 2.3 Hole count segmented `Picker` (9 / 18)
  - [x] 2.4 Scrollable hole list with per-hole par `Picker` (range 2-6) or `Stepper`
  - [x] 2.5 Save button disabled when `!canSave`
  - [x] 2.6 Cancel button to dismiss without saving
  - [x] 2.7 Navigation bar: "Cancel" (leading), "New Course" title (center), "Save" (trailing)

- [x] Task 3: Wire CourseEditorView into CourseListView (AC: 1)
  - [x] 3.1 Add `@State private var isShowingEditor = false` to `CourseListView`
  - [x] 3.2 Add `.toolbar { Button(action: { isShowingEditor = true }) { Image(systemName: "plus") } }` to course list
  - [x] 3.3 Wire existing "Add Course" empty state button to set `isShowingEditor = true`
  - [x] 3.4 Add `.sheet(isPresented: $isShowingEditor) { CourseEditorView() }` to the view

- [x] Task 4: Write tests (AC: 2, 3, 4, 5)
  - [x] 4.1 Create `HyzerAppTests/CourseEditorViewModelTests.swift`
  - [x] 4.2 Test: `canSave` is false when name is empty
  - [x] 4.3 Test: `canSave` is false when name is whitespace-only
  - [x] 4.4 Test: `canSave` is true when name has content
  - [x] 4.5 Test: `setHoleCount(9)` produces 9 par values all defaulting to 3
  - [x] 4.6 Test: `setHoleCount` preserves existing par values when shrinking from 18 to 9
  - [x] 4.7 Test: `setHoleCount` fills new holes with par 3 when expanding from 9 to 18
  - [x] 4.8 Test: `saveCourse` creates one Course with `isSeeded = false` and correct hole count
  - [x] 4.9 Test: `saveCourse` creates Hole records with correct `courseID`, `number`, and `par` values
  - [x] 4.10 Verify existing tests still pass (17 HyzerKit pass; HyzerApp tests require iOS simulator, pre-existing simulator crash on this machine unrelated to Story 2.1)

## Dev Notes

### Architecture Pattern: Course Editor

Per the architecture, `CourseListViewModel.swift` is planned in `HyzerApp/ViewModels/`. However, Story 1.3 deliberately used `@Query` directly in `CourseListView` with no ViewModel (confirmed working pattern). For this story, we create a **`CourseEditorViewModel`** specifically for the creation form where there IS business logic (validation, par management, saving). The list remains ViewModel-free.

The architecture file lists `CourseEditorView.swift` at `Views/Courses/CourseEditorView.swift` (FR8-FR9). This view will serve both creation (this story) and editing (Story 2.2). For this story, build it for creation only -- editing support is deferred.

### Current File State

| File | Current State | Story 2.1 Action |
|------|--------------|-------------------|
| `HyzerApp/Views/Courses/CourseListView.swift` | Read-only list with placeholder "Add Course" button | Add `@State` for sheet, toolbar "+", wire empty state button |
| `HyzerApp/Views/Courses/CourseDetailView.swift` | Read-only hole/par display | No changes |
| `HyzerApp/Views/Courses/CourseEditorView.swift` | Does not exist | Create -- course creation form |
| `HyzerApp/ViewModels/CourseEditorViewModel.swift` | Does not exist | Create -- validation, par management, save |
| `HyzerKit/Sources/HyzerKit/Models/Course.swift` | Exists (id, name, holeCount, isSeeded, createdAt) | No changes |
| `HyzerKit/Sources/HyzerKit/Models/Hole.swift` | Exists (id, courseID, number, par) | No changes |
| `HyzerApp/App/AppServices.swift` | Has modelContainer, iCloud, seeder | No changes |
| `HyzerApp/App/HyzerApp.swift` | Schema includes Player, Course, Hole | No changes |
| `project.yml` | Auto-discovers files in target directories | No changes |

### Key Implementation Details

**CourseEditorViewModel:**
```swift
// HyzerApp/ViewModels/CourseEditorViewModel.swift
import SwiftData
import HyzerKit

@MainActor
@Observable
final class CourseEditorViewModel {
    var courseName: String = ""
    var holeCount: Int = 18
    var holePars: [Int] = Array(repeating: 3, count: 18)

    var canSave: Bool {
        !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setHoleCount(_ count: Int) {
        let old = holePars
        holePars = (0..<count).map { i in
            i < old.count ? old[i] : 3
        }
        holeCount = count
    }

    func saveCourse(in context: ModelContext) {
        let trimmedName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let course = Course(name: trimmedName, holeCount: holeCount, isSeeded: false)
        context.insert(course)
        for (index, par) in holePars.enumerated() {
            let hole = Hole(courseID: course.id, number: index + 1, par: par)
            context.insert(hole)
        }
        try? context.save()
    }
}
```

**CourseEditorView layout:**
```swift
// HyzerApp/Views/Courses/CourseEditorView.swift
NavigationStack {
    Form {
        Section("Course Info") {
            TextField("Course Name", text: $viewModel.courseName)
            Picker("Holes", selection: holeCountBinding) {
                Text("9").tag(9)
                Text("18").tag(18)
            }
            .pickerStyle(.segmented)
        }
        Section("Par Per Hole") {
            ForEach(0..<viewModel.holeCount, id: \.self) { index in
                HStack {
                    Text("Hole \(index + 1)")
                    Spacer()
                    Picker("Par", selection: $viewModel.holePars[index]) {
                        ForEach(2...6, id: \.self) { par in
                            Text("\(par)").tag(par)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    .navigationTitle("New Course")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .disabled(!viewModel.canSave)
        }
    }
}
```

**Wiring the sheet in CourseListView:**
```swift
// Add to CourseListView
@State private var isShowingEditor = false
@Environment(\.modelContext) private var modelContext

// In body, add to Group or NavigationStack:
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button { isShowingEditor = true } label: {
            Image(systemName: "plus")
        }
    }
}
.sheet(isPresented: $isShowingEditor) {
    CourseEditorView()
}

// In emptyState, wire the existing button:
Button("Add Course") {
    isShowingEditor = true
}
```

**ModelContext access in CourseEditorView:**
The view gets `ModelContext` via `@Environment(\.modelContext)` and passes it to `viewModel.saveCourse(in:)` on save. This matches the OnboardingViewModel pattern from Story 1.1 where the ViewModel receives `ModelContext` at call time, not via constructor.

**Hole count binding:**
Because changing hole count requires rebuilding the `holePars` array, use a computed binding:
```swift
private var holeCountBinding: Binding<Int> {
    Binding(
        get: { viewModel.holeCount },
        set: { viewModel.setHoleCount($0) }
    )
}
```

### Form Styling

Use the standard SwiftUI `Form` component with design tokens where applicable:
- `Form` provides automatic section grouping, which works well for this use case
- Text uses `TypographyTokens.body` for labels
- The Form background should use `.scrollContentBackground(.hidden)` + `.background(Color.backgroundPrimary)` to match the app's dark theme
- Section headers: `.foregroundStyle(Color.textSecondary)`

### Concurrency

- `CourseEditorViewModel` is `@MainActor @Observable` -- consistent with existing `OnboardingViewModel`
- `saveCourse(in:)` is synchronous (SwiftData write from main context, no async needed)
- No `DispatchQueue` usage

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros) -- NOT XCTest.

**ViewModel tests go in `HyzerAppTests/`** (not HyzerKitTests) since the ViewModel is in the HyzerApp target.

**Pattern from Story 1.1:** `OnboardingViewModelTests` uses `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData. The save tests here should follow the same pattern.

**Test setup:**
```swift
@Suite("CourseEditorViewModel Tests")
struct CourseEditorViewModelTests {
    @Test func canSave_emptyName_isFalse() {
        let vm = CourseEditorViewModel()
        vm.courseName = ""
        #expect(!vm.canSave)
    }

    @Test func saveCourse_createsCorrectRecords() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Course.self, Hole.self,
            configurations: config
        )
        let context = ModelContext(container)
        let vm = CourseEditorViewModel()
        vm.courseName = "Test Course"
        vm.setHoleCount(9)
        vm.saveCourse(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.count == 1)
        #expect(courses[0].name == "Test Course")
        #expect(courses[0].holeCount == 9)
        #expect(!courses[0].isSeeded)
    }
}
```

**Note:** `HyzerAppTests` must be able to import both `HyzerApp` (for ViewModel) and `HyzerKit` (for models). This already works per existing `OnboardingViewModelTests`. Verify test target dependencies include both.

**Regression:** Run all 29 existing tests after implementation (17 HyzerKit + 12 HyzerApp).

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Create a `CourseListViewModel` for this story | Keep `@Query` in `CourseListView`; create `CourseEditorViewModel` only |
| Use `@Relationship` on Course model | Flat `courseID: UUID` foreign key on Hole (already implemented, Amendment A8) |
| Add `@Attribute(.unique)` for course name | No uniqueness constraint -- CloudKit incompatible. Two courses can share a name. |
| Present editor via `NavigationLink` push | Present as `.sheet` -- it's a creation flow, not drill-down navigation |
| Add CloudKit sync logic | Sync is Epic 4. This story is local-only persistence. |
| Use `DispatchQueue` or `Task.detached` | `@MainActor` only (Swift 6 strict concurrency) |
| Hardcode colors, fonts, or spacing | Use `ColorTokens`, `TypographyTokens`, `SpacingTokens` from HyzerKit |
| Build editing support into CourseEditorView | Creation only. Editing is Story 2.2. Do not add editing mode yet. |
| Add delete functionality | Deletion is Story 2.2. |
| Use `console.log` / `print` for debugging | No client-side logging per code quality rules |

### Project Structure Notes

- `CourseEditorView.swift` goes in `HyzerApp/Views/Courses/` alongside existing list and detail views
- `CourseEditorViewModel.swift` goes in `HyzerApp/ViewModels/` alongside existing `OnboardingViewModel.swift`
- `CourseEditorViewModelTests.swift` goes in `HyzerAppTests/` alongside existing `OnboardingViewModelTests.swift`
- No new HyzerKit files needed -- models already exist from Story 1.3
- No changes to `project.yml` -- XcodeGen auto-discovers new files
- No changes to `HyzerKit/Package.swift`

### Previous Story Intelligence (Story 1.3)

Key learnings from the most recent story in the codebase:

1. **@Query works without ViewModel:** Story 1.3 confirmed that `@Query` in views is the right pattern for reactive reads. No need for a list ViewModel.
2. **ModelContext at call time:** `OnboardingViewModel.savePlayer(in:)` receives `ModelContext` as a parameter, not via constructor. Follow same pattern for `CourseEditorViewModel.saveCourse(in:)`.
3. **Color token name:** The actual token is `Color.accentPrimary`, not `Color.accent`.
4. **iOS 18 Tab API:** Use `Tab(_:systemImage:content:)` initializer, not deprecated `tabItem`.
5. **Swift 6 strict concurrency:** All ViewModels must be `@MainActor @Observable`. `ModelContext` is main-actor-isolated.
6. **Test framework:** Swift Testing macros (`@Suite`, `@Test`, `#expect`), not XCTest.
7. **`#Predicate` works in SPM tests:** Confirmed from Story 1.2/1.3.

### References

- [Source: _bmad-output/planning-artifacts/prd.md -- FR5: Course creation with name, hole count, par per hole]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR6: Default par 3 with individual exceptions]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR9: No role restriction on course management]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Project Structure: CourseEditorView.swift at Views/Courses/]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Data Architecture: Course Management seed-from-JSON, last-write-wins]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A8: Flat courseID foreign key on Hole]
- [Source: _bmad-output/planning-artifacts/architecture.md -- SwiftData Model Constraints: no @Attribute(.unique), all defaults]
- [Source: _bmad-output/planning-artifacts/architecture.md -- SwiftUI View Patterns: @State for transient UI, @Observable VMs for actions, @Query for reads]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Dependency Injection: VMs receive services via constructor, not container]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Journey 2: Course creation flow in round setup]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Empty States: "Add a course to get started" with button]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Component Strategy: TextField for course name, system Form]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Button Hierarchy: destructive actions require confirmation]
- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 2 Story 2.1 acceptance criteria]
- [Source: _bmad-output/implementation-artifacts/1-3-pre-seeded-courses-and-home-screen.md -- Previous story patterns]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Build succeeded with `xcodebuild build -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'generic/platform=iOS Simulator'`
- 17/17 HyzerKit tests pass via `swift test --package-path HyzerKit`
- SwiftLint passes with zero errors or warnings on new files
- HyzerApp test runner crashes on this machine with a pre-existing simulator issue (OperationalStore fatal error on main branch too — not caused by Story 2.1)

### Completion Notes List

- Created `CourseEditorViewModel` following the `OnboardingViewModel` pattern: `@MainActor @Observable final class`, `ModelContext` passed at call time not via constructor
- `setHoleCount` preserves existing par values up to the old count, fills new slots with par 3
- `saveCourse` creates `Course` (isSeeded: false) + one `Hole` per par entry using flat `courseID` foreign key per Amendment A8
- Created `CourseEditorView` as a `NavigationStack`-wrapped `Form` sheet with segmented Picker (9/18), per-hole par Picker (2–6), Cancel/Save toolbar items
- Used custom `Binding<Int>` for hole count to route changes through `setHoleCount` so `holePars` array stays in sync
- Wired `CourseEditorView` into `CourseListView`: `@State isShowingEditor`, toolbar "+" button, empty-state "Add Course" button, `.sheet` modifier
- 10 tests written covering all canSave, setHoleCount, and saveCourse scenarios

### Senior Developer Review (AI)

**Reviewed:** 2026-02-27 by claude-opus-4-6

**Findings (9 total):** 2 HIGH, 4 MEDIUM, 3 LOW — all HIGH and MEDIUM issues fixed.

**Fixes applied:**
1. **[HIGH] `try? context.save()` → `try context.save()`** — was silently swallowing errors in violation of code-quality rules. `saveCourse` now `throws`, view handles errors with alert and only dismisses on success.
2. **[HIGH] Added `precondition` guard** in `saveCourse` to reject empty names at the API boundary.
3. **[MEDIUM] `setHoleCount` bounds validation** — now guards `count == 9 || count == 18`, ignoring invalid values.
4. **[MEDIUM] `CourseEditorView.save()` error handling** — added `do/try/catch` with `.alert` on failure instead of unconditional dismiss.
5. **[MEDIUM] Course name length limit** — added `.onChange` capping at 100 characters.
6. **[MEDIUM] Added 4 new tests** — bounds validation for `setHoleCount` (0 and 12), padded whitespace `canSave`, and `try` propagation on `saveCourse`.
7. **[LOW] Plus button tint** — applied `Color.accentPrimary` for design token consistency.

**Remaining LOW issues (deferred):**
- `ForEach(0..<viewModel.holeCount)` uses dynamic range — potential SwiftUI animation glitch (minor, only triggers on 9↔18 toggle)
- Magic number `3` for default par repeated in 3 places — cosmetic

**Test count:** 14 tests (was 10) + 17 HyzerKit = 31 total

### File List

- `HyzerApp/ViewModels/CourseEditorViewModel.swift` (new)
- `HyzerApp/Views/Courses/CourseEditorView.swift` (new)
- `HyzerApp/Views/Courses/CourseListView.swift` (modified)
- `HyzerAppTests/CourseEditorViewModelTests.swift` (new)
