## Deferred from: code review of 9-1-release-build-configuration-and-signing.md (2026-05-16)

- APS environment `aps-environment = development` in `HyzerApp/App/HyzerApp.entitlements:21` — App Store-bound Release archive carries dev APS env. Spec open question #1 parks this until Epic 12 flips it to `production`. Risk surfaces at Story 9.3 upload, not at 9.1 archive/export.
- Test targets inherit `DEVELOPMENT_TEAM` from `project.yml:20` global `settings.base` — harmless locally; signing unit-test bundles can fail on a CI agent without the team's Apple ID. Revisit when CI is introduced (Epic 13 / future story).

## Deferred from: code review of 11-3-share-round-summary-via-system-share-sheet.md (2026-05-14)

- Hardcoded English Strings (Localization Risk) in `RoundSummaryViewModel.swift` — The share caption is built using hardcoded string literals. This follows existing project patterns but should be addressed when localization is prioritized.
