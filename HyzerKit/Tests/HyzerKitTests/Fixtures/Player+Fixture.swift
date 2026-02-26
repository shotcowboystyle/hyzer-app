import Foundation
@testable import HyzerKit

public extension Player {
    /// Creates a Player with test defaults. Use in tests only.
    static func fixture(
        displayName: String = "Test Player",
        iCloudRecordName: String? = nil,
        aliases: [String] = []
    ) -> Player {
        let player = Player(displayName: displayName)
        player.iCloudRecordName = iCloudRecordName
        player.aliases = aliases
        return player
    }
}
