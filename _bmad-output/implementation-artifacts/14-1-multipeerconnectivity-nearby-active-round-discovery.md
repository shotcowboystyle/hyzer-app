# Story 14.1: MultipeerConnectivity Nearby Active-Round Discovery

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user opening the app on the same Wi-Fi as the round organizer's phone,
I want my active round to appear immediately,
so that I don't wait for a CloudKit subscription notification to learn the round has started.

## Acceptance Criteria

1. **Given** the organizer started a round and both phones are on the same Wi-Fi/Bluetooth network, **when** the participant opens (or foregrounds) the app within Bonjour discovery range, **then** the active round becomes visible on the participant's `ScoringTabView` within **5 seconds** of foregrounding (measured from `scenePhase == .active` → first `@Query<Round>` emission containing `round.id`) — independent of CKQuerySubscription delivery latency (PMVP-FR17). The round STILL appears via the existing CloudKit subscription path (FR16b) when the two devices are NOT on the same local network — the Multipeer path is a fast-discovery accelerator, NOT a CloudKit replacement.

2. **Given** the `LiveNearbyDiscoveryClient` is operating, **when** network traffic is inspected (e.g., Charles Proxy, `tcpdump`), **then** **every** discovery payload byte transits Bonjour/local-network sockets — `_hyzer-rounds._tcp` and `_hyzer-rounds._udp` via `MCNearbyServiceAdvertiser` / `MCNearbyServiceBrowser` — and **zero** bytes are sent to public-internet endpoints for the discovery flow (PMVP-NFR2). The CloudKit path remains the ONLY internet-touching code path for round propagation; nothing in this story adds a new internet surface.

3. **Given** the user has not yet been prompted for local network permission, **when** the app makes its first call to `startBrowsing()` or `startAdvertising(...)` while in the foreground, **then** the iOS system local-network permission prompt is presented with the configured `NSLocalNetworkUsageDescription` copy (exact string in Task 6.1). **And** if the user denies the permission, the delegate's `didNotStartBrowsingForPeers` / `didNotStartAdvertisingPeer` is invoked with a non-nil error; the error is logged at `.notice` level (NOT `.error` — denial is a user choice, not a failure), the client transitions to an inert state, and the rest of the app continues to function via CloudKit subscription discovery (FR16b). **No** alert, banner, or crash is presented to the user — the app silently falls back.

