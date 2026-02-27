# Story 2.2: Edit and Delete Courses

Status: ready-for-dev

## Story

As a user,
I want to edit or delete existing courses,
So that I can keep my course list accurate and up to date.

## Acceptance Criteria

1. **AC 1 -- Course editing is accessible:**
   Given the user is viewing a course in the course list,
   When they tap the course row,
   Then they navigate to the course detail view,
   And an "Edit" toolbar button is available to open the editor (FR7).

2. **AC 2 -- Course fields are editable:**
   Given the user has opened the course editor for an existing course,
   When the editor is presented,
   Then the course name, hole count, and per-hole par values are pre-populated from the existing course,
   And the user can modify any of these fields (FR7).

3. **AC 3 -- Edit changes are saved:**
   Given the user has modified a course's fields in the editor,
   When they tap "Save",
   Then the existing `Course` record is updated (not duplicated),
   And `Hole` records are added, removed, or updated to match the new configuration,
   And the course detail view reflects changes immediately via reactive `@Query` (FR7).

4. **AC 4 -- Course deletion with confirmation:**
   Given the user is viewing the course list,
   When they swipe a course row to delete,
   Then a `.confirmationDialog` is presented asking to confirm deletion (FR8),
   And upon confirmation the `Course` and all associated `Hole` records are removed from SwiftData,
   And the course list updates immediately.

5. **AC 5 -- No role restriction:**
   Given any authenticated user,
   When they attempt to edit or delete any course,
   Then the operation succeeds regardless of who created the course (FR9).

## Tasks / Subtasks

- [ ] Task 1: Extend `CourseEditorViewModel` for edit mode (AC: 2, 3)
  - [ ] 1.1 Add `private(set) var existingCourse: Course?` property to track edit vs. create mode
  - [ ] 1.2 Add `init(course: Course?, holes: [Hole])` initializer that pre-populates `courseName`, `holeCount`, `holePars` from existing course and holes; default `init()` keeps current creation behavior
  - [ ] 1.3 Add `var isEditing: Bool` computed property (`existingCourse != nil`)
  - [ ] 1.4 Update `saveCourse(in:)` to branch: if editing, update existing `Course` properties + reconcile `Hole` records; if creating, use current insert logic
  - [ ] 1.5 Hole reconciliation on edit: delete holes beyond new `holeCount`, update par values on existing holes, insert new holes if `holeCount` increased

- [ ] Task 2: Add `deleteCourse(_:in:)` to `CourseEditorViewModel` (AC: 4)
  - [ ] 2.1 Method signature: `func deleteCourse(_ course: Course, holes: [Hole], in context: ModelContext) throws`
  - [ ] 2.2 Delete all `Hole` records for the course first, then delete the `Course`
  - [ ] 2.3 Call `try context.save()`

- [ ] Task 3: Update `CourseEditorView` for edit mode (AC: 1, 2, 3)
  - [ ] 3.1 Add optional `course: Course?` and `holes: [Hole]` parameters (default `nil` and `[]` for creation)
  - [ ] 3.2 Initialize `CourseEditorViewModel(course:holes:)` via `@State` with the provided course
  - [ ] 3.3 Change `.navigationTitle` dynamically: `isEditing ? "Edit Course" : "New Course"`
  - [ ] 3.4 Save button text remains "Save" for both modes

- [ ] Task 4: Add edit entry point from `CourseDetailView` (AC: 1)
  - [ ] 4.1 Add `@State private var isShowingEditor = false` to `CourseDetailView`
  - [ ] 4.2 Add toolbar "Edit" button (trailing, `pencil` system image) that sets `isShowingEditor = true`
  - [ ] 4.3 Add `.sheet(isPresented: $isShowingEditor) { CourseEditorView(course: course, holes: holes) }`

