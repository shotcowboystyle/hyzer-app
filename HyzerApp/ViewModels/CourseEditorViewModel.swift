import Foundation
import SwiftData
import HyzerKit

/// Handles business logic for the course creation and editing form.
///
/// Receives `ModelContext` at the time of save — not via constructor — matching
/// the `OnboardingViewModel` pattern from Story 1.1.
@MainActor
@Observable
final class CourseEditorViewModel {
    private(set) var existingCourse: Course?
    var courseName: String = ""
    var holeCount: Int = 18
    var holePars: [Int] = Array(repeating: 3, count: 18)

    var canSave: Bool {
        !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isEditing: Bool {
        existingCourse != nil
    }

    init() {}

    /// Convenience initializer for edit mode. Pre-populates fields from an existing course.
    init(course: Course, holes: [Hole]) {
        existingCourse = course
        courseName = course.name
        holeCount = course.holeCount
        holePars = holes.sorted(by: { $0.number < $1.number }).map(\.par)
    }

    /// Rebuilds `holePars` to the new count, preserving existing values up to the
    /// old count and filling new slots with par 3.
    func setHoleCount(_ count: Int) {
        guard count == 9 || count == 18 else { return }
        let old = holePars
        holePars = (0..<count).map { i in
            i < old.count ? old[i] : 3
        }
        holeCount = count
    }

    /// Creates or updates a `Course` and corresponding `Hole` records in SwiftData.
    ///
    /// - Precondition: `canSave` must be `true` (non-empty name).
    func saveCourse(in context: ModelContext) throws {
        let trimmedName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!trimmedName.isEmpty, "saveCourse called with empty course name")

        if let course = existingCourse {
            let courseID = course.id
            let descriptor = FetchDescriptor<Hole>(
                predicate: #Predicate { $0.courseID == courseID },
                sortBy: [SortDescriptor(\Hole.number)]
            )
            let existingHoles = try context.fetch(descriptor)
            let oldCount = existingHoles.count
            let newCount = holeCount

            // Update par values for holes that exist in both old and new config
            for i in 0..<min(oldCount, newCount) {
                existingHoles[i].par = holePars[i]
            }
            // Delete holes beyond new count
            for i in newCount..<oldCount {
                context.delete(existingHoles[i])
            }
            // Insert new holes if count increased
            for i in oldCount..<newCount {
                let hole = Hole(courseID: courseID, number: i + 1, par: holePars[i])
                context.insert(hole)
            }
            // Update course properties
            course.name = trimmedName
            course.holeCount = newCount
        } else {
            let course = Course(name: trimmedName, holeCount: holeCount, isSeeded: false)
            context.insert(course)
            for (index, par) in holePars.enumerated() {
                let hole = Hole(courseID: course.id, number: index + 1, par: par)
                context.insert(hole)
            }
        }

        try context.save()
    }

    /// Deletes a `Course` and all associated `Hole` records from SwiftData.
    ///
    /// Fetches holes internally (matching `saveCourse` pattern) because there is
    /// no `@Relationship` cascade (flat `courseID` foreign key per Amendment A8).
    static func deleteCourse(_ course: Course, in context: ModelContext) throws {
        let courseID = course.id
        let descriptor = FetchDescriptor<Hole>(
            predicate: #Predicate { $0.courseID == courseID }
        )
        let holes = try context.fetch(descriptor)
        for hole in holes {
            context.delete(hole)
        }
        context.delete(course)
        try context.save()
    }
}
