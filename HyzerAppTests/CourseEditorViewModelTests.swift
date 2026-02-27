import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for CourseEditorViewModel (Story 2.1 + 2.2: course creation, editing, and deletion).
@Suite("CourseEditorViewModel")
@MainActor
struct CourseEditorViewModelTests {

    // MARK: - canSave

    @Test("canSave is false when name is empty")
    func test_canSave_emptyName_isFalse() {
        let vm = CourseEditorViewModel()
        vm.courseName = ""
        #expect(!vm.canSave)
    }

    @Test("canSave is false when name is whitespace-only")
    func test_canSave_whitespaceOnly_isFalse() {
        let vm = CourseEditorViewModel()
        vm.courseName = "   "
        #expect(!vm.canSave)
    }

    @Test("canSave is true when name has content")
    func test_canSave_nameWithContent_isTrue() {
        let vm = CourseEditorViewModel()
        vm.courseName = "Smugglers Notch"
        #expect(vm.canSave)
    }

    @Test("canSave is true when name has leading/trailing whitespace around content")
    func test_canSave_nameWithPaddedWhitespace_isTrue() {
        let vm = CourseEditorViewModel()
        vm.courseName = "  Maple Hill  "
        #expect(vm.canSave)
    }

    // MARK: - setHoleCount

    @Test("setHoleCount(9) produces 9 par values all defaulting to 3")
    func test_setHoleCount_9_producesParsDefault3() {
        let vm = CourseEditorViewModel()
        vm.setHoleCount(9)
        #expect(vm.holeCount == 9)
        #expect(vm.holePars.count == 9)
        #expect(vm.holePars.allSatisfy { $0 == 3 })
    }

    @Test("setHoleCount preserves existing par values when shrinking from 18 to 9")
    func test_setHoleCount_shrink_preservesExistingPars() {
        let vm = CourseEditorViewModel()
        // Customize some holes
        vm.holePars[0] = 4
        vm.holePars[1] = 5
        vm.holePars[8] = 4
        vm.setHoleCount(9)
        #expect(vm.holePars.count == 9)
        #expect(vm.holePars[0] == 4)
        #expect(vm.holePars[1] == 5)
        #expect(vm.holePars[8] == 4)
    }

    @Test("setHoleCount fills new holes with par 3 when expanding from 9 to 18")
    func test_setHoleCount_expand_fillsNewHolesWithPar3() {
        let vm = CourseEditorViewModel()
        vm.setHoleCount(9)
        vm.holePars[0] = 4
        vm.setHoleCount(18)
        #expect(vm.holePars.count == 18)
        #expect(vm.holePars[0] == 4)
        for i in 9..<18 {
            #expect(vm.holePars[i] == 3)
        }
    }

    @Test("setHoleCount ignores invalid values like 0")
    func test_setHoleCount_invalidValue_noChange() {
        let vm = CourseEditorViewModel()
        vm.setHoleCount(0)
        #expect(vm.holeCount == 18)
        #expect(vm.holePars.count == 18)
    }

    @Test("setHoleCount ignores values outside 9/18")
    func test_setHoleCount_arbitraryValue_noChange() {
        let vm = CourseEditorViewModel()
        vm.setHoleCount(12)
        #expect(vm.holeCount == 18)
        #expect(vm.holePars.count == 18)
    }

    // MARK: - saveCourse (create mode)

