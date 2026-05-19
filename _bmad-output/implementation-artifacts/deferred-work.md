## Deferred from: code review of story-15.6 (2026-05-19)

- Story-spec text was rewritten in place rather than checkboxes simply checked — Task 1.1 elicitation prompt (and subtasks 1.1–1.3) were collapsed into a single "Policy decision pre-made by user: Policy A" line. Acceptable under the new Frozen Artifact Policy because story files are explicitly NOT frozen (they are status records), but the original Task 1.1 elicitation prose is now lost from the diff history. Flagged for traceability only; no remediation planned. (`_bmad-output/implementation-artifacts/15-6-stale-planning-artifact-cleanup.md:27-61`)

## Deferred from: code review of 14-2-generative-visual-round-signature-on-summary-card (2026-05-18)

- Manual verification (Tasks 8.1–8.5) was not performed by the dev agent per Completion Notes. Includes the palette-on-`backgroundElevated` contrast spot-check (`Color.textSecondary`, `Color.backgroundTertiary` are at higher risk of failing 4.5:1 AA against the elevated background). Spec line 425 explicitly required this check before proceeding past Task 4. Recommend human verification on simulator (live + AirDrop PNG + VoiceOver + Reduce Motion) before merge.

## Deferred from: code review of 13-3-head-to-head-record-between-two-players (2026-05-18)

- `#Predicate { sharedRoundIDs.contains($0.id) }` with up to ~10k UUIDs in `sharedRoundIDs` may approach SQLite IN-clause limits — pre-existing pattern from `PlayerTrendService` / `PersonalBestService`. Needs systematic review across all three services with an explicit batching or chunking guard.
- `StandingsEngine.recompute` failure cannot be distinguished from "player legitimately not in round" in `HeadToHeadService.computeRecord:130-138` — both produce empty `currentStandings`. Pre-existing pattern; reconsider when the engine surfaces a recoverable error signal.
- `trigger: .localScore` passed when recomputing historical rounds in `HeadToHeadService.computeRecord:130` is semantically inaccurate — pre-existing pattern. Risk surfaces only if a future analytics/sync side-effect is keyed on `.localScore`.
- No `Task.isCancelled` checks inside the per-round loop in `HeadToHeadService.computeRecord:126-148` — pre-existing pattern. User navigating away from `HeadToHeadView` mid-compute pays full compute cost.
- `HeadToHeadViewModel.init(service:)` and `HeadToHeadOpponentPickerViewModel.init(service:)` rely on doc comment `"NOT used in production"` rather than access control — pre-existing pattern from Stories 13.1/13.2. Gate with `#if DEBUG` or factor into a separate testing-only module.
- `HeadToHeadServiceTests` and `HeadToHeadViewModelTests` rely on `parByHole[n] ?? 3` fallback inside `StandingsEngine` instead of inserting `Hole` rows — project-wide test pattern. Coupling that would silently green-test through an engine refactor requiring explicit holes.

## Deferred from: code review of 13-2-personal-best-per-course (2026-05-18)

- `participantRoundIDs.contains($0.id)` SwiftData translation may fall back to in-memory filtering with very large `participantRoundIDs` sets — combined with `fetchLimit = maxRounds` applied before the predicate. Same concern as Story 13.1 (already in this file). Bounded `maxRounds = 500` keeps it in-budget for PMVP. (`HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift:83-87`)
- ScoreEvent fetch `fetchLimit = maxRounds * ScoreEvent.maxEventsPerRound` multiplier may under-bound for multi-course users. ScoreEvent fetch is NOT filtered by `courseID`, so a player with 500 rounds spread across multiple courses (10 courses × 60 rounds × 18 holes = 10,800 events) hits the 10,000 cap and silently drops the oldest events. Practical risk is low at PMVP scale. (`HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift:68`)
- No PersonalBestService-level logging when `StandingsEngine.recompute` silently fails on a per-round basis. The engine catches internal errors and returns `currentStandings == []` on a fresh engine, so the round is dropped from PB candidates with no log entry from `PersonalBestService`. A transient SwiftData failure on the actual best round silently demotes PB to runner-up. Add `logger.notice` when `standing == nil || holesPlayed == 0` despite the player having events for that round. (`HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift:99-113`)
- `Round.completedAt` may be `nil` after CloudKit hydration even when `status == "completed"`. CloudKit-materialized records bypass the `Round.complete()` lifecycle method that sets the field. The `guard let completedAt = ...` skip in `PersonalBestService.computeBest` is silent; if a synced PB round arrives with nil `completedAt`, the user sees "No rounds yet on this course." Verify hydration behavior before patching. (`HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift:101`)
- Test helper `insertRound(... completedAt: Date(timeIntervalSinceNow: -1) ...)` produces near-identical timestamps for sibling inserts in the same test. SortDescriptor on identical `completedAt` can shuffle insertion order non-deterministically. Pre-existing test pattern; standalone audit deferred. (`HyzerKit/Tests/HyzerKitTests/Domain/PersonalBestServiceTests.swift:23`)

