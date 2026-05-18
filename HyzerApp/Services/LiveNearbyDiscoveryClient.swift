import Foundation
import MultipeerConnectivity
import os.log
import HyzerKit

/// Live implementation of `NearbyDiscoveryClient` wrapping MultipeerConnectivity Bonjour.
///
/// Declared in HyzerApp (not HyzerKit) because MultipeerConnectivity's delegate-driven
/// API and `MCPeerID` device-identifier semantics are iOS-application concerns.
/// Matches the split established by `LiveCloudKitClient` and `LiveNetworkMonitor`.
///
/// **Privacy guarantees (PMVP-NFR2):**
/// - Service type `"hyzer-rounds"` registered as Bonjour `_hyzer-rounds._tcp`.
/// - The `MCPeerID` display name is an ephemeral UUID, NEVER the user's `Player.displayName`
///   or `iCloudRecordName`. The MCPeerID is regenerated on every app launch.
/// - The discovery info dictionary contains only `roundID` and `playerIDs` — no
///   course data, no player names, no scores, no organizer identity.
/// - We never accept session invitations (`invitationHandler(false, nil)` always). The
///   pipeline uses Bonjour TXT-record advertising ONLY — no `MCSession`, no peer-to-peer
///   data channels, no encryption surface to manage.
final class LiveNearbyDiscoveryClient: NSObject, NearbyDiscoveryClient, @unchecked Sendable {
    // Bonjour service type. ≤15 chars, alphanumeric+hyphens, no leading/trailing hyphen.
    // "hyzer-rounds" is 12 chars — valid.
    static let serviceType = "hyzer-rounds"

    // TXT-record dictionary keys. Wire-format constants — must match across encode/decode.
    static let txtKeyRoundID = "rid"
    static let txtKeyPlayerIDs = "pids"

    // RFC 6763 limits each TXT-record key=value pair to 255 bytes. We aim for ≤240 bytes
    // for the `pids` value to leave headroom for the "pids=" prefix and DNS-SD overhead.
    static let txtValueMaxBytes = 240

    private static let logger = Logger(
        subsystem: "com.shotcowboystyle.hyzerapp",
        category: "NearbyDiscovery"
    )

    // Acceptable DispatchQueue use: MultipeerConnectivity delegates fire on private
    // framework queues, and we serialize advertiser/browser start/stop transitions on
    // our own queue. Matches the pattern in LiveNetworkMonitor.
    private let queue = DispatchQueue(
        label: "com.shotcowboystyle.hyzerapp.NearbyDiscovery",
        qos: .utility
    )

    // Stable-per-launch peer identity. The display name is an ephemeral UUID — never
    // the user's iCloud identity, never Player.displayName, never anything PII-bearing.
    private let peerID: MCPeerID

    // AsyncStream + Continuation created once at init time so the continuation is
    // immediately available for the first delegate callback. `AsyncStream.Continuation.yield`
    // is documented as thread-safe, so the continuation does NOT need to be guarded by `queue`.
    private let _discoveredRounds: AsyncStream<DiscoveredRoundPayload>
    private let _discoveredContinuation: AsyncStream<DiscoveredRoundPayload>.Continuation

    // Mutable state — all access serialized on `queue`.
    private var advertiser: MCNearbyServiceAdvertiser?
    private var advertisedRoundID: UUID?
    private var advertisedPlayerIDs: [String]?
    private var browser: MCNearbyServiceBrowser?

    override init() {
        self.peerID = MCPeerID(displayName: UUID().uuidString)
        let (stream, continuation) = AsyncStream.makeStream(of: DiscoveredRoundPayload.self)
        self._discoveredRounds = stream
        self._discoveredContinuation = continuation
        super.init()
    }

    deinit {
        // Safe to bypass `queue.sync` here: `deinit` runs when the last strong reference
        // is dropped, so no other code path can be touching this instance's mutable state
        // concurrently. Apple's `MCNearbyServiceAdvertiser.stopAdvertisingPeer()` and
        // `MCNearbyServiceBrowser.stopBrowsingForPeers()` are themselves thread-safe.
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        _discoveredContinuation.finish()
    }

    // MARK: - NearbyDiscoveryClient

    var discoveredRounds: AsyncStream<DiscoveredRoundPayload> { _discoveredRounds }

    func startAdvertising(roundID: UUID, playerIDs: [String]) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                // Idempotent only when BOTH roundID AND playerIDs are unchanged. A
                // mid-round playerIDs mutation must replace the advertiser so the new
                // TXT record reaches participants.
                if self.advertisedRoundID == roundID && self.advertisedPlayerIDs == playerIDs {
                    cont.resume()
                    return
                }
                self.advertiser?.stopAdvertisingPeer()
                self.advertiser?.delegate = nil

