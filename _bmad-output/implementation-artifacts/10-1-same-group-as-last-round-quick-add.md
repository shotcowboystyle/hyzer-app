# Story 10.1: "Same Group as Last Round" Quick-Add

Status: done

## Story

As a user starting a round with the usual group,
I want a one-tap option to reuse the player list from my most recent completed round,
so that I don't retype six names every Saturday.

## Acceptance Criteria

1. **Given** the user has at least one completed round in their local history, **when** the Add Players screen is shown during new round creation, **then** a "Same group as last round" button is visible above the manual add controls (PMVP-FR9), **and** the button label includes a preview of how many players will be added (e.g., "Same group as last round (6 players)").

2. **Given** the user taps "Same group as last round", **when** the action commits, **then** all registered players from the most recent completed round are added to the current round, **and** all guest players from that round are added as new guest entries (round-scoped, no deduplication — consistent with FR12b), **and** the user can still remove individual players, add more players, or add additional guests before tapping Start Round.

3. **Given** the user has no completed rounds in history, **when** the Add Players screen is shown, **then** the "Same group as last round" button is hidden (no fallback to seeded suggestion).

4. **Given** VoiceOver is active, **when** the "Same group as last round" button receives focus, **then** the announced label includes the player count and a hint ("Adds 6 players. Double-tap to apply.").

## Tasks / Subtasks

- [ ] Task 1: Add previous-round lookup to `RoundSetupViewModel` (AC: 1, 2, 3)
  - [ ] 1.1 Add `previousRoundPreview: PreviousRoundPreview?` published state on `RoundSetupViewModel`
  - [ ] 1.2 Add `loadPreviousRoundPlayers(currentUserID: UUID, modelContext: ModelContext)` method
        — fetches the most recent `Round` where `status == "completed"` AND `playerIDs` contains `currentUserID.uuidString`, with `fetchLimit: 1`, sorted by `completedAt` descending
  - [ ] 1.3 Define `struct PreviousRoundPreview { let registeredPlayers: [Player]; let guestNames: [String]; var totalCount: Int }` — value type, `Identifiable` not required
  - [ ] 1.4 Add `applyPreviousRoundPlayers(organizer: Player)` method that merges `previousRoundPreview.registeredPlayers` (excluding the organizer) into `addedPlayers` (deduped) and appends `guestNames` to `self.guestNames`
  - [ ] 1.5 Computed `canShowSameGroupButton: Bool` returns `previousRoundPreview != nil && (previousRoundPreview!.registeredPlayers.count + previousRoundPreview!.guestNames.count) > 0`

- [ ] Task 2: Wire the load call and surface the button in `RoundSetupView` (AC: 1, 3, 4)
  - [ ] 2.1 In `RoundSetupView.onAppear` (or `.task`), call `viewModel.loadPreviousRoundPlayers(currentUserID: organizer.id, modelContext: modelContext)`
  - [ ] 2.2 In the `playerSection` body, render a `Button` ABOVE the search results when `viewModel.canShowSameGroupButton == true`
  - [ ] 2.3 Button label: `"Same group as last round (\(preview.totalCount) players)"`
  - [ ] 2.4 Button styling matches existing tappable rows: `Color.accentPrimary` foreground, `Color.backgroundElevated` row background, `minHeight: SpacingTokens.minimumTouchTarget`, `TypographyTokens.body`
  - [ ] 2.5 Hide the button entirely when `canShowSameGroupButton == false` — no placeholder text, no fallback

- [ ] Task 3: Apply action + preserve editability (AC: 2)
  - [ ] 3.1 Button action calls `viewModel.applyPreviousRoundPlayers(organizer: organizer)`
  - [ ] 3.2 Verify that after the action the user can still: remove a registered player (existing tap behavior), remove a guest (existing swipe-to-delete), add new players via search, add new guests via the guest field
  - [ ] 3.3 Tapping the button a second time is a no-op (idempotent — existing `addPlayer` dedup logic already handles this; verify the guest list also doesn't re-append duplicates if tapped twice — append a one-shot guard: clear `previousRoundPreview` after apply OR check whether the preview's guests are already present)

