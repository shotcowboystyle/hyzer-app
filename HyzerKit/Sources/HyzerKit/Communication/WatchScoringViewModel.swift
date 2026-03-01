import SwiftUI
import Observation

/// Manages Crown score entry state for the Watch scoring screen.
///
/// Lives in HyzerKit (not HyzerWatch) so logic can be unit-tested on macOS
/// without importing WatchConnectivity — same pattern as `WatchLeaderboardViewModel`.
///
/// After `confirmScore()`, the ViewModel sends a `WatchScorePayload` to the phone
/// via `transferUserInfo` for guaranteed delivery. The phone creates the `ScoreEvent`.
@MainActor
@Observable
public final class WatchScoringViewModel {

    // MARK: - Public state

    public let playerName: String
    public let holeNumber: Int
    public let parValue: Int

    /// The currently selected stroke count. Clamped to 1...10 on set.
    public var currentScore: Int {
        get { _rawScore }
        set { _rawScore = min(10, max(1, newValue)) }
    }

    /// True after `confirmScore()` is called — triggers view dismissal.
    public private(set) var isConfirmed: Bool = false

    // MARK: - Computed

    /// Color token matching the score relative to par.
    public var scoreColor: Color {
        let rel = currentScore - parValue
        if rel < 0 { return .scoreUnderPar }
        if rel == 0 { return .scoreAtPar }
        return .scoreOverPar
    }

    /// Formatted relative-to-par string: "-1", "E", "+2".
    public var formattedScoreRelativeToPar: String {
        let rel = currentScore - parValue
        if rel < 0 { return "\(rel)" }
        if rel == 0 { return "E" }
        return "+\(rel)"
    }

    // MARK: - Private

    private var _rawScore: Int
    private let playerID: String
    private let roundID: UUID
    private let connectivityClient: any WatchConnectivityClient

    // MARK: - Init

    public init(
        playerName: String,
        playerID: String,
        holeNumber: Int,
        parValue: Int,
        roundID: UUID,
        connectivityClient: any WatchConnectivityClient
    ) {
        self.playerName = playerName
        self.playerID = playerID
        self.holeNumber = holeNumber
        self.parValue = parValue
        self.roundID = roundID
        self.connectivityClient = connectivityClient
        self._rawScore = parValue
    }

    // MARK: - Actions

    /// Sends the selected score to the phone via guaranteed `transferUserInfo` delivery
    /// and marks the session as confirmed.
    public func confirmScore() {
        let payload = WatchScorePayload(
            roundID: roundID,
            playerID: playerID,
            holeNumber: holeNumber,
            strokeCount: currentScore
        )
        connectivityClient.transferUserInfo(.scoreEvent(payload))
        isConfirmed = true
    }
}
