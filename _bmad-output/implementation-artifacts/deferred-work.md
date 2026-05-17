## Deferred from: code review of 9-2-privacy-manifest-permission-strings-and-app-icons.md (2026-05-16)

- Pin `UIUserInterfaceStyle: Dark` in `project.yml info.properties` + `HyzerApp/App/Info.plist`. Reason for deferral: current behavior is acceptable until a later polish story. The universal `LaunchBackground.colorset` still wins for the launch screen in light-mode (the near-black launch is preserved); only the launch→first-frame trait-collection seam is fragile. Pick up in the next launch / first-frame polish pass.
- Run canonical `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'` against the 407-test baseline (AC7). Reason for deferral: current machine has no simulator. To be executed by the reviewer doing the AC4/AC5/AC6 visual verification on a Mac with the paired simulator, in the same session.
- Mirror privacy manifest declarations (`NSPrivacyCollectedDataTypeUserID` Linked + AppFunctionality, `NSPrivacyCollectedDataTypeAudioData` Not-Linked + AppFunctionality) in App Store Connect's Privacy section before TestFlight submission. Story 9.3 (`epics-post-mvp.md:208-234`) owns App Store Connect setup; manifest alone is necessary but not sufficient for App Review.
- `UISupportedInterfaceOrientations`, `UIBackgroundModes`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `ITSAppUsesNonExemptEncryption` are duplicated between `project.yml info.properties` and `HyzerApp/App/Info.plist`. XcodeGen merges them so it's not drift-prone in practice, but consolidating to a single source of truth (prefer `project.yml`) is a future-cleanup item.

## Deferred from: code review of 9-1-release-build-configuration-and-signing.md (2026-05-16)

- APS environment `aps-environment = development` in `HyzerApp/App/HyzerApp.entitlements:21` — App Store-bound Release archive carries dev APS env. Spec open question #1 parks this until Epic 12 flips it to `production`. Risk surfaces at Story 9.3 upload, not at 9.1 archive/export.
- Test targets inherit `DEVELOPMENT_TEAM` from `project.yml:20` global `settings.base` — harmless locally; signing unit-test bundles can fail on a CI agent without the team's Apple ID. Revisit when CI is introduced (Epic 13 / future story).

## Deferred from: code review of 11-3-share-round-summary-via-system-share-sheet.md (2026-05-14)

- Hardcoded English Strings (Localization Risk) in `RoundSummaryViewModel.swift` — The share caption is built using hardcoded string literals. This follows existing project patterns but should be addressed when localization is prioritized.

## Deferred from: code review of 9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md (2026-05-17)

- Stale retro entry — `_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md:97` still lists `ColorTokens.border` as open debt despite Story 9.3 resolving it. Retros are historical snapshots; needs explicit "frozen artifact" policy or a one-line "Resolved by 9.3" annotation, decided out-of-band.
- Stale epic narrative — `_bmad-output/planning-artifacts/epics-post-mvp.md:81, 120, 156` still describes `ColorTokens.border` as an open blocker. Planning artifacts are typically frozen at sign-off; surface for explicit policy decision.

## Deferred from: code review of 12-1-notification-foundation-and-round-started-push.md (2026-05-17)

- `Player` schema has no `firstName` field — `displayName.split(...).first` is best-effort for compound names ("O'Brien" returns full name; "M. Smith" returns "M."). Story 12.1 follows spec Task 5.6 exactly; a future story should introduce an explicit `firstName` on `Player`.
- `MockNotificationService` duplicated across `HyzerAppTests/Mocks/` and `HyzerKit/Tests/HyzerKitTests/Mocks/` — same class name, near-identical shape. Matches the `ValueCollector` shared-test-helper debt called out in CLAUDE.md "Known Technical Debt". Pick up alongside the `ValueCollector` extraction into a shared `TestSupport` SPM target.
- `RoundRecord.toCKRecord()` writes `record["playerIDs"] = []` when the array is empty — CloudKit's serialization of empty list fields is platform-dependent and may drop the key. The PII round-trip test only covers a non-empty `playerIDs` fixture. Add an empty-array round-trip fixture in a future story (or skip assignment when empty).
- Two near-simultaneous "round started" notifications can race on `AppServices.pendingDeepLink` — the second tap overwrites the first before HomeView's `.onChange` consumes it. Rare-coincidence edge case (two organizers creating overlapping rounds within the same APNs delivery window); deferred.
- `organizerFirstName` / `courseName` empty-string payloads from upstream not defensively guarded in `LiveNotificationService.parseRoundStartedPayload` or `RoundRecord.init?(from:)`. Per CLAUDE.md "No Defensive Coding for Impossible Cases" — Player.displayName is required non-empty at onboarding (FR1) — but a future invariant change could surface this.
- `SyncEngine.fetchAllMetadata()` is bounded at `fetchLimit = 1000`; concurrent `pushRound` against an over-1000-row metadata table could race the duplicate-detect predicate. Pre-existing pattern across SyncEngine; deferred to a broader pagination pass.
- AC #4 deep-link routes to the first active round by `Round.startedAt` (via ScoringTabView's `@Query` first match), not specifically to `payload.roundID`. Functional when at most one round is active (the dominant case); edge case is two concurrent active rounds where the tapped notification's round is not the first. Deferred.
- UserDefaults idempotency key for the Round subscription is `"HyzerApp.subscriptionID.Round"` (keyed by `RoundRecord.recordType`) while the subscription ID value is `"Round-active-creation"`. Works for Story 12.1 but will collide once Story 12.2 adds a second Round subscription (e.g., `"Round-complete-update"`). Story 12.2 should re-key by full subscription ID.
