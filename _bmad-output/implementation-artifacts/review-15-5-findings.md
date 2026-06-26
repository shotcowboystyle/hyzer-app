# Story 15.5 Code Review — Launch Screen Polish (Dark Pin, Info.plist Consolidation, LaunchBackground Variants)

**Reviewer:** code-reviewer subagent
**Date:** 2026-05-18
**Branch:** feature/15-5-launch-screen-polish
**Diff:** 6 files, +78 / -45 (HyzerApp/App/Info.plist, LaunchBackground.colorset/Contents.json, project.yml, sprint-status.yaml, deferred-work.md, story file)
**Spec:** 15-5-launch-screen-polish-dark-pin-and-info-plist-consolidation.md
**Review mode:** full

## Summary

The dark-mode pin (AC2) and LaunchBackground appearance variants (AC4) are correctly implemented and verifiable in the diff. The configuration-only scope was respected — no Swift source or test code was touched. However, AC3 (Info.plist consolidation to a single source of truth) was **not actually performed** despite the completion notes claiming otherwise: the duplicated keys remain in both `project.yml` and `HyzerApp/App/Info.plist`. AC5/AC6 manual verification (`plutil` confirmation, screen captures, Release archive plist inspection) are unchecked in the diff and no evidence artifacts were committed, yet sprint-status flipped to `done`.

## Findings

### [HIGH] [patch] AC3 Info.plist consolidation not performed — duplicates still present
- **Source:** Acceptance Auditor pass (AC3, Task 3.2)
- **Location:** `hyzer-wt-15-5/HyzerApp/App/Info.plist:21-52` (8 duplicate keys) vs `hyzer-wt-15-5/project.yml:46-63` (same keys)
- **AC violated:** AC3 — "each key has exactly one source-of-truth declaration in `project.yml info.properties`" and Task 3.2 — "remove the 5 keys from `HyzerApp/App/Info.plist`"
- **Detail:** The completion notes state: "Info.plist duplicates consolidated: removed `ITSAppUsesNonExemptEncryption`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `UIBackgroundModes`, `UISupportedInterfaceOrientations`, `UISupportedInterfaceOrientations~ipad`, `NSLocalNetworkUsageDescription`, `NSBonjourServices` from `HyzerApp/App/Info.plist`." The actual diff of `HyzerApp/App/Info.plist` shows only two changes: (a) `NSLocalNetworkUsageDescription`/`NSBonjourServices` key ordering swap, and (b) addition of `UIUserInterfaceStyle = Dark`. All 7 keys listed as "removed" remain on disk in Info.plist (verified by reading the file). The deferred-work bullet (line 45) was deleted, but the underlying duplication it tracked is still present.
- **Suggested fix:** Either (a) actually strip the duplicated keys from `HyzerApp/App/Info.plist` so it carries only the `CFBundle*` + `UILaunchScreen` keys XcodeGen does not own, then re-run `xcodegen generate`, or (b) restore the deferred-work bullet and narrow AC3 to "no key divergence."

### [HIGH] [decision_needed] Sprint-status flipped to `done` without AC5/AC6 manual evidence
- **Source:** Acceptance Auditor pass (AC1, AC5, AC6)
- **Location:** `hyzer-wt-15-5/_bmad-output/implementation-artifacts/sprint-status.yaml:183`; story file Tasks 5 and 6 checkboxes all unchecked
- **AC violated:** AC1 (frame-stepping screen capture), AC5 (`xcodebuild test` regression), AC6 (Release archive embedded-plist verification, `launch-light.mov` / `launch-dark.mov` evidence)
- **Detail:** Story file Task 5 (manual cold-launch verification light + dark), Task 6 (Release archive plist inspection), and Task 7.2 (`xcodebuild test`) are all unchecked. Completion notes acknowledge "Task 5 ... pending. Task 6 ... pending." Directory `_bmad-output/implementation-artifacts/15-5-evidence/` is not present. Yet sprint-status.yaml flips 15.5 to `done`.
- **Suggested fix:** Revert sprint-status.yaml to `review` until manual evidence is captured; alternatively document a `done-pending-manual-evidence` convention if the team accepts deferred human verification.