- [ ] Task 4: Accessibility (AC: 4)
  - [ ] 4.1 `accessibilityLabel("Same group as last round")` on the button
  - [ ] 4.2 `accessibilityHint("Adds \(preview.totalCount) players. Double-tap to apply.")`
  - [ ] 4.3 `accessibilityAddTraits(.isButton)` — explicit even though SwiftUI `Button` infers it (matches the pattern elsewhere in `RoundSetupView`)

- [ ] Task 5: Tests (AC: 1, 2, 3)
  - [ ] 5.1 `RoundSetupViewModelTests.test_loadPreviousRoundPlayers_withCompletedRound_populatesPreview` — seed one `completed` round including the current user, assert preview has expected counts
  - [ ] 5.2 `test_loadPreviousRoundPlayers_noCompletedRounds_previewIsNil`
  - [ ] 5.3 `test_loadPreviousRoundPlayers_completedRoundUserNotParticipant_previewIsNil` — the query MUST require current user is in `playerIDs`; rounds the user did not play in are not eligible
  - [ ] 5.4 `test_loadPreviousRoundPlayers_picksMostRecent_byCompletedAtDesc` — seed two completed rounds, expect the newer
  - [ ] 5.5 `test_applyPreviousRoundPlayers_appendsRegisteredAndGuestEntries_excludesOrganizer`
  - [ ] 5.6 `test_applyPreviousRoundPlayers_doesNotDuplicateAlreadyAddedPlayers` — relies on existing `addPlayer` dedup
  - [ ] 5.7 `test_applyPreviousRoundPlayers_appendsGuestsAsNewEntries_noGuestDeduplication` — FR12b

## Dev Notes

### Architecture & Patterns

- **ViewModel pattern:** `@MainActor @Observable final class` (`RoundSetupViewModel` already exists at `HyzerApp/ViewModels/RoundSetupViewModel.swift`). Mutate state on the main actor; no `DispatchQueue`.
- **ModelContext usage:** `RoundSetupViewModel` does NOT hold `ModelContext` — it receives it at call time (matches `startRound(organizer:in:)` and the `CourseEditorViewModel` pattern). Pass `modelContext` into `loadPreviousRoundPlayers` from the view.
- **Round fetch:** Use `FetchDescriptor<Round>` with `predicate` filtering on `status == "completed"` AND `playerIDs.contains(currentUserIDString)`, `sortBy: [SortDescriptor(\Round.completedAt, order: .reverse)]`, `fetchLimit = 1`. Bounded query per project standard ("every SwiftData fetch must have `fetchLimit`" — CLAUDE.md).
- **`Round.status` is a stringly-typed field** that mirrors `lifecycleState` (the model uses `status` as the persisted value; see `HyzerKit/Sources/HyzerKit/Models/Round.swift`). The string `"completed"` is the persisted value for the `.completed` lifecycle state — verify by reading `Round.swift` if unsure.
- **Player resolution from `playerIDs`:** `Round.playerIDs` is `[String]` (UUID strings). To rebuild the `Player` list, fetch `Player` records whose `id.uuidString` is in that set with a separate bounded query. Exclude the organizer from the merged list (the organizer is auto-added when starting a new round — see `RoundSetupViewModel.startRound`, which prepends `organizer.id.uuidString` to `allPlayerIDs`).
- **Guest handling (FR12b):** Guests are round-scoped strings, NOT cross-round identities. The preview surfaces `Round.guestNames: [String]` from the previous round and appends them verbatim to the new round's `guestNames`. New `guestIDs` will be generated automatically at `Round.init` time via `GuestIdentifier.makeID()` (see `Round.swift:72`). Do NOT copy `guestIDs` across rounds — guest identity is per-round.

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| `RoundSetupViewModel.addPlayer(_:)` | `HyzerApp/ViewModels/RoundSetupViewModel.swift:29` | Use to merge each previous-round registered player; existing dedup by `id` |
| `RoundSetupViewModel.guestNames` array | `HyzerApp/ViewModels/RoundSetupViewModel.swift:15` | Append previous-round guest names directly (no `addGuest` because that path reads from `guestNameInput`) |
| `Round.playerIDs` / `Round.guestNames` | `HyzerKit/Sources/HyzerKit/Models/Round.swift` | Fields to read from the resolved previous round |
| Player fetch by UUID set | Use `FetchDescriptor<Player>` with `#Predicate { ids.contains($0.id) }` and a bounded `fetchLimit` | |
| `playerSection` layout | `HyzerApp/Views/Rounds/RoundSetupView.swift:105` | Add the quick-add button as the first row of this section, above the `ForEach(filteredPlayers)` |
| Existing list-row styling | `Color.backgroundElevated`, `TypographyTokens.body`, `Color.accentPrimary` | Match guest "Add" button and player tap rows |

