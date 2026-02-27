import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

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

    // MARK: - startRound

    @Test("startRound creates Round with correct courseID and organizerID")
    func test_startRound_createsRoundWithCorrectIDs() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        try vm.startRound(organizer: organizer, in: context)

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds.count == 1)
        #expect(rounds[0].courseID == course.id)
        #expect(rounds[0].organizerID == organizer.id)
    }

    @Test("startRound sets round status to active with non-nil startedAt")
    func test_startRound_setsActiveStatusWithStartedAt() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        try vm.startRound(organizer: organizer, in: context)

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].status == "active")
        #expect(rounds[0].startedAt != nil)
    }

    @Test("startRound includes organizer in playerIDs even if not explicitly added")
    func test_startRound_includesOrganizerInPlayerIDs() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        // Do NOT explicitly add organizer
        try vm.startRound(organizer: organizer, in: context)

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].playerIDs.contains(organizer.id.uuidString))
    }

    @Test("startRound includes playerIDs for all added players")
    func test_startRound_includesAddedPlayers() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
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
        try vm.startRound(organizer: organizer, in: context)

        let rounds = try context.fetch(FetchDescriptor<Round>())
        let playerIDs = rounds[0].playerIDs
        #expect(playerIDs.contains(organizer.id.uuidString))
        #expect(playerIDs.contains(player2.id.uuidString))
        #expect(playerIDs.count == 2)
    }

    @Test("startRound includes guestNames in the round")
    func test_startRound_includesGuestNames() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        vm.guestNames = ["Alice Guest", "Bob Guest"]
        try vm.startRound(organizer: organizer, in: context)

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].guestNames == ["Alice Guest", "Bob Guest"])
    }

    @Test("startRound does not add organizer twice if organizer is also in addedPlayers")
    func test_startRound_noOrganizerDuplicate() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "Cedar Creek", holeCount: 18)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        vm.addPlayer(organizer) // Organizer explicitly added — should not duplicate
        try vm.startRound(organizer: organizer, in: context)

        let rounds = try context.fetch(FetchDescriptor<Round>())
        let organizerIDString = organizer.id.uuidString
        let count = rounds[0].playerIDs.filter { $0 == organizerIDString }.count
        #expect(count == 1)
    }

    @Test("startRound denormalizes holeCount from course")
    func test_startRound_denormalizesHoleCount() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, Course.self, Hole.self, Round.self, configurations: config)
        let context = ModelContext(container)

        let organizer = Player(displayName: "Nate")
        context.insert(organizer)
        let course = Course(name: "9 Hole Course", holeCount: 9)
        context.insert(course)
        try context.save()

        let vm = RoundSetupViewModel()
        vm.selectedCourse = course
        try vm.startRound(organizer: organizer, in: context)

        let rounds = try context.fetch(FetchDescriptor<Round>())
        #expect(rounds[0].holeCount == 9)
    }
}
