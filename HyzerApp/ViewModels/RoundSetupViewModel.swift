import Foundation
import SwiftData
import HyzerKit

// MARK: - Supporting types

struct PreviousRoundPreview {
    let registeredPlayers: [Player]
    let guestNames: [String]
    var totalCount: Int { registeredPlayers.count + guestNames.count }
}

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
    var previousRoundPreview: PreviousRoundPreview?

    // MARK: - Computed

    /// True when a course is selected and at least one participant exists
    /// (the organizer counts, so this is true whenever a course is selected).
    var canStartRound: Bool {
        selectedCourse != nil
    }

    var canShowSameGroupButton: Bool {
        guard let preview = previousRoundPreview else { return false }
        return preview.totalCount > 0
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

    // MARK: - Previous round quick-add

    /// Loads player data from the most recent completed round the current user participated in.
    /// Receives ModelContext at call time — not via constructor — matching the CourseEditorViewModel pattern.
    func loadPreviousRoundPlayers(currentUserID: UUID, modelContext: ModelContext) {
        let statusValue = "completed"
        var descriptor = FetchDescriptor<Round>(
            predicate: #Predicate { $0.status == statusValue },
            sortBy: [SortDescriptor(\Round.completedAt, order: .reverse)]
        )
        // Fetch a larger window to ensure we find a round the user participated in
        descriptor.fetchLimit = 20
        let recentCompleted: [Round]
        do {
            recentCompleted = try modelContext.fetch(descriptor)
        } catch {
            // Safe to continue: preview is optional, failure leaves it nil
            previousRoundPreview = nil
            return
        }
        let userIDString = currentUserID.uuidString
        guard let round = recentCompleted.first(where: { $0.playerIDs.contains(userIDString) }) else {
            previousRoundPreview = nil
            return
        }
        let otherPlayerUUIDs = round.playerIDs
            .filter { $0 != userIDString }
            .compactMap { UUID(uuidString: $0) }
        let players: [Player]
        do {
            if otherPlayerUUIDs.isEmpty {
                players = []
            } else {
                var playerDescriptor = FetchDescriptor<Player>(
                    predicate: #Predicate { otherPlayerUUIDs.contains($0.id) }
                )
                playerDescriptor.fetchLimit = otherPlayerUUIDs.count
                players = try modelContext.fetch(playerDescriptor)
            }
        } catch {
            // Safe to continue: preview is optional, failure leaves it nil
            previousRoundPreview = nil
            return
        }
        previousRoundPreview = PreviousRoundPreview(
            registeredPlayers: players,
            guestNames: round.guestNames
        )
    }

    /// Applies the previous round's players to the current setup, then clears the preview (idempotent).
    func applyPreviousRoundPlayers(organizer: Player) {
        guard let preview = previousRoundPreview else { return }
        for player in preview.registeredPlayers where player.id != organizer.id {
            addPlayer(player)
        }
        guestNames.append(contentsOf: preview.guestNames)
        previousRoundPreview = nil
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
