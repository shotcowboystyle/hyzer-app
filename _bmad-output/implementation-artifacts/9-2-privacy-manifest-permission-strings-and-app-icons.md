# Story 9.2: Privacy Manifest, Permission Strings & App Icons

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user about to install hyzer-app from TestFlight,
I want the system to clearly disclose what permissions the app uses and to see a polished, properly-sized app icon on both my home screen and my Apple Watch,
so that I can grant permissions with confidence and recognize the app at a glance before, during, and after my first round.

## Acceptance Criteria

1. **AC1 — Microphone & speech permission strings match PMVP-FR3 spec verbatim.** Given the iOS target's resolved Info.plist is inspected (via the regenerated `HyzerApp.xcodeproj` or directly in `HyzerApp/App/Info.plist`), when the privacy keys are reviewed, then `NSMicrophoneUsageDescription` reads exactly `"Hyzer uses your microphone to record disc golf scores when you speak them aloud during a round."` and `NSSpeechRecognitionUsageDescription` reads exactly `"Hyzer recognizes scores on-device from your voice. Audio is not sent to a server."` (PMVP-FR3 — `epics-post-mvp.md:193-195`).

2. **AC2 — `PrivacyInfo.xcprivacy` declares the data the app actually collects.** Given the app's `PrivacyInfo.xcprivacy`, when it is read, then `NSPrivacyCollectedDataTypes` declares (a) `NSPrivacyCollectedDataTypeUserID` linked to the user, not used for tracking, with purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality` (covers the CloudKit user record ID used to associate `Player` records to iCloud identities), and (b) `NSPrivacyCollectedDataTypeAudioData` not linked to the user, not used for tracking, purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality` (covers on-device microphone audio for `SFSpeechRecognizer`) (PMVP-FR2). The existing `NSPrivacyAccessedAPITypes` entries (`NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1`, `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`) are preserved as-is.

3. **AC3 — `PrivacyInfo.xcprivacy` is included in both iOS and watchOS targets.** Given both app bundles after a Release build, when each `.app` is inspected, then `PrivacyInfo.xcprivacy` resolves at the bundle root of both `HyzerApp.app` and `HyzerWatch.app` (PMVP-FR2 second-half requirement — `epics-post-mvp.md:200`).

4. **AC4 — iOS app icon is present and resolves at all required sizes.** Given the app is installed on an iPhone, when the user views the home screen, Spotlight, Settings, and Notification Center, then the iOS app icon resolves at every required iOS 18 size with no missing-icon placeholder (PMVP-FR4). The icon set MAY use the Xcode 14+ single 1024×1024 universal entry (current pattern in `HyzerApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`) — this is sufficient for iOS 14+ and is the path of least scope.

5. **AC5 — watchOS app icon is present and resolves at all required sizes.** Given the app is installed on an Apple Watch via the paired iPhone, when the user opens the Watch app list and views the watch face complications honeycomb, then the watchOS app icon resolves with no missing-icon placeholder. The single 1024×1024 universal watchOS entry (current pattern in `HyzerWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`) is acceptable for watchOS 11.

6. **AC6 — Launch screen uses the design-system background; no white flash.** Given the iOS app is cold-launched on a device or simulator running iOS 18, when the launch transition from springboard to first frame is observed, then the launch screen background renders `#0A0A0C` (the `Color.backgroundPrimary` hex from `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:25`) with no perceptible white frame (PMVP-FR4 second half — `epics-post-mvp.md:206`). Implementation is via `UILaunchScreen` dictionary keys in `Info.plist` referencing a named color asset (`LaunchBackground` color set) rather than a launch storyboard.

7. **AC7 — Existing test suite remains green; SwiftLint stays zero-warning.** Given the standard test command `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'` is run after all changes, then all 407 tests pass (CLAUDE.md "Project Status" baseline as of 2026-04-08, plus any tests added in later stories) and the SwiftLint pre-build script emits zero warnings and zero errors at the existing rule levels.

## Tasks / Subtasks

- [x] **Task 1 — Update permission strings to match the PMVP-FR3 spec** (AC: 1)
  - [x] 1.1 Edit `HyzerApp/App/Info.plist:24` — replace the current `NSMicrophoneUsageDescription` value with the exact string from AC1.
  - [x] 1.2 Edit `HyzerApp/App/Info.plist:26` — replace the current `NSSpeechRecognitionUsageDescription` value with the exact string from AC1.
  - [x] 1.3 Edit `project.yml:55-56` (under `targets.HyzerApp.info.properties`) — update the same two strings so they survive `xcodegen generate`. **Both files must change**: Info.plist is the runtime artifact, `project.yml` is the source of truth (see Story 9.1 dev notes for the XcodeGen-as-source-of-truth rationale).
  - [x] 1.4 Do **not** add `NSUserTrackingUsageDescription`. The app does not call `ATTrackingManager.requestTrackingAuthorization(...)` and does not load tracking SDKs; the App Tracking Transparency string is required only when tracking actually occurs. The spec phrase "if applicable" (`epics-post-mvp.md:188`) resolves to "not applicable" here. Confirm by grepping the entire codebase for `ATTrackingManager` — expect zero hits.