### File Structure

**Files to modify:**
```
HyzerApp/ViewModels/RoundSetupViewModel.swift           # Add loadPreviousRoundPlayers + apply + preview state
HyzerApp/Views/Rounds/RoundSetupView.swift              # Add button in playerSection; .onAppear wiring
```

**Test files to add or extend:**
```
HyzerAppTests/ViewModels/RoundSetupViewModelTests.swift # If it doesn't exist, create it; otherwise extend
```

**Update `project.yml`?** No — XcodeGen auto-discovers `.swift` files.

### SwiftData Query Notes

- `#Predicate<Round>` filtering on `playerIDs.contains(idString)` is supported in iOS 18 SwiftData. If the compiler rejects the predicate (string-array containment can be tricky), fall back to fetching the most recent completed round (bounded `fetchLimit: 5`) and filtering in-memory by `playerIDs.contains(currentUserID.uuidString)`. Either approach satisfies the bounded-query rule.
- The predicate captures `currentUserID.uuidString` — assign it to a `let` before the predicate closure to satisfy `#Predicate` capture rules (the same pattern called out in Story 8.1 review notes for `FetchDescriptor<Course>`).

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test`) — not XCTest.
- **SwiftData tests:** `ModelConfiguration(isStoredInMemoryOnly: true)`.
- **Fixtures:** Reuse `Player+Fixture`, `Round+Fixture`, `Course+Fixture` from `HyzerKit/Tests/HyzerKitTests/Fixtures/` (move what you need into the iOS app test target if not already accessible).
- **Naming:** `test_{method}_{scenario}_{expectedBehavior}`.

### Scope Boundaries — Do NOT Implement

- Choosing from a list of past rounds (this story is "most recent only").
- Saving a "favorite group" template (out of scope; that's a future story if at all).
- Modifying `RoundSetupView.courseSection` — course selection is separate.
- Any cross-round guest deduplication — guests remain round-scoped per FR12b.

### Previous Story Intelligence (3.1, 8.1)

- Story 3.1 established `RoundSetupView` and `RoundSetupViewModel`; the participant model (organizer always included; `playerIDs` flat strings; guests via index-aligned `guestNames` + `guestIDs`) is unchanged here.
- Story 8.1 established the bounded-query + `let` capture pattern for `#Predicate` — apply the same pattern here.

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Epic 10, Story 10.1] — user story, scope, ACs
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#PMVP-FR9] — feature requirement
- [Source: HyzerKit/Sources/HyzerKit/Models/Round.swift] — `playerIDs`, `guestNames`, `guestIDs`, `status`
- [Source: HyzerApp/ViewModels/RoundSetupViewModel.swift] — extension target
- [Source: HyzerApp/Views/Rounds/RoundSetupView.swift] — playerSection insertion point
- [Source: CLAUDE.md#Coding Standards] — bounded queries, design tokens only
- [Source: _bmad-output/planning-artifacts/epics.md#FR12b] — guests are round-scoped, no deduplication

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Patch] Potential Type Mismatch in Predicate [RoundSetupViewModel.swift]
- [x] [Review][Patch] Boundary Condition (Fetch Window) [RoundSetupViewModel.swift]
- [x] [Review][Patch] Hardcoded Development Team [HyzerApp.xcodeproj/project.pbxproj]
- [x] [Review][Defer] Inconsistent Predicate Logic [RoundSetupViewModel.swift] — deferred, pre-existing
- [x] [Review][Patch] Fixed inconsistent error handling in loadPreviousRoundPlayers [RoundSetupViewModel.swift]
