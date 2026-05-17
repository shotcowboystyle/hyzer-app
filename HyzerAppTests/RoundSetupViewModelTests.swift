import Testing
import SwiftData
import Foundation
import CloudKit
@testable import HyzerKit
@testable import HyzerApp

// MARK: - Stubs for SyncEngine construction

private struct StubCKClientForRoundTests: CloudKitClient, @unchecked Sendable {
    var savedRecords: [CKRecord] = []
    func save(_ records: [CKRecord]) async throws -> [CKRecord] { records }
    func save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws -> [CKRecord] { records }
    func fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord] { [] }
    func subscribe(to recordType: CKRecord.RecordType, predicate: NSPredicate) async throws -> CKSubscription.ID { "" }
    func deleteSubscription(_ subscriptionID: CKSubscription.ID) async throws {}
    func fetchAllSubscriptionIDs() async throws -> [CKSubscription.ID] { [] }
    func subscribeWithAlert(
        to recordType: CKRecord.RecordType,
        predicate: NSPredicate,
        subscriptionID: CKSubscription.ID,
        notificationInfo: CKSubscription.NotificationInfo
    ) async throws -> CKSubscription.ID { subscriptionID }
}

private class CapturingCKClient: CloudKitClient, @unchecked Sendable {
    private(set) var savedRecords: [CKRecord] = []
    private(set) var savedPolicies: [CKModifyRecordsOperation.RecordSavePolicy] = []
    func save(_ records: [CKRecord]) async throws -> [CKRecord] {
        savedRecords.append(contentsOf: records)
        savedPolicies.append(contentsOf: records.map { _ in .ifServerRecordUnchanged })
        return records
    }
    func save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws -> [CKRecord] {
        savedRecords.append(contentsOf: records)
        savedPolicies.append(contentsOf: records.map { _ in savePolicy })
        return records
    }
    func fetch(matching query: CKQuery, in zone: CKRecordZone.ID?) async throws -> [CKRecord] { [] }
    func subscribe(to recordType: CKRecord.RecordType, predicate: NSPredicate) async throws -> CKSubscription.ID { "" }
    func deleteSubscription(_ subscriptionID: CKSubscription.ID) async throws {}
    func fetchAllSubscriptionIDs() async throws -> [CKSubscription.ID] { [] }
    func subscribeWithAlert(
        to recordType: CKRecord.RecordType,
        predicate: NSPredicate,
        subscriptionID: CKSubscription.ID,
        notificationInfo: CKSubscription.NotificationInfo
    ) async throws -> CKSubscription.ID { subscriptionID }
}

/// Tests for RoundSetupViewModel (Story 3.1: round creation and player setup).
@Suite("RoundSetupViewModel")
@MainActor
struct RoundSetupViewModelTests {

    // MARK: - canStartRound

    @Test("canStartRound is false when no course selected")
    func test_canStartRound_noCourse_isFalse() {
        let vm = RoundSetupViewModel()
        #expect(!vm.canStartRound)
    }

