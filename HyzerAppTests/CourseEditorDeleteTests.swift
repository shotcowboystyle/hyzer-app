import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for CourseEditorViewModel — deleteCourse (Story 2.1 + 2.2).
@Suite("CourseEditorViewModel — Delete")
@MainActor
struct CourseEditorDeleteTests {

    // MARK: - deleteCourse

    @Test("deleteCourse removes Course and all associated Holes from context")
    func test_deleteCourse_removesCourseAndHoles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
}
