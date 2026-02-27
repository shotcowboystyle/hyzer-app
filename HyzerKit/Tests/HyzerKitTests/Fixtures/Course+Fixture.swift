import Foundation
@testable import HyzerKit

public extension Course {
    /// Creates a Course with test defaults. Use in tests only.
    static func fixture(
        name: String = "Test Course",
        holeCount: Int = 18,
        isSeeded: Bool = false
    ) -> Course {
        Course(name: name, holeCount: holeCount, isSeeded: isSeeded)
    }
}

public extension Hole {
    /// Creates a Hole with test defaults. Use in tests only.
    static func fixture(
        courseID: UUID = UUID(),
        number: Int = 1,
        par: Int = 3
    ) -> Hole {
        Hole(courseID: courseID, number: number, par: par)
    }
}
