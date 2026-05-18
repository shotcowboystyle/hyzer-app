import Foundation
import SwiftUI
import SwiftData
import HyzerKit
import os.log

/// Fetches and exposes a player's personal best on a course for `PersonalBestCardView`.
///
/// Single-shot: call `compute()` once from `.task`. Matches the shape of `PlayerTrendViewModel`.
@MainActor
@Observable
final class PersonalBestViewModel {
    let playerID: String
    let courseID: UUID
    let displayTitle: String

    private(set) var best: PersonalBest?
    private(set) var errorMessage: String?
    private(set) var hasComputed: Bool = false

    var isLoading: Bool { !hasComputed && errorMessage == nil }
    var hasNoData: Bool { hasComputed && best == nil && errorMessage == nil }

    var formattedScore: String? {
        best.map { Standing.formatScore($0.scoreRelativeToPar) }
    }
    var formattedStrokes: String? {
        best.map { "\($0.totalStrokes)" }
    }
    var formattedDate: String? {
        best.map { Self.dateFormatter.string(from: $0.completedAt) }
    }
    var scoreColor: Color {
        guard let b = best else { return .textPrimary }
        if b.scoreRelativeToPar < 0 { return .scoreUnderPar }
        if b.scoreRelativeToPar == 0 { return .scoreAtPar }
        return .scoreOverPar
    }

    /// VoiceOver summary read when the card receives focus.
    /// Errors collapse to the no-data label so the spoken and visible states agree —
    /// PersonalBestCardView renders `noDataState` when `errorMessage != nil`, and the
    /// accessibility surface must tell the same story (UX-PMVP-DR5 reflective register).
    var accessibilityLabel: String {
        if isLoading { return "\(displayTitle) loading." }
        if errorMessage != nil || hasNoData { return "No rounds yet on this course." }
        guard let strokes = formattedStrokes,
              let score = formattedScore,
              let date = formattedDate else {
            return "\(displayTitle) unavailable."
        }
        return "\(displayTitle): \(strokes) strokes, \(score), on \(date)"
    }

    private let service: PersonalBestService
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "PersonalBestViewModel")

    /// Amortizes `DateFormatter` allocation across instances. Matches `HistoryListViewModel.dateFormatter` exactly.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    init(modelContext: ModelContext, playerID: String, courseID: UUID, displayTitle: String) {
        self.playerID = playerID
        self.courseID = courseID
        self.displayTitle = displayTitle
        self.service = PersonalBestService(modelContext: modelContext)
    }

    /// Fetches and computes the personal best. Called once from `.task` after the View has
    /// rendered with `isLoading == true`, so the user sees `ProgressView` while the
    /// compute pass runs. The service is `@MainActor` so the work still happens on the
    /// main actor — the async boundary exists to defer it past first paint, not to move
    /// it off-main.
    func compute() async {
        do {
            best = try service.computeBest(for: playerID, courseID: courseID)
            hasComputed = true
        } catch {
            logger.error("PersonalBestViewModel.compute failed: \(error)")
            errorMessage = "Unable to load personal best."
            hasComputed = true
        }
    }
}