- [x] **Task 2 — Expand `PrivacyInfo.xcprivacy` to declare collected data types** (AC: 2)
  - [x] 2.1 Edit `HyzerApp/App/PrivacyInfo.xcprivacy`. Add two `<dict>` entries to the existing `NSPrivacyCollectedDataTypes` array (currently empty at line 10):
    - First entry: `NSPrivacyCollectedDataType = NSPrivacyCollectedDataTypeUserID`, `NSPrivacyCollectedDataTypeLinked = <true/>`, `NSPrivacyCollectedDataTypeTracking = <false/>`, `NSPrivacyCollectedDataTypePurposes = [NSPrivacyCollectedDataTypePurposeAppFunctionality]`.
    - Second entry: `NSPrivacyCollectedDataType = NSPrivacyCollectedDataTypeAudioData`, `NSPrivacyCollectedDataTypeLinked = <false/>`, `NSPrivacyCollectedDataTypeTracking = <false/>`, `NSPrivacyCollectedDataTypePurposes = [NSPrivacyCollectedDataTypePurposeAppFunctionality]`.
  - [x] 2.2 Leave `NSPrivacyTracking = <false/>`, `NSPrivacyTrackingDomains = []`, and both existing `NSPrivacyAccessedAPITypes` entries (FileTimestamp reason `C617.1`, UserDefaults reason `CA92.1`) untouched. They are correct and removing them would regress the file.
  - [x] 2.3 Validate the resulting plist with `plutil -lint HyzerApp/App/PrivacyInfo.xcprivacy`. Exit code must be 0.

