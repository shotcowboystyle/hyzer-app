import Testing
import SwiftData
import Foundation
@testable import HyzerKit
@testable import HyzerApp

/// Tests for HistoryListViewModel story 11.1 additions: userIsWinner flag, ordinal helper,
/// and updated accessibility label format.
@Suite("HistoryListViewModel — Story 11.1 Polish")
@MainActor
struct HistoryListViewModelTests {

    // MARK: - Container

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Player.self, Course.self, Hole.self, Round.self, ScoreEvent.self,
            configurations: config
        )
    }

    private func insertCompletedRound(
        context: ModelContext,
        course: Course,
        playerIDs: [String],
        strokesPerPlayer: [String: Int],
        parPerHole: Int = 3,
        holeCount: Int = 9
    ) throws -> Round {
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: playerIDs,
            guestNames: [],
            holeCount: holeCount
        )
        context.insert(round)
        round.start()
        round.awaitFinalization()
        round.complete()

        for holeNum in 1...holeCount {
            let hole = Hole(courseID: course.id, number: holeNum, par: parPerHole)
            context.insert(hole)
            for playerID in playerIDs {
                let strokes = strokesPerPlayer[playerID] ?? parPerHole
                context.insert(ScoreEvent(
                    roundID: round.id,
                    holeNumber: holeNum,
                    playerID: playerID,
                    strokeCount: strokes,
                    reportedByPlayerID: UUID(),
                    deviceID: "test"
                ))
            }
        }
        try context.save()
        return round
    }

    // MARK: - userIsWinner (AC: 3)

    @Test("userIsWinner is true when current user has the best score")
    func test_ensureCardData_userIsWinner_whenCurrentUserIsTopPlayer() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let winner = Player(displayName: "Winner")
        let loser = Player(displayName: "Loser")
        context.insert(winner)
        context.insert(loser)

        let course = Course(name: "Test Course", holeCount: 9)
        context.insert(course)

        let round = try insertCompletedRound(
            context: context,
            course: course,
            playerIDs: [winner.id.uuidString, loser.id.uuidString],
            strokesPerPlayer: [winner.id.uuidString: 2, loser.id.uuidString: 4]
        )

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: winner.id.uuidString)
        vm.ensureCardData(for: round)

        #expect(vm.cardDataCache[round.id]?.userIsWinner == true)
    }

    @Test("userIsWinner is false when another player has the best score")
    func test_ensureCardData_userIsNotWinner_whenAnotherPlayerIsTop() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let winner = Player(displayName: "Winner")
        let loser = Player(displayName: "Loser")
        context.insert(winner)
        context.insert(loser)

        let course = Course(name: "Test Course", holeCount: 9)
        context.insert(course)

        let round = try insertCompletedRound(
            context: context,
            course: course,
            playerIDs: [winner.id.uuidString, loser.id.uuidString],
            strokesPerPlayer: [winner.id.uuidString: 2, loser.id.uuidString: 4]
        )

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: loser.id.uuidString)
        vm.ensureCardData(for: round)

        #expect(vm.cardDataCache[round.id]?.userIsWinner == false)
    }

    // MARK: - ordinal formatting (AC: 1)

    @Test("ordinal: 1 → 1st")
    func test_ordinal_1st() throws {
        let container = try makeContainer()
        let vm = HistoryListViewModel(modelContext: ModelContext(container), currentPlayerID: "x")
        #expect(vm.ordinal(1) == "1st")
    }

    @Test("ordinal: 2 → 2nd")
    func test_ordinal_2nd() throws {
        let container = try makeContainer()
        let vm = HistoryListViewModel(modelContext: ModelContext(container), currentPlayerID: "x")
        #expect(vm.ordinal(2) == "2nd")
    }

    @Test("ordinal: 3 → 3rd")
    func test_ordinal_3rd() throws {
        let container = try makeContainer()
        let vm = HistoryListViewModel(modelContext: ModelContext(container), currentPlayerID: "x")
        #expect(vm.ordinal(3) == "3rd")
    }

    @Test("ordinal: 4 → 4th")
    func test_ordinal_4th() throws {
        let container = try makeContainer()
        let vm = HistoryListViewModel(modelContext: ModelContext(container), currentPlayerID: "x")
        #expect(vm.ordinal(4) == "4th")
    }

    @Test("ordinal: 11 → 11th")
    func test_ordinal_11th() throws {
        let container = try makeContainer()
        let vm = HistoryListViewModel(modelContext: ModelContext(container), currentPlayerID: "x")
        #expect(vm.ordinal(11) == "11th")
    }

    @Test("ordinal: 21 → 21st")
    func test_ordinal_21st() throws {
        let container = try makeContainer()
        let vm = HistoryListViewModel(modelContext: ModelContext(container), currentPlayerID: "x")
        #expect(vm.ordinal(21) == "21st")
    }

    // MARK: - Accessibility label format (AC: 4)

    @Test("Accessibility label for winner case collapses to You won format")
    func test_accessibilityLabel_winnerCase_collapsedFormat() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let player = Player(displayName: "Champion")
        context.insert(player)
        let course = Course(name: "Eagle Ridge", holeCount: 9)
        context.insert(course)

        let round = try insertCompletedRound(
            context: context,
            course: course,
            playerIDs: [player.id.uuidString],
            strokesPerPlayer: [player.id.uuidString: 2]
        )

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: player.id.uuidString)
        vm.ensureCardData(for: round)

        guard let data = vm.cardDataCache[round.id] else {
            Issue.record("Card data not populated")
            return
        }

        #expect(data.userIsWinner == true)
        // Accessibility label should start with course + date and contain "You won"
        let label = accessibilityLabel(data: data)
        #expect(label.contains("Eagle Ridge"))
        #expect(label.contains("You won"))
        #expect(!label.contains("You finished"))
    }

    @Test("Accessibility label for non-winner shows winner name and user position")
    func test_accessibilityLabel_nonWinnerCase_bothLines() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let winner = Player(displayName: "TopDog")
        let currentUser = Player(displayName: "RunnerUp")
        context.insert(winner)
        context.insert(currentUser)
        let course = Course(name: "Pine Valley", holeCount: 9)
        context.insert(course)

        let round = try insertCompletedRound(
            context: context,
            course: course,
            playerIDs: [winner.id.uuidString, currentUser.id.uuidString],
            strokesPerPlayer: [winner.id.uuidString: 2, currentUser.id.uuidString: 4]
        )

        let vm = HistoryListViewModel(modelContext: context, currentPlayerID: currentUser.id.uuidString)
        vm.ensureCardData(for: round)

        guard let data = vm.cardDataCache[round.id] else {
            Issue.record("Card data not populated")
            return
        }

        #expect(data.userIsWinner == false)
        let label = accessibilityLabel(data: data)
        #expect(label.contains("TopDog won"))
        #expect(label.contains("You finished"))
        #expect(!label.contains("You won at"))
    }
}

// MARK: - Mirrors HistoryRoundCard.accessibilityLabel (private in the view; tested here independently)

private func accessibilityLabel(data: HistoryRoundCardData) -> String {
    if data.userIsWinner {
        let scoreSuffix = data.winnerFormattedScore.map { " at \($0)" } ?? ""
        return "\(data.courseName), \(data.formattedDate). You won\(scoreSuffix)."
    }
    var parts: [String] = ["\(data.courseName), \(data.formattedDate)."]
    if let name = data.winnerName {
        parts.append("\(name) won.")
    }
    if let position = data.userPosition {
        parts.append("You finished \(position).")
    }
    return parts.joined(separator: " ")
}
