import Foundation
import SwiftData

/// A hole on a disc golf course. Stored in the domain SwiftData store.
///
/// Uses a flat foreign key (`courseID: UUID`) instead of `@Relationship` per Amendment A8.
/// CloudKit requires optional or defaulted properties — all fields have defaults.
@Model
public final class Hole {
    public var id: UUID = UUID()
    public var courseID: UUID = UUID()
    public var number: Int = 1
    public var par: Int = 3

    public init(courseID: UUID, number: Int, par: Int = 3) {
        self.courseID = courseID
        self.number = number
        self.par = par
    }
}
