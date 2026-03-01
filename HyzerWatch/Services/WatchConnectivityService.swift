import Foundation
import WatchConnectivity
import Observation
import os.log
import HyzerKit

/// watchOS-side WatchConnectivity service.
///
/// Receives standings snapshots from the paired phone and exposes them as observable state.
/// On launch, loads the last persisted snapshot from `WatchCacheManager` as an offline fallback.
///
/// **Thread safety:** All observable state is `@MainActor`-isolated.
/// WCSessionDelegate callbacks arrive on an unspecified background thread and
/// are forwarded to the main actor via `Task { @MainActor in ... }`.
@MainActor
@Observable
final class WatchConnectivityService: WatchConnectivityClient, WatchStandingsObservable {

    // MARK: - Observable state

    /// The most recently received (or cached) standings snapshot.
    private(set) var currentSnapshot: StandingsSnapshot?

    /// Whether the paired iPhone is currently reachable.
    private(set) var isPhoneReachable: Bool = false

    /// The time the last snapshot was received. `nil` until first update.
    var lastUpdatedAt: Date? { currentSnapshot?.lastUpdatedAt }

    // MARK: - WatchConnectivityClient

    var isReachable: Bool { isPhoneReachable }

    // MARK: - Private

    private let cacheManager = WatchCacheManager()
    private let session = WCSession.default
    private let delegate: SessionDelegate
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp.watchkitapp", category: "WatchConnectivity")

    // MARK: - Init

    init() {
        let delegate = SessionDelegate()
        self.delegate = delegate

        // Load offline fallback immediately (before WCSession activates)
        currentSnapshot = WatchCacheManager().loadLatest()

        guard WCSession.isSupported() else { return }
        session.delegate = delegate
        session.activate()

        delegate.onReachabilityChange = { [weak self] reachable in
            Task { @MainActor [weak self] in
                self?.isPhoneReachable = reachable
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

    // MARK: - Private

    private func handleIncomingData(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WatchMessage.self, from: data) else {
            logger.error("Failed to decode incoming WatchMessage")
            return
        }
        switch message {
        case .standingsUpdate(let snapshot):
            currentSnapshot = snapshot
            do {
                try cacheManager.save(snapshot)
            } catch {
                logger.error("WatchCacheManager save failed: \(error)")
            }
        case .scoreEvent:
            break // Watch never receives score events from phone
        }
    }
}

// MARK: - WCSessionDelegate adapter

/// NSObject WCSessionDelegate adapter that forwards events to `WatchConnectivityService`.
///
/// Separated from `WatchConnectivityService` because `@Observable` does not support
/// NSObject subclasses.
private final class SessionDelegate: NSObject, WCSessionDelegate {
    var onReachabilityChange: ((Bool) -> Void)?
    var onMessageDataReceived: ((Data) -> Void)?
    var onUserInfoReceived: ((Data) -> Void)?

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            let logger = Logger(
                subsystem: "com.shotcowboystyle.hyzerapp.watchkitapp",
                category: "WatchConnectivity"
            )
            logger.error("WCSession activation failed: \(error)")
        }
        onReachabilityChange?(session.isReachable)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachabilityChange?(session.isReachable)
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        onMessageDataReceived?(messageData)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["payload"] as? Data else { return }
        onUserInfoReceived?(data)
    }
}
