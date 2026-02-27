import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("Course and Hole models")
struct CourseModelTests {

    // MARK: - 5 & 6: Default values satisfy CloudKit constraints

    @Test("test_courseDefaultValues_areCloudKitCompatible")
    func test_courseDefaultValues_areCloudKitCompatible() {
        let course = Course(name: "Test Course", holeCount: 18)
        // All properties must have defaults (no nil optionals required for CloudKit)
        #expect(course.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(course.name == "Test Course")
        #expect(course.holeCount == 18)
        #expect(course.isSeeded == false)
        #expect(course.createdAt <= Date())
    }

    @Test("test_holeDefaultValues_areCloudKitCompatible")
    func test_holeDefaultValues_areCloudKitCompatible() {
        let courseID = UUID()
        let hole = Hole(courseID: courseID, number: 1, par: 3)
        #expect(hole.courseID == courseID)
        #expect(hole.number == 1)
        #expect(hole.par == 3)
        #expect(hole.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    // MARK: - 7: Fetch holes by courseID (flat foreign key)

    @Test("test_fetchHolesByCourseID_returnsCorrectHoles")
    @MainActor
    func test_fetchHolesByCourseID_returnsCorrectHoles() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, Hole.self, configurations: config)
        let context = ModelContext(container)

        let courseA = Course.fixture(name: "Course A", holeCount: 3)
        let courseB = Course.fixture(name: "Course B", holeCount: 2)
        context.insert(courseA)
        context.insert(courseB)

        let holesA = [
            Hole(courseID: courseA.id, number: 1, par: 3),
            Hole(courseID: courseA.id, number: 2, par: 4),
            Hole(courseID: courseA.id, number: 3, par: 3),
        ]
        let holesB = [
            Hole(courseID: courseB.id, number: 1, par: 3),
            Hole(courseID: courseB.id, number: 2, par: 3),
        ]
        for hole in holesA + holesB { context.insert(hole) }
        try context.save()

        let courseAID = courseA.id
        let descriptor = FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseAID },
            sortBy: [SortDescriptor(\.number)]
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 3)
        #expect(fetched.allSatisfy { $0.courseID == courseA.id })
        #expect(fetched.map(\.number) == [1, 2, 3])
    }

    // MARK: - Persistence round-trip

    @Test("test_course_persistsAndRoundTrips")
    @MainActor
    func test_course_persistsAndRoundTrips() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Morley Field", holeCount: 18, isSeeded: true)
        context.insert(course)
        try context.save()

        let all = try context.fetch(FetchDescriptor<Course>())
        let fetched = all.filter { $0.name == "Morley Field" }
        #expect(fetched.count == 1)
        #expect(fetched[0].holeCount == 18)
        #expect(fetched[0].isSeeded == true)
    }
}
