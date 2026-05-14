# Deferred Work

## Deferred from: code review (2026-05-14) - Story 10.1, 10.2, 11.1

- [Review][Defer] Inconsistent Predicate Logic [RoundSetupViewModel.swift] — deferred, pre-existing
- [Review][Defer] Localization/Grammar (Hardcoded Par Phrases) [HoleCardView.swift] — deferred, pre-existing
- [Review][Defer] Fixed-Width Snapshot Constraints [RoundSummaryView.swift] — deferred, pre-existing
- [Review][Defer] Duplicate ShareSheetRepresentable [RoundSummaryView.swift] — deferred, pre-existing
- [Review][Defer] Stringly-Typed Lifecycle State [HyzerKit/Sources/HyzerKit/Models/Round.swift] — deferred, pre-existing

## Deferred from: code review of 11-2-screenshot-first-round-summary-card.md (2026-05-14)
- Brittle Layout Fix: `minimumScaleFactor(0.8)` on player names can create inconsistent font sizes across the list. [RoundSummaryView.swift:154]
- Layout Clipping for Large Rounds: Position column has fixed width without `minimumScaleFactor`, risking overflow for 100+ players. [RoundSummaryView.swift]
- Test Integration Overhead: Unit tests perform full model lifecycles instead of mocking. [HyzerAppTests]
