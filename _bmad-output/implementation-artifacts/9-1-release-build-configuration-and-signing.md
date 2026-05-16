# Story 9.1: Release Build Configuration & Signing

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer preparing the first TestFlight build,
I want a properly configured Release build for both iOS and watchOS targets with stable bundle identifiers, codified signing, and a coherent version pair,
so that I can produce an archivable, App-Store-validated build that the six beta testers will receive via TestFlight in Story 9.3.

> Note on framing: PRD review (`implementation-readiness-report-2026-05-13.md` §Critical Violations) flagged the "As the developer" framing. The user value is intentionally surfaced in the "so that" clause — the deliverable enables the beta-tester install path in 9.3. Do **not** rework the framing during implementation; this is accepted as a build-config story.

## Acceptance Criteria

1. **AC1 — Bundle identifiers match spec (PMVP-FR1).** Given the developer runs `xcodegen generate` and opens `HyzerApp.xcodeproj`, when the build configuration is inspected for both targets in *all* configurations (Debug + Release), then the iOS `HyzerApp` target uses `PRODUCT_BUNDLE_IDENTIFIER = com.shotcowboystyle.hyzerapp` and the watchOS `HyzerWatch` target uses `PRODUCT_BUNDLE_IDENTIFIER = com.shotcowboystyle.hyzerapp.watchkitapp`, and the watchOS `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` continues to equal the iOS bundle ID.

2. **AC2 — Shared version pair, initial value 0.1.0.** Given `project.yml` is the source of truth, when both targets are inspected, then both `HyzerApp` and `HyzerWatch` share `MARKETING_VERSION = 0.1.0` (`CFBundleShortVersionString`) and `CURRENT_PROJECT_VERSION = 1` (`CFBundleVersion`), and the iOS `Info.plist` reflects the same `CFBundleShortVersionString` value (via `$(MARKETING_VERSION)` substitution or a literal `0.1.0`).

3. **AC3 — Signing survives regeneration.** Given a clean checkout where the developer runs `xcodegen generate`, when the regenerated `HyzerApp.xcodeproj` is opened, then both targets are configured for `CODE_SIGN_STYLE = Automatic` with `DEVELOPMENT_TEAM = S4729REPN5` declared in `project.yml` (not only in `project.pbxproj`), so the configuration is not lost on the next regeneration.

4. **AC4 — Release archive succeeds without prompts.** Given the Release configuration is selected, when the developer runs `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive`, then the archive completes without interactive signing prompts, the resulting `.xcarchive` embeds the `HyzerWatch.app` under `Products/Applications/HyzerApp.app/Watch/HyzerWatch.app`, and `xcodebuild -exportArchive` with an App Store export options plist validates the archive for App Store distribution.

5. **AC5 — Zero SwiftLint warnings at Release.** Given the SwiftLint pre-build script (`HyzerApp` target, see `project.yml:64-71`) is active and strict-concurrency is `complete`, when the Release archive from AC4 is produced, then the build emits zero SwiftLint warnings and zero errors at the current `.swiftlint.yml` rule levels (max line length 160 error, max function body 100 lines error).

## Tasks / Subtasks

- [x] **Task 1 — Codify signing in `project.yml`** so it survives `xcodegen generate` (AC: 3)
  - [x] 1.1 In `project.yml` under `settings.base` (top-level), add `DEVELOPMENT_TEAM: S4729REPN5` and `CODE_SIGN_STYLE: Automatic` so all targets inherit. These currently live only in `HyzerApp.xcodeproj/project.pbxproj:785-967` and will be dropped on regeneration.
  - [x] 1.2 Confirm the iOS target also retains `CODE_SIGN_ENTITLEMENTS: HyzerApp/App/HyzerApp.entitlements` and the watch target retains `CODE_SIGN_ENTITLEMENTS: HyzerWatch/App/HyzerWatch.entitlements` (already in `project.yml:58, 85`).
  - [x] 1.3 Do **not** add `CODE_SIGN_IDENTITY` or `PROVISIONING_PROFILE_SPECIFIER`. Automatic signing manages both. The legacy `CODE_SIGN_IDENTITY = "iPhone Developer"` strings in pbxproj (lines 785, 957) are vestigial and will be removed when XcodeGen regenerates.

