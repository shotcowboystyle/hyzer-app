import Foundation
import WatchConnectivity
import Observation
import os.log
import HyzerKit

/// iOS-side WatchConnectivity service.
///
/// Bridges the phone's `StandingsEngine` to the paired Watch via `WCSession`.
/// - Sends standings via `sendMessage` (instant, both apps active) and always writes
///   the JSON cache via `WatchCacheManager` for offline fallback.
/// - Receives score events from the Watch (story 7.2 wiring scope).
///
/// **Thread safety:** All observable state is `@MainActor`-isolated.
/// WCSessionDelegate callbacks arrive on an unspecified background thread and
/// are forwarded to the main actor via `Task { @MainActor in ... }`.
@MainActor
@Observable
final class PhoneConnectivityService: WatchConnectivityClient {

    // MARK: - Observable state

    private(set) var isReachable: Bool = false

    // MARK: - Private

    private let cacheManager = WatchCacheManager()
    private let session = WCSession.default
    private let delegate: SessionDelegate
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "PhoneConnectivity")

    /// The active round ID used when building standings snapshots. Set by `AppServices` when a round starts.
    var activeRoundID: UUID?
    /// Current 1-based hole number used when building standings snapshots. Set by scoring views.
    var activeHole: Int = 1

    // MARK: - Init

    init() {
        let delegate = SessionDelegate()
        self.delegate = delegate
        guard WCSession.isSupported() else { return }
        session.delegate = delegate
        session.activate()
        delegate.onReachabilityChange = { [weak self] reachable in
            Task { @MainActor [weak self] in
                self?.isReachable = reachable
            }
        }
        delegate.onMessageDataReceived = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.handleIncomingData(data)
            }
        }
        delegate.onUserInfoReceived = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.handleIncomingData(data)
            }
        }
    }

    // MARK: - WatchConnectivityClient

    func sendMessage(_ message: WatchMessage) throws {
        guard session.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        do {
            let data = try JSONEncoder().encode(message)
            session.sendMessageData(data, replyHandler: nil, errorHandler: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.logger.error("sendMessageData failed: \(error)")
                }
            })
        } catch {
            throw WatchConnectivityError.encodingFailed(error)
        }
    }

    func transferUserInfo(_ message: WatchMessage) {
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        do {
            let data = try JSONEncoder().encode(message)
            session.transferUserInfo(["payload": data])
        } catch {
            logger.error("transferUserInfo encoding failed: \(error)")
        }
    }

    // MARK: - Standings push

    /// Builds a `StandingsSnapshot` from `engine` and sends it to Watch.
    /// Always writes to `WatchCacheManager`; uses `sendMessage` for instant delivery when reachable.
    func sendStandings(engine: StandingsEngine) {
        guard let roundID = activeRoundID else { return }
        let snapshot = StandingsSnapshot(
            standings: engine.currentStandings,
            roundID: roundID,
            currentHole: activeHole
        )
        do {
            try cacheManager.save(snapshot)
        } catch {
            logger.error("WatchCacheManager save failed: \(error)")
        }
        let message = WatchMessage.standingsUpdate(snapshot)
        try? sendMessage(message)
    }

    /// Starts observing `engine.latestChange` and auto-pushes standings on every update.
    /// Uses recursive `withObservationTracking` — idiomatic Swift 6 pattern.
    func startObservingStandings(_ engine: StandingsEngine) {
        observeStandingsLoop(engine: engine)
    }

    // MARK: - Incoming message handling

    private func handleIncomingData(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WatchMessage.self, from: data) else {
            logger.error("Failed to decode incoming WatchMessage")
            return
        }
        switch message {
        case .standingsUpdate:
            break // Phone never receives standings updates from Watch
        case .scoreEvent:
            // Story 7.2: wire to ScoringService.createScoreEvent
            logger.info("Received scoreEvent from Watch — wiring deferred to story 7.2")
        }
    }

    // MARK: - Private observation loop

    private func observeStandingsLoop(engine: StandingsEngine) {
        withObservationTracking {
            _ = engine.latestChange
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.sendStandings(engine: engine)
                self.observeStandingsLoop(engine: engine)
            }
        }
    }
}

// MARK: - WCSessionDelegate adapter

/// NSObject WCSessionDelegate adapter that forwards events to `PhoneConnectivityService`.
///
/// Separated from `PhoneConnectivityService` because `@Observable` does not support
/// NSObject subclasses. Callbacks are closures set after initialisation.
private final class SessionDelegate: NSObject, WCSessionDelegate {
    var onReachabilityChange: ((Bool) -> Void)?
    var onMessageDataReceived: ((Data) -> Void)?
    var onUserInfoReceived: ((Data) -> Void)?

    // MARK: - Required

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "PhoneConnectivity")
            logger.error("WCSession activation failed: \(error)")
        }
        onReachabilityChange?(session.isReachable)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        onReachabilityChange?(false)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        onReachabilityChange?(false)
    }

    // MARK: - Reachability

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachabilityChange?(session.isReachable)
    }

    // MARK: - Received messages

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        onMessageDataReceived?(messageData)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["payload"] as? Data else { return }
        onUserInfoReceived?(data)
    }
}