## Deferred from: code review of 12-3-organizer-only-discrepancy-detected-push-notification.md (2026-05-17)

- SyncScheduler does not re-register subscriptions on iCloud identity change. Pre-existing pattern that affects all CKQuerySubscriptions, not just `Discrepancy-creation`. Users who sign out and back in with a different iCloud account retain stale subscription predicates until manual re-registration.
- CKError partial-failure / quota-exceeded / rate-limit retry-with-backoff is not handled in `SyncEngine+Discrepancy.pushDiscrepancy`. Pre-existing pattern across all push paths (`pushRoundCompletion`, ScoreEvent push). Non-network/non-serverRecordChanged errors are uniformly marked `.failed` with no scheduled retry.
- Stale `.inFlight` detection is informational only — `pushDiscrepancy` logs "stale?" but proceeds regardless. Pre-existing across all SyncMetadata state machines. Could compare `lastAttempt` against a 30s timeout window before assuming a leaked `.inFlight` is safe to overwrite.
- Fire-and-forget `Task { await pushDiscrepancy(...) }` inside `SyncEngine.detectConflicts` is not tracked for cancellation. Pre-existing async pattern that mirrors other push call-sites. Tasks outlive the actor on rapid reinit, which has flaked tests historically.
- CKRecord field type variance: `DiscrepancyRecord.init(from: CKRecord)` reads `holeNumber` as `Int`, but APNs / CloudKit may decode integer fields as `NSNumber`. Pre-existing across all DTOs (`RoundRecord`, `CourseRecord`). Should fall back to `(value as? NSNumber)?.intValue`.
- Stacked `fullScreenCover` modifiers in `HomeView` (discrepancy + summary) depend on SwiftUI's documented-but-not-API-guaranteed ordering. Pre-existing modality pattern across the app. Should consolidate to a single state-driven cover with an enum item type.
- `activeRounds` `@Query` may not be hydrated when `HomeView.onAppear` consumes a cold-launch deep-link. Pre-existing reactive timing pattern; affects round-complete and discrepancy paths alike.
- `DiscrepancyResolutionView` does not react to a peer resolving the discrepancy mid-presentation (organizer would see stale active buttons). Pre-existing reactive coupling across resolution flows.
- `DiscrepancyResolutionDeepLinkHost.loadDiscrepancy` continues mutating SwiftUI state after the `isPresented` binding flips false. Pre-existing pattern across host views. Use `Task` cancellation or `.task(id:)`.
- `SyncEngine+Discrepancy.pushDiscrepancy` API takes 6 unstructured scalar parameters — ergonomic refactor target. Should accept `Discrepancy` or `DiscrepancyRecord` directly since `detectConflicts` already has the full record at the call site.
- `DiscrepancyResolutionDeepLinkHost.loadDiscrepancy` uses `playerDescriptor.fetchLimit = 200` magic number to resolve player names. Pre-existing concern; should query by predicate scoped to the specific `playerID` instead of fetching all players.
- Test `test_pushDiscrepancy_alreadySynced_skips` asserts `savedRecords.isEmpty` but does not assert `lastAttempt` is preserved. Additional coverage gap to prevent a future refactor from tripping retry windows.
- Test contract gap for live CloudKit payload shape — `LiveNotificationServiceTests` hand-rolls `userInfo` dictionaries that may not exactly match what CloudKit delivers in practice. Applies to all three Epic 12 subscription parsers (round-started, round-complete, discrepancy); needs a captured-real-payload fixture.

