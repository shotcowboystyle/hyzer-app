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
                case .partial(let recognized, _):
                    // Story 5.3 will handle partial UX; for now, confirm what was recognised
                    state = .confirming(recognized)
                    if !isVoiceOverFocused {
                        startAutoCommitTimer()
                    }
                case .failed:
                    state = .error(.noSpeechDetected)
                    isTerminated = true
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