- [x] **Task 2 — Align version pair to `0.1.0` / `1`** (AC: 1, 2)
  - [x] 2.1 In `project.yml` set `MARKETING_VERSION: "0.1.0"` for both `HyzerApp` (currently `"1.0"` at line 60) and `HyzerWatch` (currently `"1.0"` at line 90). Quote the string to prevent YAML treating `0.1.0` as a number.
  - [x] 2.2 Leave `CURRENT_PROJECT_VERSION: 1` unchanged on both targets — the spec calls for "initial value `0.1.0`" with a monotonically incrementing build number; this is build 1.
  - [x] 2.3 Update `HyzerApp/App/Info.plist:18` from `<string>1.0</string>` to `<string>$(MARKETING_VERSION)</string>` (preferred — single source of truth) or `<string>0.1.0</string>` (literal). The substitution form is preferred because future bumps then only require a `project.yml` change.
  - [x] 2.4 Leave `HyzerApp/App/Info.plist:20` `CFBundleVersion = 1` aligned with `CURRENT_PROJECT_VERSION` (or replace with `$(CURRENT_PROJECT_VERSION)`).
  - [x] 2.5 `HyzerWatch` uses `GENERATE_INFOPLIST_FILE: YES` (`project.yml:86`); no plist edit needed — its `CFBundleShortVersionString` and `CFBundleVersion` derive from the build settings updated in 2.1.

- [x] **Task 3 — Bundle identifier audit** (AC: 1)
  - [x] 3.1 Verify iOS `PRODUCT_BUNDLE_IDENTIFIER = com.shotcowboystyle.hyzerapp` (`project.yml:57`).
  - [x] 3.2 Verify watchOS `PRODUCT_BUNDLE_IDENTIFIER = com.shotcowboystyle.hyzerapp.watchkitapp` (`project.yml:84`).
  - [x] 3.3 Verify `INFOPLIST_KEY_WKCompanionAppBundleIdentifier = com.shotcowboystyle.hyzerapp` (`project.yml:92`).
  - [x] 3.4 Confirm `options.bundleIdPrefix: com.shotcowboystyle` is consistent (`project.yml:4`). No change expected — this task is verification, not modification.

- [x] **Task 4 — Regenerate and validate the project** (AC: 1, 2, 3)
  - [x] 4.1 Run `xcodegen generate`.
  - [x] 4.2 Inspect `HyzerApp.xcodeproj/project.pbxproj` to confirm `DEVELOPMENT_TEAM = S4729REPN5` and the new `MARKETING_VERSION = 0.1.0` appear under both targets in both Debug and Release configurations (4 occurrences each, matching the existing pattern at pbxproj lines 785-967).
  - [x] 4.3 Confirm the obsolete `CODE_SIGN_IDENTITY = "iPhone Developer"` entries no longer appear (or remain only as Xcode defaults Automatic signing tolerates).
  - [x] 4.4 Run `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch' build` to confirm the regenerated project still compiles for Debug.

