# Story 15.1: APS Environment Production Flip & App Store Connect Privacy Mirror

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer preparing to submit hyzer-app for App Store distribution beyond TestFlight,
I want the production APS environment configured on the App Store-bound entitlements and the App Store Connect Privacy section to mirror the in-bundle `PrivacyInfo.xcprivacy` declarations,
So that the first App Store submission does not get rejected for an entitlement/manifest mismatch or for an undeclared privacy data type.

## Acceptance Criteria

1. **Given** `HyzerApp/App/HyzerApp.entitlements` is opened, **when** the `aps-environment` key is read, **then** the value is `production` (Story 9.1 deferral; Epic 12 push delivery is now done and the entitlement flip is no longer blocked by missing push infrastructure). The watchOS entitlement file (`HyzerWatch/Resources/HyzerWatch.entitlements`) — if it carries an `aps-environment` key — flips identically. Verified by `plutil -p HyzerApp/App/HyzerApp.entitlements` showing `"aps-environment" => "production"`.

2. **Given** the entitlement flip is committed, **when** a fresh Release archive is produced from the resulting branch via the canonical Story 9.1 command (`xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive`), **then** the archive succeeds without manual signing prompts and the embedded `HyzerApp.app/HyzerApp.entitlements` (extracted via `codesign -d --entitlements - build/HyzerApp.xcarchive/Products/Applications/HyzerApp.app`) carries `aps-environment = production`.

3. **Given** App Store Connect's App Privacy section is opened for `com.shotcowboystyle.hyzerapp`, **when** the declared data types are compared against `HyzerApp/App/PrivacyInfo.xcprivacy`, **then** the two are intent-identical: `NSPrivacyCollectedDataTypeUserID` is declared as `User ID` (Linked to user, Not used for tracking, purpose `App Functionality`), and `NSPrivacyCollectedDataTypeAudioData` is declared as `Audio Data` (Not Linked to user, Not used for tracking, purpose `App Functionality`). No extra categories, no missing categories (Story 9.2 deferral). Evidence: screenshot of the completed questionnaire saved at `_bmad-output/implementation-artifacts/15-1-evidence/asc-app-privacy.png` (gitignored per the `*-evidence/` glob established in Story 9.3 Task 6.2).

4. **Given** CloudKit Dashboard is opened for container `iCloud.com.shotcowboystyle.hyzerapp`, **when** the schema deployment state is inspected, **then** the Development environment schema has been deployed to Production via the "Deploy Schema Changes" action (Story 9.3 Open-Questions operational flag: "If the schema is not deployed to Production, the testers' rounds will not sync — they will install the app successfully but Epic 4 sync will silently fail."). Evidence: screenshot of the Production environment's record-type list matching Development saved at `_bmad-output/implementation-artifacts/15-1-evidence/cloudkit-production-schema.png`.

5. **Given** the entitlement-flipped Release archive is uploaded to App Store Connect via the same Transporter.app / `xcrun altool` path established in Story 9.3 Task 5.1, **when** App Store Connect processes the build, **then** processing completes without "Missing Compliance" / "Invalid Provisioning Profile" / entitlement-mismatch warnings, and the build appears in the TestFlight Builds list as `Ready to Test` within ~30 minutes. The existing `Friends Beta` test group continues to install the new build successfully (regression check that the production APS flip did not break the TestFlight install path).

6. **Given** the canonical regression suite (`swift test --package-path HyzerKit` and the Story 15.2 simulator gate if available) is re-run after the entitlement flip, **when** the suite completes, **then** the count matches the Story 15.2 reconciled baseline and SwiftLint emits zero warnings — the entitlement flip is a `.entitlements` text edit only, with no Swift-source surface area.

## Tasks / Subtasks

- [x] **Task 1: Verify pre-state of `aps-environment`** (AC: 1)
  - [x] 1.1 Read `HyzerApp/App/HyzerApp.entitlements`. Confirm the current value of the `aps-environment` key is `development` (as documented in `deferred-work.md` for Story 9.1 deferral). If the value is anything else (`production`, missing, malformed), **STOP and surface to the user** — a prior story may have already flipped it.
  - [x] 1.2 Read `HyzerWatch/Resources/HyzerWatch.entitlements`. If an `aps-environment` key exists, confirm its value. If it carries `development`, it MUST be flipped to `production` in Task 2. If the file has no `aps-environment` key, do NOT add one — the watchOS app does not receive direct APNs in this codebase (Watch receives leaderboard updates via `WatchConnectivity`, not APNs — per `CLAUDE.md` "Sync Architecture" section).
  - [x] 1.3 Run `git log -p HyzerApp/App/HyzerApp.entitlements | head -100` and confirm the last edit to this file was Story 9.1's initial signing setup. If a later commit touched the file, read the commit message before proceeding.