## Deferred from: code review of 9-2-privacy-manifest-permission-strings-and-app-icons.md (2026-05-16)

- Pin `UIUserInterfaceStyle: Dark` in `project.yml info.properties` + `HyzerApp/App/Info.plist`. Reason for deferral: current behavior is acceptable until a later polish story. The universal `LaunchBackground.colorset` still wins for the launch screen in light-mode (the near-black launch is preserved); only the launch→first-frame trait-collection seam is fragile. Pick up in the next launch / first-frame polish pass.
- Run canonical `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'` against the 407-test baseline (AC7). Reason for deferral: current machine has no simulator. To be executed by the reviewer doing the AC4/AC5/AC6 visual verification on a Mac with the paired simulator, in the same session.
- `UISupportedInterfaceOrientations`, `UIBackgroundModes`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `ITSAppUsesNonExemptEncryption` are duplicated between `project.yml info.properties` and `HyzerApp/App/Info.plist`. XcodeGen merges them so it's not drift-prone in practice, but consolidating to a single source of truth (prefer `project.yml`) is a future-cleanup item.

## Deferred from: code review of 9-1-release-build-configuration-and-signing.md (2026-05-16)

- Test targets inherit `DEVELOPMENT_TEAM` from `project.yml:20` global `settings.base` — harmless locally; signing unit-test bundles can fail on a CI agent without the team's Apple ID. Revisit when CI is introduced (Epic 13 / future story).

## Deferred from: code review of 11-3-share-round-summary-via-system-share-sheet.md (2026-05-14)

- Hardcoded English Strings (Localization Risk) in `RoundSummaryViewModel.swift` — The share caption is built using hardcoded string literals. This follows existing project patterns but should be addressed when localization is prioritized.

## Deferred from: code review of 12-1-notification-foundation-and-round-started-push.md (2026-05-17)

- `Player` schema has no `firstName` field — `displayName.split(...).first` is best-effort for compound names ("O'Brien" returns full name; "M. Smith" returns "M."). Story 12.1 follows spec Task 5.6 exactly; a future story should introduce an explicit `firstName` on `Player`.
- ~~`MockNotificationService` duplicated~~ — resolved by Story 15.7. Canonical location: `HyzerKit/Tests/TestSupport/`.
- `RoundRecord.toCKRecord()` writes `record["playerIDs"] = []` when the array is empty — CloudKit's serialization of empty list fields is platform-dependent and may drop the key. The PII round-trip test only covers a non-empty `playerIDs` fixture. Add an empty-array round-trip fixture in a future story (or skip assignment when empty).
- Two near-simultaneous "round started" notifications can race on `AppServices.pendingDeepLink` — the second tap overwrites the first before HomeView's `.onChange` consumes it. Rare-coincidence edge case (two organizers creating overlapping rounds within the same APNs delivery window); deferred.
- `organizerFirstName` / `courseName` empty-string payloads from upstream not defensively guarded in `LiveNotificationService.parseRoundStartedPayload` or `RoundRecord.init?(from:)`. Per CLAUDE.md "No Defensive Coding for Impossible Cases" — Player.displayName is required non-empty at onboarding (FR1) — but a future invariant change could surface this.
- `SyncEngine.fetchAllMetadata()` is bounded at `fetchLimit = 1000`; concurrent `pushRound` against an over-1000-row metadata table could race the duplicate-detect predicate. Pre-existing pattern across SyncEngine; deferred to a broader pagination pass.
- AC #4 deep-link routes to the first active round by `Round.startedAt` (via ScoringTabView's `@Query` first match), not specifically to `payload.roundID`. Functional when at most one round is active (the dominant case); edge case is two concurrent active rounds where the tapped notification's round is not the first. Deferred.
- UserDefaults idempotency key for the Round subscription is `"HyzerApp.subscriptionID.Round"` (keyed by `RoundRecord.recordType`) while the subscription ID value is `"Round-active-creation"`. Works for Story 12.1 but will collide once Story 12.2 adds a second Round subscription (e.g., `"Round-complete-update"`). Story 12.2 should re-key by full subscription ID.