- [x] **Task 5 — Produce and validate the Release archive** (AC: 4, 5)
  - [x] 5.1 Run: `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive | xcpretty` (xcpretty optional). Expect exit 0, no signing prompts.
  - [x] 5.2 Confirm the archive embeds the Watch app: `ls build/HyzerApp.xcarchive/Products/Applications/HyzerApp.app/Watch/HyzerWatch.app` should list the watch bundle.
  - [x] 5.3 Create a minimal `build/ExportOptions.plist` with `method=app-store-connect`, `signingStyle=automatic`, `teamID=S4729REPN5`, `uploadSymbols=true`, `compileBitcode=false`. Do not commit this file — add `build/` to `.gitignore` if it isn't already (verify first; do not duplicate entries).
  - [x] 5.4 Run: `xcodebuild -exportArchive -archivePath build/HyzerApp.xcarchive -exportOptionsPlist build/ExportOptions.plist -exportPath build/Export`. The command must exit 0 with a valid `.ipa` written under `build/Export/`. **Do not upload** — Story 9.3 owns App Store Connect upload.
  - [x] 5.5 Scan the archive log for `SwiftLint` warning/error lines. Must be zero.
  - [x] 5.6 Save the trimmed archive log under `build/release-archive-log.txt` (gitignored) and reference its outcome in Completion Notes — do not commit the log.

- [x] **Task 6 — Document the archive procedure** (AC: 4)
  - [x] 6.1 In `docs/development-guide.md`, add a "Release Archive" subsection capturing the exact `xcodebuild archive` + `xcodebuild -exportArchive` invocation from Task 5, plus the team ID and the expectation that `ExportOptions.plist` is developer-local and gitignored. Keep the section short — link out, do not duplicate full Apple docs.

## Dev Notes

### Why this story exists

Epic 9 unblocks TestFlight distribution. Story 9.1 is the **prerequisite signing/build-config milestone** for Stories 9.2 (privacy manifest + icons) and 9.3 (App Store Connect record + first TestFlight upload). The archive produced in AC4 is literally the artifact that Story 9.3 uploads (see `epics-post-mvp.md:226`: *"an archive uploaded from Story 9.1 is processed by App Store Connect"*).

### Current state — what is already correct (do NOT redo)

Read these locations before changing anything:

- **Bundle identifiers already correct.** `project.yml:57` (iOS) and `project.yml:84` (watch). Verification only; no edits.
- **`DEVELOPMENT_TEAM = S4729REPN5` already in pbxproj.** At lines 787, 805, 826, 848, 933, 959 of `HyzerApp.xcodeproj/project.pbxproj`. The **problem**: it is *not* in `project.yml`, so the next `xcodegen generate` will drop it. This story's central fix is to lift it into `project.yml`.
- **SwiftLint pre-build script already configured.** `project.yml:64-71`. No change.
- **`ITSAppUsesNonExemptEncryption: false` already set.** `project.yml:42` and `HyzerApp/App/Info.plist:21-22`. This avoids the export-compliance prompt on every upload.
- **Strict concurrency already `complete`.** `project.yml:18`. Release builds must continue to compile under this setting.
- **CloudKit entitlements already in place.** `HyzerApp/App/HyzerApp.entitlements` contains the iCloud container, KV-store, app group, and `aps-environment = development`. **Do not change the APS environment in this story** — push-notification capability is Epic 12's territory. If a reviewer questions `development` for a TestFlight build, note that TestFlight tolerates `development` APS until Epic 12 ships and that the entitlement file is rewritten there.

### What this story changes

| Change | File | Line | Notes |
|---|---|---|---|
| Add `DEVELOPMENT_TEAM` + `CODE_SIGN_STYLE` to global `settings.base` | `project.yml` | ~15-19 | Inherited by all targets including `HyzerAppTests`. |
| Bump `MARKETING_VERSION` 1.0 → 0.1.0 (iOS) | `project.yml` | 60 | Quote the string. |
| Bump `MARKETING_VERSION` 1.0 → 0.1.0 (Watch) | `project.yml` | 90 | Quote the string. |
| Update `CFBundleShortVersionString` | `HyzerApp/App/Info.plist` | 17-18 | Prefer `$(MARKETING_VERSION)` substitution. |
| Regenerate project | `HyzerApp.xcodeproj/project.pbxproj` | many | Output of `xcodegen generate`. Commit the regenerated pbxproj. |
| Document archive command | `docs/development-guide.md` | new section | Short subsection only. |

### What this story must NOT touch