- [x] **Task 2: Flip `aps-environment` to `production`** (AC: 1)
  - [x] 2.1 Edit `HyzerApp/App/HyzerApp.entitlements`: change `<string>development</string>` to `<string>production</string>` under the `aps-environment` key. The surrounding `<key>aps-environment</key>` line is unchanged. No other keys in the file are touched.
  - [x] 2.2 If `HyzerWatch/Resources/HyzerWatch.entitlements` carries an `aps-environment` key (per Task 1.2), apply the same flip. Otherwise skip 2.2.
  - [x] 2.3 Verify via `plutil -p HyzerApp/App/HyzerApp.entitlements` that the resulting plist is valid and the key now reads `production`. If `plutil` reports a parse error, the edit malformed the XML — revert and re-edit.

- [x] **Task 3: Re-produce the Release archive against the flipped entitlements** (AC: 2)
  - [x] 3.1 On the branch `feature/15-1-aps-production-and-asc-privacy` (per CLAUDE.md "Git Workflow"), run the canonical Story 9.1 archive command verbatim: `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive`. Expect `** ARCHIVE SUCCEEDED **`. If signing prompts appear, surface to the user — Story 9.1 verified zero-prompt archive flow; any prompt is a regression.
  - [x] 3.2 Verify the embedded entitlement was flipped end-to-end: `codesign -d --entitlements - build/HyzerApp.xcarchive/Products/Applications/HyzerApp.app 2>&1 | grep -A1 aps-environment` — expected output includes `<string>production</string>`. If it still shows `development`, the Release configuration is pulling from a different entitlements file (`project.yml` is the only authority that XcodeGen respects); re-check `project.yml` entitlements references.

- [x] **Task 4: Mirror the App Privacy questionnaire in App Store Connect** (AC: 3)
  - [x] 4.1 **Manual step (cannot be automated from Claude Code):** Log in to `https://appstoreconnect.apple.com` with the Apple ID for team `S4729REPN5`. Navigate to Apps → `hyzer` (the record created in Story 9.3) → App Privacy.
  - [x] 4.2 Confirm the existing questionnaire from Story 9.3 Task 3.5 already matches `HyzerApp/App/PrivacyInfo.xcprivacy`. If the prior story closed correctly, this step is a no-op verification. If discrepancies surface (e.g., a category drift caused by an Apple-side questionnaire schema change post-9.3), reconcile to match the manifest verbatim — `User ID` Linked / non-tracking / AppFunctionality, `Audio Data` Not-Linked / non-tracking / AppFunctionality.
  - [x] 4.3 Save a fresh screenshot of the completed questionnaire to `_bmad-output/implementation-artifacts/15-1-evidence/asc-app-privacy.png` (create the directory; `.gitignore` already covers the `*-evidence/` glob).

- [x] **Task 5: Deploy CloudKit schema to Production** (AC: 4)
  - [x] 5.1 **Manual step:** Log in to the CloudKit Dashboard (`https://icloud.developer.apple.com/dashboard/`) for container `iCloud.com.shotcowboystyle.hyzerapp`. Open the Schema tab.
  - [x] 5.2 Compare the Development schema (record types: `RoundRecord`, `PlayerRecord`, `CourseRecord`, `DiscrepancyRecord`, `ScoreEventRecord`, `SyncMetadata` per `architecture.md` data layer documentation) against the Production schema. If the two match, deployment is already done — skip 5.3.
  - [x] 5.3 If Production is missing record types or fields, click "Deploy Schema Changes" — Apple's one-click promote-Development-to-Production operation. Confirm in the dialog. Wait for the deployment to complete (typically <1 minute; UI shows a green confirmation banner).
  - [x] 5.4 Save a screenshot of the Production schema list matching Development to `_bmad-output/implementation-artifacts/15-1-evidence/cloudkit-production-schema.png`.

