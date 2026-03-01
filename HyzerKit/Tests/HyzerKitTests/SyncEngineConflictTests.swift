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
        #expect(eventIDs == Set([localEvent.id, conflictingEvent.id]))
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

    // MARK: - Story 6.1 Task 8: Resolution event does not create a second Discrepancy

    @Test("pullRecords with resolution ScoreEvent does not create a second Discrepancy")
    @MainActor
    func test_pullRecords_resolutionScoreEvent_doesNotCreateDuplicateDiscrepancy() async throws {
        // Given: an existing Discrepancy for {roundID, playerID, holeNumber=5} that is already resolved
        let container = try makeConflictTestContainer()
        let context = container.mainContext

        let roundID = UUID()
        let playerID = UUID().uuidString
        let organizerDeviceID = "organizer-device"

        // Original conflicting events
        let originalA = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 5, playerID: playerID, strokeCount: 3, deviceID: "device-A"
        )
        let originalB = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 5, playerID: playerID, strokeCount: 4, deviceID: "device-B"
        )
        context.insert(originalA)
        context.insert(originalB)

        // Discrepancy record already exists and is resolved
        let existingDiscrepancy = Discrepancy(
            roundID: roundID,
            playerID: playerID,
            holeNumber: 5,
            eventID1: originalA.id,
            eventID2: originalB.id
        )
        existingDiscrepancy.status = .resolved
        context.insert(existingDiscrepancy)
        try context.save()

        // Resolution event: supersedesEventID == nil, from organizer device
        let resolutionEvent = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 5, playerID: playerID, strokeCount: 3, deviceID: organizerDeviceID
        )
        // supersedesEventID is nil — authoritative resolution, not a correction chain

        let mockCK = MockCloudKitClient()
        mockCK.seed([
            ScoreEventRecord(from: originalA).toCKRecord(),
            ScoreEventRecord(from: originalB).toCKRecord(),
            ScoreEventRecord(from: resolutionEvent).toCKRecord()
        ])

        let engine = SyncEngine(
            cloudKitClient: mockCK,
            standingsEngine: StandingsEngine(modelContext: context),
            modelContainer: container
        )

        // When: pull records (simulates remote device receiving resolution event)
        await engine.pullRecords()
        try await Task.sleep(for: .milliseconds(100))

        // Then: still only 1 Discrepancy (the existing one) — no duplicate created
        let discrepancies = try context.fetch(FetchDescriptor<Discrepancy>())
        #expect(discrepancies.count == 1)
        #expect(discrepancies.first?.status == .resolved)
    }

    // MARK: - Story 6.1 Task 8.2: ConflictDetector does not flag resolution event as a new discrepancy via deduplication

    @Test("pullRecords with resolution ScoreEvent updates leaderboard silently — no new unresolved Discrepancy")
    @MainActor
    func test_pullRecords_resolutionScoreEvent_updatesLeaderboardSilently() async throws {
        // Given: an existing resolved Discrepancy and three events for the same {player, hole}
        let container = try makeConflictTestContainer()
        let context = container.mainContext

        let roundID = UUID()
        let playerID = UUID().uuidString

        let eventA = ScoreEvent.fixture(roundID: roundID, holeNumber: 6, playerID: playerID, strokeCount: 3, deviceID: "device-A")
        let eventB = ScoreEvent.fixture(roundID: roundID, holeNumber: 6, playerID: playerID, strokeCount: 4, deviceID: "device-B")
        context.insert(eventA)
        context.insert(eventB)

        let discrepancy = Discrepancy(roundID: roundID, playerID: playerID, holeNumber: 6, eventID1: eventA.id, eventID2: eventB.id)
        discrepancy.status = .resolved
        context.insert(discrepancy)
        try context.save()

        // Resolution event from organizer device
        let resolutionEvent = ScoreEvent.fixture(
            roundID: roundID, holeNumber: 6, playerID: playerID, strokeCount: 4, deviceID: "organizer-device"
        )

        let mockCK = MockCloudKitClient()
        mockCK.seed([
            ScoreEventRecord(from: eventA).toCKRecord(),
            ScoreEventRecord(from: eventB).toCKRecord(),
            ScoreEventRecord(from: resolutionEvent).toCKRecord()
        ])

        let standingsEngine = StandingsEngine(modelContext: context)
        let engine = SyncEngine(cloudKitClient: mockCK, standingsEngine: standingsEngine, modelContainer: container)

        // When
        await engine.pullRecords()
        try await Task.sleep(for: .milliseconds(100))

        // Then: no new unresolved discrepancy — deduplication guard prevents duplicate
        let allDiscrepancies = try context.fetch(FetchDescriptor<Discrepancy>())
        let unresolved = allDiscrepancies.filter { $0.status == .unresolved }
        #expect(unresolved.isEmpty)
        #expect(allDiscrepancies.count == 1)
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