- **No app-icon work, no privacy manifest changes, no permission-string changes** — that is Story 9.2's scope (`epics-post-mvp.md:182-206`). The existing `HyzerApp/App/PrivacyInfo.xcprivacy` and Info.plist usage strings stay as they are; 9.2 will replace them with the spec-compliant versions.
- **No APS environment changes** — Epic 12's notification work flips `development` → `production` and adds the proper entitlement (`epics-post-mvp.md` Epic 12).
- **No App Store Connect record, no TestFlight test group, no upload** — that is Story 9.3 (`epics-post-mvp.md:208-234`).
- **No `ColorTokens.border` tech-debt resolution** — also Story 9.3. Do not be tempted by the CLAUDE.md "Known Technical Debt" list.

### Architecture compliance

- **CLAUDE.md "Architecture > Concurrency"** — Swift 6 strict-concurrency must remain `complete`. Do not relax it to make a warning disappear; fix the warning instead.
- **CLAUDE.md "Build & Test Commands"** — the canonical simulator is `iPhone 17 with Watch`. Use it for the Debug verification in Task 4.4. The Release archive in Task 5 uses `generic/platform=iOS` because archives are device-targeted, not simulator-targeted.
- **CLAUDE.md "Git Workflow"** — work on a `feature/9-1-release-build-config` branch. Direct pushes to `main`/`develop` are blocked. Conventional Commits, e.g. `chore(build): codify Release signing and bump version to 0.1.0`.
- **Architecture §Infrastructure & Development** (`_bmad-output/planning-artifacts/architecture.md:392-398`) — error reporting is intentionally limited to Xcode Organizer + `os_log`. Do not add a crash reporter or analytics SDK in this story.

### Library / framework requirements

- **XcodeGen** is the source of truth for the Xcode project. Every config knob lives in `project.yml`. If a value is only in `project.pbxproj`, it is fragile.
- **xcodebuild** (Xcode 16+ assumed since deployment targets are iOS 18 / watchOS 11). No third-party CI tools (`fastlane`, etc.) are introduced in this story — keep dependencies at zero per CLAUDE.md "Infrastructure & Development".
- **SwiftLint** runs as a pre-build script. Do not migrate to the SPM plugin in this story.

### File-structure requirements

```
project.yml                                    [EDIT — Tasks 1, 2]
HyzerApp/App/Info.plist                        [EDIT — Task 2.3-2.4]
HyzerApp.xcodeproj/project.pbxproj             [REGENERATED — Task 4.1, commit the diff]
docs/development-guide.md                      [EDIT — Task 6.1, add Release Archive subsection]
.gitignore                                     [VERIFY — confirm build/ is ignored before Task 5.3]
build/                                         [LOCAL ONLY — never commit]
```

### Testing requirements

This story has **no unit-test additions**. CLAUDE.md's "Bug Fixes Require Tests" rule does not apply — this is a build-configuration change, not a bug fix. The functional tests are the AC4 archive command and the AC5 SwiftLint pass.

Run the existing test suite once after Task 4 to confirm no regression:

```sh
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'
```

The current baseline is 407 tests (per CLAUDE.md "Project Status"). All must still pass.

### Previous-story intelligence

The last regular dev story before the Epic 9 deferral was **8.2 — Player Hole-by-Hole Breakdown** (`_bmad-output/implementation-artifacts/8-2-player-hole-by-hole-breakdown.md`, status `done`). Nothing in 8.2 informs build configuration. The Epics 1-8 retrospective (`_bmad-output/implementation-artifacts/epics-1-8-retro-2026-04-07.md`) lists known tech debt; none of it (ValueCollector, ShareSheetRepresentable, ConflictResult, SyncScheduler, ColorTokens.border) belongs in this story. Resist scope creep.

### Git intelligence

