import SwiftData
@testable import HyzerKit

/// Shared in-memory ModelContainer factories for sync and domain tests.
///
/// Eliminates duplicated `makeSyncContainer()` helpers across test files.
enum TestContainerFactory {
    /// Container with all domain + operational models for sync tests.
    @MainActor
    static func makeSyncContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self,
            configurations: config
        )
    }

    /// Container with all domain + operational models INCLUDING Discrepancy for conflict tests.
    @MainActor
    static func makeConflictTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self, Discrepancy.self,
            configurations: config
        )
    }
}
