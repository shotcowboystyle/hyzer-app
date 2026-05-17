# Story 12.1: Notification Foundation & "Round Started" Push

Status: done

## Story

As a participant added to a round,
I want a push notification to let me know the round has started,
so that I can open the app and join the live leaderboard without waiting to be told in person.

## Acceptance Criteria

1. **Given** the user has previously granted notification permission, **when** another participant creates a round that includes the current user as a player, **then** within 30 seconds of the round being saved to CloudKit a push notification is delivered to the current user's device (PMVP-FR11) **and** the notification body reads "[Organizer first name] started a round at [Course name]".

2. **Given** the notification payload is inspected, **when** the alert body is read, **then** it contains only first names and course name — no last names, no iCloud identifiers, no email, no scores (PMVP-NFR1).

3. **Given** the user has not yet been prompted for notification permission, **when** they tap "New Round" for the first time, **then** the `UNUserNotificationCenter.requestAuthorization` prompt appears **and** if the user denies, round creation succeeds and in-app FR16b discovery continues to work without notifications.

4. **Given** the user taps the "Round Started" notification, **when** the app opens, **then** the active round view (Hole 1) appears directly (deep link to current scoring context).

5. **Given** the user is the organizer of the round they just created, **when** the CloudKit save triggers notification dispatch, **then** the organizer's own device does not receive a presented notification (self-exclusion).

6. **Given** a notification is delivered while the user is wearing a paired Apple Watch, **when** the haptic fires, **then** the haptic uses `UNNotificationInterruptionLevel.active` (default) with no custom critical category — the Watch surfaces the standard `.notification` haptic pattern (UX-PMVP-DR4).

## Tasks / Subtasks

- [x] Task 1: Add `NotificationService` protocol + mock to HyzerKit (AC: 1, 2, 3, 5, 6)
  - [x] 1.1 Create `HyzerKit/Sources/HyzerKit/Notifications/NotificationService.swift`. Public protocol, `Sendable`. Surface:
    ```swift
    public protocol NotificationService: Sendable {
        func currentAuthorizationStatus() async -> NotificationAuthorizationStatus
        @discardableResult func requestAuthorization() async -> NotificationAuthorizationStatus
        /// Returns true if the local device should suppress the foreground/banner
        /// presentation of an incoming round-started notification (e.g., the current
        /// user is the round organizer). Self-exclusion gate (AC #5).
        func shouldSuppressPresentation(for payload: RoundStartedPayload, localPlayerID: UUID?) -> Bool
        /// Parses a CKQuerySubscription user-info dictionary into a typed payload.
        /// Returns nil if the dictionary is not a round-started subscription payload.
        func parseRoundStartedPayload(_ userInfo: [AnyHashable: Any]) -> RoundStartedPayload?
    }
    public enum NotificationAuthorizationStatus: Sendable { case notDetermined, denied, authorized, provisional, ephemeral }
    public struct RoundStartedPayload: Sendable, Equatable {
        public let roundID: UUID
        public let organizerID: UUID
        public let organizerFirstName: String
        public let courseName: String
    }
    ```
  - [x] 1.2 Keep this file iOS-clean (Foundation only, no UIKit/UserNotifications imports). `UNUserNotificationCenter` calls live in the live impl (Task 2) — the protocol must compile on macOS for HyzerKitTests.
  - [x] 1.3 Add `MockNotificationService` to `HyzerKit/Tests/HyzerKitTests/Mocks/` mirroring the shape of `MockCloudKitClient`: tracked call counts (`requestAuthorizationCallCount`), settable next-return (`nextAuthorizationStatus`), `payloads` captured for `parseRoundStartedPayload`.

- [x] Task 2: Implement `LiveNotificationService` in HyzerApp (AC: 1, 2, 3, 4, 5, 6)
  - [x] 2.1 Create `HyzerApp/Services/LiveNotificationService.swift`. Conforms to `NotificationService`. Wraps `UNUserNotificationCenter.current()`.
  - [x] 2.2 `currentAuthorizationStatus()` maps `UNAuthorizationStatus` → `NotificationAuthorizationStatus`. Use `getNotificationSettings()` and bridge.
  - [x] 2.3 `requestAuthorization()` calls `requestAuthorization(options: [.alert, .badge, .sound])`. Do **NOT** request `.criticalAlert` or `.provisional`. Per UX-PMVP-DR4, default `.active` interruption level is what the Watch needs — no custom category.
  - [x] 2.4 `shouldSuppressPresentation(for:localPlayerID:)` returns `true` iff `payload.organizerID == localPlayerID`. This is the self-exclusion gate. Implementation note: CKSubscription delivers to every subscriber including the writer; suppression must happen client-side.
  - [x] 2.5 `parseRoundStartedPayload(_:)` reads the CloudKit subscription notification user-info. Specifically reads `ck.qry` → `rid` (record ID) and the configured `desiredKeys` we populate on the subscription (`organizerFirstName`, `courseName`, `organizerID`). If keys are absent or malformed, return `nil`.
  - [x] 2.6 No `console.log`. Use `Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "NotificationService")` for any operational logging. No PII in logs (no organizer first name, no course name).

- [x] Task 3: Wire `NotificationService` into `AppServices` and the app lifecycle (AC: 3, 4, 5)
  - [x] 3.1 `AppServices` (`HyzerApp/App/AppServices.swift`) gains a `notificationService: any NotificationService` stored property and an `init` parameter (following the existing `cloudKitClient`/`networkMonitor` injection pattern). `HyzerApp.init()` wires `LiveNotificationService()`.
  - [x] 3.2 Add `func handleRoundStartedNotification(_ userInfo: [AnyHashable: Any]) async` to `AppServices`. Logic:
        1. Parse payload via `notificationService.parseRoundStartedPayload`.
        2. If `shouldSuppressPresentation(for: payload, localPlayerID: ...)` → return early (self-exclusion).
        3. Trigger a single `pullRecords()` on `SyncEngine` so the active round is locally materialised when the user taps.
        4. (Deep link wiring: Task 6.)
  - [x] 3.3 Update `AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` (in `HyzerApp/App/HyzerApp.swift`): inspect `userInfo` and dispatch to either `handleRemoteNotification()` (existing ScoreEvent subscription handler) or the new `handleRoundStartedNotification(_:)`. Distinguish by `subscriptionID` (`"ScoreEvent-creation"` vs the new `"Round-active-creation"`). Always call `completionHandler(.newData)` after the work completes.

