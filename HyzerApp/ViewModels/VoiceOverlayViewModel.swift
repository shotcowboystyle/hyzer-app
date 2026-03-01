import Foundation
import Observation
import HyzerKit

/// Drives the voice confirmation overlay UX.
///
/// Lifecycle: `startListening()` → recognition → parsing → `.confirming` state →
/// 1.5s auto-commit timer → `commitScores()` → `.committed`.
///
/// Injected into `ScorecardContainerView` when the user taps the mic button.
/// Lives in `HyzerApp/` — depends on `VoiceRecognitionServiceProtocol` which
/// references iOS Speech framework behaviour.
@MainActor
@Observable
final class VoiceOverlayViewModel {

    // MARK: - State

    enum State {
        case idle
        case listening
        case confirming([ScoreCandidate])
        case partial(recognized: [ScoreCandidate], unresolved: [UnresolvedCandidate])
        case failed(transcript: String)
        case committed
        case dismissed
        case error(VoiceParseError)
    }

    private(set) var state: State = .idle

    /// `true` after `commitScores()` completes successfully. Equatable for SwiftUI `onChange`.
    private(set) var isCommitted: Bool = false

    /// `true` once the overlay reaches a terminal state (committed, dismissed, or error).
    /// Equatable for SwiftUI `onChange` — use this to drive overlay dismissal.
    private(set) var isTerminated: Bool = false

    /// Incremented each time `startAutoCommitTimer()` is called.
    /// The view observes this to reset the progress bar animation on timer restarts.
    private(set) var timerResetCount: Int = 0

    // MARK: - Dependencies

    // nonisolated(unsafe): deinit is nonisolated in Swift 6; we need to capture the service
    // to call stopListening() inside a @MainActor Task hop during cleanup.
    // All actual usage of these properties happens on @MainActor.
    nonisolated(unsafe) private let voiceRecognitionService: any VoiceRecognitionServiceProtocol
    private let scoringService: ScoringService
    private let parser: VoiceParser
    private let roundID: UUID
    private let holeNumber: Int
    private let reportedByPlayerID: UUID
    private let players: [VoicePlayerEntry]

    /// All players in the round, exposed for the unresolved-entry picker.
    private(set) var availablePlayers: [VoicePlayerEntry]

    /// Players eligible for the unresolved-entry picker — excludes players already
    /// in the recognized list to prevent duplicate ScoreEvent creation.
    var pickablePlayers: [VoicePlayerEntry] {
        guard case .partial(let recognized, _) = state else { return availablePlayers }
        let resolvedIDs = Set(recognized.map(\.playerID))
        return availablePlayers.filter { !resolvedIDs.contains($0.playerID) }
    }

    // MARK: - Timer

    // nonisolated(unsafe): allows deinit to call cancel() without a main-actor hop.
    // All writes happen on @MainActor; deinit only calls cancel().
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    /// When `true` (VoiceOver focus on overlay), the auto-commit timer is paused.
    var isVoiceOverFocused: Bool = false {
        didSet {
            if isVoiceOverFocused {
                timerTask?.cancel()
                timerTask = nil
            } else if case .confirming = state {
                startAutoCommitTimer()
            }
        }
    }

    // MARK: - Init

    init(
        voiceRecognitionService: any VoiceRecognitionServiceProtocol,
        scoringService: ScoringService,
        parser: VoiceParser,
        roundID: UUID,
        holeNumber: Int,
        reportedByPlayerID: UUID,
        players: [VoicePlayerEntry]
    ) {
        self.voiceRecognitionService = voiceRecognitionService
        self.scoringService = scoringService
        self.parser = parser
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.reportedByPlayerID = reportedByPlayerID
        self.players = players
        self.availablePlayers = players
    }

    // MARK: - Public Interface