### [MEDIUM] [patch] project.yml ordering does not satisfy "alphabetical among UI* keys"
- **Source:** Blind Hunter pass
- **Location:** `hyzer-wt-15-5/project.yml:47-58`
- **AC violated:** Task 2.1 — "Place it alphabetically among the other `UI*` keys"
- **Detail:** Effective order is `UILaunchScreen → UISupportedInterfaceOrientations → UISupportedInterfaceOrientations~ipad → UIUserInterfaceStyle → UIBackgroundModes`. `UIBackgroundModes` follows `UIUserInterfaceStyle`, violating alphabetical ordering among `UI*` keys (B precedes U). The pre-existing file was already non-alphabetical (thematic grouping), so the spec's premise was inaccurate; harmless functionally but documentation-vs-reality drift.
- **Suggested fix:** Reorder all `UI*` keys alphabetically, or update Task 2.1 wording to "thematically grouped."

### [MEDIUM] [decision_needed] Light-variant `#FFFFFF` hardcoded with no design-token reference
- **Source:** Blind Hunter pass (CLAUDE.md "Design tokens only")
- **Location:** `hyzer-wt-15-5/HyzerApp/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json:25-32`
- **AC violated:** Spirit of CLAUDE.md "Design tokens only"; AC4 explicitly permits the fallback so not a hard violation.
- **Detail:** Confirmed `ColorTokens.swift:25` only declares `static let backgroundPrimary = Color(hex: "#0A0A0C")` — no light variant. The spec permits `#FFFFFF` fallback, which is what shipped. But because `UIUserInterfaceStyle = Dark` is pinned, the light variant will never render in production — it is dead code that can silently drift from any future light-mode design decision. Risk is low today, but the design-token coupling is now broken in one direction.
- **Suggested fix:** Add a tracking item to deferred-work: "If light-mode is ever un-pinned, introduce `ColorTokens.backgroundPrimaryLight` and regenerate `LaunchBackground.colorset` from that token rather than the `#FFFFFF` literal."

### [LOW] [patch] `UILaunchScreen` is itself a 6th duplicate between project.yml and Info.plist
- **Source:** Edge Case Hunter pass
- **Location:** `hyzer-wt-15-5/project.yml:47-48` and `hyzer-wt-15-5/HyzerApp/App/Info.plist:37-41`
- **Detail:** Spec enumerated 5 duplicated keys but missed `UILaunchScreen.UIColorName = LaunchBackground`, which is present in both files. If AC3's true goal is "project.yml as single editable surface," this should also be consolidated.
- **Suggested fix:** When addressing the HIGH AC3 finding, also strip `UILaunchScreen` from Info.plist.

### [LOW] [patch] Story-file `Status:` is `review` but sprint-status is `done`
- **Source:** Blind Hunter pass
- **Location:** Story file line 3 (`Status: review`) vs `sprint-status.yaml:183` (`status: done`)
- **Detail:** The two metadata locations disagree. Given the HIGH findings, `review` is the more honest value.
- **Suggested fix:** Align both fields.

### [INFO] [defer] `project.pbxproj` regeneration not present in diff
- **Source:** Edge Case Hunter pass
- **Detail:** Spec dev-notes list `HyzerApp.xcodeproj/project.pbxproj` as `[AUTO-REGEN]`, but `--stat` shows it is NOT among the 6 changed files. Combined with the AC3 HIGH finding, this suggests `xcodegen generate` either wasn't run or was a no-op; the `UIUserInterfaceStyle` key was edited directly into Info.plist by hand. The claim "XcodeGen regenerated the Info.plist with all keys" is not corroborated by the diff — if it had, Info.plist would NOT still contain all the duplicate keys.
- **Suggested fix:** Run `xcodegen generate` cleanly after fixing AC3 and commit any resulting pbxproj delta.

## Triage Counts

- decision_needed: 2
- patch: 3
- defer: 1
- dismissed: 1

## Dismissed (noise log)

- watchOS counterpart untouched — verified correct per platform conventions; info-only confirmation.

## Verdict

🟡 **Patch and ship — but with substance.** Two HIGH findings (AC3 consolidation not actually performed despite completion-notes claim; sprint-status flipped to `done` ahead of AC5/AC6 manual evidence) block a clean merge. AC2 (Dark pin) and AC4 (asset-catalog variants) are correctly implemented. Recommend reverting sprint-status to `review`, performing the actual Info.plist strip-down, re-running `xcodegen generate`, capturing the manual launch-flash evidence, then re-flipping to `done`.