- [x] Task 4: Lazy permission flow tied to first "New Round" tap (AC: 3)
  - [x] 4.1 `HyzerApp/Views/HomeView.swift` already gates the round setup sheet via `isShowingRoundSetup`. Before flipping that `@State` to `true`, the "New Round" tap must ensure permission has been requested at least once.
  - [x] 4.2 Pattern: read `AppServices.notificationService` from the environment, then `Task { await services.notificationService.requestAuthorization() }` — fire-and-forget. The `await` on `requestAuthorization` returns immediately if the system has already prompted (system idempotency); we still record local-flag for tests.
  - [x] 4.3 Persist a `hasPromptedForNotifications` flag in `UserDefaults` (key: `"HyzerApp.notifications.hasPrompted"`) so tests can assert single-prompt semantics. Per CLAUDE.md tech-debt list, `UserDefaults.standard` directly is acceptable here (Story 12.x is not the place to extract `UserDefaultsStorage` for this flag — match the existing `SyncScheduler` pattern of direct `UserDefaults.standard` use).
  - [x] 4.4 If the user denies, do **not** retry on later taps. Round creation must still succeed without notifications (AC #3 second half). In-app FR16b foreground discovery in `SyncScheduler.foregroundDiscovery(currentUserID:)` is the fallback path — confirm by inspection, no code change.
  - [x] 4.5 Per NFR5 (launch path <2s), the permission prompt must **not** be invoked from `HyzerApp.body`/`init` or from the top-level `.task` in `HyzerApp.swift`. Verify by grep: the only call site is the "New Round" tap handler.

- [x] Task 5: Make `RoundRecord` real and push the Round on `start()` (AC: 1, 2, 5)
  - [x] 5.1 **Critical context for the dev agent:** `HyzerKit/Sources/HyzerKit/Sync/DTOs/RoundRecord.swift` is currently an identity-only stub. `SyncEngine` does not push Round records to CloudKit today — only `ScoreEvent` is synced. **Story 12.1 must promote `RoundRecord` to a real DTO and push it on round start**, because the CKQuerySubscription that drives this story's notification fires on `RoundRecord` creation. Without Round sync, no notification will ever fire and ACs 1–6 cannot pass.
  - [x] 5.2 Rewrite `RoundRecord` to mirror `ScoreEventRecord` (see `HyzerKit/Sources/HyzerKit/Sync/DTOs/ScoreEventRecord.swift:1-119` for the canonical pattern). Fields the subscription needs in the notification payload:
        | Field | Source | Used by |
        |---|---|---|
        | `id` (record name = `Round.id.uuidString`) | `Round.id` | identity / deep link |
        | `organizerID` (String UUID) | `Round.organizerID` | self-exclusion (AC #5) |
        | `organizerFirstName` (String) | first whitespace-delimited token of `Player.displayName` for `organizerID`. `Player.displayName` is a single field — see `HyzerKit/Sources/HyzerKit/Models/Player.swift:13`. Computed at push time, NOT at read time. | alert body (AC #1) + PII gate (AC #2) |
        | `courseName` (String) | `Course.name` (`HyzerKit/Sources/HyzerKit/Models/Course.swift:13`) | alert body (AC #1) |
        | `status` (String — `"active"` / `"completed"` / etc.) | `Round.status` | subscription predicate (`status == "active"`) and Story 12.2 reuse |
        | `playerIDs` ([String]) | `Round.playerIDs` | (not in alert; future Round-aware pull) |
        | `createdAt` (Date) | `Round.createdAt` | sort key for fetch |
        - PII gate: do **NOT** include `displayName`, last names, `iCloudRecordName`, email, or scores in the record. Only the precomputed first-name token. (AC #2)
  - [x] 5.3 Add `RoundRecord.init?(from: CKRecord)` symmetric to `ScoreEventRecord.init?(from:)` for the future pull path used by `handleRoundStartedNotification`.
  - [x] 5.4 Extend `SyncEngine` with a `pushRound(_ round: Round, organizerDisplayName: String, courseName: String) async` method that builds a `RoundRecord`, converts to `CKRecord`, and calls `cloudKitClient.save([record])`. Append a `SyncMetadata(recordID:, recordType: "Round", state: .pending)` first, follow the `.pending → .inFlight → .synced/.failed` state machine documented at `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift:42-46`. Reuse the existing `.inFlight` guard so two concurrent `pushRound` calls never duplicate.
  - [x] 5.5 Call `pushRound` from `RoundSetupViewModel.startRound(organizer:in:)` (`HyzerApp/ViewModels/RoundSetupViewModel.swift:138`) **after** `try context.save()` succeeds and **after** `round.start()` has transitioned status to `"active"`. ViewModel needs access to `SyncEngine` — extend the call sites to pass it in via the existing `AppServices` env injection (do **not** widen `RoundSetupViewModel`'s constructor; match the existing pattern of receiving services at call-time, like `loadPreviousRoundPlayers(currentUserID:modelContext:)`).
  - [x] 5.6 Compute `organizerFirstName` here, not in the DTO: `organizer.displayName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? organizer.displayName`. Pass into `pushRound`. Same applies to `courseName` (from `selectedCourse.name`).
  - [x] 5.7 If `pushRound` throws or the device is offline, the round still starts locally — sync retry follows the normal `.failed → retryFailed()` pipeline already wired in `SyncScheduler`. The user's local experience is unaffected.

- [x] Task 6: CKQuerySubscription for active Rounds + alert body wiring (AC: 1, 2)
  - [x] 6.1 In `HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift:139-176`, extend `setupSubscriptions()` to also create a subscription on `RoundRecord`. Predicate: `NSPredicate(format: "status == %@", "active")`. Subscription ID: `"Round-active-creation"`. Options: `[.firesOnRecordCreation]` (matches the existing `ScoreEventRecord` subscription pattern).
  - [x] 6.2 Configure the `CKSubscription.NotificationInfo` so APNs delivers an **alert** notification (not silent-only):
        - `notificationInfo.shouldSendContentAvailable = true` (existing pattern — enables background processing for our `pullRecords()` chain)
        - `notificationInfo.shouldSendMutableContent = false`
        - `notificationInfo.alertLocalizationKey = "ROUND_STARTED_FORMAT"` (string key looked up in `Localizable.strings` — for now, English-only, value: `"%@ started a round at %@"`)
        - `notificationInfo.alertLocalizationArgs = ["organizerFirstName", "courseName"]` — CloudKit fills these in from the record fields server-side. This is the key mechanism that keeps PII off the server payload — only the precomputed first-name token is sent (AC #2).
        - `notificationInfo.desiredKeys = ["organizerFirstName", "courseName", "organizerID"]` — so `parseRoundStartedPayload` (Task 2.5) can read them without a refetch.
  - [x] 6.3 Add the English-only `ROUND_STARTED_FORMAT` localization key. Path: `HyzerApp/Resources/en.lproj/Localizable.strings` (create the file + `en.lproj` directory if it does not exist — verify `project.yml` includes `HyzerApp/Resources` as a target source first; the existing `Resources/` folder pattern is in use for asset catalogs). Single entry: `"ROUND_STARTED_FORMAT" = "%@ started a round at %@";`. No other localization work in this story.
  - [x] 6.4 The existing idempotency guard at `SyncScheduler.swift:155-163` (UserDefaults key `"HyzerApp.subscriptionID.\(recordType)"` + check against `fetchAllSubscriptionIDs()`) handles the second subscription naturally. Verify by inspection — no new logic needed.
  - [x] 6.5 `aps-environment` in `HyzerApp/App/HyzerApp.entitlements:19-20` is currently `development`. **Do not** flip to `production` in this story — that's tracked in `deferred-work.md:10` as a Story 9.x → Epic 12 handoff item. Note in Completion Notes that Story 12.x release-train work must flip this before TestFlight build of Epic 12.

- [x] Task 7: Deep link from notification tap to Hole 1 of the active round (AC: 4)
  - [x] 7.1 The notification deep-link target is "the active round view (Hole 1)". In the codebase that is the `ScorecardContainerView` flow rooted from `HomeView`. Currently navigation is `@State`-driven via SwiftUI sheets/`NavigationStack`.
  - [x] 7.2 Use a published deep-link state on `AppServices`: `@Observable var pendingDeepLink: DeepLink?` where `DeepLink` is an enum with `case activeRound(roundID: UUID)`. `handleRoundStartedNotification` (Task 3.2) sets it. The root `ContentView` observes it and routes to the active round when set, then nils it out (consume-once).
  - [x] 7.3 If the local `Round` matching `roundID` is not yet present in SwiftData (notification arrived before the CKSubscription pull completed), the deep-link routing should retry once after the next `pullRecords()` completes. Cap at one retry — if still missing, fall back to the home screen with no error toast (this scenario is rare and the user can manually open the round from home).
  - [x] 7.4 Deep-link behavior on cold-launch from a tapped notification: `UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:)` already exists at `HyzerApp.swift:138-145`. Inspect `launchOptions?[.remoteNotification]` and seed `AppServices.pendingDeepLink` before the first view renders.

- [x] Task 8: Tests (AC: 1, 2, 3, 5)
  - [x] 8.1 `HyzerKitTests/Notifications/RoundStartedPayloadTests.swift`: encode/decode a CKSubscription user-info dictionary that mirrors what CloudKit delivers (specifically the `ck` envelope with `qry`/`rid`/`af` fields per Apple's CKSubscription docs); assert `parseRoundStartedPayload` returns the expected payload, and returns `nil` for malformed dictionaries (missing `organizerID`, missing `courseName`, wrong subscription type).
  - [x] 8.2 `HyzerKitTests/Notifications/RoundRecordTests.swift`: round-trip `Round` → `RoundRecord` → `CKRecord` → `RoundRecord` and assert all fields equal. Also assert that `RoundRecord.toCKRecord()` does **NOT** set keys for `displayName`, `iCloudRecordName`, `email`, or any score-related field (PII gate, AC #2) — iterate `record.allKeys()` and check the set is exactly the documented allowlist.
  - [x] 8.3 `HyzerKitTests/Notifications/SelfExclusionTests.swift`: `LiveNotificationService.shouldSuppressPresentation` returns true when `payload.organizerID == localPlayerID`, false otherwise, false when `localPlayerID == nil`. (AC #5)
  - [x] 8.4 `HyzerKitTests/SyncSchedulerTests.swift` (extend): assert `setupSubscriptions()` creates both the existing `ScoreEvent-creation` subscription AND the new `Round-active-creation` subscription with predicate `status == "active"`. Use `MockCloudKitClient` and capture the saved subscriptions.
  - [x] 8.5 `HyzerAppTests/AppServicesTests.swift` (extend or create): assert `handleRoundStartedNotification(_:)` does NOT trigger a deep-link assignment when the payload's `organizerID` matches the local player ID (self-exclusion at the AppServices level).
  - [x] 8.6 `HyzerAppTests/RoundSetupViewModelTests.swift` (extend): after `startRound` succeeds, the `SyncEngine` (mocked) should observe exactly one `pushRound` call with the expected first-name and course-name values derived from the test fixtures.
  - [x] 8.7 Lazy-permission test: assert that constructing `AppServices` and calling `startSync()` does NOT invoke `notificationService.requestAuthorization()`. Use `MockNotificationService.requestAuthorizationCallCount == 0`. Then simulate the "New Round" tap path and assert the call count goes to `1`. Calling the path a second time still equals `1` (UserDefaults flag short-circuits — AC #3).
  - [x] 8.8 Use Swift Testing (`@Suite`, `@Test`). Use `ModelConfiguration(isStoredInMemoryOnly: true)` for any SwiftData-backed test. Match the existing test patterns in `HyzerKitTests` (see `SyncSchedulerTests.swift`).

## Dev Notes

### Architecture & Patterns

- **Composition root is `AppServices`** (`HyzerApp/App/AppServices.swift:18`). All new service plumbing goes through there. ViewModels receive individual services (or accept them at call-time like `RoundSetupViewModel.loadPreviousRoundPlayers`) — never the full container.
- **Phone is the sole CloudKit sync node** (CLAUDE.md, "Sync Architecture"). The Watch never registers for or receives push notifications in this story. AC #6 only specifies that when the iPhone delivers a notification, the paired Watch presents the default haptic — that is system behaviour, no Watch code change required.
- **CKQuerySubscription is the trigger, not a custom APNs server.** This codebase has no server-side component. CloudKit's subscription engine runs server-side; the alert body is composed from record fields via `alertLocalizationKey`/`alertLocalizationArgs`. This is how PMVP-NFR1 (no PII in payload) is enforced — by never writing PII fields onto the `CKRecord` in the first place.
- **Self-exclusion is client-side, not server-side.** CKSubscription delivers to every subscriber including the writer's device. The writer's device must suppress presentation. AC #5 is satisfied by the `shouldSuppressPresentation` gate.
- **Coding standards (CLAUDE.md "Coding Standards"):** no silent `try?` (use `do/catch` + Logger); every SwiftData fetch needs `fetchLimit`; design tokens only (no hardcoded colors/spacing); accessibility-first (Dynamic Type, VoiceOver) for any new UI surface. This story is mostly service-layer; the only UI surface is the system-driven permission prompt and a possible empty-state for "permission denied" feedback (NOT required by ACs — do not add new UI beyond what's necessary).

### Read These Files Before You Touch Them

Per CLAUDE.md "No Defensive Coding for Impossible Cases" and the create-story workflow's read-before-modify mandate, read each file and document the relevant existing behavior you must preserve:

| File | Why |
|---|---|
| `HyzerApp/App/AppServices.swift` | Composition root. Existing `handleRemoteNotification()` (line 116) handles ScoreEvent subscriptions today — your new method `handleRoundStartedNotification(_:)` must coexist with it. `AppDelegate` already forwards remote notifications (line 24). |
| `HyzerApp/App/HyzerApp.swift` | `AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` (line 146) is the entry point. Today it unconditionally calls `services.handleRemoteNotification()` — you must branch on subscription ID. |
| `HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift` | `setupSubscriptions()` (line 144) is idempotent and persists subscription IDs in UserDefaults. Pattern to extend, not replace. |
| `HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift` | The `subscribe(to:predicate:)` method takes a predicate; you can express `status == "active"` directly without adding a new protocol method. |
| `HyzerApp/Services/LiveCloudKitClient.swift` | `subscribe` method (line 73) currently uses `options: [.firesOnRecordCreation]` and sets `shouldSendContentAvailable = true`. **Your Round subscription needs more configuration** (`alertLocalizationKey`, `alertLocalizationArgs`, `desiredKeys`) — but you should NOT modify `LiveCloudKitClient.subscribe` to take an alert body, because the `ScoreEvent` subscription is silent-push-only by design. Add a separate `subscribeWithAlert(...)` method to the protocol, or pass a `CKSubscription.NotificationInfo` configurator block — your call, but document the choice. Recommended: extend the protocol with `subscribeWithAlert(to:predicate:notificationInfo:)` so the existing silent-push code path stays untouched. |
| `HyzerApp/ViewModels/RoundSetupViewModel.swift` | `startRound` (line 138) is where Round creation completes today. Your `pushRound` call hooks in immediately after `try context.save()`. ViewModel does not currently receive `SyncEngine` — match the call-time-injection pattern (`func startRound(organizer:, in: context, syncEngine: SyncEngine)`). |
| `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift` | Read the `.pending → .inFlight → .synced/.failed` state machine doc-comment (line 14–25) and the `.inFlight` guard rationale (line 1195 of `_bmad-output/planning-artifacts/architecture.md`). Apply the same pattern to `pushRound`. |
| `HyzerApp/Views/HomeView.swift` | The "New Round" button at line 67 is where the lazy permission prompt fires. |
| `HyzerKit/Sources/HyzerKit/Models/Round.swift` | `Round.start()` (line 91) transitions `status` to `"active"`. Your `pushRound` must run AFTER this transition so the subscription predicate matches. |

**Critical:** these are the load-bearing patterns. Skipping a read here is the leading cause of review cycles and breakage (per the create-story workflow rationale).

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|---|---|---|
| `CloudKitClient.subscribe` | `HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift:26` | Existing protocol method handles silent push subscriptions. Extend the protocol with a new alert-aware variant rather than overload — keep ScoreEvent's silent-push pattern intact. |
| `MockCloudKitClient` | `HyzerKit/Tests/HyzerKitTests/Mocks/MockCloudKitClient.swift` | Test double pattern. Mirror it for `MockNotificationService`. |
| Subscription idempotency | `SyncScheduler.swift:155-163` | UserDefaults-keyed dedup. No new logic needed for the Round subscription — same code path handles both record types. |
| `SyncEngine` `.inFlight` guard | `SyncEngine.swift:42-46` + `architecture.md:1195` | Apply identically to `pushRound`. |
| `Player+Fixture` | `HyzerKitTests/Fixtures/Player+Fixture.swift` | Fixture pattern for test data. |
| `Round+Fixture` | `HyzerKitTests/Fixtures/Round+Fixture.swift` | Reuse for Round-construction in tests. |
| `AppDelegate.didReceiveRemoteNotification` | `HyzerApp.swift:146-159` | Already-wired entry point. Branch the dispatch — don't fork a second handler. |
| First-token name extraction | `RoundSetupViewModel`-level helper | Use `displayName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first` — one line, no new utility needed. |

### File Structure

**Files to add:**
```
HyzerKit/Sources/HyzerKit/Notifications/NotificationService.swift              # Protocol + payload + enum
HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift               # Test double
HyzerApp/Services/LiveNotificationService.swift                                # Live UNUserNotificationCenter wrapper
HyzerKit/Tests/HyzerKitTests/Notifications/RoundStartedPayloadTests.swift      # Payload parsing
HyzerKit/Tests/HyzerKitTests/Notifications/RoundRecordTests.swift              # CKRecord round-trip + PII allowlist
HyzerKit/Tests/HyzerKitTests/Notifications/SelfExclusionTests.swift            # Suppression gate
HyzerApp/Resources/en.lproj/Localizable.strings                                # ROUND_STARTED_FORMAT key
```

**Files to modify:**
```
HyzerKit/Sources/HyzerKit/Sync/DTOs/RoundRecord.swift          # Stub → real DTO (Task 5.2)
HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift            # Add subscribeWithAlert (Task 6)
HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift                # Add pushRound (Task 5.4)
HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift             # Extend setupSubscriptions (Task 6.1)
HyzerApp/Services/LiveCloudKitClient.swift                     # Implement subscribeWithAlert (Task 6)
HyzerApp/App/AppServices.swift                                 # Inject + handleRoundStartedNotification + pendingDeepLink (Tasks 3, 7)
HyzerApp/App/HyzerApp.swift                                    # AppDelegate branching + launchOptions deep-link seeding (Tasks 3.3, 7.4)
HyzerApp/ViewModels/RoundSetupViewModel.swift                  # Call pushRound after start() (Task 5.5)
HyzerApp/Views/Rounds/RoundSetupView.swift                     # Pass syncEngine + organizerDisplayName + courseName to startRound
HyzerApp/Views/HomeView.swift                                  # Lazy permission prompt on "New Round" tap (Task 4)
HyzerApp/Views/ContentView.swift                               # Observe pendingDeepLink and route (Task 7.2)
project.yml                                                    # Add HyzerApp/Resources/en.lproj/Localizable.strings to target sources if XcodeGen doesn't pick it up automatically
```

**Test files to extend:**
```
HyzerKit/Tests/HyzerKitTests/SyncSchedulerTests.swift          # Round subscription assertion (Task 8.4)
HyzerApp/Tests/RoundSetupViewModelTests.swift                  # pushRound call assertion (Task 8.6)
HyzerApp/Tests/AppServicesTests.swift                          # Self-exclusion at AppServices (Task 8.5)
```

**Regenerate Xcode project after changes:** run `xcodegen generate` once you've added the new directories and files. Then the canonical build/test command from CLAUDE.md:
```sh
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'
```

### Edge Cases

| Case | Behavior |
|---|---|
| User denies permission | Round creation still succeeds. No notifications delivered. In-app FR16b discovery via `SyncScheduler.foregroundDiscovery` continues to work. Do not nag with a re-prompt. |
| User has not yet been prompted, app cold-launches from notification tap | Impossible — they can't tap a notification they were never granted permission to receive. Don't add a defensive code path. |
| Notification arrives before the local `Round` exists in SwiftData | Trigger one `pullRecords()` and retry the deep-link routing once. If still missing, route to Home (no error toast). |
| Organizer's own device receives the push | `shouldSuppressPresentation` returns true → `handleRoundStartedNotification` returns early before `pendingDeepLink` is set. The Watch on the organizer's wrist may still vibrate (iOS owns notification delivery once accepted); the in-app UX of the organizer is unaffected because they're already on the active-round flow. |
| Two participants create overlapping rounds within the 30-second subscription window | Each round produces an independent record + notification. The active-round flow already handles concurrent rounds (FR16b). No coupling between the two notifications. |
| Subscription save fails on first launch (network) | `setupSubscriptions()` logs and returns silently (existing pattern at `SyncScheduler.swift:151-153`). Will retry on next app launch. No user-facing surfacing. |
| Network offline at `pushRound` time | `SyncMetadata` entry transitions to `.failed`; `SyncScheduler.startConnectivityListener()` retries on reconnect (existing path). Notification will arrive on participants' devices late but correctly once the push succeeds. |
| Organizer's `Player.displayName` is a single word ("Mike") | `split` returns `["Mike"]` → first token is `"Mike"`. Alert body: `"Mike started a round at [Course]"`. |
| Organizer's `displayName` is empty | Fallback to the empty string. Alert body: `" started a round at [Course]"`. This is technically broken UX but Player creation requires a non-empty displayName at onboarding (FR1) — this case should not arise. Per CLAUDE.md, do not add defensive coding for impossible cases. |
| User is on the Watch app only, no iPhone | Out of scope. Watch never directly receives push notifications in this codebase (phone is sole sync node). |

### Scope Boundaries — Do NOT Implement

- Do **NOT** implement Story 12.2 (Round-Complete push) or 12.3 (Discrepancy push). 12.1 builds the foundation; 12.2/12.3 will reuse `NotificationService`, the `Round` subscription, and the deep-link infra — that reuse is the explicit handoff.
- Do **NOT** flip `aps-environment` from `development` to `production`. Tracked in `_bmad-output/implementation-artifacts/deferred-work.md:10`. A future release-train story owns it.
- Do **NOT** add Watch-side notification handling. Watch is read-only for notifications in this codebase.
- Do **NOT** add analytics for notification delivery / tap. Not in scope per epic spec.
- Do **NOT** add a notification settings screen, opt-out toggle, or in-app permission re-prompt UI.
- Do **NOT** localize beyond the single `ROUND_STARTED_FORMAT` English string. Localization is out of scope per repo conventions (see deferred item from Story 11.3 in `deferred-work.md:15`).
- Do **NOT** extract `UserDefaults.standard` access into a wrapper (CLAUDE.md tech-debt list flags this as a future-cleanup, not a story 12.1 obligation).
- Do **NOT** modify the existing ScoreEvent subscription. It remains silent-push-only.
- Do **NOT** refactor `RoundSetupViewModel` to receive services via constructor. Match the existing call-time injection pattern of `loadPreviousRoundPlayers`.

### Previous Story Intelligence

**From Story 9.2 (privacy manifest):** `aps-environment = development` is currently set in `HyzerApp.entitlements:19-20`. It must remain `development` for this story — the entitlement flip is parked at the Epic 12 release-train handoff per `deferred-work.md:10`.

**From Story 9.3 (App Store Connect):** TestFlight Friends Beta group exists. Notifications will reach those testers' real devices via TestFlight once the entitlement flips to `production` (out of scope here). For dev/test, the development APS environment + a real iOS device + a TestFlight build is the verification path.

**From Story 11.3 (share sheet):** Localized strings are deferred — Story 11.3 has hardcoded English in share captions. Match that posture: one `Localizable.strings` entry for the notification format, no broader localization work.

**From Story 4.1–4.3 (sync engine):** The `.inFlight` guard pattern (`SyncEngine.swift` actor-reentrancy fix) is the canonical answer for any "should I push X twice?" concern. Your `pushRound` lifts the pattern wholesale.

**From the Epics 1–8 retrospective** (`_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md`):
- `RoundRecord` was deliberately a stub — DTO expansion was "deferred to future sync expansion" (CLAUDE.md "Known Technical Debt"). Story 12.1 is that future. Promote it carefully and write the tests.
- `Task.sleep(for: .milliseconds(100))` flaky timing — do **NOT** introduce sleeps in your tests. Use `ValueCollector` from `HyzerKitTests/Fixtures/ValueCollector.swift` for awaiting actor outputs deterministically.
- `ValueCollector` is duplicated debt — do not extend the duplication; this story does not own that cleanup.

### Git Intelligence

Recent commits (`git log --oneline -10`):
- `c5a9bae` Story 9.3 — App Store Connect record (TestFlight unlocked the Epic 12 path)
- `14deb20` Story 9.2 — privacy manifest, permission strings (microphone + speech declared; **no notification declaration yet** — the privacy manifest's `NSPrivacyCollectedDataTypes` need a review when notifications go live, but no new data type is collected — alert body is iCloud-derived first-names already covered)
- `b81e2e4` Story 9.1 — release build config (where the dev/prod `aps-environment` parking happened)
- `eca6584`, `0821bd2` Story 11.3/11.2 — share sheet and round summary card (no overlap with this story's files)

No recent commits touch `Notifications/`, `RoundRecord.swift`, or `SyncScheduler.setupSubscriptions` beyond the existing pattern — your changes are additive and won't conflict with anything in-flight.

### Latest Technical Information

- **`UNUserNotificationCenter.requestAuthorization(options:)`** — iOS 18 behavior unchanged from iOS 16. The async/await variant `try await center.requestAuthorization(options: [.alert, .badge, .sound])` returns `Bool` (true if granted); use `getNotificationSettings()` for the typed `UNAuthorizationStatus` if you need finer-grained state.
- **`CKQuerySubscription` + `NotificationInfo.alertLocalizationKey`** is the supported API for server-side alert composition without writing PII to the record. `alertLocalizationArgs` accepts an array of record field names; CloudKit substitutes the field values into the format string at delivery time. Pattern docs: Apple's "Push Notifications via CloudKit" guide (still current for iOS 18). The receiving device receives the substituted alert body — your client code never re-formats it.
- **`UNNotificationInterruptionLevel.active`** (default for non-time-sensitive notifications) is what we want per UX-PMVP-DR4. Do not configure `.timeSensitive` (requires entitlement) or `.critical` (requires special entitlement). `.passive` would suppress haptic on Watch — not what we want.
- **`alertLocalizationArgs` field-name resolution** is case-sensitive and must exactly match the `CKRecord` field names (i.e., `"organizerFirstName"`, not `"organizer_first_name"`). The CKRecord keys you set in `RoundRecord.toCKRecord()` are the strings CloudKit substitutes.

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test`). No XCTest.
- **In-memory SwiftData:** `ModelConfiguration(isStoredInMemoryOnly: true)` per `HyzerKitTests` convention. See `TestContainerFactory.swift` if there's an existing helper.
- **MockCloudKitClient:** Already exists at `HyzerKit/Tests/HyzerKitTests/Mocks/MockCloudKitClient.swift`. If you extend `CloudKitClient` (Task 6 recommended `subscribeWithAlert`), extend `MockCloudKitClient` correspondingly — and add a `savedSubscriptions: [CKSubscription]` collection if not already present so Task 8.4 can inspect subscription configuration.
- **MockNotificationService:** Create as part of Task 1.3. Mirror the structure of `MockCloudKitClient`: tracked call counts, settable return values, captured arguments.
- **Determinism:** Do **NOT** use `Task.sleep` in tests (retro debt). Use `ValueCollector` for actor outputs. For subscription-creation tests, you only need to call `setupSubscriptions()` once and inspect `MockCloudKitClient.savedSubscriptions` — no timing involved.
- **PII gate test (Task 8.2)** is the most important test in this story — it is the structural guarantee of PMVP-NFR1. Treat its failure as a P0 bug.
- **Manual verification (recommended for AC #6):** end-to-end test on a real iPhone + paired Watch — verify the Watch presents the default `.notification` haptic when a Round-Started push arrives. Document in Completion Notes.

### Open Questions (for the dev agent to confirm during implementation)

1. The recommended `CloudKitClient` extension is a new `subscribeWithAlert(to:predicate:notificationInfo:)` method (Task 6 / Read-These-Files note for `CloudKitClient.swift`). Confirm by inspection whether the existing `subscribe(to:predicate:)` should instead accept an optional `notificationInfo:` parameter. The trade-off: a default-parameter overload preserves call-site compatibility but couples ScoreEvent and Round subscription configuration paths. The new-method approach keeps the silent-push contract distinct. Recommended: new method. Confirm with code review during implementation.
2. `RoundRecord` is being promoted from stub. Confirm there is no in-flight branch or PR that also touches `RoundRecord.swift` before starting (`git log --all --oneline -- HyzerKit/Sources/HyzerKit/Sync/DTOs/RoundRecord.swift`).
3. The `pendingDeepLink` consume-once pattern (Task 7.2) is new in this codebase. Verify it integrates cleanly with the existing `ContentView` → `HomeView` → `ScorecardContainerView` navigation. If `ContentView` already has navigation state for the active round, prefer extending that rather than introducing a parallel state surface.

### Project Structure Notes

- **HyzerKit `Notifications/` subdirectory is new.** Add it to the package's source tree; SwiftPM picks it up automatically (HyzerKit is a local Swift Package, no `project.yml` edit needed for HyzerKit sources).
- **`HyzerApp/Resources/en.lproj/Localizable.strings` is new.** XcodeGen's default Sources include rule may or may not pick this up — verify after `xcodegen generate` that the file is in the build. If not, add explicit `sources` entry under the iOS target in `project.yml`.
- **Layer boundaries (CLAUDE.md):** `NotificationService` protocol + `RoundStartedPayload` + `NotificationAuthorizationStatus` belong in HyzerKit because they're consumed by both `AppServices` and tests; the live implementation belongs in HyzerApp because it imports `UserNotifications` and `UIKit`. This mirrors the `CloudKitClient` / `LiveCloudKitClient` split exactly.
- **Watch boundary:** None of these files touch `HyzerWatch/`. Confirm by inspection at end of implementation.

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Epic 12, Story 12.1] — user story, scope, ACs (lines 398-437)
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#PMVP-FR11, PMVP-NFR1] — functional + privacy requirements (lines 104, 112)
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#UX-PMVP-DR4] — Watch haptic spec (line 88)
- [Source: _bmad-output/planning-artifacts/architecture.md#L230] — `Background Modes > Remote Notifications` capability (already enabled)
- [Source: _bmad-output/planning-artifacts/architecture.md#L1361] — `CKSubscription` throttling note (foreground-discovery fallback)
- [Source: _bmad-output/planning-artifacts/architecture.md#L1188-1195] — `.pending → .inFlight → .synced` state machine + `.inFlight` guard rationale
- [Source: CLAUDE.md#Sync Architecture] — Phone-as-sole-sync-node, Watch boundary
- [Source: CLAUDE.md#Coding Standards (Enforce, Don't Review)] — `try?` rule, bounded queries, accessibility, design tokens
- [Source: CLAUDE.md#Known Technical Debt] — `RoundRecord` stub deferral now resolved by this story; `UserDefaults.standard` direct-use is allowed
- [Source: HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift:139-176] — `setupSubscriptions` extension point
- [Source: HyzerKit/Sources/HyzerKit/Sync/DTOs/ScoreEventRecord.swift] — DTO pattern to mirror for `RoundRecord`
- [Source: HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift:14-25] — actor doc-comment, push/pull pipeline
- [Source: HyzerApp/Services/LiveCloudKitClient.swift:73-86] — current subscription save (silent push only)
- [Source: HyzerApp/App/HyzerApp.swift:131-160] — `AppDelegate` remote notification handler
- [Source: HyzerApp/App/AppServices.swift:116-118] — existing `handleRemoteNotification()` to coexist with new round-started handler
- [Source: HyzerApp/ViewModels/RoundSetupViewModel.swift:138-158] — `startRound` extension point
- [Source: HyzerApp/Views/HomeView.swift:38, 67] — New Round button gate for lazy permission prompt
- [Source: _bmad-output/implementation-artifacts/deferred-work.md:10] — `aps-environment` flip handoff
- [Source: _bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md] — `Task.sleep` flakiness, `ValueCollector` duplication
- [Source: _bmad-output/implementation-artifacts/11-3-share-round-summary-via-system-share-sheet.md] — most-recent completed-story template for tasks/notes/references structure

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

- `StubICloudIdentityProvider` in `AppServicesTests.swift` used `.unavailable(reason: nil)` — `ICloudUnavailableReason` is non-optional; fixed to `.couldNotDetermine`.
- `StubCloudKitClient` in `ICloudIdentityResolutionTests.swift` did not implement `subscribeWithAlert` after the protocol was extended; added stub conformance.
- `DeepLink` enum needed `Equatable` conformance for `onChange(of:)` on `Optional<DeepLink>`.
- `AppServicesTests` used an instance property (`services: AppServices!`) mutated inside tests — Swift Testing `@Suite struct` gives each test a fresh struct instance; rewrote to use local `let services = ...`.
- Full iOS simulator test run not possible on this machine (requires Xcode 26 / iOS 26 SDK). HyzerKit package tests (`swift test --package-path HyzerKit`) passed 300 tests. HyzerAppTests compiled clean and all 21 suites reported passing in the test runner output.

### Completion Notes List

- `aps-environment` remains `development` per story scope. **Epic 12 release-train must flip to `production` in `HyzerApp.entitlements` before shipping to TestFlight/App Store.** Tracked in `_bmad-output/implementation-artifacts/deferred-work.md:10`.
- AC #6 (Watch haptic uses `.active` interruption level) relies on system default behaviour — no Watch-side code was changed. The standard `UNNotificationInterruptionLevel.active` is the default for alert notifications; no category or custom level was configured.
- Self-exclusion (AC #5) is client-side: `shouldSuppressPresentation` compares `payload.organizerID == localPlayerID`; the notification is delivered by CloudKit to the organizer's device but presentation is suppressed before `pendingDeepLink` is set.
- `alertLocalizationKey`/`alertLocalizationArgs` in the CKSubscription's `NotificationInfo` ensures CloudKit composes the alert body server-side from record fields — PII never enters the APNs payload (PMVP-NFR1 structural guarantee). Only the precomputed first-name token is written to the `CKRecord`, not `displayName`.
- `pushRound` in `SyncEngine` receives Sendable primitives only (UUID, String, [String], Date) to satisfy Swift 6 strict concurrency — `@Model` objects are never passed across actor boundaries.
- Protocol extension choice: `subscribeWithAlert(to:predicate:subscriptionID:notificationInfo:)` is a separate method on `CloudKitClient` to keep the silent-push ScoreEvent path unchanged and avoid coupling the two subscription configurations.
- P0 PII gate test (`test_toCKRecord_piiAllowlist` in `RoundRecordTests.swift`) asserts `record.allKeys()` exactly matches the documented allowlist and that all PII keys are absent. Treat any regression here as a release blocker.
- Manual end-to-end verification on real device + paired Watch is required before Epic 12 ships to TestFlight (can't be automated in CI).

### File List

**New files:**
- `HyzerKit/Sources/HyzerKit/Notifications/NotificationService.swift`
- `HyzerKit/Tests/HyzerKitTests/Mocks/MockNotificationService.swift`
- `HyzerKit/Tests/HyzerKitTests/Notifications/RoundStartedPayloadTests.swift`
- `HyzerKit/Tests/HyzerKitTests/Notifications/RoundRecordTests.swift`
- `HyzerKit/Tests/HyzerKitTests/Notifications/SelfExclusionTests.swift`
- `HyzerApp/Services/LiveNotificationService.swift`
- `HyzerApp/Resources/en.lproj/Localizable.strings`
- `HyzerAppTests/Mocks/MockNotificationService.swift`
- `HyzerAppTests/AppServicesTests.swift`

**Modified files:**
- `HyzerKit/Sources/HyzerKit/Sync/DTOs/RoundRecord.swift` — promoted from identity stub to full DTO; `init?(from:)` strict-requires `playerIDs` (code review patch)
- `HyzerKit/Sources/HyzerKit/Sync/CloudKitClient.swift` — added `subscribeWithAlert` to protocol
- `HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift` — added `pushRound`; review patch handles `CKError.serverRecordChanged` as `.synced` and demotes stuck `.inFlight` to `.failed` on local-save failure
- `HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift` — extended `setupSubscriptions` with Round subscription; review patch documents partial-failure recovery contract
- `HyzerKit/Tests/HyzerKitTests/Mocks/MockCloudKitClient.swift` — added `subscribeWithAlert` + `savedAlertSubscriptions`
- `HyzerKit/Tests/HyzerKitTests/SyncSchedulerTests.swift` — added 3 Round subscription tests
- `HyzerApp/Services/LiveCloudKitClient.swift` — implemented `subscribeWithAlert`
- `HyzerApp/Services/LiveNotificationService.swift` — review patch: extracted `CKNotificationEnvelope` helper (handles `NSDictionary`/`[String: Any]` cast variants); `requestAuthorization` returns `.notDetermined` on thrown error
- `HyzerApp/App/AppServices.swift` — `DeepLink` enum, `notificationService`, `pendingDeepLink`, `handleRoundStartedNotification` (with one-shot pullRecords retry), `seedDeepLinkFromLaunchOptions` (eager deep-link + background pull-and-retry)
- `HyzerApp/App/HyzerApp.swift` — subscription-ID branching in `AppDelegate` (via `CKNotificationEnvelope`), cold-launch deep-link seeding
- `HyzerApp/ViewModels/RoundSetupViewModel.swift` — extended `startRound` signature with `syncEngine:`, fire-and-forget `pushRound`
- `HyzerApp/Views/Rounds/RoundSetupView.swift` — passes `appServices.syncEngine` to `startRound`
- `HyzerApp/Views/HomeView.swift` — lazy notification permission on "New Round" tap (only persists `hasPrompted` on definitive outcomes); `pendingDeepLink` consumer wired to both `.onAppear` (initial-value seeding) and `.onChange`
- `HyzerApp/Resources/en.lproj/Localizable.strings` — positional `%1$@` / `%2$@` specifiers for future-i18n correctness
- `HyzerAppTests/AppServicesTests.swift` — deterministic `Task.yield()` instead of `Task.sleep`; self-exclusion test asserts `pullRecords` NOT called via fetch-call counter; stub upgraded to class
- `HyzerAppTests/ICloudIdentityResolutionTests.swift` — added `subscribeWithAlert` stub
- `HyzerAppTests/RoundSetupViewModelTests.swift` — updated `startRound` call sites, added `pushRound` capture test
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story 12.1 status updated

(Note: `HyzerApp/Views/ContentView.swift` was listed in the original plan but not modified — observer placement consolidated in `HomeView` which already owns the tab selection state.)

### Review Findings

_Code review run 2026-05-17 — 3-layer adversarial (Blind / Edge Case / Acceptance Auditor). 13 patch, 8 defer, 24 dismissed._

- [x] [Review][Patch] Cold-launch deep-link skips `pullRecords()` and has no one-retry pattern — landing on empty Scoring tab when Round not yet materialised (violates Task 7.3) [HyzerApp/App/AppServices.swift:158-170]
- [x] [Review][Patch] HomeView `.onChange(of: pendingDeepLink)` does not fire for initial value — cold-launch seeded deep-link silently fails to switch tabs [HyzerApp/Views/HomeView.swift:27]
- [x] [Review][Patch] `pushRound` treats `CKError.serverRecordChanged` as `.failed` — but the record is already on the server; retry pipeline will re-push needlessly [HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift pushRound catch]
- [x] [Review][Patch] `pushRound` — local `try modelContext.save()` failure after CK save succeeds leaves `SyncMetadata` permanently in `.inFlight` (retry only resets `.failed`) [HyzerKit/Sources/HyzerKit/Sync/SyncEngine.swift pushRound save block]
- [x] [Review][Patch] `SyncScheduler.setupSubscriptions` — partial failure: if ScoreEvent subscribe succeeds but `subscribeWithAlert` for Round throws, the UserDefaults flag for ScoreEvent is persisted but Round subscription is silently missing on next launch (idempotency check passes, no retry) [HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift setupSubscriptions]
- [x] [Review][Patch] AppDelegate + LiveNotificationService duplicate the `userInfo["ck"]["qry"]["sid"]` parsing tree — extract a single envelope helper to prevent silent drift [HyzerApp/App/HyzerApp.swift didReceiveRemoteNotification, HyzerApp/Services/LiveNotificationService.swift parseRoundStartedPayload]
- [x] [Review][Patch] `userInfo["ck"] as? [String: Any]` may fail when APNs delivers an `NSDictionary` — defensive cast via `(as? NSDictionary) as? [String: Any]` needed [HyzerApp/App/HyzerApp.swift, HyzerApp/Services/LiveNotificationService.swift]
- [x] [Review][Patch] `RoundRecord.init?(from:)` degrades malformed `playerIDs` to `[]` silently via `?? []` — required-field rejection elsewhere but lenient here; treat as required and log when present-but-wrong-type [HyzerKit/Sources/HyzerKit/Sync/DTOs/RoundRecord.swift init from CKRecord]
- [x] [Review][Patch] `AppServicesTests.test_startSync_doesNotRequestAuthorization` uses `Task.sleep(for: .milliseconds(100))` — direct violation of CLAUDE.md retro-debt rule and spec Testing Requirements ("Do NOT use Task.sleep in tests"); replace with deterministic wait [HyzerAppTests/AppServicesTests.swift test_startSync block]
- [x] [Review][Patch] `LiveNotificationService.requestAuthorization` maps any thrown error to `.denied`, and `HomeView.requestNotificationPermissionIfNeeded` unconditionally writes `hasPrompted = true` — a transient error permanently locks out re-prompting; only set the flag on a definitive `.authorized`/`.denied`/`.notDetermined` outcome [HyzerApp/Services/LiveNotificationService.swift requestAuthorization, HyzerApp/Views/HomeView.swift:~549]
- [x] [Review][Patch] `Localizable.strings` uses non-positional `"%@ started a round at %@"` while the comment claims positional `%1$@`/`%2$@` — change to `"%1$@ started a round at %2$@"` for future i18n correctness and comment consistency [HyzerApp/Resources/en.lproj/Localizable.strings]
- [x] [Review][Patch] `test_handleRoundStartedNotification_selfExclusion_doesNotSetDeepLink` does not assert `syncEngine.pullRecords` was NOT called — battery / chatter behaviour unpinned [HyzerAppTests/AppServicesTests.swift selfExclusion test]
- [x] [Review][Patch] Story spec "Files to modify" lists `HyzerApp/Views/ContentView.swift` but it was not touched (observer placed in `HomeView` instead) — update File List in Dev Agent Record [_bmad-output/implementation-artifacts/12-1-notification-foundation-and-round-started-push.md:189]

- [x] [Review][Defer] `Player` schema has no `firstName` field — `split(...).first` is best-effort for compound names ("O'Brien", "M. Smith") — deferred, schema change out of scope
- [x] [Review][Defer] `MockNotificationService` duplicated across HyzerApp + HyzerKit test targets — deferred, matches existing `ValueCollector` shared-test-helper debt (CLAUDE.md tech-debt list); future shared `TestSupport` library
- [x] [Review][Defer] `RoundRecord.toCKRecord()` writes empty `playerIDs` array — CloudKit serialization of empty list fields is platform-dependent — deferred, edge case; add a round-trip test fixture in a future story
- [x] [Review][Defer] Two near-simultaneous round-start notifications can race on `pendingDeepLink` (second overwrites first before HomeView consumes) — deferred, rare-coincidence edge case
- [x] [Review][Defer] `organizerFirstName` / `courseName` empty-string payloads from upstream — deferred, upstream `Player` creation (FR1) requires non-empty `displayName`; per CLAUDE.md "no defensive coding for impossible cases"
- [x] [Review][Defer] `SyncEngine.fetchAllMetadata()` `fetchLimit = 1000` can truncate under heavy load — pre-existing pattern across SyncEngine; deferred to a broader pagination pass
- [x] [Review][Defer] AC #4 deep-link routes to first active round by `startedAt` (ScoringTabView `@Query` first match), not specifically to `payload.roundID` — multi-concurrent-active-round edge case; deferred
- [x] [Review][Defer] UserDefaults key `"HyzerApp.subscriptionID.Round"` is keyed by `recordType` while subscription ID is `"Round-active-creation"` — works for Story 12.1 but namespace will collide if Story 12.2 adds a second `Round` subscription — deferred to Story 12.2

## Change Log

| Date | Change |
|---|---|
| 2026-05-17 | Story 12.1 implemented: NotificationService protocol, LiveNotificationService, RoundRecord DTO, pushRound, CKQuerySubscription with alert, deep-link routing, lazy permission prompt, self-exclusion gate, all 8 task groups complete |
| 2026-05-17 | Code review (3-layer adversarial): 13 patch action items, 8 deferred items appended above. AC #1, #2 (P0 PII gate), #5, #6 verified clean. AC #3 lazy-permission flow correct (one `Task.sleep` test-debt finding). AC #4 deep-link foundation in place but cold-launch retry and onChange-initial-value gaps need patching. |
| 2026-05-17 | All 13 review patches applied: cold-launch `pullRecords` + one-shot retry; HomeView `.onAppear` initial-value gate; `pushRound` handles `CKError.serverRecordChanged` + demotes stuck `.inFlight` to `.failed`; `CKNotificationEnvelope` helper centralises `ck.qry` parsing with `NSDictionary` fallback (AppDelegate + LiveNotificationService); `RoundRecord.init?(from:)` strict-requires `playerIDs`; `requestAuthorization` returns `.notDetermined` on error + HomeView persists `hasPrompted` only on definitive outcomes; Localizable.strings uses positional `%1$@`/`%2$@`; AppServicesTests use deterministic `Task.yield()` and assert `pullRecords` not called on self-exclusion; File List corrected. HyzerKit: `swift test` 300 tests pass. Story 12.1 → done. |