- [x] **Task 6: Upload the production-APS archive to App Store Connect for regression check** (AC: 5)
  - [x] 6.1 Export the archive from Task 3 to IPA using the Story 9.3 Task 5.1 method (Transporter.app preferred). The `ExportOptions.plist` from Story 9.1 Task 5.3 is reused without modification — `method = app-store-connect` is unchanged by this story.
  - [x] 6.2 Upload the IPA. Wait for the App Store Connect processing transition from "Processing" to "Ready to Test" (~30 minutes per Story 9.3 dev notes). If a rejection email arrives, the most likely cause is entitlement-mismatch with the provisioning profile — surface the exact rejection text to the user; do NOT auto-revert.
  - [x] 6.3 Once `Ready to Test`, assign the build to the `Friends Beta` Internal Test Group (existing group from Story 9.3 Task 5.4). Notify the user that a new build is live; recommend one tester install to confirm the production-APS flip did not break the install path. **Push-delivery confirmation (code-review follow-up 2026-05-19):** the install-only check is insufficient — APNs device tokens are scoped to the APS environment that issued them, so any cached `development`-APS tokens on testers' devices are now invalid against `api.push.apple.com`. Capture one round-started OR round-complete push delivery from the new production-APS build (per Epic 12 push semantics) as Task 6.3 evidence before marking the story closed.
  - [x] 6.4 If a tester reports install failure or the build does not install, capture the error verbatim and surface — do NOT patch the entitlement until the failure mode is understood (Apple sometimes lags propagating production-APS provisioning profile updates; a 24-hour wait may resolve transient issues).

- [x] **Task 7: Regression sweep and story closeout** (AC: 6)
  - [x] 7.1 Run `swift test --package-path HyzerKit` and confirm the count equals the Story 15.2 reconciled baseline. The entitlement file is not exercised by any Swift test, so the count must be identical.
  - [x] 7.2 If a simulator is available, run the canonical `xcodebuild test ...` and confirm the same count.
  - [x] 7.3 Stage and commit: `chore(release): flip aps-environment to production and verify asc privacy mirror`. Commit body should reference Story 9.1 / 9.2 / 9.3 deferrals being closed.
  - [x] 7.4 Update `_bmad-output/implementation-artifacts/deferred-work.md`: remove the three resolved bullets (Story 9.1 APS environment, Story 9.2 ASC Privacy mirror, Story 9.3 CloudKit schema operational flag). Leave the remaining Story 9.2 entries (`UIUserInterfaceStyle` pin, Info.plist consolidation) — those are owned by Story 15.5.

## Dev Notes

### Why this story exists

Three pre-existing deferrals from Stories 9.1, 9.2, and 9.3 all share a common gate: they cannot land until Epic 12 (Push Notifications) is in production. Epic 12 closed 2026-05-17 with Stories 12.1–12.3 all `done`. The production-APS flip and its sibling ASC-privacy mirror are now unblocked; this story closes all three deferrals in a single PR.

The CloudKit schema deployment is technically a Story 9.3 operational flag, not a strict acceptance criterion. It is bundled here because (a) it is a single CloudKit Dashboard click, (b) it shares the same "manual operational step on apple.com" pattern as the App Privacy mirror, and (c) if it is forgotten, expanded TestFlight or App Store distribution will surface the issue as "rounds don't sync for new testers" — a low-signal, high-confusion failure mode best avoided.

### Current state — what is already correct (do NOT redo)

- **Story 9.1 produced a working Release archive** with correct signing identity and provisioning profile. Story 15.1 reuses that archive flow verbatim — no `project.yml` changes, no signing changes.
- **Story 9.2 fully populated `PrivacyInfo.xcprivacy`** with `NSPrivacyCollectedDataTypeUserID` and `NSPrivacyCollectedDataTypeAudioData` declarations matching the App Privacy questionnaire spec. The in-bundle manifest is the source of truth; Task 4 reconciles the App Store Connect questionnaire to match.
- **Story 9.3 created the App Store Connect record and the `Friends Beta` Internal Test Group.** Both already exist; this story reuses both — no new record, no new group.
- **Story 9.3 Task 5.2 dev note documents the parking lot:** "If a related warning appears [for `aps-environment = development`], do not patch entitlements in this story even if a related warning appears; that is Epic 12's territory (per Story 9.1 dev notes)." This story is the explicit follow-up to that parking lot.
- **`build/` is already gitignored.** No new gitignore work needed for the archive output.
- **The `*-evidence/` glob is already gitignored** (Story 9.3 Task 6.2). Creating `15-1-evidence/` requires only `mkdir` — no additional gitignore edit.

### Architecture compliance

