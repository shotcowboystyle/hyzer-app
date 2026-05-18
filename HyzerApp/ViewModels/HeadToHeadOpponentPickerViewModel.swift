import Foundation
import SwiftData
import HyzerKit
import os.log

/// Loads and exposes opponent candidates for the head-to-head picker sheet.
///
/// Single-shot: call `loadCandidates()` once from `.task`. Separate from `HeadToHeadViewModel`
/// because the picker has distinct state (a candidate list vs a computed record).
@MainActor
@Observable
final class HeadToHeadOpponentPickerViewModel {
    let playerAID: String

    private(set) var candidates: [HeadToHeadCandidate] = []
    private(set) var errorMessage: String?
    private(set) var hasComputed: Bool = false

    var isLoading: Bool { !hasComputed && errorMessage == nil }
    var hasNoCandidates: Bool { hasComputed && candidates.isEmpty && errorMessage == nil }
    var hasError: Bool { errorMessage != nil }

    private let service: HeadToHeadServicing
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "HeadToHeadOpponentPickerViewModel")

    init(modelContext: ModelContext, playerAID: String) {
        self.playerAID = playerAID
        self.service = HeadToHeadService(modelContext: modelContext)
    }

    /// Testing injection initializer. NOT used in production.
    init(service: HeadToHeadServicing, playerAID: String) {
        self.playerAID = playerAID
        self.service = service
    }

    /// Loads opponent candidates. Called once from `.task` after the sheet has rendered
    /// with `isLoading == true`, so the user sees `ProgressView` while the fetch runs.
    func loadCandidates() async {
        errorMessage = nil
        hasComputed = false
        candidates = []
        do {
            candidates = try service.findOpponentCandidates(for: playerAID, maxRounds: 500)
            hasComputed = true
        } catch {
            logger.error("HeadToHeadOpponentPickerViewModel.loadCandidates failed: \(error)")
            errorMessage = "Unable to load opponents."
            hasComputed = true
        }
    }

    /// Secondary label copy for picker rows (AC #5).
    static func roundsTogetherCopy(_ count: Int) -> String {
        count == 1 ? "1 round together" : "\(count) rounds together"
    }
}