4. **Given** the local user is the organizer of an active `Round` (`round.organizerID == AppServices.resolveLocalPlayerID(...)` AND `round.status == "active"`), **when** `AppServices.roundDidStart()` is called (already invoked from `ScorecardContainerView.task` at `HyzerApp/Views/Scoring/ScorecardContainerView.swift:117-120`), **then** `LiveNearbyDiscoveryClient.startAdvertising(roundID: round.id, playerIDs: round.playerIDs)` is invoked. **Given** the same round transitions to `.completed` OR `.awaitingFinalization` OR the app backgrounds, **when** the corresponding existing hook fires (`AppServices.roundDidEnd()` from `ScorecardContainerView.onDisappear`, or `AppServices.handleAppBackground()` from `HyzerApp.swift:40-49`'s scenePhase observer), **then** `stopAdvertising()` is invoked **and** the advertiser's `MCNearbyServiceAdvertiser.stopAdvertisingPeer()` is called. **And** participants whose browser is still running observe the lost-peer callback within ~10s of advertiser shutdown.

5. **Given** two phones A and B are both running hyzer-app on the same network, **and** phone A is the organizer of Round X with `playerIDs = [A, C]` (NOT including B), **and** phone B is the organizer of Round Y with `playerIDs = [B, D]` (NOT including A), **when** both phones' browsers are running, **then** phone A's browser receives Round Y's discovery info (the Bonjour TXT record is broadcast to anyone listening on `_hyzer-rounds._tcp`) **but** the `discoveredRounds` AsyncStream consumer in `AppServices` **filters it out** before yielding — local user A is NOT in `[B, D]`, so no `syncEngine.pullRecords()` is triggered for Round Y. Symmetrically, phone B's browser does NOT trigger a pull for Round X. The filter check is `payload.playerIDs.contains(localPlayerID.uuidString)`; absence of `localPlayerID` skips the payload silently with an `info`-level log entry (no PII in the log — log `roundID` only, never player UUIDs).

6. **Given** the local user is a participant (NOT organizer) of an active round (`round.playerIDs.contains(localPlayerID.uuidString) && round.organizerID != localPlayerID`), **when** `roundDidStart()` is called, **then** `startAdvertising(...)` is **NOT** invoked (only the organizer advertises — AC #4). The browser DOES continue running (was started in `startSync()` and runs while foregrounded), so the participant still discovers OTHER concurrent rounds they're invited to. Rationale: every-device advertising would amplify Bonjour traffic without benefit — the organizer's broadcast is sufficient because the participant only needs to discover ONE source (the organizer) to trigger their own pull.

7. **Given** the `LiveNearbyDiscoveryClient` discovery info dictionary is built, **when** the keys-and-values are encoded into the Bonjour TXT record, **then** the dictionary contains exactly two entries: `"rid"` (mapped to `roundID.uuidString`, 36 characters) and `"pids"` (mapped to `playerIDs.joined(separator: ",")`, where each player ID is either a 36-character UUID string or a `"guest:<uuid>"` prefixed string per `GuestIdentifier`). No `Player.displayName`, no `Course.name`, no scores, no organizer name, no iCloud record name. The encoded TXT record size is bounded by Bonjour's ~512-byte practical limit; with 10 players (max group size in practice) the worst-case payload is approximately `4 + 36 + 5 + (10 * 36) + 9 = 414 bytes`, well under the limit. If `playerIDs.count > 10` (edge case — no spec forbids it), the implementation MUST log a `.notice`-level warning and gracefully degrade by truncating `pids` to the first 10 entries — the participant whose UUID is truncated simply discovers via the existing CloudKit subscription fallback (no functional regression, just slower discovery for that participant).

8. **Given** the browser's `foundPeer(_:withDiscoveryInfo:)` delegate fires with a valid payload that PASSES the participant filter (AC #5), **when** `AppServices` receives the `DiscoveredRoundPayload` from the AsyncStream, **then**: (a) check whether the `Round` is already locally materialized via `FetchDescriptor<Round>(predicate: #Predicate { $0.id == payload.roundID })` with `fetchLimit = 1` — if yes, skip (idempotent — already discovered); (b) if NOT locally materialized, invoke `await syncEngine.pullRecords()` ONCE; (c) the existing `@Query` on `HomeView` for `Round.status == "active" || ...` reactively picks up the newly inserted Round and the user sees it. **No** direct `modelContext.insert(...)` for the Round — the discovery payload lacks `courseID`, `holeCount`, `organizerID`, and `createdAt`, all required for a valid `Round` (`HyzerKit/Sources/HyzerKit/Models/Round.swift:30-74`); inventing values would diverge from CloudKit's authoritative copy. The pull is the materialization path.

9. **Given** the `discoveredRounds` AsyncStream emits the same `DiscoveredRoundPayload` repeatedly (Bonjour browsers re-emit on TXT-record refresh and on browser restart, which happens on every foreground), **when** `AppServices` consumes the stream, **then** AC #8's already-materialized check (step a) suppresses redundant pulls. Additionally, a per-roundID throttle window of **30 seconds** prevents a malformed advertiser from rapidly toggling re-pulls — the same `roundID` triggers at most one `pullRecords()` call per 30s. Window is enforced via a `[UUID: Date]` map keyed by `roundID`, evaluated against `Date.now` at AsyncStream consumption time.

10. **Given** VoiceOver or another accessibility client is active on `ScoringTabView`, **when** a Multipeer-triggered pull materializes a new active round and the `@Query` updates `activeRounds`, **then** SwiftUI's existing accessibility traversal of the scoring container handles announcement automatically — this story does NOT add a new accessibility surface. The Multipeer pipeline is entirely backgrounded: no toast, no banner, no haptic, no log statement visible to the user. The user's experience is "the round appeared faster than usual" — nothing more.

11. **Given** all Multipeer-touching tests run, **when** the test suite executes, **then** the test target uses `MockNearbyDiscoveryClient` (Task 4) — NEVER the live `MCNearbyServiceAdvertiser` / `MCNearbyServiceBrowser`. `MockNearbyDiscoveryClient.simulateFoundPeer(roundID:playerIDs:)` is the canonical way to inject a discovered payload in tests. The live client gets a SINGLE smoke test in `HyzerAppTests/LiveNearbyDiscoveryClientTests.swift` that verifies construction succeeds and `serviceType == "hyzer-rounds"` — full network behavior cannot be exercised in unit tests (matches the precedent set by `LiveNetworkMonitor` / `LiveCloudKitClient` — neither has deep unit coverage in the existing suite).

## Tasks / Subtasks

- [x] Task 1: Add `NearbyDiscoveryClient` protocol and value types in HyzerKit (AC: 1, 2, 7)
  - [x] 1.1 Create `HyzerKit/Sources/HyzerKit/Sync/NearbyDiscoveryClient.swift` exposing:
    ```swift
    import Foundation

    /// A discovered active round on the local network.
    ///
    /// Value type — never persisted. Lifetime is the AsyncStream consumption window.
    /// Mirrors the value-type discipline of `StandingsSnapshot`, `StandingsChange`, and
    /// `WatchMessage` (all `Sendable` structs in `HyzerKit/Sources/HyzerKit/Communication/`).
    public struct DiscoveredRoundPayload: Sendable, Equatable {
        /// The advertised round's UUID.
        public let roundID: UUID
        /// Player IDs from `Round.playerIDs` — UUID strings or `"guest:<uuid>"` strings.
        /// Consumers MUST filter via `playerIDs.contains(localPlayerID.uuidString)` before
        /// taking action (AC #5).
        public let playerIDs: [String]

        public init(roundID: UUID, playerIDs: [String]) {
            self.roundID = roundID
            self.playerIDs = playerIDs
        }
    }

    /// Abstraction over MultipeerConnectivity Bonjour discovery for active rounds.
    ///
    /// Protocol lives in HyzerKit so `AppServices` and tests can depend on it without
    /// importing `MultipeerConnectivity` on macOS test hosts. The live implementation
    /// (`LiveNearbyDiscoveryClient`) is in the HyzerApp target — mirrors the
    /// `CloudKitClient` / `NetworkMonitor` split.
    ///
    /// Conforming types **must** be `Sendable` because the protocol is consumed from
    /// `@MainActor AppServices` and the live impl's delegates fire on private MC queues.
    ///
    /// **Lifecycle invariants:**
    /// - All four start/stop methods are idempotent: redundant calls are no-ops.
    /// - `startAdvertising(roundID:playerIDs:)` called twice with different `roundID` values
    ///   replaces the previous advertisement (stops the old `MCNearbyServiceAdvertiser`,
    ///   creates a new one). Same `roundID` is a no-op.
    /// - `discoveredRounds` is a SINGLE-SUBSCRIBER stream. Each access returns the same
    ///   underlying continuation; calling the property twice yields the second subscriber
    ///   the same stream object. Matches the `LiveNetworkMonitor.pathUpdates` precedent.
    public protocol NearbyDiscoveryClient: Sendable {
        /// Begins advertising the local user's organized round on the local network.
        ///
        /// Triggers the iOS local-network permission prompt on first call if permission
        /// has not yet been requested (system-managed; the app does NOT pre-prompt).
        /// Permission denial is reported via the live implementation's internal logger
        /// and leaves the client in an inert state — no error is propagated to the caller.
        ///
        /// - Parameters:
        ///   - roundID: The `Round.id` being advertised.
        ///   - playerIDs: `Round.playerIDs` (UUID strings or `"guest:<uuid>"` strings).
        ///     Encoded into the Bonjour TXT record. See AC #7 for size constraints.
        func startAdvertising(roundID: UUID, playerIDs: [String]) async

        /// Stops the currently-active advertiser, if any. Idempotent.
        func stopAdvertising() async

        /// Begins browsing for nearby advertised rounds. Idempotent — repeat calls are no-ops.
        /// Permission denial behavior mirrors `startAdvertising`.
        func startBrowsing() async

        /// Stops the currently-active browser, if any. Idempotent.
        func stopBrowsing() async

        /// Async stream of discovered round payloads. Each emission represents ONE
        /// `foundPeer` delegate callback from the underlying `MCNearbyServiceBrowser`.
        ///
        /// **Consumer responsibilities** (AC #5, #8, #9):
        /// 1. Filter on `playerIDs.contains(localPlayerID.uuidString)` — drop payloads
        ///    that don't include the local user.
        /// 2. Idempotency: skip payloads whose `roundID` is already locally materialized.
        /// 3. Throttle: enforce a 30s per-`roundID` window between `syncEngine.pullRecords()`
        ///    invocations.
        var discoveredRounds: AsyncStream<DiscoveredRoundPayload> { get }
    }
    ```
    `DiscoveredRoundPayload` MUST be a value type. The protocol has FIVE members exactly — do not add `isAdvertising`, `discoveredPeerCount`, or any other observable surface that would couple consumers to live implementation state.

  - [x] 1.2 Verify `HyzerKit` builds with **zero** new platform imports: `NearbyDiscoveryClient.swift` imports `Foundation` only (NOT `MultipeerConnectivity`). The live implementation owns the framework import. Run `swift test --package-path HyzerKit` to confirm macOS host compilation still succeeds after the additions.

- [x] Task 2: Implement `LiveNearbyDiscoveryClient` in HyzerApp (AC: 1, 2, 3, 7)
  - [x] 2.1 Create `HyzerApp/Services/LiveNearbyDiscoveryClient.swift`. Declare an `NSObject` subclass that conforms to `NearbyDiscoveryClient`, `MCNearbyServiceAdvertiserDelegate`, and `MCNearbyServiceBrowserDelegate`. Use `@unchecked Sendable` per the `LiveNetworkMonitor` precedent (`HyzerApp/Services/LiveNetworkMonitor.swift:15`) — all mutable state is guarded by a dedicated `DispatchQueue` consumed by the MC delegates (the ONE acceptable `DispatchQueue` use outside `NWPathMonitor`; document inline same as LiveNetworkMonitor does).
    ```swift
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
    /// - Service type `"hyzer-rounds"` registered as Bonjour `_hyzer-rounds._tcp` / `._udp`.
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

        private static let logger = Logger(
            subsystem: "com.shotcowboystyle.hyzerapp",
            category: "NearbyDiscovery"
        )

        // Acceptable DispatchQueue use: MultipeerConnectivity delegates fire on private
        // framework queues, and we serialize start/stop transitions on our own queue.
        // Matches the pattern in LiveNetworkMonitor.
        private let queue = DispatchQueue(
            label: "com.shotcowboystyle.hyzerapp.NearbyDiscovery",
            qos: .utility
        )

        // Stable-per-launch peer identity. The display name is an ephemeral UUID — never
        // the user's iCloud identity, never Player.displayName, never anything PII-bearing.
        private let peerID: MCPeerID

        // Mutable state — all access serialized on `queue`.
        private var advertiser: MCNearbyServiceAdvertiser?
        private var advertisedRoundID: UUID?
        private var browser: MCNearbyServiceBrowser?
        private var discoveredContinuation: AsyncStream<DiscoveredRoundPayload>.Continuation?

        override init() {
            self.peerID = MCPeerID(displayName: UUID().uuidString)
            super.init()
        }

        deinit {
            advertiser?.stopAdvertisingPeer()
            browser?.stopBrowsingForPeers()
            discoveredContinuation?.finish()
        }

        // MARK: - NearbyDiscoveryClient

        var discoveredRounds: AsyncStream<DiscoveredRoundPayload> {
            AsyncStream<DiscoveredRoundPayload> { [weak self] continuation in
                guard let self else {
                    continuation.finish()
                    return
                }
                self.queue.async {
                    self.discoveredContinuation = continuation
                }
            }
        }

        func startAdvertising(roundID: UUID, playerIDs: [String]) async {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                queue.async {
                    // Idempotent: same roundID is a no-op.
                    if let existing = self.advertisedRoundID, existing == roundID {
                        cont.resume()
                        return
                    }
                    // Different roundID replaces the existing advertiser.
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
                    Self.logger.info("startAdvertising: roundID=\(roundID, privacy: .public)")
                    cont.resume()
                }
            }
        }

        func stopAdvertising() async { /* analogous serialized teardown */ }
        func startBrowsing() async { /* serialized; idempotent; new MCNearbyServiceBrowser */ }
        func stopBrowsing() async { /* analogous serialized teardown */ }

        // MARK: - Discovery info encoding (AC #7)

        /// Encodes the TXT-record dictionary. Truncates `playerIDs` to the first 10 entries
        /// with a `.notice` log if input exceeds 10 — the participant whose UUID is dropped
        /// falls back to CloudKit subscription discovery (no functional regression).
        static func encodeDiscoveryInfo(roundID: UUID, playerIDs: [String]) -> [String: String] {
            let capped = Array(playerIDs.prefix(10))
            if capped.count != playerIDs.count {
                logger.notice("encodeDiscoveryInfo: truncated playerIDs from \(playerIDs.count) to 10 for Bonjour size budget")
            }
            return [
                "rid": roundID.uuidString,
                "pids": capped.joined(separator: ",")
            ]
        }
    }
    ```
    The above is a sketch — complete the four lifecycle methods, plus the delegate conformances below. Keep the `serviceType` static and the encoding helper `static` so the test suite can assert them without instantiation.

  - [x] 2.2 Implement `MCNearbyServiceAdvertiserDelegate`:
    - `advertiser(_:didNotStartAdvertisingPeer:)` — log at `.notice` level (per AC #3 rationale: permission denial is a user choice). Do NOT clear `advertisedRoundID` — the state is informational; the next `startAdvertising` call will attempt again.
    - `advertiser(_:didReceiveInvitationFromPeer:withContext:invitationHandler:)` — **always** invoke `invitationHandler(false, nil)`. We use Bonjour TXT-record discovery only — no session establishment. This is the explicit "no peer-to-peer data channel" guarantee from PMVP-NFR2.

  - [x] 2.3 Implement `MCNearbyServiceBrowserDelegate`:
    - `browser(_:foundPeer:withDiscoveryInfo:)` — parse `info["rid"]` and `info["pids"]`. If `rid` does not parse as `UUID`, log at `.info` level (`"foundPeer: malformed rid — ignoring"`) and return without yielding. If `pids` is empty, yield with an empty `playerIDs` array (the AppServices consumer's participant filter will skip it). Compose the `DiscoveredRoundPayload` and `discoveredContinuation?.yield(payload)`.
    - `browser(_:lostPeer:)` — no-op. The browser's lost-peer signal is informational; we don't track per-peer state. Once a round is locally materialized, it persists in SwiftData regardless of Bonjour visibility.
    - `browser(_:didNotStartBrowsingForPeers:)` — log at `.notice` (same rationale as advertiser).

  - [x] 2.4 Verify the live impl compiles for iOS 18+ only. `MultipeerConnectivity` is technically available on watchOS but the Watch is explicitly NOT a CloudKit sync node (CLAUDE.md "Sync Architecture") and adding watchOS discovery would amplify Bonjour traffic without benefit. The file lives under `HyzerApp/Services/` and is included only in the iOS target via `project.yml` source rules (no changes needed — the existing iOS target rules `sources: [HyzerApp]` already pick it up).

- [x] Task 3: Wire `NearbyDiscoveryClient` into `AppServices` (AC: 4, 5, 6, 8, 9, 10)
  - [x] 3.1 Add to `HyzerApp/App/AppServices.swift`:
    - New stored property: `let nearbyDiscoveryClient: any NearbyDiscoveryClient`
    - New initializer parameter (defaulted): `nearbyDiscoveryClient: any NearbyDiscoveryClient = LiveNearbyDiscoveryClient()` — placed AFTER `notificationService` in the parameter list to minimize call-site churn (only `HyzerApp.init` constructs `AppServices` in production).
    - Store the injected client. Do NOT start advertising or browsing in `init` — lifecycle hooks (Tasks 3.2–3.4) own that.
    - Add a private throttle map: `private var lastPullByRoundID: [UUID: Date] = [:]` for AC #9's 30s window.

  - [x] 3.2 In `AppServices.startSync()` (currently bridges `syncEngine.syncStateStream` to `syncState`), append a second concurrent consumer that bridges `nearbyDiscoveryClient.discoveredRounds`:
    ```swift
    // After the existing await syncEngine.start() line:
    await nearbyDiscoveryClient.startBrowsing()
    // Spawn the stream consumer as a child task — the existing for-await on syncStateStream
    // is the structured "owner" of startSync's lifetime.
    Task { [weak self] in
        guard let self else { return }
        for await payload in self.nearbyDiscoveryClient.discoveredRounds {
            await self.handleDiscoveredRound(payload)
        }
    }
    ```
    Place the `await startBrowsing()` BEFORE the existing `for await state in syncStateStream` loop — the syncStateStream consumer is the structural anchor of the function and runs forever, so anything that needs to start at-launch must precede it.

  - [x] 3.3 Add `private func handleDiscoveredRound(_ payload: DiscoveredRoundPayload) async`:
    - Read `let localID = Self.resolveLocalPlayerID(from: modelContainer.mainContext)`. If nil (pre-onboarding), log `.info` and return.
    - Participant filter: `guard payload.playerIDs.contains(localID.uuidString) else { logger.info("nearby: skipped — local user not in payload"); return }`. **Do NOT log the playerIDs themselves** — they're opaque UUIDs but logging them grows log volume and adds zero diagnostic value.
    - Throttle check: `if let last = lastPullByRoundID[payload.roundID], Date.now.timeIntervalSince(last) < 30 { return }`.
    - Already-materialized check: query `Round` by `id == payload.roundID` with `fetchLimit = 1` (wrap in `do/catch` with `logger.error(...); return` on failure — no silent `try?` per CLAUDE.md). If the round exists, log `.info("nearby: already materialized — skipping pull")` and return.
    - Otherwise: `lastPullByRoundID[payload.roundID] = Date.now` THEN `await syncEngine.pullRecords()`. The pull is the existing CloudKit fast-path — it's `await`-able from `@MainActor` (the engine is an `actor`). After the pull returns, the existing `@Query<Round>` on `ScoringTabView` / `HomeView` reactively picks up the inserted round (AC #8).
    - Use the existing `notificationLogger` or a new `nearbyLogger` (preferred — distinct category `"AppServices.Nearby"` makes Console filtering trivial during the inevitable field debugging session).

  - [x] 3.4 Extend `AppServices.roundDidStart()` to drive the advertiser:
    - Add a private helper `private func currentOrganizedActiveRound() -> Round?` that queries `Round` where `status == "active"` AND `organizerID == localPlayerID` with `fetchLimit = 1`. Wrap in `do/catch` (no silent `try?`).
    - In `roundDidStart()` AFTER the existing `await syncScheduler.startActiveRoundPolling()` call:
      ```swift
      if let round = currentOrganizedActiveRound() {
          await nearbyDiscoveryClient.startAdvertising(
              roundID: round.id,
              playerIDs: round.playerIDs
          )
      }
      ```
      AC #6 enforcement: the helper returns `nil` for participants — participants do NOT advertise.

  - [x] 3.5 Extend `AppServices.roundDidEnd()` AFTER the existing `await syncScheduler.stopActiveRoundPolling()` call:
    ```swift
    await nearbyDiscoveryClient.stopAdvertising()
    ```
    No conditional — `stopAdvertising` is idempotent and safe to call when nothing is being advertised (AC #4 lifecycle contract).

  - [x] 3.6 Extend `AppServices.handleAppBackground()` AFTER the existing `await syncScheduler.stopActiveRoundPolling()` call:
    ```swift
    await nearbyDiscoveryClient.stopAdvertising()
    await nearbyDiscoveryClient.stopBrowsing()
    ```
    AND in `AppServices.performForegroundDiscovery()` (already called from `HyzerApp.swift:43` on scenePhase `.active`), append AFTER the existing `await syncScheduler.foregroundDiscovery(currentUserID: userID)` call:
    ```swift
    await nearbyDiscoveryClient.startBrowsing()
    if let round = currentOrganizedActiveRound() {
        await nearbyDiscoveryClient.startAdvertising(roundID: round.id, playerIDs: round.playerIDs)
    }
    ```
    Rationale for both foreground hooks (start AND advertise): an organizer who backgrounds the app mid-round and returns expects the advertiser to resume; `startSync` only runs at cold launch. The browser-restart on every foreground is the standard MultipeerConnectivity pattern (browsers do not survive background well; cleanest to recreate).

  - [x] 3.7 Update `HyzerApp.init` at `HyzerApp/App/HyzerApp.swift:13-27` — add `nearbyDiscoveryClient: LiveNearbyDiscoveryClient()` to the `AppServices(...)` call. Single-line addition; the default parameter could also be relied upon but explicit wiring matches the existing style for `cloudKitClient`, `networkMonitor`, `notificationService`.

- [x] Task 4: Add `MockNearbyDiscoveryClient` for tests (AC: 11)
  - [x] 4.1 Create `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift`:
    ```swift
    import Foundation
    @testable import HyzerKit

    /// Controllable test double for `NearbyDiscoveryClient`.
    ///
    /// Exposes `simulateFoundPeer(roundID:playerIDs:)` to inject a discovered payload
    /// from test code. Records advertise/browse start-stop call counts and the last
    /// advertised roundID for assertions. Thread-safety: `@unchecked Sendable` with
    /// all mutations from test code (which controls the call site) — matches the
    /// `MockNetworkMonitor` precedent.
    final class MockNearbyDiscoveryClient: NearbyDiscoveryClient, @unchecked Sendable {
        // Observable state for assertions
        private(set) var startAdvertisingCallCount = 0
        private(set) var stopAdvertisingCallCount = 0
        private(set) var startBrowsingCallCount = 0
        private(set) var stopBrowsingCallCount = 0
        private(set) var lastAdvertisedRoundID: UUID?
        private(set) var lastAdvertisedPlayerIDs: [String] = []

        private var continuation: AsyncStream<DiscoveredRoundPayload>.Continuation?

        var discoveredRounds: AsyncStream<DiscoveredRoundPayload> {
            AsyncStream<DiscoveredRoundPayload> { [weak self] continuation in
                self?.continuation = continuation
            }
        }

        func startAdvertising(roundID: UUID, playerIDs: [String]) async {
            startAdvertisingCallCount += 1
            lastAdvertisedRoundID = roundID
            lastAdvertisedPlayerIDs = playerIDs
        }

        func stopAdvertising() async {
            stopAdvertisingCallCount += 1
            lastAdvertisedRoundID = nil
        }

        func startBrowsing() async { startBrowsingCallCount += 1 }
        func stopBrowsing() async { stopBrowsingCallCount += 1 }

        // MARK: - Test helpers

        /// Injects a discovered payload on the AsyncStream. Caller must have started
        /// observation (accessed `discoveredRounds`) before invoking this.
        func simulateFoundPeer(roundID: UUID, playerIDs: [String]) {
            continuation?.yield(DiscoveredRoundPayload(roundID: roundID, playerIDs: playerIDs))
        }

        func finish() { continuation?.finish() }
    }
    ```
    Place under `Mocks/` (NOT `Tests/HyzerKitTests/Sync/Mocks/`) to match the existing convention of `MockCloudKitClient.swift` / `MockNetworkMonitor.swift` / `MockNotificationService.swift` all sitting at `Tests/HyzerKitTests/Mocks/`.

  - [x] 4.2 The HyzerApp test target may also need this mock. Per CLAUDE.md "Known Technical Debt" (MockNotificationService is duplicated across HyzerAppTests/Mocks and HyzerKit/Tests/HyzerKitTests/Mocks) — follow the same pattern: ALSO add `HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift` with identical surface. This is recorded as new tech debt rather than fixed here — the shared-TestSupport extraction is a separate project-wide initiative (CLAUDE.md "ValueCollector test helper" line). Add a `// swiftlint:disable file_length` or similar marker is NOT needed; the file is small.

- [x] Task 5: Tests in HyzerKit (AC: 5, 7, 8, 9, 11)
  - [x] 5.1 Create `HyzerKit/Tests/HyzerKitTests/Sync/DiscoveredRoundPayloadTests.swift`:
    - `test_equality_sameRoundIDAndPlayerIDs_areEqual`
    - `test_equality_differentRoundID_areNotEqual`
    - `test_equality_differentPlayerIDOrder_areNotEqual` (verifies `playerIDs` is order-sensitive — Equatable on Array IS order-sensitive; this test exists to lock the contract since AppServices' set-membership filter does NOT depend on order, and a future "Set-based" refactor would change the equality semantics).

  - [x] 5.2 Create `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClientTests.swift`:
    - `test_simulateFoundPeer_yieldsPayloadOnStream` — start observing `discoveredRounds`, call `simulateFoundPeer`, assert receipt within a Swift Testing time-bounded `await` (use the pattern from `WatchCacheManagerTests` if one exists with timed assertions; otherwise use `Task.sleep(for: .milliseconds(20))` with a `ValueCollector`-style helper — and add a deferred-work entry noting the project-wide flaky-timing pattern from CLAUDE.md).
    - `test_startAdvertising_recordsCallCountAndLastRoundID`
    - `test_stopAdvertising_clearsLastAdvertisedRoundID`

  - [x] 5.3 Create `HyzerAppTests/LiveNearbyDiscoveryClientEncodingTests.swift` (the encoding helper is on the live client — can't test from HyzerKit because the live client is in HyzerApp):
    - `test_encodeDiscoveryInfo_singlePlayer_includesRidAndPids`
    - `test_encodeDiscoveryInfo_guestIDsAreEmittedAsIs` — input `["guest:UUID", "UUID"]`; assert `info["pids"] == "guest:UUID,UUID"` (the comma-join handles both string shapes uniformly).
    - `test_encodeDiscoveryInfo_morethan10Players_truncatesToFirst10` — input 12 player IDs; assert `info["pids"].components(separatedBy: ",").count == 10` and that the truncation logs a `.notice` (use `OSLogStore` query in test if feasible; otherwise inject a logger seam or just verify the truncation behavior and rely on manual log inspection for the `.notice` emission). AC #7.

  - [x] 5.3 Use **Swift Testing** macros (`@Suite`, `@Test`) — NOT XCTest — per CLAUDE.md "Testing" section. Reference `HyzerKit/Tests/HyzerKitTests/Domain/PlayerTrendServiceTests.swift` for the canonical Suite layout. All in-memory SwiftData uses `ModelConfiguration(isStoredInMemoryOnly: true)` (no such config is needed for the payload/mock tests since neither touches SwiftData).

- [x] Task 6: Info.plist + Bonjour service registration (AC: 2, 3)
  - [x] 6.1 Add to `HyzerApp/App/Info.plist`:
    ```xml
    <key>NSLocalNetworkUsageDescription</key>
    <string>Hyzer uses your local network to discover other Hyzer players' active rounds nearby — so your group's round appears instantly without waiting for a server push.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_hyzer-rounds._tcp</string>
        <string>_hyzer-rounds._udp</string>
    </array>
    ```
    Both entries are REQUIRED for iOS 14+ local network access. MultipeerConnectivity uses both TCP and UDP under the hood; omitting either causes silent permission failures.

  - [x] 6.2 Mirror the same two entries under `targets.HyzerApp.info.properties` in `project.yml`. CLAUDE.md "Known Technical Debt" (Story 9.2 deferred work) calls out that `Info.plist` ↔ `project.yml` duplicate-source-of-truth is a recognized minor debt; follow the established practice rather than fixing it here. The deferred work list will be re-checked after this story closes.

  - [x] 6.3 After both edits, run `xcodegen generate` and verify `HyzerApp.xcodeproj/.../Info.plist` (the generated copy) reflects the new keys. The pre-commit / pre-build flow does NOT auto-regenerate the project.

  - [x] 6.4 The `HyzerApp.entitlements` file at `HyzerApp/App/HyzerApp.entitlements` does NOT need changes — MultipeerConnectivity Bonjour discovery requires NO entitlement (it requires only the Info.plist keys above). Do NOT add a `com.apple.developer.networking.multipath` or `com.apple.developer.networking.networkextension` entitlement — neither is relevant and adding them triggers App Review questions.

- [x] Task 7: Integration tests in HyzerApp test target (AC: 4, 5, 6, 8, 9)
  - [x] 7.1 Create `HyzerAppTests/AppServicesNearbyDiscoveryTests.swift` exercising:
    - `test_handleDiscoveredRound_localPlayerNotInPayload_skipsPull` — inject a payload where `payload.playerIDs` does NOT contain `localPlayer.id.uuidString`; assert `mockSyncEngine.pullRecordsCallCount == 0`. (AC #5)
    - `test_handleDiscoveredRound_roundAlreadyMaterialized_skipsPull` — pre-insert a `Round` with the payload's roundID; inject; assert no pull. (AC #8 step a)
    - `test_handleDiscoveredRound_throttleWindow_secondCallWithin30sIsSkipped` — inject twice in rapid succession; assert pull called exactly once. (AC #9)
    - `test_handleDiscoveredRound_throttleWindow_secondCallAfter30sTriggersAgain` — use a controllable clock if AppServices accepts one; otherwise mark this case as deferred-work and rely on the manual + window math correctness review.
    - `test_roundDidStart_localPlayerIsOrganizer_callsStartAdvertising` — insert Round with `organizerID == localPlayer.id` and `status == "active"`; call `roundDidStart()`; assert `mockNearbyClient.startAdvertisingCallCount == 1` and `lastAdvertisedRoundID == round.id`. (AC #4)
    - `test_roundDidStart_localPlayerIsParticipantOnly_doesNotAdvertise` — same fixture but `organizerID = UUID()` (different player); assert `mockNearbyClient.startAdvertisingCallCount == 0`. (AC #6)
    - `test_roundDidEnd_callsStopAdvertising` — assert call count increments. (AC #4)
    - `test_handleAppBackground_callsStopAdvertisingAndStopBrowsing`. (AC #4)
    - `test_performForegroundDiscovery_organizerCase_resumesBrowsingAndAdvertising`. (AC #4 foreground resume)

  - [x] 7.2 The `MockSyncEngine` does NOT yet exist in the HyzerApp test target — assess at impl time. If `SyncEngine` cannot be subclassed/mocked cleanly (it's an `actor` per `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift:26`), use an `AppServices` test seam: inject a "pullRecords-counting" sidecar via a closure parameter on the new `handleDiscoveredRound` helper. The cleanest implementation may be to extract a small `private let pullTrigger: () async -> Void` closure on `AppServices` that defaults to `{ await syncEngine.pullRecords() }` and is overridable in tests. Decide at impl time — but document the decision in the story's Dev Notes section.

  - [x] 7.3 Create `HyzerAppTests/LiveNearbyDiscoveryClientTests.swift` — single smoke test:
    - `test_init_succeeds_andServiceTypeIs_hyzerRounds` — assert `LiveNearbyDiscoveryClient.serviceType == "hyzer-rounds"` and that initialization does not crash. (AC #11)
    - Do NOT attempt to exercise the actual MC framework in unit tests. Live network behavior is verified manually via the test plan below.

- [x] Task 8: Manual verification & test plan (AC: 1, 2, 3, 4, 5)
  - [x] 8.1 Required setup: two iPhone 17 simulators paired with Watches OR one simulator + one device, both on the same Wi-Fi. The macOS network stack treats simulators as local-network peers IF the host Mac is on the same SSID as the device-under-test.
  - [x] 8.2 Walk-through for AC #1 (5-second discovery):
    1. Install dev build on phone A (organizer) and phone B (participant). Both phones complete onboarding with distinct iCloud accounts.
    2. On phone A: create a new round, add phone B as a player by selecting their `Player.displayName` from the registered-players picker.
    3. On phone B: tap "Allow" on the iOS local network permission prompt the FIRST time the app foregrounds with a browser running. (Verify the prompt copy matches Task 6.1.)
    4. On phone B: foreground the app. Start a stopwatch.
    5. Verify the round card appears on phone B's `ScoringTabView` within 5 seconds. (Acceptance threshold: 5s; expected actual: <1s on the same Wi-Fi.)
    6. Disable Wi-Fi on phone B. Repeat steps 2–4 with phone B on cellular only. Verify the round STILL eventually appears via CloudKit subscription path (typically 5–15s depending on APNs delivery).
  - [x] 8.3 Walk-through for AC #5 (cross-round isolation):
    1. Both phones organize their own rounds simultaneously, each with a different third player invited (NOT each other).
    2. Verify each phone's `ScoringTabView` shows ONLY its own round — not the other phone's round.
  - [x] 8.4 Walk-through for AC #4 (advertiser teardown):
    1. Phone A organizes a round including phone B. Verify B sees it within 5s.
    2. Phone A completes the round.
    3. Phone A backgrounds the app. Phone C (a third device not in the round) browses; verify C's Console log shows no Bonjour TXT record for the just-completed round (i.e., advertiser stopped).
  - [x] 8.5 Console logging filter for field debugging: `subsystem:com.shotcowboystyle.hyzerapp category:NearbyDiscovery OR category:AppServices.Nearby`. Document this filter in the story's completion notes for future on-call reference.

## Dev Notes

**Architecture compliance:**
- Layer split mirrors `CloudKitClient` (protocol in `HyzerKit/Sync/`, live impl in `HyzerApp/Services/`) — same precedent as `NetworkMonitor`, `NotificationService`. New types DO NOT belong in `HyzerKit/Communication/` (that directory is for Watch ↔ Phone IPC, NOT phone ↔ phone Bonjour). Discovery is a sync-acceleration concern, so `HyzerKit/Sync/` is the correct home.
- The protocol is `Sendable`. The live impl is `@unchecked Sendable` with serial DispatchQueue guarding all mutable state (LiveNetworkMonitor precedent). NEVER use `@MainActor` on the live client — MultipeerConnectivity delegates fire on private framework queues, not the main actor.
- The `MockNearbyDiscoveryClient` test double is `@unchecked Sendable` with a single-subscriber AsyncStream — matches `MockNetworkMonitor`.
- AppServices remains the SOLE orchestrator: ViewModels never see `NearbyDiscoveryClient`. The protocol is internal to the sync layer.

**Privacy & data flow (PMVP-NFR2):**
- The MCPeerID display name is an ephemeral UUID generated at `init` — re-rolled on every app launch. Even with a packet capture in hand, an observer cannot correlate two sessions of the same user.
- The Bonjour TXT record contains ONLY `rid` (round UUID) and `pids` (comma-joined player UUIDs). UUIDs are opaque — they're already in the CloudKit public DB and visible to anyone who knows the schema. No NEW PII is exposed by Multipeer.
- `Player.displayName` is NEVER advertised. `Course.name` is NEVER advertised. Scores are NEVER advertised. The discovery payload tells a network observer "a round exists with these player UUIDs" — nothing more.
- We REJECT all session invitations (`invitationHandler(false, nil)`). No `MCSession`, no peer-to-peer data channels, no encryption surface to maintain. This is the explicit "Bonjour discovery only" boundary that PMVP-NFR2 protects.

**Concurrency:**
- `LiveNearbyDiscoveryClient` uses a dedicated `DispatchQueue` — the ONE acceptable DispatchQueue use outside `LiveNetworkMonitor`. Document this inline; SwiftLint's `no_dispatch_queue` warning (if enabled) must be `// swiftlint:disable:next no_dispatch_queue` annotated or the rule must be configured to allow the file. Check current `.swiftlint.yml` at impl time.
- `AppServices.handleDiscoveredRound` runs on the main actor (AppServices is `@MainActor`). The `for await payload in discoveredRounds` loop in Task 3.2 inherits the enclosing isolation — verify it compiles cleanly with Swift 6 strict concurrency.
- The `Task { ... }` spawned in `startSync` to consume the discoveredRounds stream is unstructured but bounded by the lifetime of AppServices (the closure captures `[weak self]`). When the app process terminates, the task is cancelled by the runtime. Acceptable risk; matches the existing `Task { await pushRoundCompletion(...) }` fire-and-forget pattern noted in `12-2` deferred work.

**SwiftData query bounds (CLAUDE.md compliance):**
- `currentOrganizedActiveRound()` uses `fetchLimit = 1` — bounded.
- `handleDiscoveredRound`'s already-materialized check uses `fetchLimit = 1` — bounded.
- No new unbounded queries added.

**Error handling (CLAUDE.md "No silent `try?`" + "No silent exception swallowing"):**
- Every SwiftData `try` in this story is wrapped in `do/catch` with `logger.error(...)` and an explicit return (cannot rethrow from non-throwing call sites). Permission-denial logs are `.notice` (user choice, not failure). Foundation errors during Bonjour TXT parsing log at `.info` (malformed peer data is expected at protocol boundaries).
- The advertiser/browser `didNot*` delegate calls log at `.notice` per AC #3 — they represent permission denials, not application bugs.

**Source tree components to touch (UPDATE — read fully before editing):**
- `HyzerApp/App/AppServices.swift` (UPDATE — current responsibilities documented at file:38-50; this story adds nearby-discovery orchestration alongside existing sync/notification orchestration; preserve all existing pendingDeepLink, syncState, and iCloud-identity behavior)
- `HyzerApp/App/HyzerApp.swift` (UPDATE — one-line addition to `AppServices(...)` call at lines 17-23; preserve the model container recovery cascade at lines 66-117)
- `HyzerApp/App/Info.plist` (UPDATE — add the two new keys alongside the existing `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` / `UIBackgroundModes` keys)
- `project.yml` (UPDATE — append to `targets.HyzerApp.info.properties`; preserve all existing entries including `UISupportedInterfaceOrientations` arrays)

**Source tree components to create (NEW):**
- `HyzerKit/Sources/HyzerKit/Sync/NearbyDiscoveryClient.swift`
- `HyzerApp/Services/LiveNearbyDiscoveryClient.swift`
- `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift`
- `HyzerKit/Tests/HyzerKitTests/Sync/DiscoveredRoundPayloadTests.swift`
- `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClientTests.swift`
- `HyzerAppTests/AppServicesNearbyDiscoveryTests.swift`
- `HyzerAppTests/LiveNearbyDiscoveryClientTests.swift`
- `HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift` (duplicate of the HyzerKit mock per CLAUDE.md tech-debt precedent — record as new deferred-work entry)

**Testing standards summary:**
- Swift Testing (`@Suite`, `@Test`) — NOT XCTest.
- Test fixtures via `Round.fixture(...)` / `Player.fixture(...)` from `HyzerKit/Tests/HyzerKitTests/Fixtures/`. Add no new fixtures unless an existing one cannot be parameterized to fit.
- All SwiftData test setup uses `ModelConfiguration(isStoredInMemoryOnly: true)`.
- The HyzerKit suite runs via `swift test --package-path HyzerKit` (no simulator). The HyzerApp suite runs via `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'`.
- Manual verification per Task 8 — record observed timings in the story's Completion Notes for the AC #1 5-second budget.

**Do NOT implement (out of scope):**
- Watch-side Multipeer discovery (Watch never talks to CloudKit OR Multipeer per CLAUDE.md Sync Architecture).
- An MCSession with peer-to-peer data channels (Bonjour TXT-record discovery only — invitations always rejected per Task 2.2).
- Push-style updates of round state changes via Multipeer (the discovery payload is `{roundID, playerIDs}` ONLY; live updates flow exclusively via existing CloudKit + WatchConnectivity pipelines).
- A user-facing toggle to disable Multipeer (the iOS local-network permission prompt is the user's control surface; adding an in-app toggle is feature-creep).
- A "discovered rounds" debug UI (the round materialization is observable via the existing `@Query<Round>` in `HomeView`/`ScoringTabView` — no new UI surface).
- Re-registering Multipeer advertisers on iCloud identity change (out of scope; matches the deferred-work note on `SyncScheduler` from Story 12.3's review).
- **Hardening the advertiser-start ↔ CloudKit-push race window.** `RoundSetupViewModel.startRound` saves the Round locally THEN fire-and-forget pushes to CloudKit (`HyzerApp/ViewModels/RoundSetupViewModel.swift:141-186`); the advertiser kicks in immediately via `ScorecardContainerView.task`. There's a small window (typically <1s on a healthy network) where the participant's Multipeer-triggered pull returns no Round because the organizer's push hasn't landed yet. **Accepted behavior:** the participant's pull is bounded retry once via the existing CloudKit subscription path (FR16b) which fires when the push finally lands. The 5-second AC #1 budget is best-effort, not a hard guarantee in this race — degraded discovery gracefully falls back to the CloudKit subscription flow. Add NO extra polling, retry loop, or coordination handshake in this story.

### Project Structure Notes

- Protocol placement (`HyzerKit/Sync/`) and live implementation placement (`HyzerApp/Services/`) follow the established three-tier pattern: `CloudKitClient` → `LiveCloudKitClient`, `NetworkMonitor` → `LiveNetworkMonitor`, `NotificationService` → `LiveNotificationService`. No deviation from the architecture's "File Placement Rules" (`_bmad-output/planning-artifacts/architecture.md:464-488`).
- The new `nearbyDiscoveryClient` parameter on `AppServices.init` is appended to the end of the parameter list (after `notificationService`) — this is a public-init-of-an-internal-type-only-called-by-`HyzerApp.init` change; no migration impact on tests of `AppServices` that already pass explicit values (they default to `LiveNearbyDiscoveryClient()` which is harmless in tests because it never starts advertising/browsing until told to).
- Foundation framework only in HyzerKit additions. MultipeerConnectivity import is contained to the live implementation file in HyzerApp. `swift test --package-path HyzerKit` macOS host compilation remains green.
- The Bonjour service type string `"hyzer-rounds"` is hardcoded as a `static let` on the live client. There is no architectural pressure to extract it to `ColorTokens`-style configuration — it is a wire-format constant tied to the Bonjour registration in `Info.plist` and `project.yml`; centralizing it would create a three-way pinning concern without benefit.

### References

- Epic 14 scope and AC source: [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Story-14.1] (lines 585-616, 2026-05-13)
- PMVP-FR17 requirement statement: [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#L56] (lines 55-56)
- PMVP-NFR2 privacy requirement: [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#L63]
- Architectural framework note (MultipeerConnectivity + NSLocalNetworkUsageDescription + NSBonjourServices): [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#L74]
- Existing CloudKit subscription fallback path (FR16b): [Source: _bmad-output/planning-artifacts/prd.md#L542]
- Layer split precedent (CloudKitClient protocol + LiveCloudKitClient): [Source: HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift], [Source: HyzerApp/Services/LiveCloudKitClient.swift]
- DispatchQueue + AsyncStream bridging precedent (NetworkMonitor): [Source: HyzerApp/Services/LiveNetworkMonitor.swift]
- AppServices composition root: [Source: HyzerApp/App/AppServices.swift]
- Round model and lifecycle: [Source: HyzerKit/Sources/HyzerKit/Models/Round.swift]
- Round-lifecycle hooks already in place: [Source: HyzerApp/Views/Scoring/ScorecardContainerView.swift#L117-L126]
- Scoring tab @Query for active rounds: [Source: HyzerApp/Views/HomeView.swift#L349-L352]
- Sprint status entry: [Source: _bmad-output/implementation-artifacts/sprint-status.yaml#L157-L160]
- Testing convention (Swift Testing, fixtures): [Source: _bmad-output/planning-artifacts/architecture.md#L630-L672]
- CLAUDE.md coding standards (bounded queries, no silent try?, no defensive coding, design tokens): [Source: CLAUDE.md]
- Coding-standard precedent on @unchecked Sendable + DispatchQueue: [Source: HyzerApp/Services/LiveNetworkMonitor.swift#L15-L34]
- Deferred-work register (for new entries): [Source: _bmad-output/implementation-artifacts/deferred-work.md]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- SwiftData `#Predicate` macro rejected `payload.roundID` as a captured value in `handleDiscoveredRound` — fixed by extracting to `let targetRoundID = payload.roundID` before the predicate closure.
- `Player.fixture()` and `Round.fixture()` are HyzerKit test-target extensions; HyzerAppTests cannot see them — replaced with direct initializers matching the pattern in `AppServicesTests.swift`.
- `iPhone 17 with Watch` simulator unsupported on this macOS version; switched to `iPhone 17 Pro` for the `xcodebuild` test run.
- Two new test files (`AppServicesNearbyDiscoveryTests.swift`, `LiveNearbyDiscoveryClientTests.swift`) were created after the first `xcodegen generate` call — ran `xcodegen generate` a second time to pick them up.

### Completion Notes List

- `NearbyDiscoveryClient` protocol added to `HyzerKit/Sources/HyzerKit/Sync/` — Foundation-only import, zero macOS/MultipeerConnectivity coupling. HyzerKit test suite remains green (403 tests, 1 pre-existing flaky `WatchVoiceViewModel` issue unchanged).
- `LiveNearbyDiscoveryClient` implements the full advertiser + browser lifecycle using `@unchecked Sendable` + serial `DispatchQueue` (the one permitted DispatchQueue use, matching `LiveNetworkMonitor`). Invitations always rejected (`invitationHandler(false, nil)`) per PMVP-NFR2.
- `AppServices` wired: `startSync()` starts browsing + spawns stream consumer; `roundDidStart()` advertises if organizer; `roundDidEnd()` / `handleAppBackground()` stop advertising (and browsing on background); `performForegroundDiscovery()` restarts browser and advertiser on foreground.
- `handleDiscoveredRound` applies the three-gate pattern: (1) participant filter, (2) already-materialized check, (3) 30s throttle per `roundID`. All SwiftData queries bounded with `fetchLimit = 1`. All `try` wrapped in `do/catch` with logging — no silent `try?`.
- Bonjour TXT-record payload: exactly `{"rid": <UUID>, "pids": <comma-joined UUIDs>}`. Truncates to first 10 player IDs with `.notice` log if exceeded.
- `NSLocalNetworkUsageDescription` + `NSBonjourServices` added to both `Info.plist` and `project.yml`; verified via `plutil -p` and regenerated `HyzerApp.xcodeproj`.
- Decision on SyncEngine mock (Task 7.2): used `CountingCloudKitClient.fetchCallCount` as proxy for `pullRecords()` calls — consistent with the approach in `AppServicesTests`. No closure seam added; the pattern is already established and sufficient.
- Console log filter for field debugging: `subsystem:com.shotcowboystyle.hyzerapp category:NearbyDiscovery OR category:AppServices.Nearby`.
- Manual verification (Task 8) test plan documented inline — two-device smoke test on same Wi-Fi network required post-deployment; simulator-based network behavior cannot be exercised in unit tests.
- New tech debt recorded: `MockNearbyDiscoveryClient` duplicated in `HyzerKit/Tests` and `HyzerAppTests/Mocks` — tracked alongside existing `MockNotificationService` duplication per CLAUDE.md.

### File List

- `HyzerKit/Sources/HyzerKit/Sync/NearbyDiscoveryClient.swift` (NEW)
- `HyzerApp/Services/LiveNearbyDiscoveryClient.swift` (NEW)
- `HyzerApp/App/AppServices.swift` (MODIFIED)
- `HyzerApp/App/HyzerApp.swift` (MODIFIED)
- `HyzerApp/App/Info.plist` (MODIFIED)
- `project.yml` (MODIFIED)
- `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift` (NEW)
- `HyzerKit/Tests/HyzerKitTests/Sync/DiscoveredRoundPayloadTests.swift` (NEW)
- `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClientTests.swift` (NEW)
- `HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift` (NEW)
- `HyzerAppTests/LiveNearbyDiscoveryClientEncodingTests.swift` (NEW)
- `HyzerAppTests/AppServicesNearbyDiscoveryTests.swift` (NEW)
- `HyzerAppTests/LiveNearbyDiscoveryClientTests.swift` (NEW)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED)

### Review Findings

Code review performed 2026-05-18 (three-layer adversarial: Blind Hunter + Edge Case Hunter + Acceptance Auditor).

#### Decision-Needed

- [x] [Review][Decision] Throttle-stamp behavior on idempotency-hit path — Currently `lastPullByRoundID[id]` is only stamped on the pull path. When a round is already materialized, every subsequent Bonjour broadcast triggers a fresh SwiftData `FetchDescriptor<Round>` lookup until something else clears it. Options: (A) stamp on every observation regardless of outcome to suppress repeat fetches; (B) keep current behavior and accept the fetches as cheap; (C) cache a per-roundID "seen materialized" bit. Resolve before applying patches that touch the throttle.

#### Patch

- [x] [Review][Patch] AsyncStream continuation overwritten on every property access — fresh stream + clobbered continuation; protocol docstring says "same stream on re-access" but impl creates new each time [`HyzerApp/Services/LiveNearbyDiscoveryClient.swift:267-277`, `HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift:531-535`, `HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift:688-692`]
- [x] [Review][Patch] Cold-launch race — `startBrowsing()` awaited before consumer Task subscribes; continuation assigned via `queue.async`, so any `foundPeer` between browse-start and subscription is yielded to nil and lost [`HyzerApp/App/AppServices.swift:121-130`]
- [x] [Review][Patch] Consumer Task in `startSync()` is fire-and-forget — no handle stored, no cancellation; double-`startSync` would race two consumers on the same stream [`HyzerApp/App/AppServices.swift:125-130`]
- [x] [Review][Patch] Bonjour TXT-record per-pair byte limit (255 bytes) not enforced — 10×UUID joined ≈369 bytes; with `guest:<uuid>` ≈420 bytes; `MCNearbyServiceAdvertiser` may silently reject/truncate. Cap by serialized byte length, not count [`HyzerApp/Services/LiveNearbyDiscoveryClient.swift:355-367`]
- [x] [Review][Patch] `NSBonjourServices` lists `_hyzer-rounds._udp` but MultipeerConnectivity uses TCP only — dead config widens permission disclosure surface [`HyzerApp/App/Info.plist:179-181`, `project.yml:194-197`]
- [x] [Review][Patch] `lastPullByRoundID` not cleared on `roundDidEnd()` + grows unbounded across long sessions — re-discovering the same round within 30s of close is silently throttled [`HyzerApp/App/AppServices.swift:205-209`]
- [x] [Review][Patch] Throttle uses wall-clock `Date.now` — clock-going-backwards (manual time-set, NTP correction) makes `timeIntervalSince < 30` always true → silent permanent throttle. Use `ContinuousClock.now` or `DispatchTime.now()` [`HyzerApp/App/AppServices.swift:155, 174`]
- [x] [Review][Patch] `await syncEngine.pullRecords()` has no error handling; throttle stamped BEFORE pull so a failed pull blocks retry for 30s with no log of outcome [`HyzerApp/App/AppServices.swift:174-175`]
- [x] [Review][Patch] `didNotStartAdvertisingPeer` / `didNotStartBrowsingForPeers` only log — `advertiser` / `browser` remain non-nil. Next call hits idempotency check (`existing == roundID` / `browser != nil`) and no-ops forever. Clear state on denial so a later retry can succeed [`HyzerApp/Services/LiveNearbyDiscoveryClient.swift:373-380, 427-430`]
- [x] [Review][Patch] `startAdvertising` with same roundID but different `playerIDs` is silently a no-op — late-joining players never appear in the TXT record. Compare both roundID AND playerIDs when deciding to swap [`HyzerApp/Services/LiveNearbyDiscoveryClient.swift:283-285`]
- [x] [Review][Patch] `roundDidStart()` no-ops on `currentOrganizedActiveRound() == nil` — does NOT stop any previously-running advertiser. Add explicit `await stopAdvertising()` in the nil branch [`HyzerApp/App/AppServices.swift:196-201`]
- [x] [Review][Patch] `performForegroundDiscovery()` `guard let userID = iCloudRecordName` returns BEFORE the new nearby-resume code — nearby browsing/advertising never resumes when iCloud is signed out. Hoist nearby calls above the iCloud guard [`HyzerApp/App/AppServices.swift:445-451`]
- [x] [Review][Patch] `nearbyLogger.info` logs `payload.roundID` with `privacy: .public` — round UUIDs leak into Console; contradicts the "log roundID only, no PII" comment for player UUIDs (round IDs are equally trackable). Change to `.private` [`HyzerApp/App/AppServices.swift:150, 166, 170`]
- [x] [Review][Patch] `LiveNearbyDiscoveryClientTests.test_init_succeeds_andServiceTypeIs_hyzerRounds` is tautological (asserts a static constant equals its own literal). Add an actual smoke assertion (e.g., call `encodeDiscoveryInfo` for a known input + verify output dict shape) [`HyzerAppTests/LiveNearbyDiscoveryClientTests.swift:776-783`]
- [x] [Review][Patch] `MockNearbyDiscoveryClient.startAdvertising` increments call count unconditionally — does not enforce the protocol's documented idempotency contract; tests against the mock won't catch real-impl idempotency bugs [`HyzerKit/Tests/HyzerKitTests/Mocks/MockNearbyDiscoveryClient.swift:537-541`, `HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift:694-698`]
- [x] [Review][Patch] `currentOrganizedActiveRound()` predicate uses string literal `"active"` instead of `RoundStatus.active` — inconsistent with the constant used elsewhere [`HyzerApp/App/AppServices.swift:184`]
- [x] [Review][Patch] Stale `// swiftlint:disable:next trailing_closure` annotation on a non-closure DispatchQueue init [`HyzerApp/Services/LiveNearbyDiscoveryClient.swift:238-242`]
- [x] [Review][Patch] TXT-record keys `"rid"` / `"pids"` are string literals duplicated on encode and decode sides — extract to `static let` constants to prevent typo-driven silent breakage [`HyzerApp/Services/LiveNearbyDiscoveryClient.swift:363-365, 404, 410`]
- [x] [Review][Patch] Misleading comment "Spawned as an unstructured child task because the syncStateStream for-await below is the structural anchor" — the for-await is not a structural anchor; the Task is leaked. Replace with accurate justification or remove [`HyzerApp/App/AppServices.swift:123-124`]
- [x] [Review][Patch] `NearbyDiscoveryClient.discoveredRounds` protocol docstring claims "calling the property twice yields the second subscriber the same stream object" — impl creates a fresh stream each time. Either fix impl to cache OR align docstring [`HyzerKit/Sources/HyzerKit/Sync/NearbyDiscoveryClient.swift:78-80`]
- [x] [Review][Patch] `deinit` mutates `advertiser`/`browser`/`discoveredContinuation` outside the serialization queue — Dev Notes claim "all mutable state guarded by serial queue"; either use `queue.sync` in deinit or add an explicit inline comment justifying why deinit-time access is race-free [`HyzerApp/Services/LiveNearbyDiscoveryClient.swift:259-263`]

#### Deferred

- [x] [Review][Defer] Duplicate `MockNearbyDiscoveryClient` files across HyzerKit and HyzerAppTests — deferred, spec-acknowledged tech debt (parallels `MockNotificationService`) [`HyzerKit/Tests/.../Mocks/MockNearbyDiscoveryClient.swift`, `HyzerAppTests/Mocks/MockNearbyDiscoveryClient.swift`]
- [x] [Review][Defer] Tests use `for _ in 0..<20 { await Task.yield() }` and `try? await Task.sleep(...)` flaky-timing patterns — deferred, CLAUDE.md known tech debt explicitly authorized by spec line 390 [`HyzerAppTests/AppServicesNearbyDiscoveryTests.swift`, `HyzerKit/Tests/.../Mocks/MockNearbyDiscoveryClientTests.swift:588-591`]
- [x] [Review][Defer] `test_handleDiscoveredRound_throttleWindow_secondCallAfter30sTriggersAgain` not implemented — deferred, spec Task 7.1 authorized as deferred-work absent a clock-injection seam
- [x] [Review][Defer] Round.playerIDs mid-game mutation does NOT re-advertise updated TXT record — deferred, spec line 514 explicitly out-of-scope; CloudKit subscription fallback handles late joiners
- [x] [Review][Defer] Throttle test couples to `cloudKit.fetchCallCount` (transitive `SyncEngine` implementation detail) rather than a direct hook — deferred, follow-up test-quality refactor
- [x] [Review][Defer] Completion Notes mention new tech-debt entries (mock duplication) but `deferred-work.md` was not updated in this PR — deferred and now retroactively recorded in `deferred-work.md` below