- **CLAUDE.md "No silent `try?`":** This story touches no Swift source. Inapplicable.
- **CLAUDE.md "Bounded SwiftData queries":** Inapplicable; no SwiftData edits.
- **CLAUDE.md "Accessibility first":** Inapplicable; no UI.
- **CLAUDE.md "Design tokens only":** Inapplicable; no UI.
- **CLAUDE.md "Git Workflow":** Work on `feature/15-1-aps-production-and-asc-privacy`. Conventional Commits: `chore(release): flip aps-environment to production and verify asc privacy mirror`.
- **Architecture §Constraints (`architecture.md:115`):** "TestFlight distribution, 6 users. No App Store review." This story preserves that constraint for the existing TestFlight scope while preparing for the optional future App Store submission — the flip itself is preparation, not commitment.
- **Architecture §Infrastructure & Development (`architecture.md:392-398`):** Error reporting is intentionally Xcode Organizer + `os_log` only. Do NOT add crash reporters or analytics SDKs even if App Store Connect's onboarding suggests them.

### Library / framework requirements

- **No new Swift package dependencies.** All work is in `.entitlements` text, App Store Connect web UI, and CloudKit Dashboard web UI.
- **No new framework imports.** APNs production environment uses the same `aps-environment` entitlement key, just with a different value — no SDK or `import` changes.

### File-structure requirements

```
HyzerApp/App/HyzerApp.entitlements                                       [EDIT — Task 2.1]
HyzerWatch/Resources/HyzerWatch.entitlements                             [EDIT — Task 2.2 only if aps-environment exists; otherwise no change]
_bmad-output/implementation-artifacts/15-1-evidence/asc-app-privacy.png          [LOCAL ONLY — Task 4.3]
_bmad-output/implementation-artifacts/15-1-evidence/cloudkit-production-schema.png  [LOCAL ONLY — Task 5.4]
build/HyzerApp.xcarchive, build/Export/HyzerApp.ipa                      [LOCAL ONLY — Task 3, gitignored]
_bmad-output/implementation-artifacts/deferred-work.md                   [EDIT — Task 7.4, remove resolved bullets]
```

Files that must NOT appear in the final diff:
- `project.yml`, `HyzerApp.xcodeproj/project.pbxproj` (no build config / signing changes; only the entitlements file is edited)
- `HyzerApp/App/Info.plist`, `HyzerApp/App/PrivacyInfo.xcprivacy`, `HyzerWatch/Resources/PrivacyInfo.xcprivacy` (Story 9.2 owns these; App Privacy questionnaire is on apple.com)
- Any Swift source file
- Any test file
- Any tester Apple ID, email, or PII

### Testing requirements