## Deferred from: code review of 12-2-round-complete-push-notification (2026-05-17)

- `pushRoundCompletion` actor reentrancy: `await` releases actor isolation; concurrent calls could race `.inFlight` writes. Same pattern in `pushRound` (Story 12.1); needs broader fix across both push paths.
- All-offline scenario: first push of a never-pushed round as `status == "completed"` lands as a CREATE on CK; `Round-complete-update` subscription (`firesOnRecordUpdate`) will not fire. Documented in story spec lines 317 and 465 as accepted limitation.
- `serverRecordChanged` catch in `pushRoundCompletion` may mask a real conflict where another device pushed a different winner (tie-break diverged across locales). Pattern lifted as-is from 12.1; reconciliation out of scope.
- `organizerFirstName` becomes empty string if organizer's `Player` is missing — same pattern as 12.1 (already noted earlier in this file).
- Hardcoded "Loading summary…" and "Unknown Course" strings in `RoundCompletionSummaryHost` are not localized. Per story spec ("Do NOT Implement"), localization beyond English is out of scope.
- `Task { await engine.pushRoundCompletion(...) }` in `handleRoundCompleted` is an unstructured fire-and-forget with no cancellation hook if the view disappears mid-push. Minor.
- `pendingSummaryRoundID` UX leak: if `pendingDeepLink` is re-delivered after `onDismiss`, the cover can re-present. Minor.
- Old UserDefaults key `"HyzerApp.subscriptionID.Round"` is never deleted post-upgrade — leaves stale data in defaults. Intentional per migration design.
- Migration test in `SyncSchedulerTests` does not simulate a `duplicate-subscription` error from CloudKit — `MockCloudKitClient` lacks that throw path. Test infra gap.
- `isShowingSummary` flag is not cleared deterministically after dismiss — theoretical duplicate `pushRoundCompletion` if `isRoundCompleted` flips false→true again. Track `hasPushedCompletionForRoundID` as future hardening.
- `SelfExclusionTests.test_completePayloadIsNotSubjectToSelfExclusionGate` is described as a compile-time regression guard but is implemented at runtime — would not actually fail if a future `shouldSuppressPresentation(for: RoundCompletePayload, ...)` overload were added.
- Migration test does not assert the old UserDefaults key is removed — there is no cleanup code by design, but the test does not document that absence.

## Deferred from: code review of 13-1-score-trend-visualization-per-player (2026-05-17)

- AC #3 on-device `<500ms` performance measurement — already noted in Completion Note #8. macOS x86 test runner measured ~0.84s for 250 rounds; device target requires on-iPhone measurement during Task 8.2/8.3 manual verification. AC #3 not claimed as fully satisfied until measured.
- No retry path after `PlayerTrendViewModel.errorMessage` is set — user stuck on "Unable to load trend." with no recovery action (`PlayerTrendViewModel.swift:64`). UX improvement; not a correctness bug.
- `TrendChartDescriptor.makeChartDescriptor()` uses `dateFormatter.string(from:)` keyed by `MMMd` template — two rounds completed the same calendar day produce duplicate `categoryOrder` keys; `AXCategoricalDataAxisDescriptor` behavior with duplicate keys is undefined. (`PlayerTrendView.swift:167-170`)
- `#Predicate { participantRoundIDs.contains($0.id) }` SwiftData translation may fall back to in-memory filtering with very large `participantRoundIDs` sets — combined with `fetchLimit = maxRounds` applied before the predicate, this could silently drop rounds. Verify on real device during Task 8.2/8.3.
- "Best" stat column always tinted `Color.scoreUnderPar` (green) even when best score is `+5` (positive over-par) — verbatim spec Task 3.6; product decision to revisit if user feedback flags it. (`PlayerTrendView.swift:123`)

## Deferred from: code review of 14-1-multipeerconnectivity-nearby-active-round-discovery (2026-05-18)