                let info = Self.encodeDiscoveryInfo(roundID: roundID, playerIDs: playerIDs)
                let new = MCNearbyServiceAdvertiser(
                    peer: self.peerID,
                    discoveryInfo: info,
                    serviceType: Self.serviceType
                )
                new.delegate = self
                new.startAdvertisingPeer()
                self.advertiser = new
                self.advertisedRoundID = roundID
                self.advertisedPlayerIDs = playerIDs
                Self.logger.info("startAdvertising: roundID=\(roundID, privacy: .private)")
                cont.resume()
            }
        }
    }

    func stopAdvertising() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                self.advertiser?.stopAdvertisingPeer()
                self.advertiser?.delegate = nil
                self.advertiser = nil
                self.advertisedRoundID = nil
                self.advertisedPlayerIDs = nil
                Self.logger.info("stopAdvertising called")
                cont.resume()
            }
        }
    }

    func startBrowsing() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                // Idempotent: if already browsing, no-op.
                if self.browser != nil {
                    cont.resume()
                    return
                }
                let new = MCNearbyServiceBrowser(peer: self.peerID, serviceType: Self.serviceType)
                new.delegate = self
                new.startBrowsingForPeers()
                self.browser = new
                Self.logger.info("startBrowsing called")
                cont.resume()
            }
        }
    }

    func stopBrowsing() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                self.browser?.stopBrowsingForPeers()
                self.browser?.delegate = nil
                self.browser = nil
                Self.logger.info("stopBrowsing called")
                cont.resume()
            }
        }
    }

    // MARK: - Discovery info encoding (AC #7)

    /// Encodes the TXT-record dictionary. Truncates `playerIDs` to fit within
    /// `txtValueMaxBytes` so the encoded "pids" pair stays under RFC 6763's 255-byte
    /// per-pair limit. Truncated participants fall back to CloudKit subscription
    /// discovery (FR16b) — no functional regression for them, just slower discovery.
    static func encodeDiscoveryInfo(roundID: UUID, playerIDs: [String]) -> [String: String] {
        var capped: [String] = []
        var byteCount = 0
        for pid in playerIDs {
            let added = byteCount == 0 ? pid.utf8.count : pid.utf8.count + 1  // +1 for the comma
            if byteCount + added > Self.txtValueMaxBytes { break }
            capped.append(pid)
            byteCount += added
        }
        if capped.count != playerIDs.count {
            logger.notice(
                "encodeDiscoveryInfo: truncated playerIDs from \(playerIDs.count) to \(capped.count) to fit Bonjour TXT-record byte budget (\(Self.txtValueMaxBytes) bytes)"
            )
        }
        return [
            Self.txtKeyRoundID: roundID.uuidString,
            Self.txtKeyPlayerIDs: capped.joined(separator: ",")
        ]
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension LiveNearbyDiscoveryClient: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        // Permission denial is a user choice — log at .notice, not .error.
        Self.logger.notice("didNotStartAdvertisingPeer: \(error.localizedDescription, privacy: .public)")
        // Reset cached advertiser state so a later retry (e.g., after the user grants
        // permission via Settings) is not short-circuited by the idempotency check.
        queue.async {
            self.advertiser?.delegate = nil
            self.advertiser = nil
            self.advertisedRoundID = nil
            self.advertisedPlayerIDs = nil
        }
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // We use Bonjour TXT-record discovery only — no session establishment.
        // This is the explicit "no peer-to-peer data channel" guarantee from PMVP-NFR2.
        invitationHandler(false, nil)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension LiveNearbyDiscoveryClient: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        guard let info else { return }

        guard
            let ridString = info[Self.txtKeyRoundID],
            let roundID = UUID(uuidString: ridString)
        else {
            Self.logger.info("foundPeer: malformed rid — ignoring")
            return
        }

        let playerIDs: [String]
        if let pids = info[Self.txtKeyPlayerIDs], !pids.isEmpty {
            playerIDs = pids.components(separatedBy: ",")
        } else {
            playerIDs = []
        }

        // AsyncStream.Continuation.yield is documented as thread-safe; no need to hop
        // onto `queue`. Yielding directly avoids dropping events that fire before any
        // serialized block on `queue` would have run.
        _discoveredContinuation.yield(DiscoveredRoundPayload(roundID: roundID, playerIDs: playerIDs))
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // No-op. Once a round is locally materialized it persists in SwiftData
        // regardless of Bonjour visibility.
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        // Permission denial is a user choice — log at .notice, not .error.
        Self.logger.notice("didNotStartBrowsingForPeers: \(error.localizedDescription, privacy: .public)")
        // Reset cached browser state so a later retry can succeed instead of being
        // short-circuited by the idempotency check in startBrowsing().
        queue.async {
            self.browser?.delegate = nil
            self.browser = nil
        }
    }
}
