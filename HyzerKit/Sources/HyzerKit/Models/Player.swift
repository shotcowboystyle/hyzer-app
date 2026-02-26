import Foundation
import SwiftData

/// A disc golf player. Stored in the domain SwiftData store and synced via CloudKit.
///
/// CloudKit compatibility constraints:
/// - No `@Attribute(.unique)` — CloudKit does not support unique constraints
/// - All properties have defaults so CloudKit can instantiate without all values
/// - Relationships must be optional (none in this model yet)
@Model
public final class Player {
    public var id: UUID = UUID()
    public var displayName: String = ""
    public var iCloudRecordName: String?
    public var aliases: [String] = []
    public var createdAt: Date = Date()

    public init(displayName: String) {
        self.displayName = displayName
    }
}