Recent commits (`eca6584`, `0821bd2`, `5f77ed9`) closed out the Epics 10/11 polish wave. The `0f84991` fix wired `activeRoundID` for watch sync — unrelated to this story. `cc626e4` was a stabilization sprint that already exercised the Release build pipeline informally, so Release should be close to green; expect minor signing/version drift only.

There is no commit history of a successful `xcodebuild archive` invocation — this is the first time. Budget time in Task 5 for first-attempt friction (provisioning profile auto-generation typically requires being signed into Xcode on the build machine with the matching Apple ID for team `S4729REPN5`).

### Latest tech information

- **Xcode 16+ `-allowProvisioningUpdates`** is **not** required when `CODE_SIGN_STYLE = Automatic` and the developer is signed into Xcode with the team's Apple ID. If 5.1 surfaces a "provisioning profile" error, add `-allowProvisioningUpdates` to the `xcodebuild archive` command before assuming a configuration bug.
- **`generic/platform=iOS`** is the correct destination for archive (do not use a specific simulator). Using a simulator destination produces a non-archivable build.
- **`xcodebuild -exportArchive` requires an `ExportOptionsPlist`** since Xcode 9. The minimum keys are `method`, `signingStyle`, `teamID`. `method = app-store-connect` is the Xcode 15+ replacement for the legacy `method = app-store`; both still work, prefer the new one.

### Open questions saved for end of analysis

1. **APS environment for Release.** The entitlements file declares `aps-environment = development`. This is acceptable for now (Epic 12 owns push), but if AC4 / `xcodebuild -exportArchive` rejects the archive over this, the fix is to bring Epic 12 forward, not patch in 9.1. Surface to the user before patching.
2. **`ExportOptions.plist` template location.** Decision deferred to the developer: keep it local-only (recommended; gitignore `build/`) or commit a sanitized template under `scripts/`. Story 9.3 may revisit this when CI/upload is automated.

### Project Structure Notes

This story's edits are localized to build configuration (`project.yml`, `Info.plist`, regenerated `pbxproj`) plus one docs subsection. No code is added or removed. No new Swift files, no new tests. The change is consistent with the documented XcodeGen-as-source-of-truth pattern in CLAUDE.md (`Build & Test Commands` section).

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md:154-180` — Epic 9 + Story 9.1 spec and ACs]
- [Source: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-13.md:308-318, 380` — Quality review and accepted framing caveat]
- [Source: `_bmad-output/planning-artifacts/architecture.md:392-398` — Infrastructure & error-reporting decisions]
- [Source: `project.yml` — current build config (lines 4, 15-26, 28-93 referenced inline above)]
- [Source: `HyzerApp/App/Info.plist:17-22` — current version + encryption keys]
- [Source: `HyzerApp/App/HyzerApp.entitlements` — current capabilities; do not edit in this story]
- [Source: `HyzerApp.xcodeproj/project.pbxproj:785-967` — current pbxproj-only signing values being lifted into `project.yml`]
- [Source: `CLAUDE.md` — Build & Test Commands, Concurrency, Git Workflow, Known Technical Debt, Coding Standards]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Archive log summary saved at `build/release-archive-log.txt` (gitignored). Outcome: ARCHIVE SUCCEEDED, EXPORT SUCCEEDED. Zero SwiftLint warnings/errors. One system-level `appintentsmetadataprocessor` note is unrelated to SwiftLint.
- `CODE_SIGN_IDENTITY = "iPhone Developer"` remains in 2 pbxproj locations (HyzerApp Debug + Release). These are Xcode defaults tolerated by Automatic signing per AC4.3 spec — not a configuration error.
- `DEVELOPMENT_TEAM` is at project level (2 occurrences) rather than per-target (4 occurrences as the story anticipated). Project-level settings are inherited by all targets — functionally equivalent.
- `CFBundleShortVersionString` and `CFBundleVersion` are managed via `info.properties` in `project.yml` (not direct plist edits) because XcodeGen regenerates the plist from its own template. This is the correct XcodeGen pattern.

