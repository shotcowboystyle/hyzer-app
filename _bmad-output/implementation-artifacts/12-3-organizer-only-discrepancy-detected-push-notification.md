# Story 12.3: Organizer-Only "Discrepancy Detected" Push Notification

Status: done

## Story

As a round organizer,
I want a push notification when a score discrepancy needs my review,
so that I can resolve conflicts without checking the app on every hole.

## Acceptance Criteria

1. **Given** the conflict detector flags a discrepancy and the current user is the round organizer, **when** the discrepancy record syncs to CloudKit, **then** within 30 seconds a push notification is delivered to the organizer's device (PMVP-FR13) **and** the alert body reads "Score discrepancy on hole [n] needs review."

2. **Given** a discrepancy is flagged in a round where the current user is a participant but not the organizer, **when** the discrepancy syncs to the device, **then** no push notification is delivered (FR49 organizer-only alert pattern preserved — enforced server-side via the subscription predicate, not client-side suppression).

3. **Given** the organizer taps the discrepancy notification, **when** the app opens, **then** the discrepancy resolution view for that specific {player, hole} appears directly.

4. **Given** the organizer has already resolved the discrepancy in-app before the notification arrives, **when** the notification is delivered, **then** tapping the notification opens the resolved discrepancy view (read-only state) with an "Already resolved" indicator **and** no duplicate resolution events are created.

5. **Given** the notification payload is inspected, **when** the alert body is read, **then** it contains only a hole number — no player names, no last names, no iCloud identifiers, no stroke counts, no course name (PMVP-NFR1 — most restrictive of the three Epic 12 stories because the discrepancy reveals organizer-internal review state).

6. **Given** multiple discrepancies are detected in the same pull cycle for the same round, **when** the alerts are dispatched, **then** the organizer receives one notification per `Discrepancy` record (CloudKit fires subscription per record save) — coalescing into a single "N discrepancies" alert is explicitly out of scope.

## Tasks / Subtasks

