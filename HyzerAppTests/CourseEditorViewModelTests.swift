import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for CourseEditorViewModel (Story 2.1: course creation form validation and persistence).
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

    // MARK: - saveCourse

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
}
