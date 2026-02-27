import SwiftData
import HyzerKit

/// Handles business logic for the course creation form.
///
/// Receives `ModelContext` at the time of save — not via constructor — matching
/// the `OnboardingViewModel` pattern from Story 1.1.
@MainActor
@Observable
final class CourseEditorViewModel {
    var courseName: String = ""
    var holeCount: Int = 18
    var holePars: [Int] = Array(repeating: 3, count: 18)

    var canSave: Bool {
        !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Rebuilds `holePars` to the new count, preserving existing values up to the
    /// old count and filling new slots with par 3.
    func setHoleCount(_ count: Int) {
        let old = holePars
        holePars = (0..<count).map { i in
            i < old.count ? old[i] : 3
        }
        holeCount = count
    }

    /// Creates a `Course` and corresponding `Hole` records in SwiftData.
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