- **No unit-test additions.** Per CLAUDE.md "Bug Fixes Require Tests" — this is not a bug fix; it is an operational entitlement flip. No test target loads or executes the `.entitlements` file.
- **Automated regression check (AC #6):** `swift test --package-path HyzerKit` after Task 2 — same count as Story 15.2 reconciled baseline. All green.
- **Simulator regression:** `xcodebuild test ...` if simulator available. If not, defer to a reviewer (consistent with Stories 9.1, 9.2, 9.3, 14.1, 14.2).
- **Manual verification (ACs #1, #3, #4, #5):** Evidence captured via screenshots in the gitignored evidence directory + Completion Notes confirming the tester install path.

### Previous-story intelligence

**Story 9.1 (Release Build Configuration & Signing — done):**
- Archive command verbatim. ExportOptions.plist template at `build/ExportOptions.plist` is gitignored; recreate from Story 9.1 Task 5.3 if missing.
- The 9.1 dev agent confirmed `aps-environment = development` was intentional at archive time and parked the flip to Epic 12. That parking lot is now expiring.

**Story 9.2 (Privacy Manifest, Permission Strings & App Icons — done):**
- `HyzerApp/App/PrivacyInfo.xcprivacy` is the source of truth for the App Privacy questionnaire. The two MUST match — Apple actively rejects submissions where they diverge as of 2025.
- Story 9.2 Task 5 explicitly deferred the App Store Connect privacy mirror "before TestFlight submission" — that gate is now Task 4 of this story.

**Story 9.3 (App Store Connect Record, TestFlight Test Group & Border Token Debt — done):**
- The `Friends Beta` Internal Test Group exists at App Store Connect. Reuse it for the regression-install in Task 6.3.
- The evidence directory pattern (`_bmad-output/implementation-artifacts/<n>-<m>-evidence/`) is established; `.gitignore` already has the glob.
- The "Open Questions — pre-answered" pattern for operational stories applies here. Anything that requires a user-decision should be elicited in Task 1 BEFORE work begins; this story has none — both the production flip and the questionnaire mirror are pre-determined by Stories 9.1/9.2 ACs.
- Story 9.3 dev note flagged: "If the schema is not deployed to Production, the testers' rounds will not sync." This is Task 5 of this story.

**Epic 12 (Push Notifications — done, 2026-05-17):**
- Stories 12.1, 12.2, 12.3 all closed. The push pipeline is live in `development` APS environment for the `Friends Beta` group. Flipping to `production` does not change the push delivery semantics — Apple routes the build's APS environment to the matching APNs gateway (`api.development.push.apple.com` vs. `api.push.apple.com`) based on the entitlement value.

### Latest tech information (2026-05-16)

- **`aps-environment = production` and TestFlight.** TestFlight builds with `production` APS environment work without restriction — Apple routes pushes through the production APNs gateway and the dev's CloudKit-triggered notifications fire identically.
- **`aps-environment = development` and App Store submission.** The inverse is the rejection-causing direction — App Store-bound builds with `development` APS are rejected at submission with a clear error message ("Invalid Provisioning Profile" or "Push notification entitlement does not match"). This story removes that rejection cause.
- **CloudKit schema Production deployment** is an idempotent one-click action in the CloudKit Dashboard — no rollback risk; if rerun on an already-deployed Production schema, the dashboard reports "no changes to deploy."
- **App Privacy questionnaire** is owned by Apple; field names may drift year-over-year. Substance is fixed: the two data types from `PrivacyInfo.xcprivacy` with the same Linked/Tracking/Purpose triples.

### Open questions — pre-answered at story-creation time

All operational choices in this story are derived from prior stories' ACs or from Apple-side requirements; no user elicitation is needed before work begins. The dev agent proceeds directly.

**Pre-answered:**
- APS environment value → `production` (per Story 9.1 deferral)
- App Privacy questionnaire data types → mirror `PrivacyInfo.xcprivacy` verbatim (per Story 9.2 deferral)
- CloudKit schema deployment → deploy Production to match Development (per Story 9.3 operational flag)
- Test group for the regression install → existing `Friends Beta` (per Story 9.3)
- Upload tool → Transporter.app default (per Story 9.3 Task 5.1)

### Project Structure Notes

This story's committed footprint is intentionally tiny — a single XML edit to one or two `.entitlements` files plus a `deferred-work.md` cleanup. The bulk of the work is on apple.com (App Store Connect privacy, CloudKit Dashboard) and is evidenced via gitignored screenshots. Acceptance is documented via screenshots + Completion Notes, not by file diffs.

### References

- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:48-50` — Story 9.1 APS environment deferral text]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:43-46` — Story 9.2 ASC privacy mirror + Info.plist consolidation deferrals]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md:211` — Story 9.3 CloudKit Production schema operational flag]
- [Source: `_bmad-output/implementation-artifacts/9-1-release-build-configuration-and-signing.md` — Archive command, ExportOptions.plist, signing setup]
- [Source: `_bmad-output/implementation-artifacts/9-2-privacy-manifest-permission-strings-and-app-icons.md` — Privacy manifest declarations]
- [Source: `_bmad-output/implementation-artifacts/9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md` — App Store Connect record, Friends Beta group, evidence directory pattern]
- [Source: `HyzerApp/App/HyzerApp.entitlements:19-20` — current `aps-environment = development` value]
- [Source: `HyzerApp/App/PrivacyInfo.xcprivacy` — source of truth for App Privacy questionnaire]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md#Epic-15` — this epic's overview and story listing]
- [Source: `CLAUDE.md` "Project Status" — current state confirmation]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None.

### Completion Notes List

1. **Tasks 1-2 complete (automatable):** Verified `aps-environment = development` pre-state, confirmed HyzerWatch.entitlements has no `aps-environment` key (no flip needed), flipped HyzerApp.entitlements to `production`. Validated via `plutil`. deferred-work.md cleaned of two resolved bullets (9.1 APS env, 9.2 ASC privacy mirror).
2. **Tasks 3-7 require manual steps:** Release archive (Task 3) requires signing credentials; Tasks 4-6 require App Store Connect and CloudKit Dashboard web UI access. Task 7.1 (swift test) passes at 413 tests, 1 known flake.
3. **Regression (Task 7.1):** `swift test --package-path HyzerKit` → 413 tests, 1 issue (known WatchVoiceViewModel auto-commit timer flake, CLAUDE.md Known Technical Debt).

### File List

- `HyzerApp/App/HyzerApp.entitlements` — flipped `aps-environment`: development → production
- `_bmad-output/implementation-artifacts/deferred-work.md` — removed 2 resolved bullets (Story 9.1 APS env, Story 9.2 ASC privacy mirror)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — Story 15.1 status: ready-for-dev → in-progress

### Change Log

- 2026-05-18: Tasks 1-2 implemented by claude-sonnet-4-6. Tasks 3-7 deferred to human (require App Store Connect and signing credentials).
- 2026-05-19: Code review applied. No code-patch findings; 4 defers migrated to deferred-work.md, 1 dismissed. Augmented Task 6.3 with explicit push-delivery confirmation requirement. Task 7.4 doc-drift note added to Completion Notes.
- 2026-05-19: Sprint-status convention decision resolved. Introduced new status `blocked-on-human-ops` (sprint-status.yaml STATUS DEFINITIONS); flipped 15.1's status from `in-progress` → `blocked-on-human-ops` in both sprint-status.yaml and this story file's H1.
- 2026-05-19: Story closed. Human owner verified Tasks 3–7: Release archive re-produced (build 2; CURRENT_PROJECT_VERSION bump landed via PR #107); ASC App Privacy questionnaire mirror confirmed; CloudKit Production schema deployed; production-APS build uploaded via Transporter and assigned to `Friends Beta` Internal Test Group; push-delivery confirmation captured per Task 6.3 augmented requirement (code-review follow-up); regression sweep complete. Evidence screenshots saved under `_bmad-output/implementation-artifacts/15-1-evidence/` (gitignored per `*-evidence/` glob). Status: `blocked-on-human-ops` → `done` in both sprint-status.yaml and this story file's H1.

### Completion Notes (post-review)

- **Task 7.4 doc-drift note:** Task 7.4 instructed removal of "three resolved bullets (Story 9.1 APS environment, Story 9.2 ASC Privacy mirror, Story 9.3 CloudKit schema operational flag)." The dev agent removed the two bullets that actually existed in `deferred-work.md`. The Story 9.3 "CloudKit Production schema deployment" operational flag was never landed in `deferred-work.md` — it lives in the Story 9.3 dev-notes / Open Questions section. The spec citation `deferred-work.md:211` in the References block is stale; the file is 103 lines on `main` at the time of this story. No further action; the diff matches the actual file state.

## Review Findings

Source: `_bmad-output/implementation-artifacts/review-15-1-findings.md` (code-reviewer subagent, 2026-05-18). Verdict: 🟡 patch-and-ship. Triage: 0 patch, 1 decision-needed, 4 defer, 1 dismissed.

- [x] [Review][Decision] Sprint-status convention for partly-manual ops stories — **Resolved 2026-05-19**: introduced new status `blocked-on-human-ops` for stories where the automatable portion is complete but remaining tasks require signing creds / Apple-web-UI access / Transporter. Documented in `sprint-status.yaml` STATUS DEFINITIONS comment block; Story 15.1 status flipped from `in-progress` → `blocked-on-human-ops`; story file H1 status line updated to match. Stories in this state are NOT eligible for dev-agent pickup. The convention will be reused by future operational stories.
- [x] [Review][Defer] Spec Task 7.4 references a third deferral bullet that does not exist in `deferred-work.md` — captured in Completion Notes (post-review) above. No further action.
- [x] [Review][Defer] Spec Task 7.3 canonical commit message convention — applies only when the human closes out Tasks 3–7. Documented for closeout awareness; out of scope for this automated portion.
- [x] [Review][Defer][Augmented] Once-merged, APS production flip invalidates cached development device tokens — augmented Task 6.3 evidence requirement (above) to include one round-started or round-complete push delivery confirmation from the new production-APS build before closing the story.
- [x] [Review][Defer] No automated guard against future reversion of `aps-environment` — migrated to `deferred-work.md` for capture as a future tiny story (a CI assertion that reads the entitlements file and confirms `aps-environment = production` for Release-configuration builds).
- (Dismissed) Watch entitlements no-op — `HyzerWatch/Resources/HyzerWatch.entitlements` does not exist; spec Task 1.2 / 2.2 correctly skipped.
