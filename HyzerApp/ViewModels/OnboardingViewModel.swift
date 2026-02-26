import Foundation
import SwiftData
import os
import HyzerKit

/// Handles business logic for the onboarding flow.
///
/// Receives `ModelContext` at the time of save — not via constructor — so it can be
/// initialized as `@State` in SwiftUI before the environment is available.
@MainActor
@Observable
final class OnboardingViewModel {
    var displayName: String = ""

    /// Maximum characters allowed for a display name.
    static let maxDisplayNameLength = 50

    var canContinue: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= Self.maxDisplayNameLength
    }

    var isOverMaxLength: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).count > Self.maxDisplayNameLength
    }

    /// Error surfaced to the view if SwiftData save fails.
    var saveError: Error?

    private var hasSaved = false
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "Onboarding")

    /// Persists a new `Player` to SwiftData. No network calls. No iCloud check (Story 1.2).
    func savePlayer(in context: ModelContext) {
        guard !hasSaved else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxDisplayNameLength else { return }

        let player = Player(displayName: trimmed)
        context.insert(player)

        do {
            try context.save()
            hasSaved = true
        } catch {
            logger.error("Failed to save player: \(error)")
            context.rollback()
            saveError = error
        }
    }
}