    /// Begins listening and parses the resulting transcript.
    ///
    /// On `.success`, transitions to `.confirming` and starts the auto-commit timer.
    /// On `.partial`, only the resolved candidates are shown.
    /// On `.failed` or thrown error, transitions to `.error`.
    func startListening() {
        state = .listening
        Task { [weak self] in
            guard let self else { return }
            do {
                let transcript = try await voiceRecognitionService.recognize()
                let result = parser.parse(transcript: transcript, players: players)
                switch result {
                case .success(let candidates):
                    state = .confirming(candidates)
                    if !isVoiceOverFocused {
                        startAutoCommitTimer()
                    }
                case .partial(let recognized, let unresolved):
                    state = .partial(recognized: recognized, unresolved: unresolved)
                    // No timer — user must resolve all unresolved entries first
                case .failed(let transcript):
                    state = .failed(transcript: transcript)
                    // isTerminated stays false — retry is available
                }
            } catch let error as VoiceParseError {
                state = .error(error)
                isTerminated = true
            } catch {
                state = .error(.recognitionUnavailable)
                isTerminated = true
            }
        }
    }

    /// Updates a score candidate at `index` and resets the auto-commit timer to 1.5s.
    func correctScore(at index: Int, newStrokeCount: Int) {
        guard case .confirming(var candidates) = state else { return }
        guard candidates.indices.contains(index) else { return }
        candidates[index] = ScoreCandidate(
            playerID: candidates[index].playerID,
            displayName: candidates[index].displayName,
            strokeCount: newStrokeCount
        )
        state = .confirming(candidates)
        if !isVoiceOverFocused {
            startAutoCommitTimer()
        }
    }

    /// Commits all confirmed candidates as ScoreEvents via `ScoringService`.
    func commitScores() {
        timerTask?.cancel()
        timerTask = nil
        guard case .confirming(let candidates) = state else { return }
        do {
            for candidate in candidates {
                try scoringService.createScoreEvent(
                    roundID: roundID,
                    holeNumber: holeNumber,
                    playerID: candidate.playerID,
                    strokeCount: candidate.strokeCount,
                    reportedByPlayerID: reportedByPlayerID
                )
            }
            state = .committed
            isCommitted = true
            isTerminated = true
        } catch {
            // Persistence error from ScoringService — mapped to .recognitionUnavailable
            // because VoiceParseError (HyzerKit) has no persistence case.
            // The overlay shows a generic error; user can retry voice entry.
            state = .error(.recognitionUnavailable)
            isTerminated = true
        }
    }

    /// Cancels the overlay: stops listening, cancels the timer, and sets state to `.dismissed`.
    func cancel() {
        timerTask?.cancel()
        timerTask = nil
        voiceRecognitionService.stopListening()
        state = .dismissed
        isTerminated = true
    }

    /// Resolves an unresolved entry by assigning it to the selected player.
    ///
    /// The resolved `ScoreCandidate` retains the parser's stroke count — the user corrects
    /// only if the stroke count is wrong, not reset to par or zero.
    /// When the last unresolved entry is resolved, transitions to `.confirming` and
    /// starts the auto-commit timer (unless VoiceOver is focused).
    func resolveUnresolved(at index: Int, player: VoicePlayerEntry) {
        guard case .partial(var recognized, var unresolved) = state else { return }
        guard unresolved.indices.contains(index) else { return }
        let resolved = ScoreCandidate(
            playerID: player.playerID,
            displayName: player.displayName,
            strokeCount: unresolved[index].strokeCount
        )
        recognized.append(resolved)
        unresolved.remove(at: index)
        if unresolved.isEmpty {
            state = .confirming(recognized)
            if !isVoiceOverFocused {
                startAutoCommitTimer()
            }
        } else {
            state = .partial(recognized: recognized, unresolved: unresolved)
        }
    }

    /// Retries voice recognition from `.failed` state. Cancels any pending timer and
    /// calls `startListening()` to begin a new recognition session.
    func retry() {
        timerTask?.cancel()
        timerTask = nil
        startListening()
    }

    // MARK: - Private

    private func startAutoCommitTimer() {
        timerTask?.cancel()
        timerResetCount += 1
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.commitScores()
        }
    }

    deinit {
        let service = voiceRecognitionService
        let timer = timerTask
        timer?.cancel()
        Task { @MainActor in
            service.stopListening()
        }
    }
}
