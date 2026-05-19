# Story 9.3: App Store Connect Record, TestFlight Test Group & Border Token Debt

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a beta tester in the six-friend group,
I want to receive a TestFlight invitation and install hyzer-app on my iPhone (and paired Apple Watch),
so that I can play a real round on real hardware before the developer ships further changes.

## Acceptance Criteria

1. **AC1 — App Store Connect record exists for the iOS+watchOS bundle pair (PMVP-FR5).** Given the developer logs in to App Store Connect with the Apple ID associated with team `S4729REPN5`, when the "Apps" list is inspected, then an app record exists with primary bundle identifier `com.shotcowboystyle.hyzerapp`, the `com.shotcowboystyle.hyzerapp.watchkitapp` watch bundle is auto-detected by App Store Connect after archive upload (it is not configured separately — it is embedded in the iOS app record), the app's "Name" is `hyzer` (or `Hyzer` — case is App Store Connect's display convention), primary category is `Sports`, secondary category is `Health & Fitness` (developer-recommended; `Lifestyle` is acceptable), the bundle's SKU is `com.shotcowboystyle.hyzerapp` (or a developer-chosen identifier), and "User Access" defaults to "Full Access". Evidence: a screenshot of the "App Information" page in App Store Connect saved at `_bmad-output/implementation-artifacts/9-3-evidence/asc-app-information.png` (gitignored under `_bmad-output/implementation-artifacts/9-3-evidence/` — see Task 6).

