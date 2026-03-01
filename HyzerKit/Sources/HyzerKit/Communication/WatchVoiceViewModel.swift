import Foundation
import Observation

/// State machine driving voice score entry via the paired phone's microphone.
///
/// Lives in HyzerKit (not HyzerWatch) so the state machine logic can be unit-tested on macOS
/// without importing WatchConnectivity — same pattern as `WatchScoringViewModel`.
///
/// Flow:
/// 1. `startVoiceRequest()` — checks reachability, sends `.voiceRequest` to phone, sets `.listening`
/// 2. Phone performs speech recognition and sends `.voiceResult` back
/// 3. `handleVoiceResult(_:)` — transitions to `.confirming`, `.partial`, or `.failed`
/// 4. Auto-commit fires after 1.5s in `.confirming`, or user calls `confirmScores()`
/// 5. `confirmScores()` — sends each candidate as `.scoreEvent` via `transferUserInfo`, sets `.committed`
@MainActor
@Observable
public final class WatchVoiceViewModel {

    // MARK: - State

    public enum State {
        case idle
        case listening
        case confirming([ScoreCandidate])
        case partial(recognized: [ScoreCandidate], unresolved: [UnresolvedCandidate])
        case failed(transcript: String)
        case committed
        case unavailable
    }

    public private(set) var state: State = .idle

    // MARK: - Private

    private let roundID: UUID
    private let holeNumber: Int
    private let playerEntries: [VoicePlayerEntry]
    private let connectivityClient: any WatchConnectivityClient

    // nonisolated(unsafe): deinit is nonisolated; all actual use is on @MainActor.
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        roundID: UUID,
        holeNumber: Int,
        playerEntries: [VoicePlayerEntry],
        connectivityClient: any WatchConnectivityClient
    ) {
        self.roundID = roundID
        self.holeNumber = holeNumber
        self.playerEntries = playerEntries
        self.connectivityClient = connectivityClient
    }

    // MARK: - Public Actions

    /// Sends a voice recognition request to the paired phone.
    ///
    /// If the phone is not reachable, transitions to `.unavailable` immediately.
    /// Otherwise sends a `.voiceRequest` via `sendMessage` and sets `.listening`.
    public func startVoiceRequest() {
        guard connectivityClient.isReachable else {
            state = .unavailable
            return
        }
        let request = WatchVoiceRequest(
            roundID: roundID,
            holeNumber: holeNumber,
            playerEntries: playerEntries
        )
        do {
            try connectivityClient.sendMessage(.voiceRequest(request))
            state = .listening
        } catch {
            state = .unavailable
        }
    }

    /// Called when the phone sends back a `WatchVoiceResult`.
    ///
    /// Transitions to `.confirming` (with auto-commit timer), `.partial`, or `.failed`.
    public func handleVoiceResult(_ result: WatchVoiceResult) {
        timerTask?.cancel()
        timerTask = nil
        switch result.result {
        case .success(let candidates):
            let clamped = candidates.map { clamp($0) }
            state = .confirming(clamped)
            startAutoCommitTimer()
        case .partial(let recognized, let unresolved):
            state = .partial(recognized: recognized.map { clamp($0) }, unresolved: unresolved)
        case .failed(let transcript):
            state = .failed(transcript: transcript)
        }
    }

    /// Commits all confirmed candidates to the phone via `transferUserInfo` (guaranteed delivery).
    public func confirmScores() {
        timerTask?.cancel()
        timerTask = nil
        guard case .confirming(let candidates) = state else { return }
        for candidate in candidates {
            let payload = WatchScorePayload(
                roundID: roundID,
                playerID: candidate.playerID,
                holeNumber: holeNumber,
                strokeCount: candidate.strokeCount
            )
            connectivityClient.transferUserInfo(.scoreEvent(payload))
        }
        state = .committed
    }

    /// Cancels the voice flow and resets to idle.
    public func cancel() {
        timerTask?.cancel()
        timerTask = nil
        state = .idle
    }

    /// Retries a voice request from `.failed` or `.partial` state.
    public func retry() {
        timerTask?.cancel()
        timerTask = nil
        startVoiceRequest()
    }

    // MARK: - Private

    private func startAutoCommitTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await self?.confirmScores()
        }
    }

    /// Clamps a ScoreCandidate's strokeCount to the valid 1...10 range.
    private func clamp(_ candidate: ScoreCandidate) -> ScoreCandidate {
        let clamped = min(10, max(1, candidate.strokeCount))
        guard clamped != candidate.strokeCount else { return candidate }
        return ScoreCandidate(playerID: candidate.playerID, displayName: candidate.displayName, strokeCount: clamped)
    }

    deinit {
        timerTask?.cancel()
    }
}
