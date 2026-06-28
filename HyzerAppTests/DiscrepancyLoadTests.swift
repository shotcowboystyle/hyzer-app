import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for DiscrepancyViewModel — load and query behaviors (Story 6.1: Discrepancy Alert & Resolution Flow).
@Suite("DiscrepancyViewModel — Load")
@MainActor
struct DiscrepancyLoadTests {

    // MARK: - Setup helpers

    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self, Discrepancy.self,
            configurations: config
        )
        return (container, container.mainContext)
    }

    private func makeVM(
        context: ModelContext,
        roundID: UUID,
        organizerID: UUID,
        currentPlayerID: UUID
    ) -> DiscrepancyViewModel {
        let service = ScoringService(modelContext: context, deviceID: "test-device")
        let engine = StandingsEngine(modelContext: context)
        return DiscrepancyViewModel(
            scoringService: service,
            standingsEngine: engine,
            modelContext: context,
            roundID: roundID,
            organizerID: organizerID,
            currentPlayerID: currentPlayerID
        )
    }

    private func makeDiscrepancy(
        roundID: UUID,
        playerID: String,
        holeNumber: Int,
        eventID1: UUID,
        eventID2: UUID,
        status: DiscrepancyStatus = .unresolved
    ) -> Discrepancy {
        let d = Discrepancy(roundID: roundID, playerID: playerID, holeNumber: holeNumber, eventID1: eventID1, eventID2: eventID2)
        d.status = status
        return d
    }

    private func makeScoreEvent(
        roundID: UUID,
        holeNumber: Int,
        playerID: String,
        strokeCount: Int,
        reportedByPlayerID: UUID = UUID()
    ) -> ScoreEvent {
        ScoreEvent(
            roundID: roundID,
            holeNumber: holeNumber,
            playerID: playerID,
            strokeCount: strokeCount,
            reportedByPlayerID: reportedByPlayerID,
            deviceID: "test-device"
        )
    }

    // MARK: - AC1: isOrganizer

    @Test("isOrganizer returns true when currentPlayerID matches organizerID")
    func test_isOrganizer_matchingPlayerID_returnsTrue() throws {
        // Given
        let (_, context) = try makeContainer()
        let organizerID = UUID()

        // When
        let vm = makeVM(context: context, roundID: UUID(), organizerID: organizerID, currentPlayerID: organizerID)

        // Then
        #expect(vm.isOrganizer == true)
    }

    @Test("isOrganizer returns false when currentPlayerID differs from organizerID")
    func test_isOrganizer_differentPlayerID_returnsFalse() throws {
        // Given
        let (_, context) = try makeContainer()

        // When
        let vm = makeVM(
            context: context,
            roundID: UUID(),
            organizerID: UUID(),
            currentPlayerID: UUID()
        )

        // Then
        #expect(vm.isOrganizer == false)
    }

    // MARK: - AC5: loadUnresolved

    @Test("loadUnresolved filters to current round and unresolved status only")
    func test_loadUnresolved_filtersToCurrentRound_unresolvedOnly() throws {
        // Given
        let (_, context) = try makeContainer()
        let roundID = UUID()
        let otherRoundID = UUID()
        let playerID = UUID().uuidString
        let e1 = UUID()
        let e2 = UUID()

        let unresolved1 = makeDiscrepancy(roundID: roundID, playerID: playerID, holeNumber: 1, eventID1: e1, eventID2: e2, status: .unresolved)
        let unresolved2 = makeDiscrepancy(roundID: roundID, playerID: playerID, holeNumber: 2, eventID1: e1, eventID2: e2, status: .unresolved)
        let resolved = makeDiscrepancy(roundID: roundID, playerID: playerID, holeNumber: 3, eventID1: e1, eventID2: e2, status: .resolved)
        let otherRound = makeDiscrepancy(roundID: otherRoundID, playerID: playerID, holeNumber: 1, eventID1: e1, eventID2: e2, status: .unresolved)

        for d in [unresolved1, unresolved2, resolved, otherRound] {
            context.insert(d)
        }
        try context.save()

        let organizerID = UUID()
        let vm = makeVM(context: context, roundID: roundID, organizerID: organizerID, currentPlayerID: organizerID)

        // When
        vm.loadUnresolved()

        // Then: only the 2 unresolved records for this round
        #expect(vm.unresolvedDiscrepancies.count == 2)
        let holeNumbers = vm.unresolvedDiscrepancies.map(\.holeNumber).sorted()
        #expect(holeNumbers == [1, 2])
    }

    // MARK: - AC2: loadConflictingEvents

    @Test("loadConflictingEvents returns both ScoreEvents for a discrepancy")
    func test_loadConflictingEvents_returnsBothScoreEvents() throws {
        // Given
        let (_, context) = try makeContainer()
        let roundID = UUID()
        let playerID = UUID().uuidString

        let event1 = makeScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3)
        let event2 = makeScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4)
        context.insert(event1)
        context.insert(event2)

        let discrepancy = makeDiscrepancy(
            roundID: roundID, playerID: playerID, holeNumber: 1,
            eventID1: event1.id, eventID2: event2.id
        )
        context.insert(discrepancy)
        try context.save()

        let organizerID = UUID()
        let vm = makeVM(context: context, roundID: roundID, organizerID: organizerID, currentPlayerID: organizerID)

        // When
        let result = vm.loadConflictingEvents(for: discrepancy)

        // Then
        #expect(result != nil)
        guard let (e1, e2) = result else { return }
        let fetchedIDs: [UUID] = [e1.id, e2.id].sorted { $0.uuidString < $1.uuidString }
        let expectedIDs: [UUID] = [event1.id, event2.id].sorted { $0.uuidString < $1.uuidString }
        #expect(fetchedIDs == expectedIDs)
    }
}