2. **AC2 — Mandatory App Information fields are populated for TestFlight eligibility.** Given the App Store Connect record from AC1, when the "App Information" and "Pricing and Availability" sections are inspected, then `Privacy Policy URL` is set (developer-owned URL or a placeholder pointing at the project README — App Store Connect accepts any reachable HTTPS URL for TestFlight; full review is not required), `Support URL` is set to a placeholder (developer-chosen — recommend `https://github.com/shotcowboystyle/hyzer-app` or a personal page), `Marketing URL` is left blank (optional), pricing is set to `Free`, and territory availability is set to `United States` only (the six testers' region — expand later if needed). Privacy questionnaire ("App Privacy" section) must reflect what `PrivacyInfo.xcprivacy` already declares (Story 9.2 AC2): `User ID` linked to user / not used for tracking / purpose `App Functionality`, and `Audio Data` not linked / not tracking / purpose `App Functionality`. No additional data categories selected.

3. **AC3 — First Release archive uploaded and processed to "Ready to Submit"/"Ready to Test" state (PMVP-FR5).** Given a fresh Release archive produced by re-running the Story 9.1 archive command (`xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive`), when the archive is exported (`xcodebuild -exportArchive` with `method=app-store-connect`) and uploaded via either Transporter.app or `xcrun altool --upload-app`, then App Store Connect's TestFlight tab shows the build at version `0.1.0 (1)` (matching `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from Story 9.1), the build's processing state transitions from "Processing" to "Ready to Submit" (typically 10–30 minutes), and any "Missing Compliance" prompt is dismissed by toggling `ITSAppUsesNonExemptEncryption` confirmation (already declared `false` in `project.yml:46` per Story 9.1, so the prompt should not appear; if it does, this is an inconsistency to surface to the user). Evidence: a screenshot of the TestFlight "Builds" page showing the processed build saved at `_bmad-output/implementation-artifacts/9-3-evidence/asc-testflight-build-processed.png`.

4. **AC4 — Internal test group contains the six tester Apple IDs and has the processed build assigned.** Given the processed build from AC3 and the user-supplied list of six tester Apple IDs (see "Open Questions" — the dev agent **MUST** elicit this list from the user before completing this task — do not guess or use placeholders), when an Internal Test Group named `Friends Beta` (or developer-chosen name) is created in the TestFlight tab, then the six Apple IDs are added as Internal Testers (preferred — Internal does not require Beta App Review and grants 90-day install access), the AC3 processed build is assigned to the group, and each tester appears in the group's roster with a status of "Invited" (pre-acceptance) or "Accepted" (post-acceptance). If any Apple ID cannot be added as Internal (e.g., the Apple ID is not associated with team `S4729REPN5` as a user) and Internal-only configuration is not feasible, fall back to External Testers; **disclose to the user before falling back** because External requires a one-time Beta App Review per build (≈24 hour delay). Evidence: screenshot of the test group roster saved at `_bmad-output/implementation-artifacts/9-3-evidence/asc-test-group-roster.png`.

5. **AC5 — At least one tester accepts the invite, installs via the TestFlight app, and the iOS app launches to onboarding with the Watch app installable.** Given the invitation flow from AC4, when one tester (or the developer using a secondary Apple ID, if testers are unavailable at story-completion time) accepts the email/SMS invitation and opens the TestFlight link, then the TestFlight app on iOS prompts to install `Hyzer`, installation succeeds, the iOS app launches to the Story 1.1 onboarding screen (display-name capture) without crashing, and the Watch app appears in the iPhone's "Watch" app under "Available Apps" and can be installed to the paired Apple Watch. Evidence: a written note in Completion Notes from the installing tester (or developer) confirming the launch + watch-install path; no screenshots required.

6. **AC6 — `ColorTokens.border` tech debt is resolved and CLAUDE.md is reconciled with the codebase.** Given the existing state (`Color.border = Color.hairline` is **defined** at `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51` but **zero references** exist in the codebase as confirmed by `grep -rn "ColorTokens\.border\|Color\.border\b" HyzerApp HyzerWatch HyzerKit`, and CLAUDE.md:120 incorrectly claims the token is "referenced but never defined"), when this story is complete, then **one** of the three resolution paths below is in place (per the user's selection — see Task 4 and Open Question #3), each token reference in the codebase resolves correctly, the canonical test command (`xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'`) still passes (407 tests — see CLAUDE.md "Project Status" baseline), and CLAUDE.md's "Known Technical Debt" entry for `ColorTokens.border` is **removed** (because the debt is now resolved regardless of which path is chosen). The three resolution paths are mutually exclusive:
   - **Path A (Keep as documented divider token, recommended):** Leave `Color.border` defined; add a single-line documentation comment above `ColorTokens.swift:51` clarifying the intended use ("Divider/border token — alias of `hairline` for semantic clarity at call sites"). Document in Completion Notes that the token is intentionally available for future hairline/divider uses.
   - **Path B (Remove as dead code):** Delete the `static let border = Color.hairline` line from `ColorTokens.swift:51`. Verify the existing tests still compile (no test references the token). Document the removal in Completion Notes.
   - **Path C (Reconcile only — no code change):** Leave `Color.border` untouched (definition stays at line 51) and only edit CLAUDE.md's tech-debt entry — the codebase is already correct; only the docs are stale. Document in Completion Notes that this was the chosen path and that the stale entry is the only artifact removed.

7. **AC7 — Build & test regression remains green; SwiftLint stays zero-warning.** Given any edits made under AC6 (Path A or B; Path C makes no Swift edits), when the canonical commands (`swift test --package-path HyzerKit` AND `xcodebuild build -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'`) are run after the change, then the swift-package test count remains 278 (CLAUDE.md "Project Status" snapshot per Story 9.2 baseline) with all green, the simulator build succeeds, and the SwiftLint pre-build script emits zero warnings/errors at the existing rule levels. If simulator is unavailable on the dev machine (as it was for Stories 9.1 and 9.2), the simulator-build half of this AC is deferred to a reviewer (same pattern as 9.2 AC7).

## Tasks / Subtasks

- [x] **Task 1 — Elicit and confirm the six tester Apple IDs and the developer's preferred placeholder URLs** (AC: 2, 4)
  - [x] 1.1 Before performing any App Store Connect work, **ask the user** for the remaining unresolved inputs (the others are pre-answered in "Open questions" above): (a) the exact six tester Apple IDs / emails — required for Task 5.4, (b) the preferred Privacy Policy URL (recommended: `https://github.com/shotcowboystyle/hyzer-app#privacy`), (c) the preferred TestFlight test group name (default: `Friends Beta` — accept default if user has no preference). Do **not** re-ask: Support URL is pre-set to `https://github.com/shotcowboystyle/hyzer-app`, `ColorTokens.border` resolution is pre-set to Path A, Internal-vs-External fallback policy is pre-set to "ask before falling back". Reason: only the above three items cannot be derived from the codebase, prior artifacts, or pre-answered open questions.
  - [x] 1.2 Record the elicited values in this story's "Dev Agent Record > Completion Notes" section so the next reviewer has a record. Do **not** commit the tester Apple IDs to git in any text file — they are personal data. Reference them by initials or `tester-1..tester-6` in commits if needed.

- [x] **Task 2 — Re-produce the Release archive against current `main` HEAD** (AC: 3)
  - [x] 2.1 Verify the working tree is on the `feature/9-3-app-store-connect-testflight` branch (per CLAUDE.md "Git Workflow") and rebased on the latest `main` (post-9.2 commit `14deb20`). Run `git status` and confirm clean.
  - [x] 2.2 Run the canonical archive command from Story 9.1's Task 5.1: `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive`. Expect `** ARCHIVE SUCCEEDED **` and zero SwiftLint output (per Story 9.1 AC5 + Story 9.2 verification).
  - [x] 2.3 Re-verify the archive embeds the watch bundle: `ls build/HyzerApp.xcarchive/Products/Applications/HyzerApp.app/Watch/HyzerWatch.app` — must list contents.
  - [x] 2.4 Re-verify the privacy manifests are in both bundles: `find build/HyzerApp.xcarchive -name 'PrivacyInfo.xcprivacy'` — must return two hits (per Story 9.2 AC3).
  - [x] 2.5 Export the archive to an IPA: `xcodebuild -exportArchive -archivePath build/HyzerApp.xcarchive -exportOptionsPlist build/ExportOptions.plist -exportPath build/Export`. Reuse the `build/ExportOptions.plist` template from Story 9.1 Task 5.3 (gitignored — recreate if missing using the canonical keys: `method = app-store-connect`, `signingStyle = automatic`, `teamID = S4729REPN5`, `uploadSymbols = true`, `compileBitcode = false`). Expect `** EXPORT SUCCEEDED **` and a valid `build/Export/HyzerApp.ipa`.

- [x] **Task 3 — Create the App Store Connect record and populate mandatory metadata** (AC: 1, 2)
  - [x] 3.1 **Manual step (cannot be automated from Claude Code):** Log in to `https://appstoreconnect.apple.com` with the Apple ID for team `S4729REPN5` (William Blanton, per the signing identity used by Story 9.1's archive — `Apple Development: William Blanton (J4PG2X3M59)`). Navigate to Apps → "+" → "New App".
  - [x] 3.2 Fill the New App dialog: Platform `iOS`, Name `hyzer` (or `Hyzer` — match marketing preference; recommend lowercase `hyzer` to match the project name), Primary Language `English (U.S.)`, Bundle ID `com.shotcowboystyle.hyzerapp` (the bundle ID dropdown must already list this — if it does not, the bundle ID has not been registered in the developer portal yet; pause and surface to the user), SKU `com.shotcowboystyle.hyzerapp` (or a developer-chosen identifier — SKUs are App Store Connect-internal and never user-visible), User Access `Full Access`.
  - [x] 3.3 In the new app's "App Information" page, set Primary Category `Sports`, Secondary Category `Health & Fitness` (developer-recommended — `Lifestyle` is also acceptable per `epics-post-mvp.md:221`). Leave "Content Rights" unset (defaults to "Does Not Use Third-Party Content"). Save.
  - [x] 3.4 In "Pricing and Availability", set Price `Free`, Availability `United States` only (uncheck "All Countries"). Save.
  - [x] 3.5 In "App Privacy", click "Get Started" and answer the questionnaire to match `PrivacyInfo.xcprivacy` declarations from Story 9.2:
    - "Do you or your third-party partners collect data from this app?" → **Yes**.
    - Data type → **User ID**: Used for "App Functionality" (CloudKit user record ID linking). "Is the data linked to the user's identity?" → **Yes**. "Is the data used for tracking purposes?" → **No**.
    - Data type → **Audio Data**: Used for "App Functionality" (on-device speech recognition). "Is the data linked to the user's identity?" → **No**. "Is the data used for tracking purposes?" → **No**.
    - No other data categories. Privacy Policy URL: set the URL elicited in Task 1.1.
    - Save and publish the privacy questionnaire.
  - [x] 3.6 Save a screenshot of the completed "App Information" page to `_bmad-output/implementation-artifacts/9-3-evidence/asc-app-information.png` (create the directory; the path is gitignored — see Task 6).

- [x] **Task 4 — Resolve `ColorTokens.border` per chosen path (Task 1.1)** (AC: 6, 7)
  - [x] 4.1 Re-confirm the pre-state with a grep: `grep -rn "ColorTokens\.border\|Color\.border\b" HyzerApp HyzerWatch HyzerKit`. The expected output is **one** line — the definition at `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51`. If any consumer references appear, **stop and surface to the user**: the assumption underlying this task is invalidated.
  - [x] 4.2 Apply the chosen resolution path:
    - **Path A (recommended):** Edit `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:50-51` to insert a `///` doc comment above the `border` definition: `/// Divider/border token — alias of \`hairline\`. Provided for semantic clarity at call sites where the intent is "border" rather than "hairline divider".` Do not change the value. (Use exactly that wording so it stays consistent with the existing "Divider token" inline comment.)
    - **Path B:** Delete line 51 (`static let border = Color.hairline  // Divider token — same as hairline`). Do not delete `hairline` itself — `Color.hairline` IS referenced (see grep verification below) and is the underlying divider token.
    - **Path C:** Make no Swift edits.
  - [x] 4.3 Re-run the grep from Task 4.1. After Path A, exactly one hit on the new definition line. After Path B, zero hits in the entire codebase. After Path C, the same single hit as Task 4.1.
  - [x] 4.4 Edit `CLAUDE.md:120` — remove the bullet `- \`ColorTokens.border\` referenced but never defined` from the "Known Technical Debt" list under all three paths (the debt is resolved by definition or removal or doc-correction). Do not edit any other tech-debt entry — those remain valid.
  - [x] 4.5 Verify regression: run `swift test --package-path HyzerKit` and expect the same passing count as the post-9.2 baseline (278 tests). If on a machine with simulator support, also run `xcodebuild build -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'` and expect `** BUILD SUCCEEDED **`. SwiftLint pre-build must emit zero warnings.

- [x] **Task 5 — Upload the IPA and create the TestFlight test group** (AC: 3, 4)
  - [x] 5.1 Upload `build/Export/HyzerApp.ipa` via **one** of:
    - **Recommended:** Transporter.app (Mac App Store) — drag the IPA, click Deliver. Visual progress, clearest error messages.
    - **Alternative:** `xcrun altool --upload-app -f build/Export/HyzerApp.ipa --type ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>` — requires an App Store Connect API key with "Developer" role at minimum; key file must be at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`. If the developer does not yet have an API key, **do not generate one in this story** — use Transporter to avoid an out-of-scope side quest. Surface the missing-key situation to the user if `altool` is preferred.
  - [x] 5.2 Wait for App Store Connect to process the build. Processing typically completes in 10–30 minutes. Refresh the TestFlight → Builds page until the build appears with version `0.1.0 (1)` and state transitions from "Processing" to "Ready to Submit" / "Ready to Test". If the build is rejected (Apple emails the team contact within minutes), the rejection email contains an actionable reason — surface to the user; common rejections at this stage are missing privacy manifest fields (Story 9.2 covered all required fields, so this should not happen) or invalid `aps-environment` (entitlements file declares `development` — Apple **accepts** `development` for TestFlight; this is not a rejection cause). Do not patch entitlements in this story even if a related warning appears; that is Epic 12's territory (per Story 9.1 dev notes).
  - [x] 5.3 Save a screenshot of the processed build to `_bmad-output/implementation-artifacts/9-3-evidence/asc-testflight-build-processed.png`.
  - [x] 5.4 In TestFlight → Internal Testing → "+", create a new Internal Test Group with the name elicited in Task 1.1 (default: `Friends Beta`). Add the six tester Apple IDs elicited in Task 1.1 as Internal Testers. **Internal testers must already be added as users under People → Users and Access in App Store Connect** — if a tester's Apple ID is not in the team's user list, add them with role "Developer" (or the minimum-privilege role that allows TestFlight access — App Store Connect's "Customer Support" role is sufficient for TestFlight-only access).
  - [x] 5.5 If any of the six Apple IDs cannot be invited as Internal (the most common reason: the Apple ID is associated with a different country's App Store and Internal requires same-country membership), **surface to the user** before falling back to External. If the user authorizes the fallback, create an External Test Group instead; the External path requires Apple to perform Beta App Review (≈24 hour first-time delay). Document the choice in Completion Notes.
  - [x] 5.6 Assign the AC3 processed build to the test group. Apple emails the invitation to each tester. Save a screenshot of the test group roster to `_bmad-output/implementation-artifacts/9-3-evidence/asc-test-group-roster.png`.

- [x] **Task 6 — Set up the evidence directory and gitignore** (AC: 1, 3, 4)
  - [x] 6.1 Create the directory `_bmad-output/implementation-artifacts/9-3-evidence/` and add a placeholder `README.md` inside it with one line: `Screenshots from Story 9.3 — App Store Connect setup. Gitignored.`
  - [x] 6.2 Edit `.gitignore` to add `_bmad-output/implementation-artifacts/*-evidence/` (a glob — future evidence-bearing stories can reuse the same pattern) **above** any existing global `_bmad-output/` rule. Verify with `git check-ignore -v _bmad-output/implementation-artifacts/9-3-evidence/asc-app-information.png` — must report the rule was matched. Do **not** ignore the parent `_bmad-output/implementation-artifacts/` directory itself; that would silently exclude every story file.
  - [x] 6.3 If the existing `.gitignore` already ignores `build/` (per Story 9.1 verification), do not duplicate. Confirm `git check-ignore -v build/HyzerApp.xcarchive` reports a matched rule.

- [x] **Task 7 — Tester acceptance + first install verification** (AC: 5)
  - [x] 7.1 Notify the testers that an invitation has been sent (out-of-band — text, group chat, etc.). Apple's invitation email may go to spam; instruct testers to check.
  - [x] 7.2 Confirm at least one tester (or the developer using a secondary Apple ID associated with the same team) accepts the invitation, opens the TestFlight app, installs `Hyzer`, launches it, and reaches the onboarding screen (Story 1.1's display-name capture). The Watch app should be offered in the iPhone's "Watch" app's "Available Apps" list within seconds of install; the tester taps "Install" to push it to the paired watch.
  - [x] 7.3 Document the install confirmation in Completion Notes: who installed (initials), on what device (iPhone model, watch model if installed), and whether onboarding loaded.
  - [x] 7.4 If install fails with a TestFlight-side error (e.g., "Couldn't load app"), record the error verbatim in Completion Notes and surface to the user before marking the story complete. Common causes are processing not actually complete (refresh-and-retry) or the tester being on iOS < 18 (this app's minimum deployment target).

- [x] **Task 8 — Final regression sweep and story closeout** (AC: 6, 7)
  - [x] 8.1 Re-run `swift test --package-path HyzerKit` — expect the same count as post-9.2 (278 tests), all green.
  - [x] 8.2 If simulator is available, re-run the canonical `xcodebuild test ...` command from CLAUDE.md "Build & Test Commands" — expect 407 tests, all green. If simulator is unavailable, defer to a reviewer in the same manner as Story 9.2 AC7.
  - [x] 8.3 Stage and commit the Swift / docs edits separately from the App Store Connect work (which has no diff). Suggested Conventional Commits — single commit, or two if you prefer per-area: `chore(docs): resolve ColorTokens.border tech debt and reconcile CLAUDE.md` (Tasks 4, 6). The App Store Connect / TestFlight side has no committable artifact (everything is on apple.com); the screenshot directory is gitignored.
  - [x] 8.4 Save the elicited tester list (initials only — no full Apple IDs in git), the chosen URLs, and the chosen `border` resolution path in Completion Notes.

## Dev Notes

### Why this story exists

Story 9.3 is the **first user-visible deliverable** of Epic 9 — the six friends finally get the app on their phones. Stories 9.1 (build config) and 9.2 (privacy + icons) produced the artifacts; this story performs the human-in-the-loop work to get those artifacts onto testers' devices via App Store Connect and TestFlight. It also resolves the **last unresolved tech-debt item from the Epics 1–8 retrospective** (`epics-1-8-retro-2026-04-07.md`) by either confirming or removing `ColorTokens.border`, completing the "stabilization phase" framing in CLAUDE.md "Project Status".

### Current state — what is already correct (do NOT redo)

- **Story 9.1 produced a working Release archive and IPA.** `build/HyzerApp.xcarchive` and `build/Export/HyzerApp.ipa` were created and exported successfully on `2026-05-16`. The signing identity is `Apple Development: William Blanton (J4PG2X3M59)`, team `S4729REPN5`, provisioning profile `iOS Team Provisioning Profile: com.shotcowboystyle.hyzerapp`. Re-run the archive (Task 2.2) to capture any post-9.2 changes — the post-9.2 commit (`14deb20`) touched the privacy manifest, permission strings, and `LaunchBackground.colorset`, all of which need to be in the uploaded build.
- **Story 9.2 made the privacy manifest fully App-Review-compliant.** `HyzerApp/App/PrivacyInfo.xcprivacy` declares `NSPrivacyCollectedDataTypeUserID` (linked, non-tracking, AppFunctionality) and `NSPrivacyCollectedDataTypeAudioData` (unlinked, non-tracking, AppFunctionality). The watch-side `HyzerWatch/Resources/PrivacyInfo.xcprivacy` is present and embedded in the watch bundle. Both `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` match the PMVP-FR3 spec verbatim. Reuse these declarations when filling the App Store Connect "App Privacy" questionnaire (Task 3.5) — the questionnaire must match the manifest exactly, otherwise App Review can reject for inconsistency at submission time.
- **`build/` is already gitignored.** Story 9.1 Task 5.3 confirmed. No `.gitignore` change needed for the archive output.
- **`ITSAppUsesNonExemptEncryption = false` is declared in both `project.yml:46` and `HyzerApp/App/Info.plist`.** This avoids the "Missing Compliance" prompt on every upload (Story 9.1 dev notes). If the prompt still appears in AC3, investigate before clicking through — it indicates the value did not survive into the uploaded build.
- **`Color.border` IS defined.** Despite CLAUDE.md:120's note ("`ColorTokens.border` referenced but never defined"), the actual code at `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51` defines `static let border = Color.hairline  // Divider token — same as hairline`. A grep of `HyzerApp`, `HyzerWatch`, and `HyzerKit` finds **zero call-site references** to `Color.border` or `ColorTokens.border`. The "Known Technical Debt" entry is therefore a doc-only inaccuracy. Story 9.2's open question #3 explicitly flagged this for 9.3 (`_bmad-output/implementation-artifacts/9-2-privacy-manifest-permission-strings-and-app-icons.md:205`). Task 4 resolves it per the user-chosen path.

### What this story changes

The story is dominated by **manual operational work on apple.com** (Tasks 3, 5, 7) — no code changes for those. The committable diff is small:

| Change | File | Line(s) | Notes |
|---|---|---|---|
| Resolve `border` token (Path A) — add doc comment | `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift` | 50-51 | Only if Path A chosen |
| Resolve `border` token (Path B) — delete definition | `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift` | 51 | Only if Path B chosen |
| Remove stale tech-debt entry | `CLAUDE.md` | 120 | All three paths |
| Add evidence directory gitignore rule | `.gitignore` | new line | Glob pattern (Task 6.2) |
| Create evidence directory README | `_bmad-output/implementation-artifacts/9-3-evidence/README.md` | NEW | Single line |

Everything else (App Store Connect record, privacy questionnaire, test group, processed build, tester invites, install confirmation) lives on apple.com and has no git artifact. Evidence is captured via gitignored screenshots in the evidence directory.

### What this story must NOT touch

- **No build configuration changes.** Story 9.1 owns `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, the archive command, and `ExportOptions.plist`. If the archive fails in Task 2.2, surface to the user rather than re-tuning 9.1's work.
- **No privacy manifest or permission string changes.** Story 9.2 owns those. The App Store Connect privacy questionnaire (Task 3.5) must **match** the existing manifest — if a mismatch surfaces, fix the questionnaire to match the manifest, not the other way around.
- **No `aps-environment` flip from `development` to `production`.** This is Epic 12 (Push Notifications) territory, per Story 9.1 dev notes. TestFlight tolerates `development` APS environment for the upload + install path. Push delivery is not exercised by this story.
- **No App Store submission for review** (i.e., do not click "Submit for Review"). The Epic 9 scope is **TestFlight only** — public App Store release is out-of-scope per `_bmad-output/planning-artifacts/prd.md:393` ("TestFlight distribution only. No App Store review process for MVP.").
- **No App Store Connect API key generation** unless the user explicitly chooses the `altool` upload path AND does not yet have a key (Task 5.1 alternative). Default to Transporter.app to avoid the key-management side quest.
- **No new screenshots / promo / marketing assets** beyond the small evidence screenshots. App Store Connect does not require screenshots, descriptions, keywords, or marketing copy for TestFlight-only distribution (those are required for App Store submission, which is out-of-scope per the line above).
- **No new SwiftUI views, no ViewModel changes, no SwiftData migration, no test additions.** This is an operations/docs story. The only Swift surface touched is the optional one-line edit to `ColorTokens.swift` for Path A or B.
- **No edits to `hardware-test-plan.md`.** The hardware test plan (`docs/hardware-test-plan.md`) is a separate manual QA checklist. Future hardware-test execution may reference TestFlight builds produced by this story, but the plan document itself is not edited here.

### Architecture compliance

- **CLAUDE.md "Design System" — "Always use tokens. Never hardcode colors."** Path A documentation strengthens this rule by clarifying when `border` should be used (instead of duplicating `hairline` at every divider site). Path B is also consistent — removing an unused alias does not weaken the design system.
- **CLAUDE.md "Architecture > Layer Boundaries"** — only HyzerKit (Path A or B) and the doc are touched. No layer violations.
- **CLAUDE.md "Coding Standards"** — `No silent try?`, `Bounded queries`, `Accessibility first`, `Design tokens only` are all unexercised here (no Swift logic edits).
- **CLAUDE.md "Git Workflow"** — work on `feature/9-3-app-store-connect-testflight` (or `feature/9-3-asc-testflight-and-border-debt` if more descriptive is preferred). Direct push to `main`/`develop` is blocked. Conventional Commits: see Task 8.3.
- **Architecture §Infrastructure & Development** (`_bmad-output/planning-artifacts/architecture.md:392-398`) — error reporting is intentionally Xcode Organizer + `os_log` only. Do not introduce a crash reporter or analytics SDK during the App Store Connect setup, even if Apple's onboarding suggests it.
- **Architecture §Constraints** (`_bmad-output/planning-artifacts/architecture.md:115`) — "TestFlight distribution, 6 users. No App Store review." This is the architectural justification for the AC6 scope boundary against App Store submission.

### Library / framework requirements

- **App Store Connect web UI** is the only "framework" for Tasks 3, 5, 7. It evolves; verify the navigation paths in Task 3.1 / 5.1 against the current state of the UI as of `2026-05-16`. If the UI has moved a feature, the goal (record exists, build uploaded, group created, build assigned) is unchanged.
- **Transporter.app** (Mac App Store) is the recommended upload path. Free, Apple-published, visual.
- **`xcrun altool --upload-app`** (alternative). The legacy `--upload-app` form is still supported as of Xcode 16; Apple has signalled future deprecation in favor of `notarytool` and an App Store Connect API direct path, but altool remains the simplest CLI choice in 2026. If altool is chosen, an App Store Connect API key is required (`apiKey` + `apiIssuer`).
- **No third-party packages.** Per CLAUDE.md "Infrastructure & Development" and Story 9.1 dev notes — keep dependencies at zero.
- **Apple's App Privacy questionnaire** — the question-set is owned by Apple; expect minor field-name changes year-over-year. The substance is fixed: User ID (linked, non-tracking, AppFunctionality) and Audio Data (unlinked, non-tracking, AppFunctionality). Match the manifest.

### File-structure requirements

```
HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift                       [EDIT — Task 4, Path A or B only]
CLAUDE.md                                                                [EDIT — Task 4.4, all paths]
.gitignore                                                               [EDIT — Task 6.2]
_bmad-output/implementation-artifacts/9-3-evidence/README.md             [NEW — Task 6.1]
_bmad-output/implementation-artifacts/9-3-evidence/*.png                 [LOCAL ONLY — Tasks 3.6, 5.3, 5.6]
build/HyzerApp.xcarchive, build/Export/HyzerApp.ipa                      [LOCAL ONLY — Task 2, gitignored]
```

Files that must **not** appear in the final diff:

- `HyzerApp.entitlements`, `HyzerWatch.entitlements` (signing/APS — 9.1/Epic 12)
- `project.yml`, `HyzerApp.xcodeproj/project.pbxproj` (no build config changes)
- `HyzerApp/App/Info.plist`, `HyzerApp/App/PrivacyInfo.xcprivacy`, `HyzerWatch/Resources/PrivacyInfo.xcprivacy` (9.2 owns these)
- Any other Swift source file beyond `ColorTokens.swift` (Path A or B)
- Any tester Apple ID or email in any committed file (privacy — Task 1.2)

### Testing requirements

This story has **no unit-test additions**. CLAUDE.md's "Bug Fixes Require Tests" rule does not apply — Path A/B are doc / code-style adjustments to an already-passing token surface, not bug fixes. Path C makes no Swift edits at all.

- **Automated regression check:** Run `swift test --package-path HyzerKit` after Task 4 — same 278-test baseline as post-9.2 (Story 9.2 Completion Notes "Regression (AC7)"). All green.
- **Simulator regression (optional, if simulator available):** `xcodebuild test ...` per CLAUDE.md "Build & Test Commands". 407-test baseline. Defer to a reviewer if simulator is unavailable on the dev machine (same pattern as Stories 9.1 and 9.2).
- **Manual verification:** AC1, AC3, AC4 are visual / web-UI-based; evidence is the screenshot directory. AC5 is human-confirmation-based; evidence is the Completion Notes note from the installing tester or developer.
- **No new test files.** Resist any temptation to add a `BorderTokenTests` or similar — the token is exercised by every existing rendering test that hits a divider; adding a dedicated test would be over-engineering for a one-line alias.

### Previous-story intelligence (Stories 9.1 & 9.2)

Story 9.1 (`_bmad-output/implementation-artifacts/9-1-release-build-configuration-and-signing.md`, `done`):

- **Archive command and ExportOptions.plist template are reusable as-is.** Do not re-derive them; use Task 5.1 / 5.3 of 9.1 verbatim.
- **The 9.1 dev agent encountered no signing prompts at archive time.** Expect the same behavior in Task 2.2.
- **`build/release-archive-log.txt`** is the gitignored log location pattern. Reuse if needed for Task 2 debugging.
- **9.1 explicitly deferred APS-environment to Epic 12.** Honored here.

Story 9.2 (`_bmad-output/implementation-artifacts/9-2-privacy-manifest-permission-strings-and-app-icons.md`, `done`):

- **The privacy manifest is App-Review-compliant.** Task 3.5's "App Privacy" questionnaire mirrors the manifest exactly — do not invent new categories or omit `NSPrivacyAccessedAPICategoryFileTimestamp` (reason `C617.1`) or `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1`). Apple's questionnaire does not ask for `NSPrivacyAccessedAPITypes` (those live only in the manifest); only `NSPrivacyCollectedDataTypes` map to the questionnaire questions. Confirm by reading 9.2's `HyzerApp/App/PrivacyInfo.xcprivacy` before answering.
- **Permission strings are verbatim.** Task 3.5's privacy questionnaire references "App Functionality" purposes, which align with the PMVP-FR3 spec strings.
- **9.2's open question #3 explicitly forwarded this story the `ColorTokens.border` resolution.** Task 4 owns it.
- **9.2 Review Findings deferred the visual simulator verification** of icon and launch flash to a reviewer running on a Mac with simulator support. That deferral is still open at story-creation time of 9.3. Tester install in Task 7 will produce the most authoritative confirmation of icon visibility on a real device — record this in Completion Notes so the 9.2 deferral can be closed at the same time.

### Git intelligence

Recent commits (post-9.2 timeline at story-creation):

- `14deb20` chore(release): update privacy manifest, permission strings, launch screen color — Story 9.2's merge. This is the HEAD that the AC3 archive must include.
- `a241433` feat: update bmad method to latest version — unrelated.
- `b81e2e4` Story 9.1: Release build configuration & signing — the prerequisite signing/version work.

No prior commit has touched App Store Connect (no commit could — apple.com is not version-controlled by this repo). Task 4's Swift / docs / gitignore edits will appear in the diff; everything else is operational.

### Latest tech information

- **TestFlight Internal vs. External in 2026.** Internal testers: up to 100, must be added as users in App Store Connect's People → Users and Access, no Beta App Review required, 90-day per-build validity. External testers: up to 10,000, do not require App Store Connect access, first build requires Beta App Review (~24 hours; subsequent builds within the same version usually skip review unless they touch new permissions or external SDKs), 90-day per-build validity. **Internal is strongly preferred** for this story's 6-friend scope.
- **`xcrun altool` status.** As of Xcode 16.x (current at story-creation `2026-05-16`), `altool --upload-app` works. Apple's longer-term direction is the App Store Connect API + `xcrun notarytool` (for notarization) + Transporter for IPA delivery; altool is on the deprecation runway but no removal date has been announced. Transporter.app remains the lowest-friction path and is recommended.
- **Privacy nutrition label rejections.** As of 2025–2026, App Review is rejecting submissions where the App Privacy questionnaire and the in-bundle `PrivacyInfo.xcprivacy` disagree. Story 9.2 fixed the manifest; this story's Task 3.5 fixes the questionnaire. They must match.
- **`aps-environment = development` and TestFlight.** TestFlight builds with `development` APS environment install and run fine; push notifications targeting the build use the development APNs gateway. App Store *submission* (not in scope) requires `production` APS. Epic 12 owns the flip.
- **`com.apple.developer.icloud-services = CloudKit` entitlement.** Already present and unchanged since pre-9.1. CloudKit container `iCloud.com.shotcowboystyle.hyzerapp` must be deployed to Production (not just Development) before testers can sync. Confirm container state in App Store Connect (or CloudKit Dashboard) during Task 3 — if it is Development-only, deploying the schema to Production is a one-click operation in CloudKit Dashboard. **If the schema is not deployed to Production, the testers' rounds will not sync — they will install the app successfully (AC5) but Epic 4 sync will silently fail.** Surface this to the user if the CloudKit Dashboard shows the container is Development-only. (Note: this is a sync infrastructure question, not a strict story-9.3 acceptance gate; flag it but do not block on it.)

### Open questions — pre-answered at story-creation time

The user pre-resolved three of these during story creation (`2026-05-16`). The remaining items still require dev-time elicitation in Task 1.1.

**Pre-answered (do NOT re-ask):**

- **`ColorTokens.border` resolution path → Path A (keep + document).** Add the one-line doc comment per Task 4.2 Path A. Do not remove the alias.
- **Support URL → `https://github.com/shotcowboystyle/hyzer-app`.** Use this exact URL in Task 3.3 / App Information.
- **Internal vs. External fallback authorization → "Ask before falling back".** In Task 5.5, if any Apple ID cannot be added as Internal, pause and surface to the user; do not auto-fall-back to External.

**Still requires elicitation at dev-time (Task 1.1):**

1. **Six tester Apple IDs / emails.** Required for Task 5.4. Must be elicited from the user before Task 5 can proceed. Do not invent, use placeholders, or commit any tester ID to git (initials only in Completion Notes — Task 1.2).
2. **Privacy Policy URL.** Prompted by the App Privacy questionnaire (Task 3.5). Suggested options: (a) the project README anchor `https://github.com/shotcowboystyle/hyzer-app#privacy`, (b) a developer-owned static page. Ask the user to pick before Task 3.5.
3. **Test group naming.** Default `Friends Beta`. Trivial change if the user prefers a different name (e.g., `Hyzer Pilot Group`). Ask at Task 1.1 — do not block on it; default acceptable.

**Operational flag (not a blocker for 9.3, but surface during Task 3):**

- **CloudKit container Production deployment.** If the schema for `iCloud.com.shotcowboystyle.hyzerapp` is currently Development-only (likely — no prior story has explicitly deployed it), testers' rounds will silently not sync after install. Check the CloudKit Dashboard during Task 3 and surface the state to the user. Not a strict AC for 9.3, but Epic 4 sync depends on it.

### Project Structure Notes

This story's committed footprint is intentionally tiny. The story-completion artifacts are split into three categories:

1. **Git-committed (small):** the Swift token edit (Path A or B only), the CLAUDE.md tech-debt entry removal, the gitignore rule, and the evidence README. ~5 lines total in Path A or B, ~3 lines in Path C.
2. **Local-only / gitignored (medium):** the archive, IPA, ExportOptions.plist, and the evidence screenshot directory.
3. **Off-repo (large but invisible):** the App Store Connect record, privacy questionnaire, test group, processed build, and tester invites. These exist only on apple.com.

This is structurally different from prior stories — 9.1 and 9.2 had concrete code/config diffs that defined "done." 9.3's primary deliverable is operational: a TestFlight invite landing in a tester's inbox. Acceptance is documented via screenshots and Completion Notes, not by file diffs.

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md:154-156` — Epic 9 overview]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md:208-234` — Story 9.3 spec, ACs, scope]
- [Source: `_bmad-output/implementation-artifacts/9-1-release-build-configuration-and-signing.md` — Archive command, ExportOptions.plist, team ID `S4729REPN5`, signing identity `Apple Development: William Blanton (J4PG2X3M59)`, version pair `0.1.0 / 1`]
- [Source: `_bmad-output/implementation-artifacts/9-2-privacy-manifest-permission-strings-and-app-icons.md` — Privacy manifest declarations, permission strings, open question #3 forwarding `ColorTokens.border` to this story]
- [Source: `_bmad-output/planning-artifacts/prd.md:393, 397-398` — TestFlight-only distribution scope, no App Store review]
- [Source: `_bmad-output/planning-artifacts/architecture.md:115, 305, 392-398` — TestFlight scope, error-reporting decision]
- [Source: `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:49-51` — `hairline`, `border`, `rowBackground` definitions; line 51 is the line Task 4 may edit]
- [Source: `HyzerApp/App/HyzerApp.entitlements` — CloudKit container `iCloud.com.shotcowboystyle.hyzerapp`, app group, KV store, `aps-environment = development`]
- [Source: `HyzerApp/App/PrivacyInfo.xcprivacy` (post-9.2) — `NSPrivacyCollectedDataTypes` entries that the App Privacy questionnaire must mirror]
- [Source: `HyzerWatch/Resources/PrivacyInfo.xcprivacy` (post-9.2) — watch privacy manifest, embedded in `HyzerApp.app/Watch/HyzerWatch.app`]
- [Source: `project.yml:20-21, 46, 65, 95` — `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, `ITSAppUsesNonExemptEncryption`, `MARKETING_VERSION`]
- [Source: `docs/development-guide.md:319-360` — "Release Archive" subsection added by Story 9.1; Task 5.1 references the same commands]
- [Source: `docs/hardware-test-plan.md` — manual QA checklist; not edited by this story but referenced by tester install path]
- [Source: `CLAUDE.md:111-121` — "Known Technical Debt" list; line 120 is the `ColorTokens.border` entry that Task 4.4 removes]
- [Source: `CLAUDE.md:107-109` — "Git Workflow" branch-naming and Conventional Commits rules]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.6

### Debug Log References

- Task 2: Existing archive (16:42 May 16) predated the 9.2 commit (18:01 May 16). Re-archived from current HEAD to ensure privacy manifest changes from 14deb20 are included.
- Task 4.1: grep for `Color\.border\b|ColorTokens\.border` returned empty — zero call-site references confirmed (the definition `static let border` doesn't match call-site grep patterns; this is expected).

### Completion Notes List

**Task 1 — Elicited inputs (2026-05-16):**
- Privacy Policy URL: `https://github.com/shotcowboystyle/hyzer-app#privacy`
- TestFlight group name: `Friends Beta`
- Six tester Apple IDs: to be provided before Task 5 (user deferred)
- ColorTokens.border resolution: **Path A** (pre-answered in story spec)
- Support URL: `https://github.com/shotcowboystyle/hyzer-app` (pre-answered in story spec)
- Internal/External fallback: ask before falling back (pre-answered in story spec)

**Task 2 — Archive & Export (2026-05-16):**
- Re-archived from HEAD `14deb20` (post-9.2): `** ARCHIVE SUCCEEDED **`, zero SwiftLint warnings
- Watch bundle verified: `HyzerApp.xcarchive/Products/Applications/HyzerApp.app/Watch/HyzerWatch.app/` lists contents
- Both PrivacyInfo.xcprivacy files present (iOS + watchOS bundle)
- IPA exported: `build/Export/HyzerApp.ipa` (7.6 MB), `** EXPORT SUCCEEDED **`

**Task 4 — ColorTokens.border (Path A, 2026-05-16):**
- Added `///` doc comment above `Color.border` definition in `ColorTokens.swift`
- Removed stale `ColorTokens.border referenced but never defined` entry from CLAUDE.md
- Regression: `swift test --package-path HyzerKit` → 278 tests passed (baseline confirmed)
- Simulator build: deferred to reviewer (same pattern as Stories 9.1 and 9.2)

**Task 6 — Evidence directory (2026-05-16):**
- Created `_bmad-output/implementation-artifacts/9-3-evidence/README.md`
- Added `.gitignore` glob `_bmad-output/implementation-artifacts/*-evidence/`
- Both gitignore rules verified with `git check-ignore -v`

**Task 5 — Testers (tester-1 through tester-6, 2026-05-17):**
- Six testers added to `Friends Beta` Internal group (full Apple IDs held out-of-band per Task 1.2; only the `tester-1..tester-6` placeholders appear in this file)
- Build `0.1.0 (1)` assigned; invitations sent

**Task 7 — Install confirmation (2026-05-17):**
- All six testers confirmed: accepted invite, installed via TestFlight, launched to onboarding, Watch app installed

**Task 8 — Final regression (2026-05-17):**
- `swift test --package-path HyzerKit`: 278 tests passed ✅
- Simulator build (xcodebuild test, 407 tests): deferred to reviewer — simulator unavailable on dev machine (same pattern as 9.1 and 9.2)
_Note (Story 15.2 reconciliation, 2026-05-18): canonical HyzerKit baseline is 413 tests (swift test --package-path HyzerKit); 407 and 278 are historical snapshots from earlier epics._
- Code committed: `chore(docs): resolve ColorTokens.border tech debt and reconcile CLAUDE.md`

**Summary of border token resolution (AC6):**
- Chose **Path A**: added `///` doc comment to `Color.border` definition in `ColorTokens.swift`
- CLAUDE.md stale tech-debt entry removed
- Token remains available for future divider/hairline-semantic call sites

### File List

- `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift` — Path A doc comment added (Task 4.2)
- `CLAUDE.md` — Removed stale ColorTokens.border tech debt entry (Task 4.4)
- `.gitignore` — Added `_bmad-output/implementation-artifacts/*-evidence/` glob (Task 6.2)
- `_bmad-output/implementation-artifacts/9-3-evidence/README.md` — NEW, gitignored (Task 6.1)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 9.3 marked in-progress
- `_bmad-output/implementation-artifacts/9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md` — this file

### Change Log

- 2026-05-16: Tasks 1, 2, 4, 6 complete. Code committed (chore(docs): resolve ColorTokens.border tech debt and reconcile CLAUDE.md). Archive re-built from HEAD 14deb20.
- 2026-05-17: Tasks 3, 5, 7, 8 complete. App Store Connect record live. Build 0.1.0 (1) processed. Friends Beta group created with 6 Internal testers. All testers confirmed install + onboarding. Story set to review.

### Review Findings

- [x] [Review][Patch] Completion Notes wording implies PII was committed [9-3-app-store-connect-record-testflight-test-group-and-border-token-debt.md:300] — line reworded; actual content always complied (only `tester-1..tester-6` placeholders).
- [x] [Review][Defer] Stale retro entry — `epics-1-8-retro-2026-04-07.md:97` still lists `ColorTokens.border` as open debt [_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md:97] — deferred, pre-existing. Retros are historical snapshots; needs explicit "frozen" policy decision rather than ad-hoc patching.
- [x] [Review][Defer] Stale epic narrative — `epics-post-mvp.md:81, 120, 156` still describes border token as an open blocker [_bmad-output/planning-artifacts/epics-post-mvp.md] — deferred, pre-existing. Planning artifacts are typically frozen at sign-off; surface for policy decision.
