import Foundation
import SwiftData
@testable import HyzerKit
import TestSupport

/// Kit-level integration harness — wires `ScoringService`, `StandingsEngine`,
/// `RoundLifecycleManager`, and `SyncEngine` against an in-memory SwiftData
/// container. No `AppServices`, no ViewModels.
///
/// Use in `HyzerKitTests/Integration/` test files that exercise the domain
/// pipeline end-to-end without the HyzerApp layer (e.g.,
/// `FullRoundLifecycleKitTests`, `ScoreCorrectionConflictTests`,
/// `RemoteScoreEventArrivalTests`). These tests run via `swift test` — no
/// iOS Simulator required, dodging the iOS 18.2 runtime gap.
///
/// Counterpart at the app layer: `HyzerAppTests/Integration/Support/IntegrationTestHarness.swift`.
@MainActor
struct IntegrationKitHarness {

    // MARK: Captured references

    let container: ModelContainer
    let cloudKit: MockCloudKitClient
    let scoringService: ScoringService
    let standingsEngine: StandingsEngine
    let roundLifecycleManager: RoundLifecycleManager
    let syncEngine: SyncEngine

    /// Stable test deviceID — set by `make()`. Tests that need a different value
    /// for conflict scenarios (two devices reporting same hole) can construct a
    /// second `ScoringService` directly with a different `deviceID`.
    let deviceID: String

    // MARK: Factory

    /// Wires up an in-memory container (including `Discrepancy` for conflict
    /// tests) and the four core domain services.
    static func make(deviceID: String = "test-device") throws -> IntegrationKitHarness {
        let container = try TestContainerFactory.makeConflictTestContainer()
        let cloudKit = MockCloudKitClient()
        let standingsEngine = StandingsEngine(modelContext: container.mainContext)
        let roundLifecycleManager = RoundLifecycleManager(modelContext: container.mainContext)
        let scoringService = ScoringService(modelContext: container.mainContext, deviceID: deviceID)
        let syncEngine = SyncEngine(
            cloudKitClient: cloudKit,
            standingsEngine: standingsEngine,
            modelContainer: container
        )
        return IntegrationKitHarness(
            container: container,
            cloudKit: cloudKit,
            scoringService: scoringService,
            standingsEngine: standingsEngine,
            roundLifecycleManager: roundLifecycleManager,
            syncEngine: syncEngine,
            deviceID: deviceID
        )
    }

    // MARK: Seeders

    /// Inserts a Player and saves.
    @discardableResult
    func seedPlayer(
        displayName: String = "Test Player",
        iCloudRecordName: String? = nil
    ) throws -> Player {
        let player = Player.fixture(
            displayName: displayName,
            iCloudRecordName: iCloudRecordName
        )
        container.mainContext.insert(player)
        try container.mainContext.save()
        return player
    }

    /// Inserts a Course and `holeCount` Holes (all par `parPerHole`) and saves.
    @discardableResult
    func seedCourse(
        name: String = "Test Course",
        holeCount: Int = 18,
        parPerHole: Int = 3
    ) throws -> Course {
        let course = Course(name: name, holeCount: holeCount)
        container.mainContext.insert(course)
        for n in 1...holeCount {
            let hole = Hole(courseID: course.id, number: n, par: parPerHole)
            container.mainContext.insert(hole)
        }
        try container.mainContext.save()
        return course
    }

    /// Inserts an active Round with the given organizer + players and saves.
    @discardableResult
    func seedActiveRound(
        courseID: UUID,
        organizerID: UUID,
        playerIDs: [String],
        guestNames: [String] = [],
        holeCount: Int = 18
    ) throws -> Round {
        let round = Round(
            courseID: courseID,
            organizerID: organizerID,
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: holeCount
        )
        round.start()
        container.mainContext.insert(round)
        try container.mainContext.save()
        return round
    }
}