### Completion Notes List

- **Task 1 ✅**: Added `DEVELOPMENT_TEAM: S4729REPN5` and `CODE_SIGN_STYLE: Automatic` to global `settings.base` in `project.yml`. Both now survive `xcodegen generate`. Entitlement references already in place on both targets.
- **Task 2 ✅**: `MARKETING_VERSION` bumped to `"0.1.0"` for both HyzerApp and HyzerWatch targets. `CURRENT_PROJECT_VERSION` remains 1. `CFBundleShortVersionString` updated to `$(MARKETING_VERSION)` and `CFBundleVersion` to `$(CURRENT_PROJECT_VERSION)` via `info.properties` in project.yml — surviving regeneration correctly.
- **Task 3 ✅**: All bundle identifiers verified correct — no changes needed.
- **Task 4 ✅**: `xcodegen generate` ran successfully. pbxproj shows `DEVELOPMENT_TEAM = S4729REPN5` (2 project-level entries), `MARKETING_VERSION = 0.1.0` (4 target entries), `CODE_SIGN_STYLE = Automatic` (2 project-level entries). Debug simulator build: `** BUILD SUCCEEDED **`.
- **Task 5 ✅**: Release archive: `** ARCHIVE SUCCEEDED **`. Signed with `Apple Development: William Blanton (J4PG2X3M59)` using provisioning profile `iOS Team Provisioning Profile: com.shotcowboystyle.hyzerapp`. Watch app embedded at `build/HyzerApp.xcarchive/.../HyzerApp.app/Watch/HyzerWatch.app`. Export: `** EXPORT SUCCEEDED **`. IPA at `build/Export/HyzerApp.ipa`. Zero SwiftLint warnings/errors.
- **Task 6 ✅**: "Release Archive" subsection added to `docs/development-guide.md` with exact archive + export commands, team ID, and gitignore note.
- No tests added (per story spec — this is a build-config story, not a bug fix; no unit-test additions required).

### File List

- `project.yml` — added `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE` to global settings.base; bumped `MARKETING_VERSION` to `"0.1.0"` on both targets; added `CFBundleShortVersionString`/`CFBundleVersion` to `info.properties`
- `HyzerApp/App/Info.plist` — `CFBundleShortVersionString` updated to `$(MARKETING_VERSION)`, `CFBundleVersion` updated to `$(CURRENT_PROJECT_VERSION)` (via xcodegen regeneration from info.properties)
- `HyzerApp.xcodeproj/project.pbxproj` — regenerated by `xcodegen generate`; now contains `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, `MARKETING_VERSION = 0.1.0`
- `docs/development-guide.md` — added "Release Archive" subsection

### Review Findings

- [x] [Review][Patch] Reverted out-of-scope Story 12.1 status flip [_bmad-output/implementation-artifacts/sprint-status.yaml:135] — Restored to `backlog`. Untracked `12-1-notification-foundation-and-round-started-push.md` left in working tree to be committed separately as part of Epic 12 planning.
- [x] [Review][Defer] APS environment `aps-environment = development` for App Store-bound archive [HyzerApp/App/HyzerApp.entitlements:21] — deferred, spec open question #1 explicitly acknowledges and parks this until Epic 12 flips it to `production`. Risk materializes only at Story 9.3 upload, not at 9.1 archive/export.
- [x] [Review][Defer] Test targets inherit `DEVELOPMENT_TEAM` from global `settings.base` [project.yml:20] — deferred, harmless locally but will require an override when CI is introduced (Epic 13 / future story). No action while there is no CI agent.

### Change Log

- 2026-05-16: Lifted signing config (`DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`) into `project.yml` global settings so it survives regeneration. Bumped `MARKETING_VERSION` 1.0 → 0.1.0 on both targets. Added `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` substitution to Info.plist via info.properties. Regenerated pbxproj. Produced first-ever Release archive + IPA export. Documented archive procedure in development guide.