- [x] Task 1: Extend `NotificationService` with `DiscrepancyDetectedPayload` parsing (AC: 3, 5)
  - [x] 1.1 In `HyzerKit/Sources/HyzerKit/Notifications/NotificationService.swift`, add a new payload struct alongside `RoundStartedPayload` / `RoundCompletePayload`:
    ```swift
    public struct DiscrepancyDetectedPayload: Sendable, Equatable {
        public let discrepancyID: UUID
        public let roundID: UUID
        public let playerID: String
        public let holeNumber: Int

        public init(discrepancyID: UUID, roundID: UUID, playerID: String, holeNumber: Int) {
            self.discrepancyID = discrepancyID
            self.roundID = roundID
            self.playerID = playerID
            self.holeNumber = holeNumber
        }
    }
    ```
    Keep the file UserNotifications/UIKit-clean — it must compile on macOS for HyzerKitTests (same constraint as 12.1/12.2). The payload carries `playerID` (a String, since `Player.id` UUIDs are stored as strings on the Discrepancy DTO for guest compatibility) so the deep-link handler can navigate directly to the correct `{player, hole}` pair (AC #3).
  - [x] 1.2 Add a new protocol method symmetric to `parseRoundCompletePayload(_:)`:
    ```swift
    /// Parses a CKQuerySubscription user-info dictionary into a typed `DiscrepancyDetectedPayload`.
    /// Returns `nil` if the dictionary is not a Discrepancy-creation subscription payload,
    /// or if required fields (`rid`, `playerID`, `holeNumber`) are absent or malformed.
    ///
    /// No `shouldSuppressPresentation` overload exists for this payload — organizer-only
    /// enforcement happens server-side via the subscription predicate `organizerID == <localUserID>`.
    /// Non-organizer devices never register the subscription, so they never receive the push.
    func parseDiscrepancyDetectedPayload(_ userInfo: [AnyHashable: Any]) -> DiscrepancyDetectedPayload?
    ```
  - [x] 1.3 Extend `MockNotificationService` in **both** `HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift` and `HyzerAppTests/Mocks/MockNotificationService.swift` with `parseDiscrepancyDetectedPayload` (mirror the `parseRoundCompletePayload` shape: settable `discrepancyPayloadToReturn`, tracked `parseDiscrepancyPayloadCallCount`, captured `capturedParseDiscrepancyPayloadArgs`). Do **not** consolidate the two mocks — that cleanup belongs with the `ValueCollector` extraction debt (deferred-work.md:25).
  - [x] 1.4 In `HyzerApp/Services/LiveNotificationService.swift`, implement `parseDiscrepancyDetectedPayload` reusing the shared `CKNotificationEnvelope` helper. The subscription delivers `desiredKeys = ["playerID", "holeNumber"]` under `qry["af"]`. Required: `qry["sid"] == NotificationSubscriptionID.discrepancyCreation`, `qry["rid"]` → discrepancy UUID, `af["roundID"]` → round UUID string, `af["playerID"]` → String, `af["holeNumber"]` → Int. Missing or malformed → return `nil`. Follow Story 12.2's parser shape exactly (the P2 review patch added SID validation; do not regress).
  - [x] 1.5 Add a new subscription-ID constant to the `NotificationSubscriptionID` enum in `LiveNotificationService.swift`:
    ```swift
    enum NotificationSubscriptionID {
        static let roundActiveCreation = "Round-active-creation"
        static let roundCompleteUpdate = "Round-complete-update"
        static let discrepancyCreation = "Discrepancy-creation"
    }
    ```
    Used by both the subscription registration in `SyncScheduler` (Task 5) and the parser SID guard (Task 1.4) and the AppDelegate dispatch switch (Task 7.1).

- [x] Task 2: Add `DiscrepancyRecord` DTO and `recordType` plumbing (AC: 1, 2, 5)
  - [x] 2.1 Create `HyzerKit/Sources/HyzerKit/Sync/DTOs/DiscrepancyRecord.swift` modelled on `RoundRecord.swift`. The `Discrepancy` model does NOT currently sync to CloudKit — this story is what makes it sync. PII gate (PMVP-NFR1, AC #5): the DTO must NOT carry any data not strictly required for routing + the organizer-only subscription predicate.
    ```swift
    import Foundation
    import CloudKit

    /// DTO for syncing `Discrepancy` to CloudKit so the `Discrepancy-creation` subscription
    /// can fire and deliver an organizer-only push notification (Story 12.3).
    ///
    /// PII gate (PMVP-NFR1, Story 12.3 AC #5):
    /// - NO playerName (we send playerID string only — the organizer's local DB resolves to a display name)
    /// - NO course name, no stroke counts, no event IDs
    /// - organizerID is denormalized from the parent Round so the subscription predicate
    ///   `organizerID == <localUserID>` can filter server-side; non-organizers never receive the push
    public struct DiscrepancyRecord: Sendable {
        public static let recordType = "Discrepancy"

        public let id: UUID
        public let roundID: UUID
        /// Denormalized from the parent Round.organizerID so the CK subscription predicate
        /// can filter server-side without a join. The only reason this field exists on the DTO.
        public let organizerID: UUID
        /// String form (Player UUID or guest:<uuid>) — matches Discrepancy.playerID storage type.
        public let playerID: String
        public let holeNumber: Int
        public let createdAt: Date

        public init(id: UUID, roundID: UUID, organizerID: UUID, playerID: String, holeNumber: Int, createdAt: Date) {
            self.id = id
            self.roundID = roundID
            self.organizerID = organizerID
            self.playerID = playerID
            self.holeNumber = holeNumber
            self.createdAt = createdAt
        }
    }

    extension DiscrepancyRecord {
        public func toCKRecord() -> CKRecord {
            let recordID = CKRecord.ID(recordName: id.uuidString)
            let record = CKRecord(recordType: Self.recordType, recordID: recordID)
            record["roundID"] = roundID.uuidString as CKRecordValue
            record["organizerID"] = organizerID.uuidString as CKRecordValue
            record["playerID"] = playerID as CKRecordValue
            record["holeNumber"] = holeNumber as CKRecordValue
            record["createdAt"] = createdAt as CKRecordValue
            return record
        }

        public init?(from ckRecord: CKRecord) {
            guard ckRecord.recordType == Self.recordType else { return nil }
            let recordName = ckRecord.recordID.recordName
            guard !recordName.isEmpty, let id = UUID(uuidString: recordName) else { return nil }
            guard
                let roundIDString = ckRecord["roundID"] as? String,
                let roundID = UUID(uuidString: roundIDString),
                let organizerIDString = ckRecord["organizerID"] as? String,
                let organizerID = UUID(uuidString: organizerIDString),
                let playerID = ckRecord["playerID"] as? String,
                let holeNumber = ckRecord["holeNumber"] as? Int,
                let createdAt = ckRecord["createdAt"] as? Date
            else { return nil }
            self.id = id
            self.roundID = roundID
            self.organizerID = organizerID
            self.playerID = playerID
            self.holeNumber = holeNumber
            self.createdAt = createdAt
        }
    }
    ```
  - [x] 2.2 **Do NOT add `eventID1`, `eventID2`, `resolvedByEventID`, or `status` to the DTO.** Those are local resolution-state fields. Syncing them would either (a) leak resolution-internal data through APNs alertLocalizationArgs (PMVP-NFR1 violation if ever surfaced in the alert body) or (b) require Discrepancy resolution to also sync — which is event-sourced via the resolution ScoreEvent already (Story 6.1). The CK record exists only to trigger the subscription and route the deep-link.
  - [x] 2.3 **Record ID is the local `Discrepancy.id` UUID, not a deterministic content hash.** All devices independently detect the same discrepancy and create independent local `Discrepancy` records with different UUIDs. The first device to push wins the CKRecord; subsequent pushes from peer devices either succeed (creating duplicate CKRecords for the same conceptual conflict) or fail with `.serverRecordChanged` if they happen to collide. Task 4.3 enforces "first writer wins" via an in-memory dedup gate in `SyncEngine` so the organizer doesn't get N duplicate push notifications for the same {round, player, hole} conflict.

- [x] Task 3: Add organizer-id resolution helper on `AppServices` (AC: 2)
  - [x] 3.1 The CK subscription predicate is `organizerID == %@` where `%@` is the local player's `Player.id` UUID **string form**. The local player ID is already resolvable via `AppServices.resolveLocalPlayerID(from:)` (`HyzerApp/App/AppServices.swift:187-197`). No new helper needed — read directly at subscription-setup time.
  - [x] 3.2 **The subscription must be (re)registered when the local player ID becomes available** — i.e., after `Player` onboarding completes. At app first-launch, the Player row exists before `SyncScheduler.start()` is called (onboarding is enforced by `ContentView` before `HomeView` mounts, and `startSync()` runs from HomeView's `.task`). Confirm by inspection of `HyzerApp.swift` lifecycle and `ContentView` routing before implementing. If `resolveLocalPlayerID` returns `nil` at subscription setup time (pre-onboarding edge), skip the discrepancy subscription registration and rely on the next launch to register it. Do NOT crash, do NOT subscribe with an empty predicate, and do NOT subscribe with `NSPredicate(value: true)` (that would send every device every discrepancy — catastrophic PII leak and exactly the AC #2 failure mode).
  - [x] 3.3 Important contract: the subscription is keyed by `organizerID == <thisDevicePlayerID>`. A user who is the organizer of round A but a participant in round B receives notifications ONLY for round A's discrepancies — exactly correct. If a user is never an organizer, they will never receive a discrepancy push (correct per AC #2).

- [x] Task 4: Add `pushDiscrepancy` to `SyncEngine` + wire from `detectConflicts` (AC: 1, 2, 6)
  - [x] 4.1 Create `HyzerKit/Sources/HyzerKit/Sync/SyncEngine+Discrepancy.swift` (new file, mirrors the `SyncEngine+RoundCompletion.swift` extraction pattern from Story 12.2 — keeps the main `SyncEngine.swift` under the 600-line SwiftLint threshold). Inside, add:
    ```swift
    public func pushDiscrepancy(
        discrepancyID: UUID,
        roundID: UUID,
        organizerID: UUID,
        playerID: String,
        holeNumber: Int,
        createdAt: Date
    ) async
    ```
    Signature mirrors `pushRoundCompletion`'s value-only (Sendable primitives only) shape — `@Model` objects must never cross the actor boundary.
  - [x] 4.2 Implementation: build a `DiscrepancyRecord`, convert to `CKRecord`, save via `cloudKitClient.save([record])` (use the standard `.ifServerRecordUnchanged` policy — this is a CREATE-only write; the record is brand new with no existing server tag). Reuse the `.pending → .inFlight → .synced/.failed` state machine via `SyncMetadata` keyed by `DiscrepancyRecord.recordType` + `discrepancyID.uuidString`. Apply the same `CKError.serverRecordChanged → .synced` handling lifted from `pushRound`/`pushRoundCompletion` — for this use case `serverRecordChanged` indicates a concurrent push from a peer device for the same `Discrepancy.id` (rare — different devices generate different UUIDs) or a re-push of the same record after a local crash; treat as success.
  - [x] 4.3 **Duplicate-push gate** — `SyncEngine.detectConflicts` (`SyncEngine.swift:392-450`) already has an `existingDiscrepancies.contains { ... }` guard that skips creating a second `Discrepancy` record for the same `{roundID, playerID, holeNumber}` triple on a single device. The CloudKit write goes inside the `case .discrepancy` branch, AFTER `modelContext.insert(discrepancy)`. Because the `existingDiscrepancies` guard already prevents per-device duplicates, the push call below it is fired at most once per `{round, player, hole}` per device. Cross-device duplicates (Device A and Device B both push their local `Discrepancy.id` for the same conceptual conflict) are accepted as a known limitation — see Edge Cases. **Do not** attempt cross-device deduplication via deterministic record IDs (Task 2.3) — that complicates resolution semantics and is out of scope.
  - [x] 4.4 Wire the push from `detectConflicts` after the insert. The conflict-detection code path does NOT have direct access to `organizerID` — it has `newEvent.roundID` only. Fetch the `Round` once at the top of `detectConflicts` (bounded query, scoped to `affectedRoundIDArray`) and build a `[roundID: organizerID]` lookup so each `pushDiscrepancy` call can resolve organizerID without re-fetching. If a round is missing locally (peer pushed events for a round that hasn't reached this device yet), log and skip the push for that discrepancy — the next pull cycle will re-detect once the round arrives.
    ```swift
    let roundLookup = fetchRounds(forIDs: Set(affectedRoundIDArray))
    let organizerByRoundID = Dictionary(uniqueKeysWithValues: roundLookup.map { ($0.id, $0.organizerID) })
    // ... existing detection loop ...
    // After modelContext.insert(discrepancy):
    if let organizerID = organizerByRoundID[newEvent.roundID] {
        let did = discrepancy.id
        let rid = newEvent.roundID
        let pid = newEvent.playerID
        let hole = newEvent.holeNumber
        let createdAt = discrepancy.createdAt
        Task { await self.pushDiscrepancy(discrepancyID: did, roundID: rid, organizerID: organizerID, playerID: pid, holeNumber: hole, createdAt: createdAt) }
    } else {
        logger.error("SyncEngine.detectConflicts: round \(newEvent.roundID) not locally materialised — skipping discrepancy push")
    }
    ```
    Add a private `fetchRounds(forIDs:)` helper alongside `fetchScoreEvents(forRoundIDs:)` at `SyncEngine.swift:489-499` using the same bounded pattern: `descriptor.fetchLimit = idArray.count`.
  - [x] 4.5 **Actor boundary**: `pushDiscrepancy` is called from within `detectConflicts` which already runs on the SyncEngine actor. Wrap the call in `Task { await self.pushDiscrepancy(...) }` (fire-and-forget, NOT awaited inline) so a slow CK save doesn't block the rest of the conflict-detection loop. The `Task` captures `self` weakly... actually, since `SyncEngine` is an actor, `Task { await self.foo() }` is safe — actor self-references inside child tasks don't create a cycle (the task completes and releases). Use a strong reference for clarity. Same pattern as `ScorecardContainerView.handleRoundCompleted`'s fire-and-forget.

- [x] Task 5: Add `Discrepancy-creation` CKQuerySubscription with organizer-only predicate (AC: 1, 2)
  - [x] 5.1 In `HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift`, add a private method `setupDiscrepancyCreationSubscription(existingIDs:localPlayerID:)` modelled on `setupRoundCompleteSubscription(existingIDs:)` (line 241-269).
  - [x] 5.2 Subscription configuration:
    - Subscription ID: `"Discrepancy-creation"`
    - **Predicate: `NSPredicate(format: "organizerID == %@", localPlayerID.uuidString)`** — this is the server-side organizer-only gate (AC #2). Non-organizer devices register a subscription with their own player ID, which will never match a discrepancy from a round where they are not the organizer.
    - Options: `[.firesOnRecordCreation]` — Discrepancy records are CREATE-only (immutable per event-sourcing; resolution is a separate ScoreEvent, not a Discrepancy mutation). `firesOnRecordUpdate` is NOT appropriate.
    - `NotificationInfo.shouldSendContentAvailable = true`, `shouldSendMutableContent = false`
    - `alertLocalizationKey = "DISCREPANCY_DETECTED_FORMAT"`
    - `alertLocalizationArgs = ["holeNumber"]` — case-sensitive field name matching the CKRecord key exactly. **No player name, no course name.** AC #5 requires the alert body to mention only the hole number — CloudKit substitutes the record-side `holeNumber` value into the localized format string at delivery; PII never enters the APNs payload (PMVP-NFR1 structural guarantee, same mechanism as 12.1/12.2).
    - `desiredKeys = ["playerID", "holeNumber"]` so `parseDiscrepancyDetectedPayload` reads them without a refetch. `roundID` is also needed by the deep-link handler — include in `desiredKeys` too: `["roundID", "playerID", "holeNumber"]`. Do NOT include `organizerID` in `desiredKeys` (the predicate already filtered; the client doesn't need it back).
  - [x] 5.3 Call `await cloudKitClient.subscribeWithAlert(...)` (added in Story 12.1). No protocol changes needed.
  - [x] 5.4 UserDefaults idempotency key: `"HyzerApp.subscriptionID.Discrepancy-creation"` (keyed by full subscription ID, matching the post-12.2 convention).
    
    **Critical: invalidation on organizer-ID change.** The subscription is keyed by the local player's UUID embedded in the predicate. If a future story ever supports identity migration (e.g., re-onboarding under a new iCloud account) the subscription must be re-registered with the new predicate. Today, `Player.id` is stable per device (set once at onboarding and never reassigned), so the subscription does not need re-registration during normal use. Document this constraint in the function doc-comment so future maintainers know to delete and re-register if the player ID semantics change.
  - [x] 5.5 Wire `setupDiscrepancyCreationSubscription` into `setupSubscriptions()` after the call to `setupRoundCompleteSubscription`. Resolve `localPlayerID` once at the top of `setupSubscriptions` via the existing `Player` fetch pattern from `AppServices.resolveLocalPlayerID`. **`SyncScheduler` does NOT currently have a `ModelContainer` reference** — it would need one to fetch the `Player`. Two design options:
    - (a) Inject a `localPlayerIDProvider: @Sendable () async -> UUID?` closure into `SyncScheduler.init`, defaulting to a closure that fetches from the main `ModelContainer` via the `AppServices` composition root. Cleanest separation.
    - (b) Pass `localPlayerID: UUID?` directly as a parameter to `SyncScheduler.start()`. Simpler but couples the call site to identity timing.
    
    **Choose (a)** — it preserves `SyncScheduler.start()`'s zero-argument signature (Story 12.1/12.2 callers stay unchanged) and gives tests a clean injection point.
  - [x] 5.6 In `AppServices.init`, wire the closure: `localPlayerIDProvider: { [container = modelContainer] in await MainActor.run { AppServices.resolveLocalPlayerID(from: container.mainContext) } }`. The `await MainActor.run` is required because `ModelContainer.mainContext` is `@MainActor`-isolated and `SyncScheduler` is a non-MainActor actor.
  - [x] 5.7 If `localPlayerID` is `nil` at subscription-setup time, log and skip the discrepancy subscription registration (Task 3.2). The next launch's `setupSubscriptions()` will retry. **Do NOT subscribe with a "match nothing" predicate as a placeholder** — that wastes a subscription quota slot.
  - [x] 5.8 `aps-environment` remains `development` — same constraint as 12.1/12.2 (`deferred-work.md:10`). After this story ships, the Epic 12 release-train flip blocks all three Epic 12 stories. Note in Completion Notes.

- [x] Task 6: Pull discrepancy records on remote-notification + extend `pullRecords` to pull Discrepancy (AC: 3, 4)
  - [x] 6.1 `SyncEngine.pullRecords` (`SyncEngine.swift:304-385`) currently pulls only `ScoreEvent` records. The organizer's local DB needs the `Discrepancy` record materialised before the deep-link handler can navigate to it (otherwise tapping the notification fails to find the discrepancy locally). **However**: `detectConflicts` already creates a local `Discrepancy` record on the organizer's device when their own pull cycle materialises the conflicting `ScoreEvent`s. The CK push from peer devices is a *separate* path that supplements (does not replace) local detection.
    
    **Decision**: do NOT extend `pullRecords` to pull Discrepancy CKRecords. The organizer's local `Discrepancy` is created by `detectConflicts` on the organizer's own device's pull. The CK push exists ONLY to drive the subscription notification. The deep-link handler (Task 7) reads the local Discrepancy by either {round, player, hole} lookup (preferred) or by ID — if not found, it falls back to the `DiscrepancyListView` for the round (still useful to the organizer; matches AC #4 "Already resolved" state).
  - [x] 6.2 Document this design choice in Dev Notes: the CK Discrepancy record is push-only fuel for the subscription, not a synced authoritative source. The local Discrepancy is the source of truth for resolution state. This means pull-side handling for Discrepancy is **not needed** in this story.

- [x] Task 7: Add `.discrepancyResolution` deep-link + AppServices handler (AC: 3, 4)
  - [x] 7.1 In `HyzerApp/App/AppServices.swift`, extend the `DeepLink` enum:
    ```swift
    enum DeepLink: Equatable {
        case activeRound(roundID: UUID)
        case roundSummary(roundID: UUID)
        case discrepancyResolution(roundID: UUID, playerID: String, holeNumber: Int)
    }
    ```
    Keep `Equatable` conformance (added in 12.1, relied on by HomeView's `.onChange`). Routing key is `{roundID, playerID, holeNumber}` because the local `Discrepancy.id` UUID may differ from the CKRecord's UUID (Task 2.3 first-writer-wins); the triple is the stable cross-device identity.
  - [x] 7.2 Add `handleDiscrepancyDetectedNotification(_ userInfo: [AnyHashable: Any]) async` symmetric to `handleRoundCompleteNotification` (line 151-183). Logic:
    1. Parse payload via `notificationService.parseDiscrepancyDetectedPayload`.
    2. **No self-exclusion check needed** — the subscription predicate already guarantees server-side that only the organizer receives this. The `shouldSuppressPresentation` family of overloads should NOT be extended for `DiscrepancyDetectedPayload`.
    3. `await syncEngine.pullRecords()` so any conflicting `ScoreEvent`s arrive locally and `detectConflicts` materialises the local `Discrepancy` if it hasn't already. The local `Discrepancy` is what the resolution view reads.
    4. One-shot retry: if no `Discrepancy` exists locally matching `{payload.roundID, payload.playerID, payload.holeNumber}` after the first pull, pull once more (covers notify-before-sync race for the underlying ScoreEvent records).
    5. **Idempotency / "already resolved" support (AC #4)**: do NOT filter by `status == .unresolved`. If the matching `Discrepancy` exists with `status == .resolved`, set the deep-link anyway — the view layer (Task 8) is responsible for showing the read-only resolved state.
    6. Set `pendingDeepLink = .discrepancyResolution(roundID:, playerID:, holeNumber:)`. If no matching `Discrepancy` exists even after retry, do NOT set the deep-link (would route to an empty view that instantly dismisses, per the Story 12.2 review patch). Log and return.
    7. Logger.info — no PII (no player name, no course name).
  - [x] 7.3 Extend `seedDeepLinkFromLaunchOptions(_:)` (line 208-241) to recognise discrepancy-detected notifications. Cleanest pattern: try `parseDiscrepancyDetectedPayload` first, then `parseRoundCompletePayload`, then `parseRoundStartedPayload`, set the appropriate `DeepLink` case. Reuse the same fire-and-forget pull + one-shot retry block. Order matters: discrepancy-detected first because it's the most specific routing target.
  - [x] 7.4 No new helper needed on AppServices beyond the existing `roundExists`. The deep-link does not require the round to exist for AC #4's "already resolved" path — the local Discrepancy may exist even after the round is completed and archived.

- [x] Task 8: AppDelegate branching + HomeView deep-link consumption (AC: 3, 4)
  - [x] 8.1 In `HyzerApp/App/HyzerApp.swift` `AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` (line 150-171), extend the subscription-ID switch:
    ```swift
    switch subscriptionID {
    case NotificationSubscriptionID.roundActiveCreation:
        await services.handleRoundStartedNotification(userInfo)
    case NotificationSubscriptionID.roundCompleteUpdate:
        await services.handleRoundCompleteNotification(userInfo)
    case NotificationSubscriptionID.discrepancyCreation:
        await services.handleDiscrepancyDetectedNotification(userInfo)
    default:
        await services.handleRemoteNotification()
    }
    ```
    Always call `completionHandler(.newData)` after the work completes (existing pattern).
  - [x] 8.2 In `HyzerApp/Views/HomeView.swift`, extend `consumePendingDeepLinkIfNeeded()` (line 55-74). Add a `.discrepancyResolution` case:
    - Switch `selectedTab = 0` (Scoring tab — where the organizer's mental model of "the round" lives).
    - **If `activeRounds` contains the target `roundID`**: the organizer is in-app on that round's scoring view. The existing `discrepancyBadgeCount` + `LeaderboardPillView` badge + `DiscrepancyListView` sheet path (`ScorecardContainerView.swift:106-108, 192-219, 408-417`) already surfaces the discrepancy. Setting `selectedTab = 0` is sufficient — the existing `@Query` for `roundDiscrepancies` will include the new record and the `unresolvedDiscrepancies.count` `.onChange` (`ScorecardContainerView.swift:147`) will spin up the `DiscrepancyViewModel`. Set `pendingDeepLink = nil` and **do not** force-present the resolution sheet (the badge is enough; respect the organizer's flow).
    - **If `activeRounds` does NOT contain the target `roundID`** (e.g., round completed, or organizer closed the app): present `DiscrepancyResolutionDeepLinkHost` (a new lightweight host similar to `RoundCompletionSummaryHost`) as a `.fullScreenCover` from HomeView. The host fetches the matching local `Discrepancy` and presents `DiscrepancyResolutionView` directly (the existing view already handles both `.unresolved` and `.resolved` states via `viewModel.unresolvedDiscrepancies`).
  - [x] 8.3 Add `@State private var pendingDiscrepancyKey: DiscrepancyDeepLinkKey?` to `HomeView` where `DiscrepancyDeepLinkKey` is `struct { let roundID: UUID; let playerID: String; let holeNumber: Int }: Identifiable, Equatable` (Identifiable via a composed `id = "\(roundID)-\(playerID)-\(holeNumber)"`).
  - [x] 8.4 Add a `.fullScreenCover(item: $pendingDiscrepancyKey)` modifier wrapping the existing one, presenting `DiscrepancyResolutionDeepLinkHost(key:onDismiss:)` (Task 8.5). Order modifiers so the discrepancy cover and the summary cover don't double-present — SwiftUI's `.fullScreenCover` does not stack; if both `pendingDiscrepancyKey` and `pendingSummaryRoundID` are set in the same render cycle (extremely unlikely but possible), the first-defined modifier wins. Add the discrepancy modifier ABOVE the summary modifier so a discrepancy notification preempts a summary notification (correct priority — discrepancies are organizer action items).
  - [x] 8.5 Add `DiscrepancyResolutionDeepLinkHost`: a `private struct` in `HomeView.swift` modelled on `RoundCompletionSummaryHost`. Body:
    1. Bounded `@Query` (use imperative `try modelContext.fetch` with `fetchLimit = 1` since the key is dynamic) for the matching `Discrepancy` where `roundID == key.roundID && playerID == key.playerID && holeNumber == key.holeNumber`. Order by `createdAt` descending and take the first — if multiple `Discrepancy` records exist for the same triple (cross-device duplicate, see Edge Cases), prefer the most recent.
    2. Bounded `@Query` for the `Player` referenced by `key.playerID` (if it's a guest ID prefixed `guest:`, fall back to the guest name lookup via the parent `Round.guestNames`). Bounded `@Query` for the `Round` (for the organizer ID, needed by `DiscrepancyViewModel.init`).
    3. Construct a `DiscrepancyViewModel` with the same constructor inputs as `ScorecardContainerView.updateDiscrepancyViewModel()` (line 207-214). `currentPlayerID` is the local Player UUID (the organizer, since this code path is gated by the subscription predicate).
    4. Present `DiscrepancyResolutionView` directly (not the list — there's exactly one discrepancy targeted). Wrap in a `NavigationStack` with a "Done" toolbar button that calls `onDismiss`.
    5. **AC #4 "Already resolved" indicator**: extend `DiscrepancyResolutionView` to accept an optional banner. When the loaded `Discrepancy.status == .resolved`, show a non-blocking banner above the score-option buttons ("Already resolved — read-only") and disable the score-option buttons (so tapping is a no-op). The existing view already loads the `(ScoreEvent, ScoreEvent)` pair from `eventID1`/`eventID2`; rendering them read-only preserves the audit trail for the organizer. AC #4 explicitly forbids creating duplicate resolution events, so the disabled buttons are the safest path.
  - [x] 8.6 Confirm the existing `.onAppear` / `.onChange(of: pendingDeepLink)` pattern (line 39-40) handles both cold-launch (Task 7.3 seeding) and hot-launch routing for the new case — verify in a unit test by setting `appServices.pendingDeepLink = .discrepancyResolution(...)` and expecting `pendingDiscrepancyKey` to populate.

- [x] Task 9: Localizable strings + tests (AC: 1, 2, 3, 4, 5, 6)
  - [x] 9.1 Extend `HyzerApp/Resources/en.lproj/Localizable.strings`:
    ```
    /* Push notification alert body for "Discrepancy Detected" (Story 12.3, AC #1, #5).
       %1$@ = hole number (CloudKit substitutes the integer via alertLocalizationArgs).
       PII gate: NO player name, NO course name, NO stroke counts in the alert body.
       Positional specifier preserved for future translator flexibility (matches 12.1/12.2). */
    "DISCREPANCY_DETECTED_FORMAT" = "Score discrepancy on hole %1$@ needs review.";
    ```
    Match the positional-specifier style of `ROUND_STARTED_FORMAT` and `ROUND_COMPLETE_FORMAT`.
  - [x] 9.2 `HyzerKit/Tests/HyzerKitTests/Notifications/DiscrepancyDetectedPayloadTests.swift` (new file): payload value-type tests + `MockNotificationService.parseDiscrepancyDetectedPayload` stub-contract tests, mirroring `RoundCompletePayloadTests.swift`. **Live parser** SID/field validation goes in `HyzerAppTests/LiveNotificationServiceTests.swift` (not this file — `LiveNotificationService` is in HyzerApp). Mirror the Story 12.2 P1 patch — do not skip live-parser tests.
  - [x] 9.3 `HyzerKit/Tests/HyzerKitTests/DiscrepancyRecordTests.swift` (new file):
    - `test_toCKRecord_writesExactKeySet`: assert `record.allKeys()` is exactly `["roundID", "organizerID", "playerID", "holeNumber", "createdAt"]`. PII allowlist guarantee (AC #5) — must NOT contain `eventID1`, `eventID2`, `resolvedByEventID`, `status`, or any name/course field.
    - `test_init_fromCKRecord_roundTrip`: build a CKRecord with all keys, init the DTO, assert fields match.
    - `test_init_fromCKRecord_missingRequiredField_returnsNil`: iterate over each required key, remove it from the CKRecord, assert `init?(from:)` returns nil.
    - `test_init_fromCKRecord_wrongRecordType_returnsNil`: pass a CKRecord with `recordType = "WrongType"`, assert nil.
  - [x] 9.4 `HyzerKit/Tests/HyzerKitTests/SyncSchedulerTests.swift` (extend the existing suite from Story 12.2):
    - Assert that after `setupSubscriptions()` runs with a non-nil `localPlayerIDProvider`, **four** subscriptions are saved: `ScoreEvent-creation`, `Round-active-creation`, `Round-complete-update`, and `Discrepancy-creation`.
    - Assert the discrepancy subscription's `notificationInfo.alertLocalizationKey == "DISCREPANCY_DETECTED_FORMAT"`, `alertLocalizationArgs == ["holeNumber"]`, `desiredKeys == ["roundID", "playerID", "holeNumber"]`.
    - Assert the discrepancy subscription's `predicate.predicateFormat` contains `organizerID == "<some-uuid>"` (use a fixed UUID injected via the provider so the assertion is deterministic).
    - `test_setupSubscriptions_skipsDiscrepancy_whenLocalPlayerIDUnavailable`: inject a provider that returns `nil`, assert `savedAlertSubscriptions` does NOT contain a `Discrepancy-creation` entry, and the other three subscriptions are still created.
    - Idempotency: second call to `setupSubscriptions()` with the same persisted IDs does NOT save an additional discrepancy subscription.
  - [x] 9.5 `HyzerKit/Tests/HyzerKitTests/SyncEnginePushDiscrepancyTests.swift` (new file, mirrors `SyncEnginePushRoundCompletionTests.swift`):
    - `test_pushDiscrepancy_savesCKRecord_andMarksSynced`: call `pushDiscrepancy`, assert `MockCloudKitClient.savedRecords` contains the discrepancy record and `SyncMetadata` for it is `.synced`.
    - `test_pushDiscrepancy_serverRecordChanged_marksSynced`: configure mock to throw `CKError(.serverRecordChanged)`, assert `SyncMetadata.syncStatus == .synced` (concurrent-push idempotency).
    - `test_pushDiscrepancy_networkError_marksFailed`: configure mock to throw `CKError(.networkUnavailable)`, assert `.failed`.
    - `test_pushDiscrepancy_alreadySynced_skips`: pre-populate `SyncMetadata` with `.synced` for the discrepancy ID, call `pushDiscrepancy`, assert no additional save on the mock.
  - [x] 9.6 `HyzerKit/Tests/HyzerKitTests/SyncEngineConflictTests.swift` (extend the existing suite — see `HyzerKit/Tests/HyzerKitTests/ConflictDetectorTests.swift` and `SyncEngineConflictTests.swift` for the existing patterns):
    - `test_detectConflicts_pushesDiscrepancy_onNewConflict`: run a pull that triggers a discrepancy; assert exactly one `pushDiscrepancy` call recorded by an injected mock. Use a small wrapper or partial-mock pattern that intercepts `pushDiscrepancy` without touching the actor's `cloudKitClient` directly — easier: inspect `MockCloudKitClient.savedRecords` for a `DiscrepancyRecord.recordType` entry.
    - `test_detectConflicts_doesNotPush_whenRoundMissing`: arrange a peer-pushed ScoreEvent for a roundID not present in local SwiftData; assert no `Discrepancy` CKRecord is saved (Task 4.4 fallback) and the `detectConflicts` log line is emitted.
    - `test_detectConflicts_doesNotDoublePush_onSecondPullCycle`: run pull twice with the same peer events; the existing `existingDiscrepancies.contains` guard means the second pass skips both the local insert AND the push (Task 4.3). Assert exactly one `DiscrepancyRecord` save on the mock.
  - [x] 9.7 `HyzerAppTests/AppServicesTests.swift` (extend):
    - `test_handleDiscrepancyDetectedNotification_setsDeepLink`: feed synthetic userInfo, pre-populate a local `Discrepancy`, assert `pendingDeepLink == .discrepancyResolution(roundID:, playerID:, holeNumber:)`.
    - `test_handleDiscrepancyDetectedNotification_dropsDeepLink_whenDiscrepancyMissing`: pre-populate no local Discrepancy and a stubbed `SyncEngine.pullRecords` that does nothing; assert `pendingDeepLink == nil`.
    - `test_handleDiscrepancyDetectedNotification_setsDeepLink_whenAlreadyResolved`: pre-populate a Discrepancy with `status == .resolved`; assert deep-link is still set (AC #4).
    - `test_handleDiscrepancyDetectedNotification_retriesPullOnce_whenDiscrepancyMissing`: assert exactly two `pullRecords` calls before giving up.
    - Use `Task.yield()` for actor synchronization, NOT `Task.sleep` — same rule as 12.1/12.2 (CLAUDE.md retro debt).
  - [x] 9.8 `HyzerAppTests/LiveNotificationServiceTests.swift` (extend):
    - `test_parseDiscrepancyDetectedPayload_validInput_returnsPayload`: construct a representative `userInfo` dict matching the CKSubscription envelope shape (`ck.qry.sid == "Discrepancy-creation"`, `ck.qry.rid == <UUID>`, `ck.qry.af = ["roundID": ..., "playerID": ..., "holeNumber": ...]`); assert the parser returns the expected payload.
    - Negative tests: wrong SID, missing `rid`, missing each required `af` field — assert nil.
    - **Foreign-payload SID guard test**: feed a `userInfo` with `sid == "Round-complete-update"` (structurally compatible since both carry `rid`); assert `parseDiscrepancyDetectedPayload` returns nil (regression on the Story 12.2 P2 patch that added SID guards).
  - [x] 9.9 `HyzerAppTests/DiscrepancyDeepLinkRoutingTests.swift` (new file): integration test for the HomeView deep-link consumption. Pre-populate `AppServices.pendingDeepLink = .discrepancyResolution(...)` plus a matching local Discrepancy, render HomeView in a hosting controller, assert `pendingDiscrepancyKey` is populated and `selectedTab == 0`. (If HostingController-based view tests are not used elsewhere in HyzerAppTests, skip this in favor of an `AppServicesTests` unit test that asserts the deep-link is set correctly — leave UI verification to manual testing per AC #3 / #4 sign-off.)
  - [x] 9.10 **PII allowlist test (Task 9.3)** is the most important test in this story — it is the structural guarantee of PMVP-NFR1 for the discrepancy notification path. Treat any regression as a P0 release blocker. The blocklist is exhaustive: no `playerName`, no `displayName`, no `iCloudRecordName`, no `email`, no `courseName`, no `strokeCount`, no `eventID1`/`eventID2`, no `resolvedByEventID`, no `status`.

### Review Findings

_Code review 2026-05-17 — Blind Hunter + Edge Case Hunter + Acceptance Auditor (parallel adversarial layers)._

**Decision needed (0):** _All 3 resolved into patches (see below)._

- [x] [Review][Decision][Resolved → Patch] AC #3 literal vs Task 8.2 reinterpretation — accepted current behavior; documented in code with a docstring note that AC #3 is reinterpreted via Task 8.2 for active rounds (badge path is sufficient).
- [x] [Review][Decision][Resolved → Patch] Deep-link clobber — adopt precedence rule: `discrepancyResolution > roundSummary > activeRound`. Handlers and `seedDeepLinkFromLaunchOptions` must skip overwrite when the in-flight link has equal-or-higher precedence and log the skip.
- [x] [Review][Decision][Resolved → Patch] `.mcp.json` — revert from this commit; ship separately if needed.

**Patches (15) — all applied:**

- [x] [Review][Patch] AC #3 docstring annotation — added in `consumePendingDeepLinkIfNeeded`. [`HyzerApp/Views/HomeView.swift`]
- [x] [Review][Patch] Deep-link precedence rule — `DeepLink.precedence` + `setPendingDeepLinkIfHigherOrEqualPrecedence` applied across all 3 handlers and `seedDeepLinkFromLaunchOptions` (all 3 branches). [`HyzerApp/App/AppServices.swift`]
- [x] [Review][Patch] Reverted `.mcp.json` to prior config. [`.mcp.json`]

- [x] [Review][Patch] `Task.sleep` replaced with `awaitCondition(timeout:)` in both negative conflict tests. [`HyzerKit/Tests/HyzerKitTests/SyncEngineConflictTests.swift`]
- [x] [Review][Patch] Silent `try?` × 3 in `DiscrepancyResolutionDeepLinkHost.loadDiscrepancy` replaced with `do/catch` + `Logger.error`. [`HyzerApp/Views/HomeView.swift`]
- [x] [Review][Patch] `loadUnresolved()` now guarded by `if d.status == .unresolved`; spec Open Question #3 cited in comment. [`HyzerApp/Views/HomeView.swift`]
- [x] [Review][Patch] Test renamed + assertion extended to cover both subscription surfaces (1 silent + 3 alert). [`HyzerKit/Tests/HyzerKitTests/SyncSchedulerTests.swift`]
- [x] [Review][Patch] `localPlayerIDProvider` default `{ nil }` removed; all test call sites updated to inject explicitly. [`HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift`]
- [x] [Review][Patch] Banner localized via `DISCREPANCY_ALREADY_RESOLVED_BANNER` + `_A11Y` keys. [`HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift` + `Localizable.strings`]
- [x] [Review][Patch] `pushDiscrepancy` now returns `@discardableResult Bool` — explicit `true` on success/already-synced/serverRecordChanged, `false` on save or push failure. [`HyzerKit/Sources/HyzerKit/Sync/SyncEngine+Discrepancy.swift`]
- [x] [Review][Patch] Missing-Round log downgraded from `.error` to `.info` with explanatory comment. [`HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift`]
- [x] [Review][Patch] Logger instantiation consolidated into a single `helperLogger` static; three helper call sites now reuse it. [`HyzerApp/App/AppServices.swift`]
- [x] [Review][Patch] Removed the redundant `disabled ? {} : onSelect` action and `.opacity(0.5)`; `.disabled(disabled)` alone now drives both tap suppression and styling. [`HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift`]
- [x] [Review][Patch] Added `test_seedDeepLinkFromLaunchOptions_discrepancyPath_setsDeepLink` and `_noPayload_noDeepLink` to `AppServicesTests`. [`HyzerAppTests/AppServicesTests.swift`]
- [x] [Review][Patch] HyzerApp `MockNotificationService` now captures `parseDiscrepancyDetectedPayload` / round-started / round-complete args; surface matches HyzerKit mock. [`HyzerAppTests/Mocks/MockNotificationService.swift`]

**Deferred (13) — pre-existing patterns, recorded in `_bmad-output/implementation-artifacts/deferred-work.md`:**

- [x] [Review][Defer] SyncScheduler does not re-register subscriptions on iCloud identity change [`SyncScheduler.swift`] — pre-existing pattern across all subscriptions
- [x] [Review][Defer] CKError partial-failure / quota / rate-limit retry-with-backoff missing [`SyncEngine+Discrepancy.swift:78-107`] — pre-existing across all push paths
- [x] [Review][Defer] Stale `.inFlight` detection (timestamp window) missing [`SyncEngine+Discrepancy.swift:43-45`] — pre-existing pattern across all state machines
- [x] [Review][Defer] Fire-and-forget `Task { await pushDiscrepancy(...) }` in `detectConflicts` is not tracked for cancellation [`SyncEngine.swift:867`] — pre-existing async pattern
- [x] [Review][Defer] CKRecord field type variance (NSNumber vs Int) for `holeNumber` [`DiscrepancyRecord.swift:from(ckRecord:)`] — pre-existing across all DTOs
- [x] [Review][Defer] Stacked `fullScreenCover` modifiers depend on SwiftUI ordering [`HomeView.swift:52-66`] — should consolidate to single state-driven cover with enum item
- [x] [Review][Defer] `activeRounds` `@Query` may not be hydrated at cold-launch `.onAppear` [`HomeView.swift:80-95`] — pre-existing reactive timing pattern
- [x] [Review][Defer] `DiscrepancyResolutionView` does not react to a peer resolving mid-presentation [`DiscrepancyResolutionView.swift:97-117`] — pre-existing reactive coupling
- [x] [Review][Defer] `loadDiscrepancy` continues mutating state after `isPresented` flips false [`HomeView.swift:262-265`] — pre-existing pattern across hosts
- [x] [Review][Defer] `pushDiscrepancy` 6-scalar parameter API ergonomic refactor [`SyncEngine+Discrepancy.swift:26-33`] — accept `Discrepancy` / `DiscrepancyRecord` instead
- [x] [Review][Defer] `Player` fetch `fetchLimit = 200` magic number [`HomeView.swift:280`] — should query by predicate scoped to `playerID`
- [x] [Review][Defer] Test for already-`.synced` skip does not assert `lastAttempt` preservation [`SyncEnginePushDiscrepancyTests.swift`] — additional coverage gap
- [x] [Review][Defer] Test contract gap for live CloudKit payload shape [`LiveNotificationServiceTests.swift`] — applies to all subscription parsers; needs a captured-real-payload fixture

## Dev Notes

### Architecture & Patterns

- **This story is the third occupant of the Story 12.1 infrastructure** — same pattern as 12.2. Add a payload struct, add a DTO, add a subscription, add a handler, add a deep-link case. Three things differ from 12.2:
  1. **Server-side organizer-only filtering** via the subscription predicate `organizerID == <localPlayerID>`. No client-side `shouldSuppressPresentation` overload needed; non-organizers never receive the push because they never register a matching subscription.
  2. **`Discrepancy` did not previously sync to CloudKit at all.** This story introduces `DiscrepancyRecord` + `pushDiscrepancy` purely to drive the subscription. The local Discrepancy remains the source of truth for resolution state (Task 6).
  3. **Tightest PII gate of the three Epic 12 stories** — alert body shows only the hole number. No first names, no course name, no stroke counts. The discrepancy reveals organizer-internal review state and must minimise the data surface accordingly.
- **`firesOnRecordCreation` is correct** (compare to 12.2's `firesOnRecordUpdate`). Discrepancy records are immutable per event-sourcing: resolution creates a new ScoreEvent, not a Discrepancy mutation. There is no "update" lifecycle for a Discrepancy CKRecord.
- **Server-side predicate is load-bearing for privacy.** If the predicate were `NSPredicate(value: true)` (the pattern used for ScoreEvent subscriptions), every device would receive every discrepancy push — a catastrophic PII leak and an AC #2 failure. The `organizerID == %@` predicate is the structural enforcement of the organizer-only contract.
- **Why we don't deterministic-hash the record ID across devices**: Two devices independently detect the same conceptual conflict and create independent local `Discrepancy` UUIDs. Using a deterministic ID like `sha256("\(roundID)-\(playerID)-\(holeNumber)")` would let them collide at CloudKit, eliminating duplicate pushes — but it would also (a) violate the event-sourcing convention of opaque UUIDs, (b) complicate the existing Story 6.1 resolution code that reads `Discrepancy.id` for `resolvedByEventID` audit linkage, and (c) introduce a subtle attack surface if any peer could craft a forged Discrepancy ID. Accept duplicate cross-device pushes as a documented limitation (see Edge Cases).
- **Coding standards** (CLAUDE.md "Coding Standards"): same as 12.1/12.2 — no silent `try?` (use `do/catch` + Logger); every SwiftData fetch needs `fetchLimit` (apply to the new `fetchRounds(forIDs:)` helper and `DiscrepancyResolutionDeepLinkHost`'s queries); design tokens only (existing `DiscrepancyResolutionView` already complies; the "Already resolved" banner must use existing tokens); accessibility-first (existing view is VoiceOver-labelled; banner needs a VoiceOver label).

### Read These Files Before You Touch Them

Per CLAUDE.md "No Defensive Coding for Impossible Cases" and the create-story workflow's read-before-modify mandate, read each file completely and document the existing behavior you must preserve. **Skipping this is the leading cause of review cycles and breakage.**

| File | Why |
|---|---|
| `HyzerKit/Sources/HyzerKit/Models/Discrepancy.swift` | The `@Model` you're adding a DTO for. Note that `playerID` is `String` (not UUID) to support guest IDs. Note `status` is `unresolved`/`resolved` — your DTO must NOT carry status. |
| `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift` (lines 387-450) | `detectConflicts` is the call site for `pushDiscrepancy`. Existing `existingDiscrepancies.contains` guard at line 420-430 is the per-device dedup — preserve it; the push call sits AFTER `modelContext.insert(discrepancy)` and IS gated by this guard. |
| `HyzerKit/Sources/HyzerKit/Sync/SyncEngine+RoundCompletion.swift` | Your template for `SyncEngine+Discrepancy.swift`. Lift the `.inFlight → .failed` demotion on local-save-failure, the `CKError.serverRecordChanged → .synced` handling, and the `.inFlight` reentrancy guard — all three patterns are non-negotiable per Story 12.2's review patches. |
| `HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift` (lines 148-269) | `setupSubscriptions` is where you add the discrepancy subscription. `setupRoundCompleteSubscription` (line 241-269) is your template. UserDefaults keying convention is `"HyzerApp.subscriptionID.\(roundSubID)"` — match it. |
| `HyzerApp/Services/LiveNotificationService.swift` | `parseRoundCompletePayload` (line 69-91) is your template. The SID guard at line 71-72 is REQUIRED — the Story 12.2 P2 patch added it after finding a structurally-compatible foreign-payload misroute. Your new parser must include the same guard. `CKNotificationEnvelope` (line 110-129) is the shared user-info parser — REUSE it. |
| `HyzerApp/App/AppServices.swift` (lines 8-11, 119-241) | `DeepLink` enum, `handleRoundStartedNotification`, `handleRoundCompleteNotification`, `seedDeepLinkFromLaunchOptions`, `resolveLocalPlayerID`, `roundExists` — all of these are extended in this story. The eager-set-then-fire-and-forget-pull pattern is canonical. |
| `HyzerApp/App/HyzerApp.swift` (lines 150-171) | `AppDelegate.didReceiveRemoteNotification` switch — add the discrepancy branch. Keep the `completionHandler(.newData)` posture. |
| `HyzerApp/Views/HomeView.swift` (lines 1-75, 77-200+) | `pendingSummaryRoundID` / `RoundCompletionSummaryHost` is your template for `pendingDiscrepancyKey` / `DiscrepancyResolutionDeepLinkHost`. The `.fullScreenCover(item:)` ordering matters — discrepancy modifier above summary modifier. |
| `HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift` | The view you're presenting from the deep-link host AND extending with the "Already resolved" banner. Inspect its `onAppear` → `loadEvents` flow; the banner state is read from `discrepancy.status` once at body render. |
| `HyzerApp/Views/Discrepancy/DiscrepancyListView.swift` | Reference for the existing presentation pattern from `ScorecardContainerView` (.medium detent sheet, single-discrepancy shortcut to ResolutionView). Your deep-link host follows the single-discrepancy pattern. |
| `HyzerApp/ViewModels/DiscrepancyViewModel.swift` | The ViewModel you construct in the deep-link host. Constructor inputs are `scoringService, standingsEngine, modelContext, roundID, organizerID, currentPlayerID` — match `ScorecardContainerView.updateDiscrepancyViewModel()` (line 207-214) exactly. `loadUnresolved()` filters to `.unresolved` only — for the AC #4 "already resolved" path you may need a `loadAll()` variant or use `loadConflictingEvents(for:)` directly. |
| `HyzerApp/Views/Scoring/ScorecardContainerView.swift` (lines 23, 30-31, 62, 67-75, 106-108, 147, 192-219, 408-417) | Existing discrepancy badge + list path on the active scoring view. AC #3's "navigate directly" requirement is satisfied by ensuring this path's `@Query` reactively picks up the new Discrepancy — do NOT add a parallel sheet-presentation hook from outside ScorecardContainerView. |
| `HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift` | The `subscribeWithAlert` method (line 62-67) is the protocol entry point. The 2-arg `save(_:savePolicy:)` overload (line 25) is NOT needed for discrepancy push (CREATE-only). Use the 1-arg `save(_:)` overload (line 18). |
| `_bmad-output/implementation-artifacts/deferred-work.md` (lines 33-46) | Story 12.2 deferred items. None directly intersect this story, but the actor reentrancy item (line 35) is a known limitation that also applies to `pushDiscrepancy` — accept the same posture. |

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|---|---|---|
| `Discrepancy` model | `HyzerKit/Sources/HyzerKit/Models/Discrepancy.swift` | Build the DTO from it; do NOT modify the model schema. |
| `SyncEngine+RoundCompletion.swift` push pattern | `HyzerKit/Sources/HyzerKit/Sync/SyncEngine+RoundCompletion.swift` | Lift structure for `SyncEngine+Discrepancy.swift`. |
| `subscribeWithAlert` | `CloudKitClient.swift:62` + `LiveCloudKitClient.swift:101` | Already implemented; just call. |
| `CKNotificationEnvelope` + SID guard pattern | `LiveNotificationService.swift:110-129, 71-72` | Reuse both. |
| `DeepLink` enum | `AppServices.swift:8-11` | Extend with `.discrepancyResolution`. Keep `Equatable`. |
| `roundExists(_:in:)` | `AppServices.swift:245-255` | Reuse for retry-guard logic in `handleDiscrepancyDetectedNotification`. |
| `resolveLocalPlayerID(from:)` | `AppServices.swift:187-197` | Resolve organizer ID for the subscription predicate. |
| `DiscrepancyViewModel` | `HyzerApp/ViewModels/DiscrepancyViewModel.swift` | Construct in `DiscrepancyResolutionDeepLinkHost`. |
| `DiscrepancyResolutionView` | `HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift` | Present from the deep-link host (extended with the read-only banner for AC #4). |
| `existingDiscrepancies` dedup guard | `SyncEngine.swift:420-430` | Already prevents per-device duplicate pushes when the push call is placed AFTER the insert (Task 4.3). |
| `MockCloudKitClient.savedAlertSubscriptions` + `savedRecords` | `HyzerKitTests/Mocks/MockCloudKitClient.swift` | Already populated by `subscribeWithAlert` and `save` calls; inspect for the new `Discrepancy-creation` subscription and `DiscrepancyRecord` saves in tests. |
| `MockNotificationService` | `HyzerKitTests/Mocks/` + `HyzerAppTests/Mocks/` | Extend both with `parseDiscrepancyDetectedPayload`. Do NOT consolidate. |
| `IdentifiableUUID` pattern | `HomeView.swift:6-8` | Apply the same wrapper concept for `DiscrepancyDeepLinkKey` (or just use a composed string ID). |

### File Structure

**Files to add:**
```
HyzerKit/Sources/HyzerKit/Sync/DTOs/DiscrepancyRecord.swift                  # DTO + CKRecord conversion
HyzerKit/Sources/HyzerKit/Sync/SyncEngine+Discrepancy.swift                  # pushDiscrepancy actor extension
HyzerKit/Tests/HyzerKitTests/Notifications/DiscrepancyDetectedPayloadTests.swift   # Payload value-type + mock parser
HyzerKit/Tests/HyzerKitTests/DiscrepancyRecordTests.swift                    # DTO PII allowlist + round-trip
HyzerKit/Tests/HyzerKitTests/SyncEnginePushDiscrepancyTests.swift            # pushDiscrepancy lifecycle
HyzerAppTests/DiscrepancyDeepLinkRoutingTests.swift                          # HomeView deep-link consumption (optional — see Task 9.9)
```

**Files to modify:**
```
HyzerKit/Sources/HyzerKit/Notifications/NotificationService.swift            # + DiscrepancyDetectedPayload, + parseDiscrepancyDetectedPayload
HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift                              # + fetchRounds(forIDs:) helper, + push call in detectConflicts
HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift                           # + setupDiscrepancyCreationSubscription, + localPlayerIDProvider init param
HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift             # + parseDiscrepancyDetectedPayload + stub fields
HyzerKit/Tests/HyzerKitTests/SyncSchedulerTests.swift                        # Four-subscription assertion + provider injection + skip-when-nil
HyzerKit/Tests/HyzerKitTests/SyncEngineConflictTests.swift                   # detectConflicts now also pushes Discrepancy
HyzerApp/Services/LiveNotificationService.swift                              # + parseDiscrepancyDetectedPayload, + NotificationSubscriptionID.discrepancyCreation
HyzerApp/App/AppServices.swift                                               # + .discrepancyResolution DeepLink case, + handleDiscrepancyDetectedNotification, extend seedDeepLinkFromLaunchOptions, wire localPlayerIDProvider into SyncScheduler init
HyzerApp/App/HyzerApp.swift                                                  # AppDelegate: switch case for discrepancyCreation
HyzerApp/Views/HomeView.swift                                                # + pendingDiscrepancyKey state, + .discrepancyResolution case in consumePendingDeepLinkIfNeeded, + .fullScreenCover, + DiscrepancyResolutionDeepLinkHost wrapper
HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift                   # + "Already resolved" banner + disabled score-option buttons when status == .resolved
HyzerApp/Resources/en.lproj/Localizable.strings                              # + DISCREPANCY_DETECTED_FORMAT
HyzerAppTests/Mocks/MockNotificationService.swift                            # + parseDiscrepancyDetectedPayload + stub fields
HyzerAppTests/AppServicesTests.swift                                         # + handleDiscrepancyDetectedNotification suite
HyzerAppTests/LiveNotificationServiceTests.swift                             # + parseDiscrepancyDetectedPayload live tests + foreign-SID guard
```

**Regenerate Xcode project after adding files:** run `xcodegen generate`. Canonical build/test commands per CLAUDE.md:
```sh
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'
```
HyzerKit-only validation (faster, no simulator):
```sh
swift test --package-path HyzerKit
```

### Edge Cases

| Case | Behavior |
|---|---|
| Cross-device duplicate push (Device A and B both detect the same conflict, both push) | Two `DiscrepancyRecord` CKRecords are created with different UUIDs. The organizer receives two push notifications for the same conceptual conflict. **Accept as known limitation.** Per Task 2.3, deterministic IDs are not pursued. The organizer's local DB has only one Discrepancy (Task 4.3 dedup guard); the second notification's deep-link routes to the same local Discrepancy. AC #6 explicitly allows "one notification per Discrepancy record" — this is technically conformant. |
| Organizer hasn't onboarded yet (no Player row exists) | `localPlayerIDProvider` returns nil; subscription registration is skipped (Task 5.7). Next launch retries. No discrepancy notifications until the user onboards. |
| Network offline when discrepancy is detected | `pushDiscrepancy` marks `.failed` in SyncMetadata; `SyncScheduler.startConnectivityListener` retries on reconnect (existing pipeline from Stories 4.1/4.2). Notification arrives late but correctly. |
| Round is completed before the discrepancy push lands | Subscription still fires for the organizer. Deep-link routes to `DiscrepancyResolutionDeepLinkHost` (round not in `activeRounds`). Organizer can still resolve (resolution creates a `ScoreEvent` which Story 6.1 already handles for completed rounds — confirm by inspection). |
| Discrepancy was already resolved before notification arrives (AC #4) | `handleDiscrepancyDetectedNotification` finds the local Discrepancy with `.resolved` status, sets the deep-link anyway. `DiscrepancyResolutionView` shows the "Already resolved" banner and disables the score-option buttons. No duplicate resolution event is created. |
| Discrepancy is missing locally even after retry pull | Deep-link is NOT set (Task 7.2 step 6). No "appear-then-instantly-dismiss" cover; no toast (matches Story 12.2 P2 patch). User can re-tap the notification later when sync catches up. |
| Multiple discrepancies detected in the same pull cycle | `detectConflicts` loops over `newEvents`; each `.discrepancy` case fires a fire-and-forget `Task { pushDiscrepancy }`. Organizer receives N independent push notifications. Per AC #6, coalescing is out of scope. |
| User changes iCloud account mid-session | `Player.id` is stable per device (set once at onboarding). The CK subscription predicate stays valid. iCloud identity change does not invalidate the subscription. (If a future story supports re-onboarding, the subscription would need explicit re-registration — see Task 5.4.) |
| Empty `playerID` or hole `0` (broken upstream data) | Per CLAUDE.md "No Defensive Coding for Impossible Cases" — `Discrepancy.playerID` is required non-empty and `holeNumber >= 1` by construction in `SyncEngine.detectConflicts`. Do not add defensive guards. |
| Two organizers in the same round (impossible) | `Round.organizerID` is a single UUID. Can't happen. |
| Subscription quota exceeded (CloudKit limit) | `subscribeWithAlert` throws; the existing catch block in `SyncScheduler.setupRoundCompleteSubscription` (line 266-268) logs and continues. The discrepancy subscription's failure does not block other subscriptions. The user sees no discrepancy notifications until a future launch succeeds. |
| Organizer-only subscription predicate mismatches actual organizer (data corruption) | Subscription delivers no notifications. The organizer must check the app to see badges. Same UX as pre-12.3 (badge-only). Not a crash, not a privacy leak. |

### Scope Boundaries — Do NOT Implement

- Do **NOT** add notification coalescing for multiple-discrepancies-per-round. AC #6 explicitly accepts one notification per Discrepancy record. Coalescing is a future story.
- Do **NOT** add deterministic Discrepancy CKRecord IDs (Task 2.3). Accept cross-device duplicate pushes as documented.
- Do **NOT** pull `DiscrepancyRecord` from CloudKit in `pullRecords` (Task 6). Local detection is authoritative; the CK record is push-only fuel for the subscription.
- Do **NOT** add a `shouldSuppressPresentation(for: DiscrepancyDetectedPayload, ...)` overload to `NotificationService`. Server-side predicate filtering is the enforcement; client-side suppression is unnecessary and would obscure the contract.
- Do **NOT** add notification badge counts, sound customization, or notification grouping. Out of scope.
- Do **NOT** add a "Resolve Now" / "View Later" notification action button. Single-tap dismissal is the spec.
- Do **NOT** flip `aps-environment` from `development` to `production`. Tracked at `deferred-work.md:10`. Epic 12 release-train story owns it.
- Do **NOT** add Watch-side handling of the discrepancy notification. Phone is the sole CloudKit/APNs node (CLAUDE.md "Sync Architecture"). The Watch will surface the default `.notification` haptic via the iPhone-to-Watch system bridge.
- Do **NOT** localize beyond the single English `DISCREPANCY_DETECTED_FORMAT` string (matches 12.1/12.2 / Story 11.3 precedent; `deferred-work.md:15`).
- Do **NOT** consolidate the duplicated `MockNotificationService` across HyzerKitTests and HyzerAppTests. That cleanup belongs with the `ValueCollector` extraction (CLAUDE.md "Known Technical Debt", `deferred-work.md:25`).
- Do **NOT** refactor `SyncEngine.detectConflicts` into a separate type. The pattern of "conflict detection lives in SyncEngine" is established (Story 4.3 / 6.1); preserve it.
- Do **NOT** modify the existing `ScoreEvent-creation`, `Round-active-creation`, or `Round-complete-update` subscriptions. The only Story-12.1/12.2 file edit you make is the new `localPlayerIDProvider` init parameter on `SyncScheduler` (Task 5.5).
- Do **NOT** sync `Discrepancy.status` or `resolvedByEventID` to CloudKit. Resolution state stays local per Task 6.2; the resolution audit trail lives in the `ScoreEvent` chain.
- Do **NOT** introduce a `firstName` field on `Player` to clean up the alert body — the discrepancy alert body has NO name (AC #5). This story does not surface the long-deferred `firstName` debt (`deferred-work.md:24`).

### Previous Story Intelligence

**From Story 12.2 (round complete push):**
- `SyncEngine+RoundCompletion.swift` extension-file extraction was needed to keep `SyncEngine.swift` under the 600-line SwiftLint threshold. Repeat the pattern: `SyncEngine+Discrepancy.swift` keeps the main file uncluttered.
- `CKError.serverRecordChanged → .synced` handling is the canonical concurrent-push idempotency pattern. Lift as-is.
- `.inFlight` reentrancy guard from `pushRound` / `pushRoundCompletion` — lift as-is.
- `.inFlight → .failed` demotion on local-save-failure (Story 12.1 review patch) — lift as-is. Skipping it strands SyncMetadata entries permanently.
- SID guard in payload parsers (12.2 P2 patch). Required. A structurally-compatible foreign payload could misroute without it.
- Locale-independent ordering rule from 12.2 P2 patch — `compare(_:options:.caseInsensitive)`. Not applicable to discrepancy because the alert body has no name field, but the principle stands for any future cross-device deterministic ordering.
- The `seedDeepLinkFromLaunchOptions` "eager set + fire-and-forget pull + one-shot retry" pattern is canonical. Mirror it for `.discrepancyResolution`.
- HomeView's `.fullScreenCover(item:)` pattern with an `Identifiable` wrapper is the way to present from a deep-link. Repeat for `DiscrepancyResolutionDeepLinkHost`.
- Story 12.2 P2 patch added a "drop deep-link if round not materialised" guard — `handleDiscrepancyDetectedNotification` needs the same posture (Task 7.2 step 6).
- Story 12.2 P3 patch removed defensive `winner == nil` guard — apply the same rule: no defensive `playerID.isEmpty` or `holeNumber == 0` guards in `handleDiscrepancyDetectedNotification`.
- `Task.sleep` in tests is a hard "no" — Story 12.2 P1 patch found and removed an instance. Use `Task.yield()` for actor synchronization.
- `aps-environment = development` is parked at `deferred-work.md:10` — this story inherits the same constraint; cannot ship real APNs delivery to TestFlight until the Epic 12 release-train story flips it.

**From Story 12.1 (notification foundation):**
- `NotificationService` (HyzerKit) + `LiveNotificationService` (HyzerApp) split is the canonical pattern. The payload struct lives in HyzerKit; the live parser lives in HyzerApp.
- `CKNotificationEnvelope` was extracted during 12.1 review to centralise the brittle `userInfo["ck"]["qry"]` cast tree. **Reuse it.** Drift between AppDelegate parse and LiveNotificationService parse was a P1 review finding — don't reintroduce two parsers.

**From Story 6.1 (discrepancy resolution):**
- `DiscrepancyViewModel.resolve(discrepancy:selectedStrokeCount:playerID:holeNumber:)` creates an authoritative `ScoreEvent` (`supersedesEventID = nil`) and updates `Discrepancy.status` to `.resolved`. The view layer reads `viewModel.unresolvedDiscrepancies` — for the AC #4 "already resolved" path, your deep-link host needs a path that reads ALL discrepancies (not just unresolved). Either add `loadAll()` to `DiscrepancyViewModel` or query directly in the host (cleaner — keeps the ViewModel focused on the unresolved-flow it was designed for).
- The resolution event is the source of truth; `Discrepancy.status` is a local cache for badge display. The CK record we add in this story does NOT participate in resolution at all.

**From Story 4.3 (silent merge & discrepancy detection):**
- `ConflictDetector.check` returns four cases: `.noConflict`, `.correction`, `.silentMerge`, `.discrepancy(existingID, incomingID)`. Only the `.discrepancy` case triggers a Discrepancy insert and (now) a `pushDiscrepancy` call.

**From the Epics 1–8 retrospective** (`_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md`):
- `ValueCollector` is duplicated debt — do not extend the duplication.
- `Task.sleep` flakiness — banned in tests. Use `Task.yield()` + `ValueCollector`.

### Git Intelligence

Recent commits (`git log --oneline -10`):
- `adac268` Story 12.2 — Round Complete push notification (the foundation this story builds on, alongside 12.1)
- `c861c3f` Story 12.1 — Notification Foundation & Round Started Push
- `c5a9bae` Story 9.3 — App Store Connect record (TestFlight infra)
- `df67b34`, `f281ada` chore(deps): renovate-bumped actions
- `ed117eb` fix(hooks): conventional-commits PreToolUse hook heredoc fix

No recent commits touch `Discrepancy.swift`, `ConflictDetector.swift`, `DiscrepancyViewModel.swift`, or the discrepancy views beyond Story 6.1's original commit. Your changes will be additive; no merge-conflict surface.

Run `git log --all --oneline -- HyzerKit/Sources/HyzerKit/Models/Discrepancy.swift` before starting to confirm no in-flight branch is mid-refactor on this file.

### Latest Technical Information

- **`CKQuerySubscription` with a per-user predicate** (`organizerID == "<localUserID>"`) is a documented Apple pattern for personalized subscriptions. Each device registers its own subscription instance; CloudKit evaluates the predicate at delivery time against the record's `organizerID` field. There is no per-user CKSubscription cost beyond the standard 200-subscriptions-per-database quota — this story adds 1 subscription per device, well within budget.
- **`CKSubscription.NotificationInfo.alertLocalizationArgs` with an Int field** (`holeNumber`): CloudKit substitutes the integer value into the `%@` positional specifier. iOS's `String(format:)` converts the Int to a string via `description`. Tested on iOS 18; behavior unchanged from iOS 16. The `DISCREPANCY_DETECTED_FORMAT` string uses `%1$@` (not `%1$d`) to match the CKSubscription-side substitution shape — `%d` is not supported by `alertLocalizationArgs`.
- **`firesOnRecordCreation` semantics**: fires when a new CKRecord matching the predicate is saved server-side. Does NOT fire for updates. Discrepancy records are immutable per Task 2.3 + event-sourcing convention, so `firesOnRecordCreation` is the correct option.
- **`UNNotificationInterruptionLevel.active`** (default) is correct for this story — same as 12.1/12.2. The discrepancy is an organizer review task, not a time-sensitive emergency.
- **`CKModifyRecordsOperation.RecordSavePolicy.ifServerRecordUnchanged`** is correct for `pushDiscrepancy` (CREATE-only write; no existing server record to merge against). Do NOT use `.changedKeys` (that's required for `pushRoundCompletion` because that's an UPDATE; here it's a CREATE).
- **SwiftData `try modelContext.fetch` with `fetchLimit`** — `DiscrepancyResolutionDeepLinkHost` uses imperative fetches (not `@Query`) because the keys are dynamic via the host's constructor. `fetchLimit = 1` per CLAUDE.md bounded-query rule.

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test`). No XCTest.
- **In-memory SwiftData:** `ModelConfiguration(isStoredInMemoryOnly: true)` per `HyzerKitTests` convention.
- **MockCloudKitClient:** Already has `savedAlertSubscriptions` and `savedRecords` collections from Story 12.1/12.2. No mock changes required beyond inspecting the new `Discrepancy-creation` subscription and `DiscrepancyRecord` saves.
- **MockNotificationService:** Extend (don't replace) — both copies (HyzerKitTests + HyzerAppTests) need the `parseDiscrepancyDetectedPayload` surface.
- **SyncScheduler test setup**: tests must inject a `localPlayerIDProvider` closure returning a fixed UUID for deterministic predicate assertions. The skip-when-nil test injects a closure returning nil.
- **Determinism:** Do NOT use `Task.sleep`. Use `Task.yield()` for awaiting actor task completion, or `ValueCollector` (`HyzerKitTests/Fixtures/ValueCollector.swift`) for awaiting stream outputs.
- **PII allowlist test (Task 9.3)** is the most important test in this story — structural guarantee of PMVP-NFR1. Treat regression as a P0 release blocker.
- **Manual verification (recommended for AC #1, #3, #4):** end-to-end on two real iPhones (Device A = participant, Device B = organizer). Score the same {player, hole} differently from each device; verify Device B (organizer) receives the push within 30 seconds with body "Score discrepancy on hole [n] needs review."; Device A receives nothing. Tap the notification on Device B; verify navigation to the resolution view. Pre-resolve via badge before the notification arrives; tap and verify "Already resolved" read-only state. Document in Completion Notes.

### Open Questions (for the dev agent to confirm during implementation)

1. **`SyncScheduler` `ModelContainer` dependency**: Task 5.5/5.6 recommend a `localPlayerIDProvider` closure injected from `AppServices`. Confirm the closure executes its `await MainActor.run { ... }` correctly when called from `SyncScheduler.setupSubscriptions` (a non-MainActor actor context). The `ModelContainer.mainContext` access must happen on the main actor; `MainActor.run` is the correct primitive. Alternative: pass the resolved `UUID?` value to `SyncScheduler.start(localPlayerID:)` and propagate downward — simpler but couples timing. Pick (a) per Task 5.5 unless implementation surfaces a blocker.
2. **`DiscrepancyResolutionView` banner placement**: Task 8.5 step 5 adds the "Already resolved" banner ABOVE the score-option buttons. Confirm visually that this doesn't break the existing layout's centered-buttons design. If layout regresses, alternative is to replace the buttons entirely with a read-only score summary card. Decide during implementation.
3. **`DiscrepancyResolutionDeepLinkHost` vs reusing `DiscrepancyListView` single-discrepancy mode**: `DiscrepancyListView` already has a "single-discrepancy → ResolutionView directly" shortcut (line 22-30). Consider whether the deep-link host can present `DiscrepancyListView` with a single-element filter rather than constructing `DiscrepancyResolutionView` directly. Trade-off: `DiscrepancyListView` reads `viewModel.unresolvedDiscrepancies` which excludes resolved records — breaks AC #4. Stick with the direct `DiscrepancyResolutionView` host. Confirm during implementation.
4. **Cross-device duplicate notification UX**: Task 2.3 and Edge Cases document that two devices may push for the same conceptual conflict, and the organizer receives two notifications. Confirm with PM during manual verification whether this duplicate-notification UX is acceptable for v1 or whether it warrants a dedup-window guard at the AppDelegate level (e.g., suppress a second discrepancy push within 5s for the same `{roundID, playerID, holeNumber}`). Default: accept duplicates per AC #6 wording.
5. **`pushDiscrepancy` actor reentrancy**: same posture as `pushRound` / `pushRoundCompletion` (deferred-work.md:35). Concurrent calls could race `.inFlight` writes. Out of scope for this story.
6. **iCloud identity not yet resolved at first launch**: `iCloudRecordName` may be nil at first sync. The discrepancy subscription only requires `Player.id` (local), not `iCloudRecordName`. Confirm by inspection that `Player.id` is set during onboarding (it is — `Player.swift` constructor) before any sync runs.

### Project Structure Notes

- **One new directory not needed.** `HyzerKit/Sources/HyzerKit/Sync/DTOs/` already exists. `HyzerKit/Tests/HyzerKitTests/Notifications/` already exists from Story 12.1/12.2.
- **`xcodegen generate` is needed** if Task 9.9 adds `HyzerAppTests/DiscrepancyDeepLinkRoutingTests.swift` and the existing HyzerAppTests target source pattern doesn't pick it up automatically. Verify after generate that the file is in the build.
- **HyzerKit `Sync/DTOs/` and `Sync/SyncEngine+*.swift` extension files** are picked up automatically by SwiftPM — no `project.yml` edit for HyzerKit-side changes.
- **Layer boundary (CLAUDE.md):** `DiscrepancyDetectedPayload`, `DiscrepancyRecord`, and `SyncEngine+Discrepancy.swift` belong in HyzerKit. The parser lives in `LiveNotificationService` (HyzerApp). The deep-link host (`DiscrepancyResolutionDeepLinkHost`) lives in HomeView.swift (HyzerApp). The "Already resolved" banner edit to `DiscrepancyResolutionView` is HyzerApp-only.
- **Watch boundary:** None of these files touch `HyzerWatch/`. Confirm by inspection at end of implementation.

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Story 12.3] — user story, scope, ACs (lines 465-491)
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#PMVP-FR13, PMVP-NFR1, FR49] — functional + privacy + organizer-only requirements (lines 48, 62, 106)
- [Source: _bmad-output/planning-artifacts/architecture.md#L186-194] — SwiftData + CloudKit compatibility constraints (Discrepancy CK model defaults)
- [Source: _bmad-output/planning-artifacts/architecture.md#L325] — Conflict detection paradigm (silent merge vs discrepancy)
- [Source: CLAUDE.md#Sync Architecture] — Phone-as-sole-sync-node, Watch boundary
- [Source: CLAUDE.md#Coding Standards (Enforce, Don't Review)] — try? rule, bounded queries, accessibility, design tokens
- [Source: HyzerKit/Sources/HyzerKit/Models/Discrepancy.swift] — model to wrap in a DTO
- [Source: HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift:387-450] — `detectConflicts` call site for `pushDiscrepancy`
- [Source: HyzerKit/Sources/HyzerKit/Sync/SyncEngine+RoundCompletion.swift] — extension-file template for `SyncEngine+Discrepancy.swift`
- [Source: HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift:148-269] — `setupSubscriptions` + `setupRoundCompleteSubscription` template
- [Source: HyzerKit/Sources/HyzerKit/Sync/DTOs/RoundRecord.swift] — DTO template for `DiscrepancyRecord`
- [Source: HyzerApp/Services/LiveNotificationService.swift:69-99] — `parseRoundCompletePayload` + SID guard template + `NotificationSubscriptionID` enum
- [Source: HyzerApp/App/AppServices.swift:8-11, 147-241] — `DeepLink` enum + complete-handler template + launch-options seeding extension points
- [Source: HyzerApp/App/HyzerApp.swift:150-171] — `AppDelegate.didReceiveRemoteNotification` switch
- [Source: HyzerApp/Views/HomeView.swift:1-200] — `.fullScreenCover(item:)` deep-link pattern + `RoundCompletionSummaryHost` template
- [Source: HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift] — view to extend with "Already resolved" banner + disabled-state behavior
- [Source: HyzerApp/Views/Discrepancy/DiscrepancyListView.swift] — single-discrepancy → ResolutionView pattern reference
- [Source: HyzerApp/ViewModels/DiscrepancyViewModel.swift] — ViewModel construction reference
- [Source: HyzerApp/Views/Scoring/ScorecardContainerView.swift:23, 30-31, 62, 67-75, 106-108, 147, 192-219, 408-417] — in-active-round discrepancy badge + sheet path that AC #3 piggybacks on
- [Source: _bmad-output/implementation-artifacts/12-1-notification-foundation-and-round-started-push.md] — Story 12.1 foundation
- [Source: _bmad-output/implementation-artifacts/12-2-round-complete-push-notification.md] — Story 12.2 patterns (extension files, P0/P1/P2 review patches lifted)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md:10, 22-46] — Story 12.1/12.2 deferred items applicable here
- [Source: _bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md] — `Task.sleep` flakiness ban, `ValueCollector` duplication note

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

- Fixed `LiveNotificationService.parseDiscrepancyDetectedPayload` placement (function was accidentally placed after the struct's closing brace; corrected to be inside the struct).
- Fixed `SyncEnginePushDiscrepancyTests.makeEngine` — marked `@MainActor` to allow access to `container.mainContext` (Swift 6 strict concurrency).
- Fixed two `Round(...)` initializer calls in `SyncEngineConflictTests` — parameter order was wrong (used `organizerID:courseID:` instead of `courseID:organizerID:`) and `playerIDs: []` was missing.
- Task 9.9 (DiscrepancyDeepLinkRoutingTests) — skipped per story guidance: "skip this in favor of an AppServicesTests unit test." Coverage provided by `test_handleDiscrepancyDetectedNotification_*` in Task 9.7.

### Completion Notes List

- All 9 Tasks (1–9, including all subtasks) implemented and verified. Task 9.9 intentionally skipped per story spec guidance (covered by AppServicesTests unit tests).
- HyzerKit: 355/355 tests pass (`swift test --package-path HyzerKit`).
- HyzerApp: 14/14 AppServicesTests pass and 21/21 LiveNotificationServiceTests (including 9 new parseDiscrepancyDetectedPayload tests) pass via `xcodebuild test`.
- `DiscrepancyDetectedPayload` and `parseDiscrepancyDetectedPayload` added to `NotificationService` protocol (HyzerKit) — macOS-clean, no UIKit/UserNotifications imports.
- `DiscrepancyRecord` DTO created with PII gate: exactly `["roundID", "organizerID", "playerID", "holeNumber", "createdAt"]` — P0 PII allowlist test (`test_toCKRecord_writesExactKeySet`) guards PMVP-NFR1.
- `SyncEngine+Discrepancy.swift` extension file: `pushDiscrepancy` with `.inFlight → .synced/.failed` state machine; `serverRecordChanged → .synced` idempotency; CREATE-only via `.ifServerRecordUnchanged` policy.
- `SyncEngine.detectConflicts` extended with `fetchRounds(forIDs:)` helper and fire-and-forget `pushDiscrepancy` call after discrepancy insert (bounded query, per-device dedup guard preserved).
- `SyncScheduler` extended with `localPlayerIDProvider` closure injection and `setupDiscrepancyCreationSubscription` — predicate `organizerID == <localPlayerID>` enforces server-side organizer-only delivery (AC #2); skips gracefully when player ID unavailable.
- `AppServices.handleDiscrepancyDetectedNotification` — no self-exclusion (subscription predicate handles it); pull + one-shot retry; drops deep-link if discrepancy still missing after retry; sets deep-link for resolved discrepancies (AC #4).
- `DiscrepancyResolutionView` extended with `isAlreadyResolved` parameter — shows "Already resolved — read-only" banner and disables score-option buttons (AC #4).
- `HomeView` extended with `DiscrepancyResolutionDeepLinkHost` fullScreenCover and `.discrepancyResolution` deep-link consumption; cover placed above summary cover (correct priority).
- `DISCREPANCY_DETECTED_FORMAT` localizable string added — PII gate: hole number only, no names or course.
- `aps-environment` remains `development` per deferred-work.md:10 — Epic 12 release-train story owns the flip.

### File List

**New files:**
- `HyzerKit/Sources/HyzerKit/Sync/DTOs/DiscrepancyRecord.swift`
- `HyzerKit/Sources/HyzerKit/Sync/SyncEngine+Discrepancy.swift`
- `HyzerKit/Tests/HyzerKitTests/Notifications/DiscrepancyDetectedPayloadTests.swift`
- `HyzerKit/Tests/HyzerKitTests/DiscrepancyRecordTests.swift`
- `HyzerKit/Tests/HyzerKitTests/SyncEnginePushDiscrepancyTests.swift`

**Modified files:**
- `HyzerKit/Sources/HyzerKit/Notifications/NotificationService.swift`
- `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift`
- `HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift`
- `HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift`
- `HyzerKit/Tests/HyzerKitTests/SyncSchedulerTests.swift`
- `HyzerKit/Tests/HyzerKitTests/SyncEngineConflictTests.swift`
- `HyzerApp/Services/LiveNotificationService.swift`
- `HyzerApp/App/AppServices.swift`
- `HyzerApp/App/HyzerApp.swift`
- `HyzerApp/Views/HomeView.swift`
- `HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift`
- `HyzerApp/Resources/en.lproj/Localizable.strings`
- `HyzerAppTests/Mocks/MockNotificationService.swift`
- `HyzerAppTests/AppServicesTests.swift`
- `HyzerAppTests/LiveNotificationServiceTests.swift`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-17: Story 12.3 fully implemented (Tasks 1–9, 9.9 skipped per spec). All ACs satisfied. HyzerKit: 355 tests pass. HyzerApp: all AppServicesTests and LiveNotificationServiceTests pass. Status → review.