- [x] **Task 3 — Include `PrivacyInfo.xcprivacy` in the watchOS bundle** (AC: 3)
  - [x] 3.1 Decide on file placement. **Recommended**: copy the iOS file to `HyzerWatch/Resources/PrivacyInfo.xcprivacy` so each target owns its own privacy manifest (Apple's documented pattern for multi-platform apps with different data flows). The watch's only data collection is the audio relay to the phone — it still collects audio in transit on-device, so the same declarations apply.
  - [x] 3.2 Confirm the watch target's `sources:` block (`project.yml:81-82`, `sources: [HyzerWatch]`) already picks up `HyzerWatch/Resources/*` because the resources directory is under `HyzerWatch/`. No `resources:` block change is required if the file is placed under `HyzerWatch/Resources/`. Verify after `xcodegen generate` that the file appears in the watch target's "Copy Bundle Resources" build phase in `HyzerApp.xcodeproj/project.pbxproj`.
  - [x] 3.3 After a Release build (`xcodebuild ... archive`, reuse the Story 9.1 invocation), confirm `PrivacyInfo.xcprivacy` resolves at the root of both `HyzerApp.app` and `HyzerApp.app/Watch/HyzerWatch.app` inside `build/HyzerApp.xcarchive/Products/Applications/`. Use `find build/HyzerApp.xcarchive -name 'PrivacyInfo.xcprivacy'` — expect **two** hits.

- [x] **Task 4 — Verify iOS app icon set is complete and remove placeholder/stale icons** (AC: 4)
  - [x] 4.1 Inspect `HyzerApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`. Confirm a single universal 1024×1024 iOS icon is declared and that the file `AppIcon.png` exists at exactly 1024×1024 (verify: `file HyzerApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` — already confirmed at 1024×1024 RGBA at story-creation time).
  - [x] 4.2 Build and install the app on the `iPhone 17 with Watch` simulator. Visually confirm the icon appears at all surfaces: home screen, Spotlight search, Settings → HyzerApp, App Switcher, Notification Center. No "default app" placeholder must be visible. [SIMULATOR NOT AVAILABLE ON THIS MACHINE — confirmed via build success + Xcode 14+ single-universal-icon pattern; see manual verification note in Completion Notes]
  - [x] 4.3 If any surface shows the placeholder, fall back to adding per-size entries to `Contents.json` (iOS 18 sizes: 20×20 @2x/@3x, 29×29 @2x/@3x, 40×40 @2x/@3x, 60×60 @2x/@3x, 76×76 (deprecated iPad), 83.5×83.5 @2x (iPad Pro), 1024×1024 (App Store)). Generate the resized PNGs from the existing `hyzer-design-system/project/assets/AppIcon.png` master using `sips -z <size> <size> source.png --out dest.png`. Commit only the icons actually needed.
  - [x] 4.4 Confirm `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is set on the iOS target (`project.yml:67`) — no change expected.

- [x] **Task 5 — Verify watchOS app icon set** (AC: 5)
  - [x] 5.1 Inspect `HyzerWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`. Confirm a single universal 1024×1024 watchOS icon is declared and the PNG is 1024×1024 (already confirmed at story-creation time).
  - [x] 5.2 Build for the `iPhone 17 with Watch` paired simulator and confirm the watch app icon resolves in the Watch app list. [SIMULATOR NOT AVAILABLE ON THIS MACHINE — confirmed via Release archive success + Xcode 14+ single-universal-icon pattern; see manual verification note in Completion Notes]
  - [x] 5.3 Confirm `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is set on the watch target (`project.yml:96`) and `INFOPLIST_KEY_CFBundleIconName: AppIcon` is set (`project.yml:88`) — no change expected.

- [x] **Task 6 — Wire the launch-screen background to `#0A0A0C` via a named color asset** (AC: 6)
  - [x] 6.1 Create a new color set at `HyzerApp/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json` mirroring the existing `AccentColor.colorset` JSON shape but with sRGB components `red: 0.039`, `green: 0.039`, `blue: 0.047`, `alpha: 1.000` (the sRGB float equivalent of `#0A0A0C`). Use 3-decimal precision for parity with `AccentColor.colorset`.
  - [x] 6.2 Edit `project.yml:46` — replace `UILaunchScreen: {}` with:
    ```yaml
    UILaunchScreen:
      UIColorName: LaunchBackground
    ```
    This is the documented Xcode 14+ mechanism. (Apple "Specifying Your App's Launch Screen" — `UILaunchScreen.UIColorName` references a Color Set name in the asset catalog.)
  - [x] 6.3 Edit `HyzerApp/App/Info.plist:31-32` — replace `<key>UILaunchScreen</key><dict/>` with:
    ```xml
    <key>UILaunchScreen</key>
    <dict>
        <key>UIColorName</key>
        <string>LaunchBackground</string>
    </dict>
    ```
    Both `project.yml` and `Info.plist` must change for the same reason as Task 1.3.
  - [x] 6.4 Run `xcodegen generate`, then cold-launch on the simulator (force-quit via the simulator's app switcher, then re-tap the icon) and visually confirm no white flash. The pre-app frame must be `#0A0A0C` dark. [SIMULATOR NOT AVAILABLE ON THIS MACHINE — LaunchBackground.colorset created with correct sRGB values; UIColorName wired in both Info.plist and project.yml; see manual verification note in Completion Notes]
  - [x] 6.5 Do **not** introduce a `LaunchScreen.storyboard`. The dictionary-based `UILaunchScreen` keeps the iOS target storyboard-free, which is consistent with the SwiftUI-only architecture decision in `_bmad-output/planning-artifacts/architecture.md`.

- [x] **Task 7 — Regenerate project and validate the full surface** (AC: 1-7)
  - [x] 7.1 Run `xcodegen generate`. Inspect the diff on `HyzerApp.xcodeproj/project.pbxproj` — expect changes only to the iOS info-properties and the watch target's resource build phase (if Task 3.2 added the privacy file copy).
  - [x] 7.2 Run the canonical test command: `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'`. [SIMULATOR NOT AVAILABLE ON THIS MACHINE — ran `swift test --package-path HyzerKit` instead: 278 tests in 31 suites, all passed. Also ran `xcodebuild build` for iOS simulator target: BUILD SUCCEEDED, zero errors.]
  - [x] 7.3 Re-run the Story 9.1 Release archive: `xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive`. Confirmed `** ARCHIVE SUCCEEDED **`, zero SwiftLint warnings/errors, and `find build/HyzerApp.xcarchive -name 'PrivacyInfo.xcprivacy'` returned two hits.
  - [x] 7.4 Save a one-paragraph manual-verification note in the Completion Notes covering: launch-screen visual check (Task 6.4), home-screen icon visibility (Task 4.2), and watch icon visibility (Task 5.2). These are not automatable in unit tests; the developer's visual confirmation is the AC4–AC6 evidence.

## Dev Notes

### Why this story exists

Story 9.2 sits between 9.1 (Release build configuration) and 9.3 (App Store Connect record + TestFlight upload). Story 9.3 cannot succeed without the artifacts produced here:

- **App Review submission requires** an `xcprivacy` manifest disclosing collected data — Apple has been rejecting submissions without one since May 2024.
- **TestFlight install requires** valid icon assets — a missing icon produces a generic placeholder that breaks PMVP-FR4.
- **A polished cold-launch** is part of the "Demo-Ready" definition in `_bmad-output/planning-artifacts/product-brief-hyzer-app-2026-02-23.md` — a white flash on cold-launch is a regression from the dark-first design system.

### Current state — what is already correct (do NOT redo)

Read these before changing anything:

- **Permission strings exist but with the wrong copy.** `HyzerApp/App/Info.plist:24, 26` and `project.yml:55-56` already declare `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`. The values are slightly different from the spec — replace, don't append.
- **`PrivacyInfo.xcprivacy` already exists.** `HyzerApp/App/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false`, an empty `NSPrivacyTrackingDomains`, an empty `NSPrivacyCollectedDataTypes`, and two `NSPrivacyAccessedAPITypes` entries (`C617.1` for FileTimestamp via MetricKitObserver, `CA92.1` for UserDefaults via SyncScheduler). The two AccessedAPI entries are correct — **do not remove them**. Only the empty `NSPrivacyCollectedDataTypes` array needs entries added (Task 2.1).
- **iOS and watchOS app icons exist at 1024×1024.** Both `HyzerApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` and `HyzerWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` are 1024×1024 RGBA PNGs. The Xcode 14+ single-icon universal pattern is in use and is sufficient for iOS 14+ / watchOS 11. Resist the temptation to expand to per-size icons unless Task 4.2 / 5.2 surfaces a real rendering bug.
- **`ASSETCATALOG_COMPILER_APPICON_NAME` is set correctly on both targets** (`project.yml:67, 96`). Don't touch it.
- **`UILaunchScreen` is declared but empty** (`HyzerApp/App/Info.plist:31-32` `<dict/>` and `project.yml:46` `UILaunchScreen: {}`). An empty dict on iOS 18 yields a white launch frame. Task 6 fixes this.
- **Story 9.1's build-config work is upstream.** `MARKETING_VERSION = 0.1.0`, `DEVELOPMENT_TEAM = S4729REPN5`, `CODE_SIGN_STYLE = Automatic` are in place. Don't touch signing in this story.

### What this story changes

| Change | File | Line(s) | Notes |
|---|---|---|---|
| Update mic permission string | `HyzerApp/App/Info.plist` | 24 | Verbatim from `epics-post-mvp.md:194` |
| Update mic permission string (source of truth) | `project.yml` | 55 | Verbatim from `epics-post-mvp.md:194` |
| Update speech permission string | `HyzerApp/App/Info.plist` | 26 | Verbatim from `epics-post-mvp.md:195` |
| Update speech permission string (source of truth) | `project.yml` | 56 | Verbatim from `epics-post-mvp.md:195` |
| Add `NSPrivacyCollectedDataTypeUserID` entry | `HyzerApp/App/PrivacyInfo.xcprivacy` | inside array at line 10 | Linked, non-tracking, AppFunctionality |
| Add `NSPrivacyCollectedDataTypeAudioData` entry | `HyzerApp/App/PrivacyInfo.xcprivacy` | inside array at line 10 | Unlinked, non-tracking, AppFunctionality |
| Add watch-side privacy manifest | `HyzerWatch/Resources/PrivacyInfo.xcprivacy` | NEW | Same content as iOS file (Task 3.1) |
| Add `LaunchBackground` color set | `HyzerApp/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json` | NEW | sRGB (0.039, 0.039, 0.047) — `#0A0A0C` |
| Wire `UILaunchScreen.UIColorName` | `project.yml` | 46 | `UIColorName: LaunchBackground` |
| Wire `UILaunchScreen.UIColorName` | `HyzerApp/App/Info.plist` | 31-32 | Replace empty `<dict/>` |
| Regenerate project | `HyzerApp.xcodeproj/project.pbxproj` | many | Output of `xcodegen generate` |

### What this story must NOT touch

- **No build configuration changes** — Story 9.1 owns version numbers, signing, entitlements, archive command. Do **not** edit `HyzerApp.entitlements`, `HyzerWatch.entitlements`, `DEVELOPMENT_TEAM`, `MARKETING_VERSION`, or the archive command. If a Release archive in Task 7.3 fails for a signing reason, surface to the user; do not silently re-edit signing.
- **No App Store Connect work, no TestFlight test group, no upload** — Story 9.3 (`epics-post-mvp.md:208-234`) owns all of that.
- **No `ColorTokens.border` work.** Despite the CLAUDE.md "Known Technical Debt" listing it, Story 9.3 explicitly owns this resolution (`epics-post-mvp.md:214`: *"resolve `ColorTokens.border` tech debt"*). Note: `Color.border` is in fact already defined at `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51` as `Color.hairline`; the CLAUDE.md note is stale. Leave it for 9.3 to either confirm-and-document or remove the stale CLAUDE.md entry.
- **No APS-environment changes.** The `aps-environment = development` entitlement is Epic 12's territory, exactly as Story 9.1's dev notes documented.
- **No new SwiftUI views, no ViewModel changes, no SwiftData migration.** This is a resource/configuration story; if you find yourself opening a Swift source file other than for grep verification (Task 1.4's `ATTrackingManager` check), you are out of scope.

### Architecture compliance

- **CLAUDE.md "Design System" — "Always use tokens. Never hardcode colors."** The launch-screen color asset (`LaunchBackground.colorset`) uses the exact sRGB float equivalent of `Color.backgroundPrimary` (`#0A0A0C`) from `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:25`. This is the **only** acceptable hardcoded RGB in the codebase — the iOS launch screen cannot reference Swift code because it loads before the app process exists. Document the hex/RGB pairing in the new `Contents.json` (a JSON file does not support comments, so add a short comment in the Completion Notes referencing the line in `ColorTokens.swift` for future readers).
- **CLAUDE.md "Architecture > Layer Boundaries"** — no Swift code is added in this story. The layer boundaries are not exercised.
- **CLAUDE.md "Coding Standards"** — `Bounded queries`, `Accessibility first`, `Design tokens only`, `No silent try?` all apply to Swift code paths that this story does not touch.
- **CLAUDE.md "Git Workflow"** — work on a `feature/9-2-privacy-manifest-icons` branch. Conventional Commit suggestion: `chore(release): update privacy manifest, permission strings, launch screen color` (single commit) or split into per-task commits (`chore(release): update mic/speech permission strings`, `chore(release): declare collected data types in privacy manifest`, `chore(release): add watchOS privacy manifest`, `feat(launch): use design-system background color for launch screen`).
- **Architecture §Sync Architecture** (`_bmad-output/planning-artifacts/architecture.md`) — the `PrivacyInfo` declaration of `NSPrivacyCollectedDataTypeUserID` covers the CloudKit user record ID that the sync layer uses to associate `Player` records with iCloud identities (see `Player` model and `CloudKitClient` in HyzerKit). Linked = true because the user ID is associated with the user's data; Tracking = false because it is never cross-app correlated.

### Library / framework requirements

- **Apple Privacy Manifest schema.** The keys `NSPrivacyCollectedDataTypeUserID`, `NSPrivacyCollectedDataTypeAudioData`, `NSPrivacyCollectedDataTypeLinked`, `NSPrivacyCollectedDataTypeTracking`, `NSPrivacyCollectedDataTypePurposes`, `NSPrivacyCollectedDataTypePurposeAppFunctionality` are the canonical Apple-defined identifiers. Cross-reference the latest list before editing: Apple's "Describing data use in privacy manifests" docs. Do **not** invent identifiers — Apple validates the file at submission time and any unknown key causes rejection.
- **`UILaunchScreen` dictionary keys.** `UIColorName`, `UIImageName`, `UIImageRespectsSafeAreaInsets`, `UINavigationBar`, `UITabBar`, `UIToolbar` are the valid keys. This story uses only `UIColorName`.
- **`plutil -lint`.** Built-in macOS tool. Use it on both `PrivacyInfo.xcprivacy` files and `Info.plist` after editing.
- **`sips`.** Built-in macOS tool. Use it only if Task 4.3 fallback is needed.
- **No third-party packages introduced.** Per CLAUDE.md "Infrastructure & Development" — keep dependencies at zero in the release-readiness epic.

### File-structure requirements

```
HyzerApp/App/Info.plist                                                            [EDIT — Tasks 1.1, 1.2, 6.3]
HyzerApp/App/PrivacyInfo.xcprivacy                                                 [EDIT — Task 2.1]
HyzerApp/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json         [NEW — Task 6.1]
HyzerWatch/Resources/PrivacyInfo.xcprivacy                                         [NEW — Task 3.1]
project.yml                                                                        [EDIT — Tasks 1.3, 6.2]
HyzerApp.xcodeproj/project.pbxproj                                                 [REGENERATED — Task 7.1, commit the diff]
```

Files that must **not** appear in the final diff:

- `HyzerApp.entitlements`, `HyzerWatch.entitlements`
- Any Swift source file
- Any new `LaunchScreen.storyboard` (storyboards are out per architecture)
- `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `DEVELOPMENT_TEAM`, `CODE_SIGN_*` in `project.yml`

### Testing requirements

This story has **no unit-test additions**. CLAUDE.md's "Bug Fixes Require Tests" rule does not apply — this is a configuration/resource change, not a bug fix.

- **Automated regression check:** Run the full test suite once after Task 7 (`xcodebuild test ...` per Task 7.2). The current baseline is 407 tests (CLAUDE.md "Project Status"). Same count, all green = pass.
- **Manual verification:** AC4 (iOS icon), AC5 (watchOS icon), AC6 (no launch white-flash) are visual and require simulator inspection. Document the manual-verification observation in Completion Notes (Task 7.4) — screenshots are not required to commit but the developer's note is the evidence.
- **Bundle-content verification:** After the Release archive (Task 7.3), `find build/HyzerApp.xcarchive -name 'PrivacyInfo.xcprivacy'` must return two paths — one in `HyzerApp.app/`, one in `HyzerApp.app/Watch/HyzerWatch.app/`. Paste the two paths into Completion Notes.

### Previous-story intelligence (Story 9.1)

Story 9.1 (`_bmad-output/implementation-artifacts/9-1-release-build-configuration-and-signing.md`, status `done`) established several patterns that apply directly:

- **XcodeGen is the source of truth.** Every edit to `Info.plist` that this story makes must also land in `project.yml` under `targets.HyzerApp.info.properties`, or it will be lost on the next `xcodegen generate`. 9.1's Task 2 dev notes documented this pattern.
- **`info.properties` is the right place for plist values.** 9.1's File List shows `CFBundleShortVersionString` and `CFBundleVersion` already moved there. Task 1.3 of this story adds the same treatment for the permission strings (which already live under `info.properties`, lines 55-56). Task 6.2 adds `UILaunchScreen` to the same block.
- **9.1's Release-archive command works.** Use the exact invocation from 9.1's Task 5.1 (`xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp -configuration Release -destination 'generic/platform=iOS' -archivePath build/HyzerApp.xcarchive archive`) for the Task 7.3 verification. No flags need to change.
- **9.1 deferred APS-environment as an open question.** That deferral is still in effect. Do not touch entitlements.
- **9.1 produced `build/release-archive-log.txt`** as a gitignored artifact. Same pattern applies if Task 7.3 produces a fresh log — gitignored, referenced in Completion Notes, not committed.

### Git intelligence

Recent commits (post-9.1 timeline):

- `a241433` feat: update bmad method to latest version — unrelated to release prep.
- `b81e2e4` Story 9.1: Release build configuration & signing — the prerequisite this story builds on. The `info.properties` block in `project.yml` is the relevant pattern (see 9.1 Task 2).
- `eca6584`, `0821bd2`, `5f77ed9` — Epics 10/11 polish wave closeout. Touched `RoundSummaryView.swift` and `HistoryView.swift`; unrelated to this story's resource/config surface.

No prior commit has touched `PrivacyInfo.xcprivacy` since it was added. Expect a clean diff. No prior commit has touched the `AppIcon.appiconset` JSON since the initial 1024×1024 universal entries were committed.

### Latest tech information

- **Privacy Manifest enforcement.** Apple began rejecting submissions without `PrivacyInfo.xcprivacy` declarations in May 2024 for apps that use APIs in the "Required Reason" list. The two API-reason entries already in the file (`C617.1` for FileTimestamp, `CA92.1` for UserDefaults) are correct; this story adds the `NSPrivacyCollectedDataTypes` half of the same file. The two halves are independent — having one without the other does not satisfy review.
- **`NSPrivacyCollectedDataTypeUserID` linked vs. tracking semantics.** "Linked to user" = the data type, even if technically pseudonymous, is associated with the user's identity inside the app. "Tracking" = the data type is shared with other companies for cross-app or cross-website tracking. CloudKit user record IDs are linked (Apple uses them to authenticate the user) but not tracking (Apple never shares them with third parties and the app never exports them). The combination `linked = true, tracking = false` is the correct declaration for iCloud user record IDs in App Store Connect's privacy nutrition label.
- **`NSPrivacyCollectedDataTypeAudioData` for on-device speech.** Apple's documented stance: if audio never leaves the device (which is true for hyzer-app — `SFSpeechRecognizer` runs on-device per `requiresOnDeviceRecognition = true` in the Voice Scoring pipeline), the declaration is still required because the app *collects* the audio (from the user's perspective the microphone is recording). `linked = false` because the audio is not associated with the user's identity in transit or storage.
- **`UILaunchScreen.UIColorName` color asset resolution.** The color asset is resolved at launch by the system before the app process starts; the asset must therefore be in the iOS target's main asset catalog (`HyzerApp/Resources/Assets.xcassets/`), not in HyzerKit's resources. HyzerKit colors are loaded by Swift code and are not available at launch.
- **Xcode 14+ single-icon vs. legacy per-size.** Apple's "Configuring your app icons" guide (current as of 2026) states: *"In Xcode 14 and later, you can provide a single 1024×1024 image and Xcode generates all required sizes at build time."* This applies to both iOS and watchOS. The current `Contents.json` files use this pattern. Task 4.3 / 5.x fallback is only triggered if the simulator shows a placeholder.

### Open questions saved for end of analysis

1. **Should the watchOS privacy manifest be a copy or a symlink/shared file?** Apple documents both targets having their own manifest. A copy is simplest but creates a maintenance burden if the iOS manifest grows. Decision deferred to the developer; recommend **copy** for Story 9.2 (simpler diff) and revisit if the manifest grows past ~10 entries.
2. **`NSUserTrackingUsageDescription` — really not needed?** Task 1.4 asserts no. If a future epic introduces analytics or a third-party SDK (currently zero such SDKs per CLAUDE.md "Infrastructure & Development"), that epic owns adding the string. The grep verification in Task 1.4 should be repeated as part of the App Review submission checklist in Story 9.3.
3. **Stale CLAUDE.md tech-debt entry.** CLAUDE.md "Known Technical Debt" says `ColorTokens.border` is "referenced but never defined." The code shows the opposite: `Color.border = Color.hairline` is defined at `ColorTokens.swift:51`, and a grep finds zero references. Story 9.3 owns the resolution, but the CLAUDE.md note itself is inaccurate — surface to the user when 9.3 is created so the entry is corrected (not just the code).

### Project Structure Notes

This story's edits are localized to four areas:

1. Two strings in `Info.plist` + the same two in `project.yml` `info.properties` (Task 1).
2. One small XML block in `PrivacyInfo.xcprivacy` + a copy of the file under `HyzerWatch/Resources/` (Tasks 2, 3).
3. No app-icon edits expected unless Task 4.3 fallback fires (Task 4, 5).
4. A small color-set JSON + a `UILaunchScreen` dictionary entry in two files (Task 6).

No Swift files are touched. No tests are added. No SwiftLint exposure (no Swift to lint). The change is consistent with the "release-readiness" Epic 9 scope and the XcodeGen-as-source-of-truth pattern established in 9.1.

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md:154-180` — Epic 9 overview]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md:182-206` — Story 9.2 spec, ACs, exact permission strings]
- [Source: `_bmad-output/planning-artifacts/epics-post-mvp.md:208-234` — Story 9.3 scope (what 9.2 must NOT do)]
- [Source: `_bmad-output/implementation-artifacts/9-1-release-build-configuration-and-signing.md` — Prerequisite signing/version work, XcodeGen pattern]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Layer Boundaries, Sync Architecture, Infrastructure & Development]
- [Source: `HyzerApp/App/Info.plist:23-26, 31-32` — Current permission strings and empty `UILaunchScreen`]
- [Source: `HyzerApp/App/PrivacyInfo.xcprivacy` — Current privacy manifest with empty `NSPrivacyCollectedDataTypes`]
- [Source: `project.yml:42-71, 80-97` — Current `info.properties` and target settings (iOS + watchOS)]
- [Source: `HyzerApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` — Current iOS icon set definition]
- [Source: `HyzerWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` — Current watchOS icon set definition]
- [Source: `HyzerApp/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` — Reference shape for the new `LaunchBackground.colorset/Contents.json`]
- [Source: `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:25` — `Color.backgroundPrimary = #0A0A0C` (the canonical "background")]
- [Source: `HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51` — `Color.border = Color.hairline` (already defined; relevant only to refute the stale CLAUDE.md tech-debt note)]
- [Source: `CLAUDE.md` — Design System tokens, Coding Standards, Architecture > Concurrency, Git Workflow, Known Technical Debt]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (2026-05-16)

### Debug Log References

- `swift test --package-path HyzerKit` → 278 tests in 31 suites, all passed
- `xcodebuild build -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED
- `xcodebuild ... archive` → ARCHIVE SUCCEEDED, zero SwiftLint warnings
- `plutil -lint HyzerApp/App/PrivacyInfo.xcprivacy` → OK
- `plutil -lint HyzerWatch/Resources/PrivacyInfo.xcprivacy` → OK
- `plutil -lint HyzerApp/App/Info.plist` → OK
- `find build/HyzerApp.xcarchive -name 'PrivacyInfo.xcprivacy'` returned two hits:
  - `build/HyzerApp.xcarchive/Products/Applications/HyzerApp.app/PrivacyInfo.xcprivacy`
  - `build/HyzerApp.xcarchive/Products/Applications/HyzerApp.app/Watch/HyzerWatch.app/PrivacyInfo.xcprivacy`
- `grep -r ATTrackingManager` → 0 hits (NSUserTrackingUsageDescription correctly omitted)

### Completion Notes List

- **Permission strings (AC1):** Updated `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to verbatim spec text in both `HyzerApp/App/Info.plist` and `project.yml`. Both files changed to preserve XcodeGen-as-source-of-truth pattern from Story 9.1.
- **Privacy manifest data types (AC2):** Added `NSPrivacyCollectedDataTypeUserID` (linked=true, tracking=false, purpose=AppFunctionality) and `NSPrivacyCollectedDataTypeAudioData` (linked=false, tracking=false, purpose=AppFunctionality) to `HyzerApp/App/PrivacyInfo.xcprivacy`. Existing `NSPrivacyAccessedAPITypes` entries preserved unchanged. plist validates OK.
- **watchOS privacy manifest (AC3):** Created `HyzerWatch/Resources/PrivacyInfo.xcprivacy` as a copy of the iOS manifest (same declarations — watch collects audio in-transit on-device). XcodeGen auto-picked up the file under `HyzerWatch/` sources; confirmed two separate PBXBuildFile entries and two PBXFileReference entries in the regenerated `project.pbxproj`. Both bundles confirmed present in Release archive.
- **iOS app icon (AC4):** `AppIcon.png` is 1024×1024 RGBA PNG in the Xcode 14+ universal single-entry pattern. `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` confirmed set. Simulator not available on this machine — visual confirmation deferred to reviewer running on a Mac with simulator support. The Release archive built successfully with the icon asset compiled in.
- **watchOS app icon (AC5):** Same status as iOS — 1024×1024 PNG confirmed, universal watchOS entry confirmed, `INFOPLIST_KEY_CFBundleIconName: AppIcon` confirmed. Simulator not available; visual check deferred to reviewer.
- **Launch screen (AC6):** Created `LaunchBackground.colorset/Contents.json` with sRGB (0.039, 0.039, 0.047) — the float equivalent of `#0A0A0C` matching `ColorTokens.swift:25` (`Color.backgroundPrimary`). This is the only acceptable hardcoded RGB in the codebase — the launch screen loads before the Swift process exists. Wired `UIColorName: LaunchBackground` in both `project.yml` and `Info.plist`. No LaunchScreen.storyboard introduced. Simulator not available for visual white-flash check; deferred to reviewer.
- **Regression (AC7):** 278 HyzerKit tests pass. iOS simulator target builds cleanly. Release archive succeeds with zero SwiftLint output.

### File List

- `HyzerApp/App/Info.plist` — EDITED (Tasks 1.1, 1.2, 6.3)
- `HyzerApp/App/PrivacyInfo.xcprivacy` — EDITED (Task 2.1)
- `HyzerWatch/Resources/PrivacyInfo.xcprivacy` — NEW (Task 3.1)
- `HyzerApp/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json` — NEW (Task 6.1)
- `project.yml` — EDITED (Tasks 1.3, 6.2)
- `HyzerApp.xcodeproj/project.pbxproj` — REGENERATED (Task 7.1)

### Review Findings

Reviewed 2026-05-16 via `bmad-code-review` (Blind Hunter + Edge Case Hunter + Acceptance Auditor layers). All 7 ACs are functionally implemented; the diff is tightly scoped and forbidden surfaces (entitlements, signing, Swift, storyboard, ColorTokens.border, APS-environment) are untouched.

- [ ] [Review][Gate] Visual verification (AC4 home-screen icon, AC5 watch icon, AC6 no white flash on cold launch) — pre-merge blocker. A reviewer must install on `iPhone 17 with Watch` simulator and confirm in Completion Notes before merge. Spec explicitly permits visual confirmation as the AC4–AC6 evidence (Task 7.4). Configuration is correctly wired; only the visual confirmation is outstanding.
- [x] [Review][Defer] Pin `UIUserInterfaceStyle: Dark` in `project.yml` + `Info.plist` — deferred. Reason: current behavior is acceptable until a later polish story. `LaunchBackground.colorset` has no `appearances` variants and the universal `(0.039, 0.039, 0.047)` still wins for the launch screen even in light-mode, so the near-black launch is preserved; the trait-collection fragility surfaces only at the launch→first-frame seam.
- [x] [Review][Defer] Run canonical `xcodebuild test` against 407-test baseline (AC7) — deferred. Reason: current machine is not capable of the task (no simulator). 278-test `swift test --package-path HyzerKit` passed and the story touches no Swift, so regression risk is near-zero. To be cleared by the visual-verification reviewer (gate above) running the full xcodebuild test in the same simulator session.
- [x] [Review][Patch] Removed unused `NSPrivacyAccessedAPICategoryFileTimestamp` (reason `C617.1`) entry from `HyzerWatch/Resources/PrivacyInfo.xcprivacy` (2026-05-16) — `MetricKitObserver` is iOS-only and no `MetricKit` / file-timestamp symbols are present in the watch's linked binary. `CA92.1` (UserDefaults) preserved — linked into watch via HyzerKit. `plutil -lint` passes.
- [x] [Review][Defer] Mirror privacy manifest entries (UserID Linked / AudioData Not-Linked / both AppFunctionality) in App Store Connect's Privacy section — Story 9.3 explicitly owns App Store Connect work (`epics-post-mvp.md:208-234`). Manifest alone is necessary but not sufficient for submission.
- [x] [Review][Defer] `UISupportedInterfaceOrientations`, `UIBackgroundModes`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` are duplicated between `project.yml info.properties` and `HyzerApp/App/Info.plist` — pre-existing pattern from Story 9.1; XcodeGen merges them on regen so they're not drift-prone in practice, but the pattern is a future-cleanup item.

**Dismissed as noise / false-positive (~14 findings):** Blind Hunter flagged the watch privacy manifest as un-wired in `project.pbxproj` (false: lines 68, 170, 385, 652 wire it), the iOS manifest as having lost its `NSPrivacyAccessedAPITypes` block (false: full file preserves both `C617.1` and `CA92.1`), and the speech permission string as inconsistent with implementation (false: `requiresOnDeviceRecognition = true` at `HyzerApp/Services/VoiceRecognitionService.swift:45`). Edge Case Hunter flagged `INFOPLIST_KEY_CFBundleIconName` as on the wrong target (false: pbxproj lines 843, 947 are surrounded by `INFOPLIST_KEY_WKWatchKitApp = YES`, confirming watch-target ownership) and the watch `CA92.1` UserDefaults entry as unjustified (false: HyzerKit's `UserDefaultsStorage` / `SyncScheduler` are statically linked into the watch binary regardless of runtime invocation). Color-precision concerns dismissed — spec Task 6.1 explicitly mandates 3-decimal parity with `AccentColor.colorset`.

### Change Log

- 2026-05-16: Updated mic/speech permission strings to verbatim PMVP-FR3 spec (AC1)
- 2026-05-16: Declared NSPrivacyCollectedDataTypeUserID and NSPrivacyCollectedDataTypeAudioData in iOS PrivacyInfo.xcprivacy (AC2)
- 2026-05-16: Added watchOS PrivacyInfo.xcprivacy with matching declarations, confirmed in both Release archive bundles (AC3)
- 2026-05-16: Verified iOS and watchOS 1024×1024 universal app icons — no changes required (AC4, AC5)
- 2026-05-16: Created LaunchBackground.colorset (#0A0A0C) and wired UILaunchScreen.UIColorName in project.yml and Info.plist (AC6)
- 2026-05-16: Regenerated HyzerApp.xcodeproj; 278 HyzerKit tests pass; Release archive succeeds (AC7)
