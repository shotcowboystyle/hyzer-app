import Foundation
import SwiftData

/// A disc golf course. Stored in the domain SwiftData store.
///
/// CloudKit compatibility constraints:
/// - No `@Attribute(.unique)` — CloudKit does not support unique constraints
/// - All properties have defaults so CloudKit can instantiate without all values
/// - No `@Relationship` — holes reference courses via flat `courseID` foreign key (Amendment A8)
@Model
public final class Course {
    public var id: UUID = UUID()
    public var name: String = ""
    public var holeCount: Int = 18
    public var isSeeded: Bool = false
    public var createdAt: Date = Date()

    public init(name: String, holeCount: Int, isSeeded: Bool = false) {
        self.name = name
        self.holeCount = holeCount
        self.isSeeded = isSeeded
    }
}