- [ ] Task 5: Add swipe-to-delete on `CourseListView` (AC: 4)
  - [ ] 5.1 Add `@State private var courseToDelete: Course?` to `CourseListView`
  - [ ] 5.2 Add `.swipeActions(edge: .trailing)` with a destructive `Button` (role: `.destructive`) on each course row
  - [ ] 5.3 Add `.confirmationDialog` bound to `courseToDelete` asking "Delete '[course name]'?"
  - [ ] 5.4 On confirmation: fetch Holes by courseID, call `CourseEditorViewModel.deleteCourse(_:holes:in:)`, handle errors with alert

- [ ] Task 6: Write tests (AC: 2, 3, 4, 5)
  - [ ] 6.1 Test: init with existing course pre-populates `courseName`, `holeCount`, `holePars`
  - [ ] 6.2 Test: `isEditing` is true when initialized with a course, false when default init
  - [ ] 6.3 Test: `saveCourse` in edit mode updates existing course name/holeCount, does not create a new course
  - [ ] 6.4 Test: edit with hole count decrease (18→9) deletes excess holes, preserves first 9
  - [ ] 6.5 Test: edit with hole count increase (9→18) creates 9 new holes with par 3
  - [ ] 6.6 Test: edit with par change updates existing hole par values
  - [ ] 6.7 Test: `deleteCourse` removes Course and all associated Holes from context
  - [ ] 6.8 Test: `deleteCourse` throws on context.save() failure (verify error propagation)
  - [ ] 6.9 Verify all existing tests still pass (14 HyzerApp + 17 HyzerKit = 31 total)

## Dev Notes

### Architecture Pattern: Extending CourseEditorViewModel

Story 2.1 created `CourseEditorViewModel` for creation only. This story extends it to handle editing. The key pattern:

- **Create mode:** `CourseEditorViewModel()` -- empty defaults, `saveCourse` inserts new records
- **Edit mode:** `CourseEditorViewModel(course: existingCourse, holes: existingHoles)` -- pre-populated from existing data, `saveCourse` updates existing records

The `existingCourse` reference determines the mode. The view model needs the `Hole` array passed in because `Hole` uses a flat `courseID` foreign key (Amendment A8) -- there is no `@Relationship` to traverse from `Course` to its holes.

### Hole Reconciliation Strategy

When editing, the hole count may change. The reconciliation logic in `saveCourse(in:)` for edit mode:

1. **Fetch existing holes** from the context using `#Predicate { $0.courseID == course.id }`, sorted by number
2. **Par updates:** For holes that still exist (index < new holeCount AND index < old count), update `par` values
3. **Hole deletion:** For holes where `number > newHoleCount`, delete them from context
4. **Hole creation:** For new holes where `number > oldHoleCount`, insert new `Hole` records with par from `holePars`
5. **Update course:** Set `course.name` and `course.holeCount` on the existing model

Important: The ViewModel receives existing holes at init time (for pre-populating `holePars`), but at save time it must re-fetch holes from the context to get the current SwiftData-managed objects for mutation/deletion.

### Delete Strategy

Course deletion requires manually deleting child `Hole` records because there is no `@Relationship` cascade (flat FK per Amendment A8). The delete method:

1. Fetch all `Hole` records where `courseID == course.id`
2. Delete each `Hole` from the context
3. Delete the `Course` from the context
4. `try context.save()`

The PRD has no restrictions on deleting seeded courses (FR8 says "a user can delete a course" without qualification, FR9 confirms equal access). Seeded courses can be deleted.

### Swipe-to-Delete UX

The UX spec mandates: "Destructive actions require confirmation" via `.confirmationDialog` with a clear description. The swipe action reveals a red delete button. Tapping it shows the system confirmation dialog. On confirm, the course + holes are deleted.

Use SwiftUI's `.swipeActions(edge: .trailing)` rather than `.onDelete` because `.onDelete` only works with `ForEach` inside `List` and doesn't integrate as cleanly with the `NavigationLink` rows. `.swipeActions` gives direct control over the button appearance and destructive role.

### Current File State

