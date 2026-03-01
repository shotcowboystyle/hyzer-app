import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for DiscrepancyViewModel (Story 6.1: Discrepancy Alert & Resolution Flow).
@Suite("DiscrepancyViewModel")
@MainActor
struct DiscrepancyViewModelTests {

    // MARK: - Setup helpers

    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
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

    // MARK: - AC3: resolve creates authoritative ScoreEvent

    @Test("resolve creates authoritative ScoreEvent with correct fields")
    func test_resolve_createsAuthoritativeScoreEvent_withCorrectFields() throws {
        // Given
        let (_, context) = try makeContainer()
        let roundID = UUID()
        let organizerID = UUID()
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

        let vm = makeVM(context: context, roundID: roundID, organizerID: organizerID, currentPlayerID: organizerID)

        // When
        vm.resolve(discrepancy: discrepancy, selectedStrokeCount: 4, playerID: playerID, holeNumber: 1)

        // Then: resolution ScoreEvent created with correct fields
        let allEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        let resolutionEvent = allEvents.first { $0.reportedByPlayerID == organizerID }
        #expect(resolutionEvent != nil)
        #expect(resolutionEvent?.strokeCount == 4)
        #expect(resolutionEvent?.roundID == roundID)
        #expect(resolutionEvent?.holeNumber == 1)
        #expect(resolutionEvent?.playerID == playerID)
        #expect(resolutionEvent?.supersedesEventID == nil)
    }

    // MARK: - AC3: resolve updates Discrepancy status