- ~~Duplicate `MockNearbyDiscoveryClient` files~~ — resolved by Story 15.7. Canonical location: `HyzerKit/Tests/TestSupport/`.
- Tests use `for _ in 0..<20 { await Task.yield() }` and `try? await Task.sleep(for: .milliseconds(20))` to wait for async pipeline propagation — CLAUDE.md known flaky-timing tech debt, authorized by Story 14.1 spec line 390. Needs deterministic-wait helper.
- `test_handleDiscoveredRound_throttleWindow_secondCallAfter30sTriggersAgain` missing — Story 14.1 spec Task 7.1 authorized deferral absent a controllable-clock seam on `AppServices`. Re-evaluate when `lastPullByRoundID` clock source is refactored to `ContinuousClock`.
- Round.playerIDs mid-game mutation does NOT re-advertise an updated TXT record — Story 14.1 spec line 514 explicitly out of scope; CloudKit subscription path (FR16b) handles late joiners. Re-evaluate if observed in field debugging.
- `AppServicesNearbyDiscoveryTests` asserts on `cloudKit.fetchCallCount` as a proxy for `syncEngine.pullRecords()` invocations — couples test to transitive `SyncEngine` impl. Replace with a direct hook on `AppServices.pullTrigger` (closure seam) in a follow-up.
- New tech-debt entries discovered during Story 14.1 implementation (mock duplication, flaky timing) were noted in Completion Notes but not appended to this file at PR time — retroactively captured above. Future stories: append in the same PR.

## Deferred from: code review of story-15.10 (2026-05-19)

- **CloudKit-side `"completed"` literal predicate (`HyzerKit/Sources/HyzerKit/Sync/SyncScheduler.swift:275`)** — `NSPredicate(format: "status == %@", "completed")` for the CKQuerySubscription on Round-status-completed. Same string-literal class as the SwiftData `#Predicate` sites this story closed, but a different domain (CloudKit subscriptions, not SwiftData queries). Trivially fixable to `RoundStatus.completed`. Defer to a sync-domain follow-up story; do not re-open Story 15.10 for this.
- **DTO-write `"completed"` literal (`HyzerKit/Sources/HyzerKit/Sync/SyncEngine+RoundCompletion.swift:78`)** — `RoundRecord(... status: "completed", ...)` is a value write, not a comparison, so strictly outside AC #3 scope. Trivial substitution to `RoundStatus.completed` would tighten the symbol coupling without changing behavior. Bundle with the SyncScheduler fix above.

## Deferred from: code review of story-15.9 (2026-05-19)

- `verboseScore(relativeToPar:)` is a free function in `HyzerKit/Sources/HyzerKit/Domain/Standing+Formatting.swift` rather than a static on `Standing`. Spec recommended the free-function form so this is "acceptable as-is", but a `Standing.verboseScore(relativeToPar:)` static would mirror the existing `Standing.formatScore(_:)` static for symmetry. Cosmetic.

_(2026-05-19: `HoleCardView.relativeToParPhrase` duplication promoted from Defer to Patch and resolved in PR #98 follow-up commit — removed from this list.)_

## Deferred from: code review of story-15.1 (2026-05-19)

- **No automated guard against future reversion of `aps-environment`** (`HyzerApp/App/HyzerApp.entitlements:19-20`). A future `project.yml` regeneration, a merge resolving against an old branch, or a copy-paste from a sample project could silently revert `aps-environment` from `production` back to `development`, and there is no test or CI guard that would catch it. Pre-existing pattern (Story 9.1 didn't add one either). Future tiny story: add a Swift Testing assertion that reads `HyzerApp/App/HyzerApp.entitlements` from disk and asserts `aps-environment = production` for Release-configuration builds. Gate with an env var so dev-simulator runs aren't affected.
- **APS production flip operational handoff (Tasks 3–7)** — archive build, ASC privacy declarations update, CloudKit container production switch, TestFlight regression upload, and push-delivery confirmation per the augmented Task 6.3. All five tasks require human ops with signing credentials and Apple-web-UI access; out of automation scope. See story `15-1-*.md` Tasks 3–7 for the canonical handoff checklist.