| File | Current State | Story 2.2 Action |
|------|--------------|-------------------|
| `HyzerApp/ViewModels/CourseEditorViewModel.swift` | Create-only (46 lines) | Add edit init, update saveCourse branching, add deleteCourse |
| `HyzerApp/Views/Courses/CourseEditorView.swift` | Create-only (96 lines) | Accept optional course/holes params, dynamic nav title |
| `HyzerApp/Views/Courses/CourseListView.swift` | List with create sheet (84 lines) | Add swipeActions, confirmationDialog, delete logic |
| `HyzerApp/Views/Courses/CourseDetailView.swift` | Read-only (53 lines) | Add Edit toolbar button + sheet |
| `HyzerKit/Sources/HyzerKit/Models/Course.swift` | Complete (24 lines) | No changes |
| `HyzerKit/Sources/HyzerKit/Models/Hole.swift` | Complete (21 lines) | No changes |
| `HyzerAppTests/CourseEditorViewModelTests.swift` | 14 tests, create-only (145 lines) | Add 8+ edit/delete tests |
| `project.yml` | Auto-discovers files | No changes |

### Key Implementation Details

**CourseEditorViewModel edit init:**
```swift
// New convenience init for edit mode
convenience init(course: Course, holes: [Hole]) {
    self.init()
    self.existingCourse = course
    self.courseName = course.name
    self.holeCount = course.holeCount
    self.holePars = holes.sorted(by: { $0.number < $1.number }).map(\.par)
}
```

**saveCourse branching (edit mode):**
```swift
if let course = existingCourse {
    // Update existing course
    course.name = trimmedName
    course.holeCount = holeCount
    // Reconcile holes: fetch from context, update/delete/insert as needed
    let descriptor = FetchDescriptor<Hole>(
        predicate: #Predicate { $0.courseID == course.id },
        sortBy: [SortDescriptor(\Hole.number)]
    )
    let existingHoles = try context.fetch(descriptor)
    // ... reconciliation logic
} else {
    // Create new course (existing logic)
}
```

**Swipe-to-delete in CourseListView:**
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        courseToDelete = course
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
.confirmationDialog(
    "Delete Course",
    isPresented: $isShowingDeleteConfirmation,
    presenting: courseToDelete
) { course in
    Button("Delete \"\(course.name)\"", role: .destructive) {
        deleteCourse(course)
    }
}
```

**Edit button in CourseDetailView:**
```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button {
            isShowingEditor = true
        } label: {
            Image(systemName: "pencil")
        }
        .tint(Color.accentPrimary)
    }
}
.sheet(isPresented: $isShowingEditor) {
    CourseEditorView(course: course, holes: holes)
}
```

### Form Styling

Reuse the exact same Form styling from Story 2.1:
- `.scrollContentBackground(.hidden)` + `.background(Color.backgroundPrimary)` for dark theme
- Section headers: `.foregroundStyle(Color.textSecondary)`
- Design tokens for all colors, fonts, spacing

### Concurrency

- All ViewModels remain `@MainActor @Observable` -- consistent with Story 2.1
- `saveCourse(in:)` and `deleteCourse(_:holes:in:)` are synchronous throws (SwiftData write from main context)
- No `DispatchQueue` usage, no `Task.detached`

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros, `#expect`) -- NOT XCTest.

**ViewModel tests in `HyzerAppTests/`** (not HyzerKitTests) since the ViewModel is in the HyzerApp target.