    @Test("resolve updates Discrepancy status to .resolved")
    func test_resolve_updatesDiscrepancyStatus_toResolved() throws {
        // Given
        let (_, context) = try makeContainer()
        let roundID = UUID()
        let organizerID = UUID()
        let playerID = UUID().uuidString

        let event1 = makeScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 3)
        let event2 = makeScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 5)
        context.insert(event1)
        context.insert(event2)
        let discrepancy = makeDiscrepancy(
            roundID: roundID, playerID: playerID, holeNumber: 2,
            eventID1: event1.id, eventID2: event2.id, status: .unresolved
        )
        context.insert(discrepancy)
        try context.save()

        let vm = makeVM(context: context, roundID: roundID, organizerID: organizerID, currentPlayerID: organizerID)

        // When
        vm.resolve(discrepancy: discrepancy, selectedStrokeCount: 5, playerID: playerID, holeNumber: 2)

        // Then
        #expect(discrepancy.status == .resolved)
    }

    // MARK: - AC3: resolve sets resolvedByEventID

    @Test("resolve sets resolvedByEventID on the Discrepancy")
    func test_resolve_setsResolvedByEventID() throws {
        // Given
        let (_, context) = try makeContainer()
        let roundID = UUID()
        let organizerID = UUID()
        let playerID = UUID().uuidString

        let event1 = makeScoreEvent(roundID: roundID, holeNumber: 3, playerID: playerID, strokeCount: 3)
        let event2 = makeScoreEvent(roundID: roundID, holeNumber: 3, playerID: playerID, strokeCount: 4)
        context.insert(event1)
        context.insert(event2)
        let discrepancy = makeDiscrepancy(
            roundID: roundID, playerID: playerID, holeNumber: 3,
            eventID1: event1.id, eventID2: event2.id
        )
        context.insert(discrepancy)
        try context.save()

        let vm = makeVM(context: context, roundID: roundID, organizerID: organizerID, currentPlayerID: organizerID)

        // When
        vm.resolve(discrepancy: discrepancy, selectedStrokeCount: 3, playerID: playerID, holeNumber: 3)

        // Then
        #expect(discrepancy.resolvedByEventID != nil)
        // The resolvedByEventID should match the resolution ScoreEvent's id
        let allEvents = try context.fetch(FetchDescriptor<ScoreEvent>())
        let resolutionEvent = allEvents.first { $0.reportedByPlayerID == organizerID }
        #expect(discrepancy.resolvedByEventID == resolutionEvent?.id)
    }

    // MARK: - AC3: resolve calls StandingsEngine.recompute with .conflictResolution trigger

    @Test("resolve calls StandingsEngine.recompute with .conflictResolution trigger")
    func test_resolve_callsStandingsRecompute_withConflictResolutionTrigger() throws {
        // Given
        let (_, context) = try makeContainer()
        let organizerID = UUID()
        let playerID = UUID().uuidString

        // Set up a minimal round so StandingsEngine can compute
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)
        context.insert(Hole(courseID: course.id, number: 1, par: 3))
        let round = Round(
            courseID: course.id,
            organizerID: organizerID,
            playerIDs: [playerID],
            guestNames: [],
            holeCount: 1
        )
        context.insert(round)
        try context.save()

        let roundID = round.id
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

        let service = ScoringService(modelContext: context, deviceID: "test-device")
        let engine = StandingsEngine(modelContext: context)
        let vm = DiscrepancyViewModel(
            scoringService: service,
            standingsEngine: engine,
            modelContext: context,
            roundID: roundID,
            organizerID: organizerID,
            currentPlayerID: organizerID
        )

        // When
        vm.resolve(discrepancy: discrepancy, selectedStrokeCount: 3, playerID: playerID, holeNumber: 1)

        // Then: StandingsEngine has a latestChange with .conflictResolution trigger
        #expect(engine.latestChange?.trigger == .conflictResolution)
    }

    // MARK: - AC5: Multiple discrepancies resolved sequentially

    @Test("multiple discrepancies can be resolved sequentially")
    func test_resolve_multipleDiscrepancies_resolvedSequentially() throws {
        // Given
        let (_, context) = try makeContainer()
        let roundID = UUID()
        let organizerID = UUID()
        let playerID = UUID().uuidString

        let e1a = makeScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3)
        let e1b = makeScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4)
        let e2a = makeScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 2)
        let e2b = makeScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 5)
        for e in [e1a, e1b, e2a, e2b] { context.insert(e) }

        let d1 = makeDiscrepancy(roundID: roundID, playerID: playerID, holeNumber: 1, eventID1: e1a.id, eventID2: e1b.id)
        let d2 = makeDiscrepancy(roundID: roundID, playerID: playerID, holeNumber: 2, eventID1: e2a.id, eventID2: e2b.id)
        context.insert(d1)
        context.insert(d2)
        try context.save()

        let vm = makeVM(context: context, roundID: roundID, organizerID: organizerID, currentPlayerID: organizerID)
        vm.loadUnresolved()
        #expect(vm.unresolvedDiscrepancies.count == 2)

        // When: resolve first discrepancy
        vm.resolve(discrepancy: d1, selectedStrokeCount: 3, playerID: playerID, holeNumber: 1)

        // Then: one remains
        #expect(vm.unresolvedDiscrepancies.count == 1)

        // When: resolve second discrepancy
        vm.resolve(discrepancy: d2, selectedStrokeCount: 5, playerID: playerID, holeNumber: 2)

        // Then: none remain
        #expect(vm.unresolvedDiscrepancies.count == 0)
    }

    // MARK: - AC5: badgeCount reflects unresolved count

    @Test("badgeCount reflects the count of unresolvedDiscrepancies")
    func test_badgeCount_reflectsUnresolvedCount() throws {
        // Given
        let (_, context) = try makeContainer()
        let roundID = UUID()
        let organizerID = UUID()
        let playerID = UUID().uuidString

        let event1 = makeScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3)
        let event2 = makeScoreEvent(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4)
        let event3 = makeScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 2)
        let event4 = makeScoreEvent(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 5)
        for e in [event1, event2, event3, event4] { context.insert(e) }

        let d1 = makeDiscrepancy(roundID: roundID, playerID: playerID, holeNumber: 1, eventID1: event1.id, eventID2: event2.id)
        let d2 = makeDiscrepancy(roundID: roundID, playerID: playerID, holeNumber: 2, eventID1: event3.id, eventID2: event4.id)
        context.insert(d1)
        context.insert(d2)
        try context.save()

        let vm = makeVM(context: context, roundID: roundID, organizerID: organizerID, currentPlayerID: organizerID)

        // Before load: no discrepancies in state
        #expect(vm.badgeCount == 0)

        // After load: 2 unresolved
        vm.loadUnresolved()
        #expect(vm.badgeCount == 2)

        // After first resolution: 1 remains
        vm.resolve(discrepancy: d1, selectedStrokeCount: 3, playerID: playerID, holeNumber: 1)
        #expect(vm.badgeCount == 1)

        // After second resolution: 0 remain
        vm.resolve(discrepancy: d2, selectedStrokeCount: 5, playerID: playerID, holeNumber: 2)
        #expect(vm.badgeCount == 0)
    }
}
