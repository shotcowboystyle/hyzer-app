import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("CourseSeeder")
struct CourseSeederTests {

    // MARK: - Helper

    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        return ModelContext(container)
    }

    // MARK: - 1: Inserts three courses with holes

    @Test("test_seedIfNeeded_insertsThreeCoursesWithHoles")
    @MainActor
    func test_seedIfNeeded_insertsThreeCoursesWithHoles() throws {
        let context = try makeContext()
        try CourseSeeder.seedIfNeeded(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.count == 3)

        for course in courses {
            let courseID = course.id
            let holeDescriptor = FetchDescriptor<Hole>(
                predicate: #Predicate { $0.courseID == courseID }
            )
            let holes = try context.fetch(holeDescriptor)
            #expect(holes.count == course.holeCount)
            #expect(holes.count > 0)
        }
    }

    // MARK: - 2: Idempotency

    @Test("test_seedIfNeeded_isIdempotent")
    @MainActor
    func test_seedIfNeeded_isIdempotent() throws {
        let context = try makeContext()
        try CourseSeeder.seedIfNeeded(in: context)
        try CourseSeeder.seedIfNeeded(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.count == 3)
    }

    // MARK: - 3: All courses marked as seeded

    @Test("test_seedIfNeeded_allCoursesMarkedAsSeeded")
    @MainActor
    func test_seedIfNeeded_allCoursesMarkedAsSeeded() throws {
        let context = try makeContext()
        try CourseSeeder.seedIfNeeded(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        #expect(courses.allSatisfy { $0.isSeeded == true })
    }

    // MARK: - 4: Holes have correct courseID

    @Test("test_seedIfNeeded_holesHaveCorrectCourseID")
    @MainActor
    func test_seedIfNeeded_holesHaveCorrectCourseID() throws {
        let context = try makeContext()
        try CourseSeeder.seedIfNeeded(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        let allHoles = try context.fetch(FetchDescriptor<Hole>())

        let courseIDs = Set(courses.map(\.id))
        #expect(allHoles.allSatisfy { courseIDs.contains($0.courseID) })

        for course in courses {
            let courseID = course.id
            let descriptor = FetchDescriptor<Hole>(
                predicate: #Predicate { $0.courseID == courseID }
            )
            let holes = try context.fetch(descriptor)
            #expect(holes.count == course.holeCount)
        }
    }
}