**Pattern:** Follow Story 2.1 test patterns exactly. Use `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData tests. Pre-insert Course + Hole records, then exercise edit/delete methods and verify results via `FetchDescriptor`.

**Test setup for edit tests:**
```swift
@Test("saveCourse in edit mode updates existing course without creating new one")
func test_saveCourse_editMode_updatesExisting() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
    let context = ModelContext(container)

    // Insert existing course + holes
    let course = Course(name: "Old Name", holeCount: 9, isSeeded: false)
    context.insert(course)
    for i in 1...9 {
        context.insert(Hole(courseID: course.id, number: i, par: 3))
    }
    try context.save()

    let holes = try context.fetch(FetchDescriptor<Hole>(
        predicate: #Predicate { $0.courseID == course.id },
        sortBy: [SortDescriptor(\Hole.number)]
    ))

    let vm = CourseEditorViewModel(course: course, holes: holes)
    vm.courseName = "New Name"
    try vm.saveCourse(in: context)

    let courses = try context.fetch(FetchDescriptor<Course>())
    #expect(courses.count == 1)
    #expect(courses[0].name == "New Name")
}
```

**Regression:** Run all existing tests after implementation (14 HyzerApp + 17 HyzerKit = 31 total minimum).

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Create a separate `CourseEditViewModel` class | Extend existing `CourseEditorViewModel` with edit mode |
| Use `@Relationship` to cascade delete Holes | Manually fetch and delete Holes by `courseID` (flat FK, Amendment A8) |
| Add `@Attribute(.unique)` for course name validation | No uniqueness constraint -- CloudKit incompatible |
| Skip delete confirmation | Always show `.confirmationDialog` for destructive actions (UX spec requirement) |
| Use `.onDelete` modifier on the List | Use `.swipeActions(edge: .trailing)` for better control with `NavigationLink` rows |
| Restrict deletion of seeded courses | PRD FR8/FR9 allow deletion of any course by any user |
| Use `print()` or `console.log` for debugging | No client-side logging per code quality rules |
| Hardcode colors, fonts, or spacing | Use `ColorTokens`, `TypographyTokens`, `SpacingTokens` from HyzerKit |
| Add CloudKit sync logic to edit/delete | Sync is Epic 4. This story is local-only persistence. |

### Project Structure Notes

- No new files created -- all modifications to existing files from Story 2.1
- `CourseEditorViewModel.swift` modified (add edit init, update save, add delete)
- `CourseEditorView.swift` modified (accept optional course param, dynamic title)
- `CourseListView.swift` modified (add swipe-to-delete + confirmation)
- `CourseDetailView.swift` modified (add Edit toolbar button + sheet)
- `CourseEditorViewModelTests.swift` modified (add edit + delete tests)
- No changes to HyzerKit models or `project.yml`

### Previous Story Intelligence (Story 2.1)

Key learnings from Story 2.1 that directly apply:

1. **`CourseEditorView` was built for reuse:** Story 2.1 dev notes state "This view will serve both creation (this story) and editing (Story 2.2)."
2. **`try context.save()` -- not `try?`:** Story 2.1 review caught silent error swallowing. All save calls must `throw`.
3. **`precondition` guard on empty name:** `saveCourse` has a precondition check. Edit mode should also validate this.
4. **`setHoleCount` bounds validation:** Only 9 or 18 are valid. Same constraint applies in edit mode.
5. **Course name 100-char limit:** Enforced in the view via `.onChange`. Keep this for edit mode.
6. **`holeCountBinding` pattern:** Custom `Binding<Int>` routes changes through `setHoleCount`. Reuse for edit mode.
7. **Error handling with `.alert`:** View shows error alert on save failure, only dismisses on success.
8. **14 existing tests** (was 10, review added 4 more). Build on these patterns.

### References

- [Source: _bmad-output/planning-artifacts/prd.md -- FR7: Edit existing course's name, hole count, par values]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR8: Delete a course]
- [Source: _bmad-output/planning-artifacts/prd.md -- FR9: Equal access, no role restriction on course CRUD]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Amendment A8: Flat courseID foreign key on Hole, no @Relationship]
- [Source: _bmad-output/planning-artifacts/architecture.md -- SwiftData Model Constraints: no @Attribute(.unique), all defaults]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Course Management: last-write-wins for conflicts]
- [Source: _bmad-output/planning-artifacts/architecture.md -- SwiftUI View Patterns: @State for transient UI, @Observable VMs for actions, @Query for reads]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Destructive actions require confirmation via .confirmationDialog]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md -- Component Strategy: .alert/.confirmationDialog for delete course]
- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 2 Story 2.2 acceptance criteria]
- [Source: _bmad-output/implementation-artifacts/2-1-create-a-new-course.md -- Previous story patterns, review findings]
- [Source: HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift -- destructive = #FF3B30]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