    @Test("saveCourse creates one Course with isSeeded false and correct hole count")
    func test_saveCourse_createsCorrectCourse() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let vm = CourseEditorViewModel()
        vm.courseName = "Maple Hill"
        vm.setHoleCount(18)
        try vm.saveCourse(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.count == 1)
        #expect(courses[0].name == "Maple Hill")
        #expect(courses[0].holeCount == 18)
        #expect(!courses[0].isSeeded)
    }

    @Test("saveCourse creates Hole records with correct courseID, number, and par values")
    func test_saveCourse_createsHoleRecords() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let vm = CourseEditorViewModel()
        vm.courseName = "Smugglers Notch"
        vm.setHoleCount(9)
        vm.holePars[0] = 4
        vm.holePars[4] = 5
        try vm.saveCourse(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.count == 1)
        let courseID = courses[0].id

        let holeDescriptor = FetchDescriptor<Hole>(sortBy: [SortDescriptor(\.number)])
        let holes = try context.fetch(holeDescriptor)
        #expect(holes.count == 9)
        #expect(holes.allSatisfy { $0.courseID == courseID })
        #expect(holes[0].number == 1)
        #expect(holes[0].par == 4)
        #expect(holes[4].number == 5)
        #expect(holes[4].par == 5)
        #expect(holes[8].number == 9)
        #expect(holes[8].par == 3)
    }

    // MARK: - isEditing

    @Test("isEditing is false when using default init")
    func test_isEditing_defaultInit_isFalse() {
        let vm = CourseEditorViewModel()
        #expect(!vm.isEditing)
    }

    @Test("isEditing is true when initialized with an existing course")
    func test_isEditing_withCourse_isTrue() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Maple Hill", holeCount: 9, isSeeded: false)
        context.insert(course)
        try context.save()

        let vm = CourseEditorViewModel(course: course, holes: [])
        #expect(vm.isEditing)
    }

    // MARK: - init(course:holes:) — pre-population

    @Test("init with existing course pre-populates courseName, holeCount, and holePars")
    func test_init_withCourse_prePopulatesFields() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Smugglers Notch", holeCount: 9, isSeeded: false)
        context.insert(course)
        let pars = [4, 3, 3, 5, 3, 4, 3, 3, 4]
        var holes: [Hole] = []
        for (i, par) in pars.enumerated() {
            let hole = Hole(courseID: course.id, number: i + 1, par: par)
            context.insert(hole)
            holes.append(hole)
        }
        try context.save()

        let vm = CourseEditorViewModel(course: course, holes: holes)
        #expect(vm.courseName == "Smugglers Notch")
        #expect(vm.holeCount == 9)
        #expect(vm.holePars == pars)
    }

    // MARK: - saveCourse (edit mode)

    @Test("saveCourse in edit mode updates existing course without creating a new one")
    func test_saveCourse_editMode_updatesExistingCourse() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Old Name", holeCount: 9, isSeeded: false)
        context.insert(course)
        for i in 1...9 {
            context.insert(Hole(courseID: course.id, number: i, par: 3))
        }
        try context.save()

        let courseID = course.id
        let fetchedHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID },
            sortBy: [SortDescriptor(\Hole.number)]
        ))

        let vm = CourseEditorViewModel(course: course, holes: fetchedHoles)
        vm.courseName = "New Name"
        try vm.saveCourse(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.count == 1)
        #expect(courses[0].name == "New Name")
    }

    @Test("saveCourse edit mode decreasing hole count from 18 to 9 deletes excess holes")
    func test_saveCourse_editMode_holeCountDecrease_deletesExcessHoles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Test Course", holeCount: 18, isSeeded: false)
        context.insert(course)
        for i in 1...18 {
            context.insert(Hole(courseID: course.id, number: i, par: 3))
        }
        try context.save()

        let courseID = course.id
        let fetchedHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID },
            sortBy: [SortDescriptor(\Hole.number)]
        ))

        let vm = CourseEditorViewModel(course: course, holes: fetchedHoles)
        vm.setHoleCount(9)
        try vm.saveCourse(in: context)

        let remainingHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID }
        ))
        #expect(remainingHoles.count == 9)
        #expect(course.holeCount == 9)
        let numbers = remainingHoles.map(\.number).sorted()
        #expect(numbers == Array(1...9))
    }

    @Test("saveCourse edit mode increasing hole count from 9 to 18 creates 9 new holes with par 3")
    func test_saveCourse_editMode_holeCountIncrease_createsNewHoles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Test Course", holeCount: 9, isSeeded: false)
        context.insert(course)
        for i in 1...9 {
            context.insert(Hole(courseID: course.id, number: i, par: 4))
        }
        try context.save()

        let courseID = course.id
        let fetchedHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID },
            sortBy: [SortDescriptor(\Hole.number)]
        ))

        let vm = CourseEditorViewModel(course: course, holes: fetchedHoles)
        vm.setHoleCount(18)
        try vm.saveCourse(in: context)

        let allHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID },
            sortBy: [SortDescriptor(\Hole.number)]
        ))
        #expect(allHoles.count == 18)
        #expect(course.holeCount == 18)
        // First 9 holes should keep their par 4 values
        for i in 0..<9 {
            #expect(allHoles[i].par == 4)
        }
        // New holes 10-18 should default to par 3
        for i in 9..<18 {
            #expect(allHoles[i].par == 3)
        }
    }

    @Test("saveCourse edit mode with par change updates existing hole par values")
    func test_saveCourse_editMode_parChange_updatesHolePars() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Test Course", holeCount: 9, isSeeded: false)
        context.insert(course)
        for i in 1...9 {
            context.insert(Hole(courseID: course.id, number: i, par: 3))
        }
        try context.save()

        let courseID = course.id
        let fetchedHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID },
            sortBy: [SortDescriptor(\Hole.number)]
        ))

        let vm = CourseEditorViewModel(course: course, holes: fetchedHoles)
        vm.holePars[0] = 4
        vm.holePars[4] = 5
        try vm.saveCourse(in: context)

        let updatedHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID },
            sortBy: [SortDescriptor(\Hole.number)]
        ))
        #expect(updatedHoles[0].par == 4)
        #expect(updatedHoles[4].par == 5)
        #expect(updatedHoles[1].par == 3)
    }

    // MARK: - deleteCourse

    @Test("deleteCourse removes Course and all associated Holes from context")
    func test_deleteCourse_removesCourseAndHoles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "To Delete", holeCount: 9, isSeeded: false)
        context.insert(course)
        for i in 1...9 {
            context.insert(Hole(courseID: course.id, number: i, par: 3))
        }
        try context.save()

        try CourseEditorViewModel.deleteCourse(course, in: context)

        let remainingCourses = try context.fetch(FetchDescriptor<Course>())
        let remainingHoles = try context.fetch(FetchDescriptor<Hole>())
        #expect(remainingCourses.isEmpty)
        #expect(remainingHoles.isEmpty)
    }

    @Test("deleteCourse only removes holes for the deleted course, not other courses")
    func test_deleteCourse_onlyDeletesTargetCourseHoles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let courseA = Course(name: "Course A", holeCount: 9, isSeeded: false)
        let courseB = Course(name: "Course B", holeCount: 9, isSeeded: false)
        context.insert(courseA)
        context.insert(courseB)

        for i in 1...9 {
            context.insert(Hole(courseID: courseA.id, number: i, par: 3))
        }
        let courseBID = courseB.id
        for i in 1...9 {
            context.insert(Hole(courseID: courseBID, number: i, par: 3))
        }
        try context.save()

        try CourseEditorViewModel.deleteCourse(courseA, in: context)

        let remainingCourses = try context.fetch(FetchDescriptor<Course>())
        #expect(remainingCourses.count == 1)
        #expect(remainingCourses[0].name == "Course B")

        let remainingHoles = try context.fetch(FetchDescriptor<Hole>())
        #expect(remainingHoles.count == 9)
        #expect(remainingHoles.allSatisfy { $0.courseID == courseBID })
    }

    // MARK: - Seeded course editing

    @Test("saveCourse in edit mode on seeded course preserves isSeeded flag")
    func test_saveCourse_editMode_seededCourse_preservesIsSeeded() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Seeded Course", holeCount: 9, isSeeded: true)
        context.insert(course)
        for i in 1...9 {
            context.insert(Hole(courseID: course.id, number: i, par: 3))
        }
        try context.save()

        let courseID = course.id
        let fetchedHoles = try context.fetch(FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID },
            sortBy: [SortDescriptor(\Hole.number)]
        ))

        let vm = CourseEditorViewModel(course: course, holes: fetchedHoles)
        vm.courseName = "Renamed Seeded"
        try vm.saveCourse(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.count == 1)
        #expect(courses[0].name == "Renamed Seeded")
        #expect(courses[0].isSeeded)
    }
}