    @Test("canStartRound is true when course is selected")
    func test_canStartRound_courseSelected_isTrue() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Course.self, configurations: config)
        let context = ModelContext(container)

        let course = Course(name: "Test Course", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        #expect(vm.canStartRound)
    }

    // MARK: - addPlayer / removePlayer

    @Test("addPlayer adds player to addedPlayers list")
    func test_addPlayer_addsToList() {
        let vm = RoundSetupViewModel()
        let player = Player(displayName: "Bob")

        vm.addPlayer(player)

        #expect(vm.addedPlayers.count == 1)
        #expect(vm.addedPlayers[0].id == player.id)
    }

    @Test("addPlayer does not add duplicate players")
    func test_addPlayer_noDuplicates() {
        let vm = RoundSetupViewModel()
        let player = Player(displayName: "Bob")

        vm.addPlayer(player)
        vm.addPlayer(player)

        #expect(vm.addedPlayers.count == 1)
    }

    @Test("removePlayer removes player from addedPlayers list")
    func test_removePlayer_removesFromList() {
        let vm = RoundSetupViewModel()
        let player = Player(displayName: "Bob")
        vm.addPlayer(player)

        vm.removePlayer(player)

        #expect(vm.addedPlayers.isEmpty)
    }

    // MARK: - addGuest

    @Test("addGuest trims whitespace before adding")
    func test_addGuest_trimsWhitespace() {
        let vm = RoundSetupViewModel()
        vm.guestNameInput = "  Alice  "

        vm.addGuest()

        #expect(vm.guestNames == ["Alice"])
        #expect(vm.guestNameInput.isEmpty)
    }

    @Test("addGuest rejects empty string")
    func test_addGuest_rejectsEmptyString() {
        let vm = RoundSetupViewModel()
        vm.guestNameInput = ""

        vm.addGuest()

        #expect(vm.guestNames.isEmpty)
    }

    @Test("addGuest rejects whitespace-only input")
    func test_addGuest_rejectsWhitespaceOnly() {
        let vm = RoundSetupViewModel()
        vm.guestNameInput = "   "

        vm.addGuest()

        #expect(vm.guestNames.isEmpty)
    }

    @Test("addGuest enforces max 50 character limit")
    func test_addGuest_enforces50CharLimit() {
        let vm = RoundSetupViewModel()
        let longName = String(repeating: "A", count: 60)
        vm.guestNameInput = longName

        vm.addGuest()

        #expect(vm.guestNames.count == 1)
        #expect(vm.guestNames[0].count == 50)
    }

    @Test("addGuest accepts exactly 50 characters")
    func test_addGuest_accepts50Chars() {
        let vm = RoundSetupViewModel()
        let exactName = String(repeating: "B", count: 50)
        vm.guestNameInput = exactName

        vm.addGuest()

        #expect(vm.guestNames.count == 1)
        #expect(vm.guestNames[0].count == 50)
    }

    @Test("addGuest clears guestNameInput after adding")
    func test_addGuest_clearsInput() {
        let vm = RoundSetupViewModel()
        vm.guestNameInput = "Charlie"

        vm.addGuest()

        #expect(vm.guestNameInput.isEmpty)
    }

    // MARK: - removeGuest

    @Test("removeGuest removes guest at specified index")
    func test_removeGuest_removesAtIndex() {
        let vm = RoundSetupViewModel()
        vm.guestNames = ["Alice", "Bob", "Charlie"]

        vm.removeGuest(at: IndexSet(integer: 1))

        #expect(vm.guestNames == ["Alice", "Charlie"])
    }

    @Test("addGuest rejects duplicate guest name")
    func test_addGuest_rejectsDuplicateName() {
        let vm = RoundSetupViewModel()
        vm.guestNameInput = "Alice"
        vm.addGuest()
        vm.guestNameInput = "Alice"
        vm.addGuest()

        #expect(vm.guestNames.count == 1)
    }

    // MARK: - startRound helpers

    /// Container schema includes SyncMetadata so SyncEngine can persist metadata entries.
    private func makeStartRoundContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, SyncMetadata.self, configurations: config)
    }

    private func makeSyncEngine(container: ModelContainer, ckClient: any CloudKitClient = StubCKClientForRoundTests()) -> SyncEngine {
        let standings = StandingsEngine(modelContext: container.mainContext)
        return SyncEngine(cloudKitClient: ckClient, standingsEngine: standings, modelContainer: container)
    }

    // MARK: - startRound

    @Test("startRound creates Round with correct courseID and organizerID")
    func test_startRound_createsRoundWithCorrectIDs() throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        try vm.startRound(organizer: organizer, in: context, syncEngine: makeSyncEngine(container: container))

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds.count == 1)
        #expect(rounds[0].courseID == course.id)
        #expect(rounds[0].organizerID == organizer.id)
    }

    @Test("startRound sets round status to active with non-nil startedAt")
    func test_startRound_setsActiveStatusWithStartedAt() throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        try vm.startRound(organizer: organizer, in: context, syncEngine: makeSyncEngine(container: container))

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].status == "active")
        #expect(rounds[0].startedAt != nil)
    }

    @Test("startRound includes organizer in playerIDs even if not explicitly added")
    func test_startRound_includesOrganizerInPlayerIDs() throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        // Do NOT explicitly add organizer
        try vm.startRound(organizer: organizer, in: context, syncEngine: makeSyncEngine(container: container))

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].playerIDs.contains(organizer.id.uuidString))
    }

    @Test("startRound includes playerIDs for all added players")
    func test_startRound_includesAddedPlayers() throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        let player2 = Player(displayName: "Sam")
        context.insert(organizer)
        context.insert(player2)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        vm.addPlayer(player2)
        try vm.startRound(organizer: organizer, in: context, syncEngine: makeSyncEngine(container: container))

        let rounds = try context.fetch(FetchDescriptor<Round>())
        let playerIDs = rounds[0].playerIDs
        #expect(playerIDs.contains(organizer.id.uuidString))
        #expect(playerIDs.contains(player2.id.uuidString))
        #expect(playerIDs.count == 2)
    }

    @Test("startRound includes guestNames in the round")
    func test_startRound_includesGuestNames() throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        vm.guestNames = ["Alice Guest", "Bob Guest"]
        try vm.startRound(organizer: organizer, in: context, syncEngine: makeSyncEngine(container: container))

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].guestNames == ["Alice Guest", "Bob Guest"])
    }

    @Test("startRound does not add organizer twice if organizer is also in addedPlayers")
    func test_startRound_noOrganizerDuplicate() throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        vm.addPlayer(organizer) // Organizer explicitly added — should not duplicate
        try vm.startRound(organizer: organizer, in: context, syncEngine: makeSyncEngine(container: container))

        let rounds = try context.fetch(FetchDescriptor<Round>())
        let organizerIDString = organizer.id.uuidString
        let count = rounds[0].playerIDs.filter { $0 == organizerIDString }.count
        #expect(count == 1)
    }

    @Test("startRound denormalizes holeCount from course")
    func test_startRound_denormalizesHoleCount() throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "9 Hole Course", holeCount: 9)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        try vm.startRound(organizer: organizer, in: context, syncEngine: makeSyncEngine(container: container))

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].holeCount == 9)
    }

    // MARK: - pushRound assertion (Story 12.1, Task 8.6)

    @Test("startRound triggers exactly one pushRound call with correct organizerFirstName and courseName")
    @MainActor
    func test_startRound_triggersOneRoundPushWithCorrectFields() async throws {
        let container = try makeStartRoundContainer()
        let context = ModelContext(container)
        let capturingCK = CapturingCKClient()

        let organizer = Player(displayName: "Mike Jones")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let syncEngine = makeSyncEngine(container: container, ckClient: capturingCK)
        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        try vm.startRound(organizer: organizer, in: context, syncEngine: syncEngine)

        // Wait for the fire-and-forget Task to complete
        await awaitCondition(timeout: .seconds(3)) {
            !capturingCK.savedRecords.isEmpty
        }

        #expect(capturingCK.savedRecords.count == 1)
        let record = capturingCK.savedRecords.first
        #expect(record?.recordType == "Round")
        // organizerFirstName must be the first token only (PII gate)
        #expect(record?["organizerFirstName"] as? String == "Mike")
        #expect(record?["courseName"] as? String == "Cedar Creek")
        #expect(record?["status"] as? String == "active")
    }

    // MARK: - loadPreviousRoundPlayers (Story 10.1)

    private func makeContainer10_1() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Player.self, Course.self, Round.self, configurations: config)
    }

    private func insertCompletedRound(
        context: ModelContext,
        playerIDs: [String],
        guestNames: [String] = [],
        completedAt: Date = Date()
    ) -> Round {
        let round = Round(
            courseID: UUID(),
            organizerID: UUID(),
            playerIDs: playerIDs,
            guestNames: guestNames,
            holeCount: 18
        )
        round.start()
        round.awaitFinalization()
        round.complete()
        round.completedAt = completedAt
        context.insert(round)
        return round
    }

    @Test("loadPreviousRoundPlayers: completed round with user populates preview")
    func test_loadPreviousRoundPlayers_withCompletedRound_populatesPreview() throws {
        let container = try makeContainer10_1()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Organizer")
        let other = Player(displayName: "Other")
        context.insert(organizer)
        context.insert(other)
        _ = insertCompletedRound(
            context: context,
            playerIDs: [organizer.id.uuidString, other.id.uuidString]
        )
        try context.save()

        let vm = RoundSetupViewModel()
        vm.loadPreviousRoundPlayers(currentUserID: organizer.id, modelContext: context)

        #expect(vm.previousRoundPreview != nil)
        #expect(vm.previousRoundPreview?.registeredPlayers.count == 1)
        #expect(vm.previousRoundPreview?.registeredPlayers.first?.id == other.id)
    }

    @Test("loadPreviousRoundPlayers: no completed rounds yields nil preview")
    func test_loadPreviousRoundPlayers_noCompletedRounds_previewIsNil() throws {
        let container = try makeContainer10_1()
        let context = ModelContext(container)
        let organizer = Player(displayName: "Solo")
        context.insert(organizer)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.loadPreviousRoundPlayers(currentUserID: organizer.id, modelContext: context)

        #expect(vm.previousRoundPreview == nil)
    }

    @Test("loadPreviousRoundPlayers: completed round where user is not participant yields nil")
    func test_loadPreviousRoundPlayers_completedRoundUserNotParticipant_previewIsNil() throws {
        let container = try makeContainer10_1()
        let context = ModelContext(container)

        let user = Player(displayName: "User")
        let other = Player(displayName: "Other")
        context.insert(user)
        context.insert(other)
        // Round does NOT include user
        _ = insertCompletedRound(context: context, playerIDs: [other.id.uuidString])
        try context.save()

        let vm = RoundSetupViewModel()
        vm.loadPreviousRoundPlayers(currentUserID: user.id, modelContext: context)

        #expect(vm.previousRoundPreview == nil)
    }

    @Test("loadPreviousRoundPlayers: picks most recent completed round by completedAt")
    func test_loadPreviousRoundPlayers_picksMostRecent_byCompletedAtDesc() throws {
        let container = try makeContainer10_1()
        let context = ModelContext(container)

        let user = Player(displayName: "User")
        let playerA = Player(displayName: "Older")
        let playerB = Player(displayName: "Newer")
        context.insert(user)
        context.insert(playerA)
        context.insert(playerB)

        let older = Date(timeIntervalSinceNow: -7200)
        let newer = Date(timeIntervalSinceNow: -3600)
        _ = insertCompletedRound(context: context, playerIDs: [user.id.uuidString, playerA.id.uuidString], completedAt: older)
        _ = insertCompletedRound(context: context, playerIDs: [user.id.uuidString, playerB.id.uuidString], completedAt: newer)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.loadPreviousRoundPlayers(currentUserID: user.id, modelContext: context)

        #expect(vm.previousRoundPreview?.registeredPlayers.first?.id == playerB.id)
    }

    @Test("applyPreviousRoundPlayers: adds registered players (not organizer) and guests")
    func test_applyPreviousRoundPlayers_appendsRegisteredAndGuestEntries_excludesOrganizer() throws {
        let container = try makeContainer10_1()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Org")
        let player2 = Player(displayName: "P2")
        let player3 = Player(displayName: "P3")
        context.insert(organizer)
        context.insert(player2)
        context.insert(player3)
        _ = insertCompletedRound(
            context: context,
            playerIDs: [organizer.id.uuidString, player2.id.uuidString, player3.id.uuidString],
            guestNames: ["GuestA"]
        )
        try context.save()

        let vm = RoundSetupViewModel()
        vm.loadPreviousRoundPlayers(currentUserID: organizer.id, modelContext: context)
        vm.applyPreviousRoundPlayers(organizer: organizer)

        #expect(vm.addedPlayers.count == 2)
        #expect(!vm.addedPlayers.contains(where: { $0.id == organizer.id }))
        #expect(vm.guestNames == ["GuestA"])
    }

    @Test("applyPreviousRoundPlayers: does not duplicate already-added players")
    func test_applyPreviousRoundPlayers_doesNotDuplicateAlreadyAddedPlayers() throws {
        let container = try makeContainer10_1()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Org")
        let player2 = Player(displayName: "P2")
        context.insert(organizer)
        context.insert(player2)
        _ = insertCompletedRound(context: context, playerIDs: [organizer.id.uuidString, player2.id.uuidString])
        try context.save()

        let vm = RoundSetupViewModel()
        vm.addPlayer(player2)  // manually added before apply
        vm.loadPreviousRoundPlayers(currentUserID: organizer.id, modelContext: context)
        vm.applyPreviousRoundPlayers(organizer: organizer)

        #expect(vm.addedPlayers.filter({ $0.id == player2.id }).count == 1)
    }

    @Test("applyPreviousRoundPlayers: appends guest names verbatim without deduplication (FR12b)")
    func test_applyPreviousRoundPlayers_appendsGuestsAsNewEntries_noGuestDeduplication() throws {
        let container = try makeContainer10_1()
        let context = ModelContext(container)

        let organizer = Player(displayName: "Org")
        context.insert(organizer)
        _ = insertCompletedRound(context: context, playerIDs: [organizer.id.uuidString], guestNames: ["Alice"])
        try context.save()

        let vm = RoundSetupViewModel()
        vm.guestNames = ["Alice"]  // already in the list
        vm.loadPreviousRoundPlayers(currentUserID: organizer.id, modelContext: context)
        vm.applyPreviousRoundPlayers(organizer: organizer)

        // FR12b: guests are round-scoped, no cross-round dedup
        #expect(vm.guestNames == ["Alice", "Alice"])
    }
}
