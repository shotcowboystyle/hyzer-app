import Testing
import Foundation
import SwiftData
import CloudKit
@testable import HyzerKit

// MARK: - Helpers

/// Builds an in-memory ModelContainer for conflict integration tests.
/// Includes Discrepancy in the domain schema.
@MainActor
private func makeConflictTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, SyncMetadata.self, Discrepancy.self,
        configurations: config
    )
}

// MARK: - Test Suite

@Suite("SyncEngine — Conflict Detection")
struct SyncEngineConflictTests {

    // MARK: - AC5: Silent merge produces no Discrepancy

    @Test("pullRecords with identical remote score from different device silently merges — no Discrepancy created")
    @MainActor
    func test_pullRecords_identicalRemoteScore_silentMerge_noDiscrepancy() async throws {
        let container = try makeConflictTestContainer()
        let context = container.mainContext

        let roundID = UUID()
        let playerID = UUID().uuidString

        // Arrange: device-A score already exists locally
        let localEvent = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-A"
        )
        context.insert(localEvent)
        try context.save()

        // Seed CloudKit with BOTH the local event AND a matching score from device-B
        let remoteEventB = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-B"
        )
        let mockCK = MockCloudKitClient()
        mockCK.seed([
            ScoreEventRecord(from: localEvent).toCKRecord(),
            ScoreEventRecord(from: remoteEventB).toCKRecord()
        ])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act
        await engine.pullRecords()
        try await Task.sleep(for: .milliseconds(100))

        // Assert: device-B's event was inserted
        let allEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        #expect(allEvents.contains { $0.id == remoteEventB.id })

        // Assert: no Discrepancy record created (silent merge)
        let discrepancies = try context.fetch(FetchDescriptor<Discrepancy>())
        #expect(discrepancies.isEmpty)
    }

    // MARK: - AC2: Conflicting remote score creates Discrepancy

    @Test("pullRecords with conflicting remote score creates Discrepancy with correct fields")
    @MainActor
    func test_pullRecords_conflictingRemoteScore_createsDiscrepancy() async throws {
        let container = try makeConflictTestContainer()
        let context = container.mainContext

        let roundID = UUID()
        let playerID = UUID().uuidString

        // Arrange: device-A says 3, device-B says 4 — conflict
        let localEvent = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 3, deviceID: "device-A"
        )
        context.insert(localEvent)
        try context.save()

        let conflictingEvent = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 4, deviceID: "device-B"
        )
        let mockCK = MockCloudKitClient()
        mockCK.seed([
            ScoreEventRecord(from: localEvent).toCKRecord(),
            ScoreEventRecord(from: conflictingEvent).toCKRecord()
        ])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act
        await engine.pullRecords()
        try await Task.sleep(for: .milliseconds(100))

        // Assert: Discrepancy was created
        let discrepancies = try context.fetch(FetchDescriptor<Discrepancy>())
        #expect(discrepancies.count == 1)

        let discrepancy = try #require(discrepancies.first)
        #expect(discrepancy.roundID == roundID)
        #expect(discrepancy.playerID == playerID)
        #expect(discrepancy.holeNumber == 2)
        #expect(discrepancy.status == .unresolved)
        // The two conflicting event IDs are stored (order may vary)
        let eventIDs = Set([discrepancy.eventID1, discrepancy.eventID2])
        #expect(eventIDs.contains(localEvent.id) || eventIDs.contains(conflictingEvent.id))
    }

    // MARK: - AC3: Same-device correction — no discrepancy

    @Test("pullRecords with correction from same device does not create Discrepancy")
    @MainActor
    func test_pullRecords_correctionFromSameDevice_noDiscrepancy() async throws {
        let container = try makeConflictTestContainer()
        let context = container.mainContext

        let roundID = UUID()
        let playerID = UUID().uuidString

        // Arrange: original event from device-A, then correction from device-A
        let originalEvent = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 3, playerID: playerID, strokeCount: 3, deviceID: "device-A"
        )
        context.insert(originalEvent)
        try context.save()

        // Correction from same device (sets supersedesEventID)
        let correctionEvent = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 3, playerID: playerID, strokeCount: 5, deviceID: "device-A"
        )
        correctionEvent.supersedesEventID = originalEvent.id

        let mockCK = MockCloudKitClient()
        mockCK.seed([
            ScoreEventRecord(from: originalEvent).toCKRecord(),
            ScoreEventRecord(from: correctionEvent).toCKRecord()
        ])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act
        await engine.pullRecords()
        try await Task.sleep(for: .milliseconds(100))

        // Assert: no Discrepancy created — same-device correction is not a conflict
        let discrepancies = try context.fetch(FetchDescriptor<Discrepancy>())
        #expect(discrepancies.isEmpty)
    }

    // MARK: - AC4: Cross-device supersession creates Discrepancy

    @Test("pullRecords with cross-device supersession creates Discrepancy")
    @MainActor
    func test_pullRecords_crossDeviceSupersession_createsDiscrepancy() async throws {
        let container = try makeConflictTestContainer()
        let context = container.mainContext

        let roundID = UUID()
        let playerID = UUID().uuidString

        // Arrange: device-A recorded original; device-B "corrects" it (cross-device supersession)
        let originalByA = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 4, playerID: playerID, strokeCount: 3, deviceID: "device-A"
        )
        context.insert(originalByA)
        try context.save()

        let crossCorrectionByB = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 4, playerID: playerID, strokeCount: 5, deviceID: "device-B"
        )
        crossCorrectionByB.supersedesEventID = originalByA.id

        let mockCK = MockCloudKitClient()
        mockCK.seed([
            ScoreEventRecord(from: originalByA).toCKRecord(),
            ScoreEventRecord(from: crossCorrectionByB).toCKRecord()
        ])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // Act
        await engine.pullRecords()
        try await Task.sleep(for: .milliseconds(100))

        // Assert: Discrepancy was created for cross-device supersession
        let discrepancies = try context.fetch(FetchDescriptor<Discrepancy>())
        #expect(discrepancies.count == 1)
        let discrepancy = try #require(discrepancies.first)
        #expect(discrepancy.roundID == roundID)
        #expect(discrepancy.playerID == playerID)
        #expect(discrepancy.holeNumber == 4)
        #expect(discrepancy.status == .unresolved)
    }
}
