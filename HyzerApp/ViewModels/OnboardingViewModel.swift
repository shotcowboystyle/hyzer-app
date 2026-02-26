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

    var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "Onboarding")

    /// Persists a new `Player` to SwiftData. No network calls. No iCloud check (Story 1.2).
    func savePlayer(in context: ModelContext) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let player = Player(displayName: trimmed)
        context.insert(player)

        do {
            try context.save()
        } catch {
            logger.error("Failed to save player: \(error)")
            // Safe to surface: error will be visible when @Query returns no results
        }
    }
}
