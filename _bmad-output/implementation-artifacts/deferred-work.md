## Deferred from: code review of 11-3-share-round-summary-via-system-share-sheet.md (2026-05-14)

- Hardcoded English Strings (Localization Risk) in `RoundSummaryViewModel.swift` — The share caption is built using hardcoded string literals. This follows existing project patterns but should be addressed when localization is prioritized.
