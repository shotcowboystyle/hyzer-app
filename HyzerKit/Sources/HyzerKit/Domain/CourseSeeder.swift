import Foundation
import SwiftData

/// Seeds pre-defined local disc golf courses into the SwiftData store on first launch.
///
/// Courses are loaded from `SeededCourses.json` in the HyzerKit bundle — no network required.
/// The seeder is idempotent: it is a no-op if seeded courses already exist.
@MainActor
public enum CourseSeeder {

    /// Seeds courses from the bundle JSON if no seeded courses exist yet.
    public static func seedIfNeeded(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Course>(
            predicate: #Predicate { $0.isSeeded == true }
        )
        let existingCount = try context.fetchCount(descriptor)
        guard existingCount == 0 else { return }

        let seedData = try loadSeedData()
        for seedCourse in seedData {
            let course = Course(name: seedCourse.name, holeCount: seedCourse.holes.count, isSeeded: true)
            context.insert(course)
            for seedHole in seedCourse.holes {
                let hole = Hole(courseID: course.id, number: seedHole.number, par: seedHole.par)
                context.insert(hole)
            }
        }
        try context.save()
    }

    // MARK: - Private

    private static func loadSeedData() throws -> [SeedCourse] {
        guard let url = Bundle.module.url(forResource: "SeededCourses", withExtension: "json") else {
            throw CourseSeederError.resourceNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SeedCourse].self, from: data)
    }
}

// MARK: - Errors

public enum CourseSeederError: Error {
    case resourceNotFound
}

// MARK: - Seed data structures (internal decoding only)

private struct SeedCourse: Decodable {
    let name: String
    let holes: [SeedHole]
}

private struct SeedHole: Decodable {
    let number: Int
    let par: Int
}
