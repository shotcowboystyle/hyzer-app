import Foundation
import SwiftData
import HyzerKit

/// Handles business logic for the round setup flow: course selection, player management,
/// guest addition, and round creation.
///
/// Receives `ModelContext` at save time — not via constructor — matching the
/// `CourseEditorViewModel` pattern.
@MainActor
@Observable
final class RoundSetupViewModel {
    var selectedCourse: Course?
    var addedPlayers: [Player] = []
    var guestNames: [String] = []
    var guestNameInput: String = ""
    var saveError: Error?

    // MARK: - Computed

    /// True when a course is selected and at least one participant exists
    /// (the organizer counts, so this is true whenever a course is selected).
    var canStartRound: Bool {
        selectedCourse != nil
    }

    // MARK: - Player management

    func addPlayer(_ player: Player) {
        guard !addedPlayers.contains(where: { $0.id == player.id }) else { return }
        addedPlayers.append(player)
    }

    func removePlayer(_ player: Player) {
        addedPlayers.removeAll { $0.id == player.id }
    }

    // MARK: - Guest management

    /// Trims whitespace, rejects empty strings, and enforces max 50 characters.
    func addGuest() {
        let trimmed = guestNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = String(trimmed.prefix(50))
        guard !guestNames.contains(name) else { return }
        guestNames.append(name)
        guestNameInput = ""
    }

    func removeGuest(at offsets: IndexSet) {
        guestNames.remove(atOffsets: offsets)
    }

    // MARK: - Round creation

    /// Creates a Round in SwiftData with the organizer as the default participant.
    ///
    /// The organizer is always included in `playerIDs` (FR16).
    /// Calls `round.start()` to transition from "setup" to "active".
    ///
    /// - Parameters:
    ///   - organizer: The current user's Player record.
    ///   - context: The SwiftData `ModelContext` for persistence.
    func startRound(organizer: Player, in context: ModelContext) throws {
        precondition(canStartRound, "startRound called when canStartRound is false")
        guard let course = selectedCourse else { return }

        // Organizer is always a participant (FR16). Added players are additional participants.
        var allPlayerIDs: [String] = [organizer.id.uuidString]
        for player in addedPlayers where player.id != organizer.id {
            allPlayerIDs.append(player.id.uuidString)
        }

        let round = Round(
            courseID: course.id,
            organizerID: organizer.id,
            playerIDs: allPlayerIDs,
            guestNames: guestNames,
            holeCount: course.holeCount
        )
        context.insert(round)
        round.start()
        try context.save()
    }
}
