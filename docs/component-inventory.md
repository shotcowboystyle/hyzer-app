# HyzerApp — Component Inventory

## SwiftData Models

| Model | Store | File | Properties | Key Behavior |
|-------|-------|------|------------|--------------|
| `Player` | Domain | `HyzerKit/Models/Player.swift` | `id`, `displayName`, `iCloudRecordName?`, `aliases: [String]`, `createdAt` | Voice recognition aliases; iCloud identity link |
| `Course` | Domain | `HyzerKit/Models/Course.swift` | `id`, `name`, `holeCount`, `isSeeded`, `createdAt` | Denormalized `holeCount`; `isSeeded` for pre-loaded courses |
| `Hole` | Domain | `HyzerKit/Models/Hole.swift` | `id`, `courseID` (FK), `number`, `par` | Flat FK to Course (no @Relationship) |
| `Round` | Domain | `HyzerKit/Models/Round.swift` | `id`, `courseID` (FK), `organizerID`, `playerIDs: [String]`, `guestNames: [String]`, `status`, `holeCount`, timestamps | State machine: setup → active → awaitingFinalization → completed |
| `ScoreEvent` | Domain | `HyzerKit/Models/ScoreEvent.swift` | `id`, `roundID` (FK), `holeNumber`, `playerID`, `strokeCount`, `supersedesEventID?`, `reportedByPlayerID`, `deviceID`, `createdAt` | Append-only (NFR19); corrections chain via `supersedesEventID` |
| `Discrepancy` | Domain | `HyzerKit/Models/Discrepancy.swift` | `id`, `roundID`, `playerID`, `holeNumber`, `eventID1`, `eventID2`, `status`, `resolvedByEventID?`, `createdAt` | Created by `ConflictDetector` on cross-device conflicts |
| `SyncMetadata` | Operational | `HyzerKit/Sync/SyncMetadata.swift` | `id`, `recordID`, `recordType`, `syncStatus`, `lastAttempt?`, `createdAt` | Local-only; tracks push state per CKRecord |

---

## ViewModels (iOS)

All ViewModels are `@MainActor @Observable final class`.

| ViewModel | File | Injected Dependencies | Key State | Key Methods |
|-----------|------|-----------------------|-----------|-------------|
| `ScorecardViewModel` | `HyzerApp/ViewModels/ScorecardViewModel.swift` | `ScoringService`, `RoundLifecycleManager`, `roundID`, `reportedByPlayerID` | `isAwaitingFinalization`, `isRoundCompleted` | `enterScore()`, `correctScore()`, `finishRound()`, `finalizeRound()` |
| `LeaderboardViewModel` | `HyzerApp/ViewModels/LeaderboardViewModel.swift` | `StandingsEngine`, `roundID`, `currentPlayerID` | `currentStandings`, `isExpanded`, `showPulse`, `positionChanges` | `handleScoreEntered()` |
| `VoiceOverlayViewModel` | `HyzerApp/ViewModels/VoiceOverlayViewModel.swift` | `VoiceRecognitionServiceProtocol`, `VoiceParser`, `roundID`, `holeNumber`, `players` | State machine: idle → listening → confirming → committed | `startListening()`, `confirmScores()`, `cancel()` |
| `RoundSetupViewModel` | `HyzerApp/ViewModels/RoundSetupViewModel.swift` | `ModelContext`, `organizerID` | `selectedCourse`, `selectedPlayers`, `guestNames` | `createRound()`, `addGuest()`, `removePlayer()` |
| `CourseEditorViewModel` | `HyzerApp/ViewModels/CourseEditorViewModel.swift` | `ModelContext` | `name`, `holes: [EditableHole]`, `isValid` | `save()`, `addHole()`, `removeHole()`, `loadCourse()` |
| `OnboardingViewModel` | `HyzerApp/ViewModels/OnboardingViewModel.swift` | `ModelContext` | `displayName`, `isValid` | `createPlayer()` |
| `DiscrepancyViewModel` | `HyzerApp/ViewModels/DiscrepancyViewModel.swift` | `ModelContext`, `ScoringService`, `roundID` | `discrepancies`, `selectedDiscrepancy` | `resolve(choosing:)`, `loadDiscrepancies()` |
| `HistoryListViewModel` | `HyzerApp/ViewModels/HistoryListViewModel.swift` | `ModelContext` | `rounds: [RoundCard]` | `loadRounds()` |
| `RoundSummaryViewModel` | `HyzerApp/ViewModels/RoundSummaryViewModel.swift` | `ModelContext`, `roundID` | `standings`, `courseName`, `roundDate` | `loadSummary()` |
| `PlayerHoleBreakdownViewModel` | `HyzerApp/ViewModels/PlayerHoleBreakdownViewModel.swift` | `ModelContext`, `roundID`, `playerID`, `playerName` | `holeScores: [HoleScore]`, totals | `computeBreakdown()` |

---

## ViewModels (watchOS — in HyzerKit)

| ViewModel | File | Key State | Key Methods |
|-----------|------|-----------|-------------|
| `WatchLeaderboardViewModel` | `HyzerKit/Communication/WatchLeaderboardViewModel.swift` | `snapshot`, `standings`, `isStale`, `isConnected` | Observes `WatchStandingsObservable` |
| `WatchScoringViewModel` | `HyzerKit/Communication/WatchScoringViewModel.swift` | `currentScore` (1–10), `isConfirmed`, `scoreColor` | `confirmScore()` — sends via `transferUserInfo` |
| `WatchVoiceViewModel` | `HyzerKit/Communication/WatchVoiceViewModel.swift` | State: idle → listening → confirming → committed → unavailable | `startVoiceRequest()`, `confirmScores()`, `cancel()`, `retry()` |

---

## Views (iOS)

### Root & Navigation

| View | File | Purpose |
|------|------|---------|
| `ContentView` | `HyzerApp/Views/ContentView.swift` | Root router — `@Query` checks for Player; shows Onboarding or Home |
| `HomeView` | `HyzerApp/Views/HomeView.swift` | 3-tab `TabView` (Scoring / History / Courses) |

### Onboarding

| View | File | Purpose |
|------|------|---------|
| `OnboardingView` | `HyzerApp/Views/Onboarding/OnboardingView.swift` | First-launch name entry; creates Player |

### Course Management

| View | File | Purpose |
|------|------|---------|
| `CourseListView` | `HyzerApp/Views/Courses/CourseListView.swift` | Alphabetical course list; uses `@Query` directly |
| `CourseDetailView` | `HyzerApp/Views/Courses/CourseDetailView.swift` | Read-only course + holes; Edit toolbar button |
| `CourseEditorView` | `HyzerApp/Views/Courses/CourseEditorView.swift` | Sheet: create/edit course form |

### Round Setup

| View | File | Purpose |
|------|------|---------|
| `RoundSetupView` | `HyzerApp/Views/Rounds/RoundSetupView.swift` | Sheet: course selection → player management → start |

### Live Scoring

| View | File | Purpose |
|------|------|---------|
| `ScorecardContainerView` | `HyzerApp/Views/Scoring/ScorecardContainerView.swift` | Horizontal paging card stack; hosts floating leaderboard pill |
| `HoleCardView` | `HyzerApp/Views/Scoring/HoleCardView.swift` | Per-hole card: hole info + player score rows |
| `ScoreInputView` | `HyzerApp/Views/Scoring/ScoreInputView.swift` | Inline horizontal stroke picker (1–10); highlights par |
| `VoiceOverlayView` | `HyzerApp/Views/Scoring/VoiceOverlayView.swift` | Translucent voice result overlay; 1.5s auto-commit |
| `RoundSummaryView` | `HyzerApp/Views/Scoring/RoundSummaryView.swift` | Full-screen cover: final standings + share |

### Leaderboard

| View | File | Purpose |
|------|------|---------|
| `LeaderboardPillView` | `HyzerApp/Views/Leaderboard/LeaderboardPillView.swift` | Floating pill: condensed standings; pulses on change; discrepancy badge |
| `LeaderboardExpandedView` | `HyzerApp/Views/Leaderboard/LeaderboardExpandedView.swift` | Modal: animated full leaderboard with position arrows |

### History

| View | File | Purpose |
|------|------|---------|
| `HistoryListView` | `HyzerApp/Views/History/HistoryListView.swift` | Reverse-chronological completed rounds list |
| `HistoryRoundDetailView` | `HyzerApp/Views/History/HistoryRoundDetailView.swift` | Round detail: final standings, metadata, share |
| `PlayerHoleBreakdownView` | `HyzerApp/Views/History/PlayerHoleBreakdownView.swift` | Hole-by-hole scores for one player |

### Discrepancy Resolution

| View | File | Purpose |
|------|------|---------|
| `DiscrepancyListView` | `HyzerApp/Views/Discrepancy/DiscrepancyListView.swift` | Unresolved conflicts list; auto-skips if single |
| `DiscrepancyResolutionView` | `HyzerApp/Views/Discrepancy/DiscrepancyResolutionView.swift` | Side-by-side conflict picker |

### Shared Components

| View | File | Purpose |
|------|------|---------|
| `SyncIndicatorView` | `HyzerApp/Views/Components/SyncIndicatorView.swift` | Toolbar: sync status (idle/syncing/offline/error) |

---

## Views (watchOS)

| View | File | Purpose |
|------|------|---------|
| `WatchLeaderboardView` | `HyzerWatch/Views/WatchLeaderboardView.swift` | Standings list; tap row → scoring; stale indicator |
| `WatchScoringView` | `HyzerWatch/Views/WatchScoringView.swift` | Digital Crown score entry; mic button for voice |
| `WatchStaleIndicatorView` | `HyzerWatch/Views/WatchStaleIndicatorView.swift` | Warning when standings >30s old and phone unreachable |
| `WatchVoiceOverlayView` | `HyzerWatch/Views/WatchVoiceOverlayView.swift` | Voice scoring states: listening/confirming/failed/unavailable |

---

## Domain Services

| Service | File | Isolation | Purpose |
|---------|------|-----------|---------|
| `ScoringService` | `HyzerKit/Domain/ScoringService.swift` | `@MainActor` callers | Create score events; correct scores (new event with `supersedesEventID`) |
| `StandingsEngine` | `HyzerKit/Domain/StandingsEngine.swift` | `@MainActor @Observable` | Compute leaderboard from score events; track position changes |
| `RoundLifecycleManager` | `HyzerKit/Domain/RoundLifecycleManager.swift` | `@MainActor` | Round state transitions; completion checking; player mutation guards |
| `ConflictDetector` | `HyzerKit/Domain/ConflictDetector.swift` | `Sendable struct` | Pure function: classify incoming events as conflict/correction/merge |
| `CourseSeeder` | `HyzerKit/Domain/CourseSeeder.swift` | `@MainActor enum` | First-launch seeding from `SeededCourses.json` |

**Free function:** `resolveCurrentScore(for:hole:in:)` in `ScoreResolution.swift` — leaf-node resolution per Amendment A7.

---

## Sync Services

| Service | File | Isolation | Purpose |
|---------|------|-----------|---------|
| `SyncEngine` | `HyzerKit/Sync/SyncEngine.swift` | `actor` (ModelActor) | Push/pull CloudKit records; conflict detection; background ModelContext |
| `SyncScheduler` | `HyzerKit/Sync/SyncScheduler.swift` | `actor` | Orchestrate sync timing: 45s polling, remote notifications, connectivity |

---

## Live Service Implementations (iOS)

| Service | File | Conforms To | Purpose |
|---------|------|-------------|---------|
| `LiveCloudKitClient` | `HyzerApp/Services/LiveCloudKitClient.swift` | `CloudKitClient` | CloudKit public DB: save, fetch (paginated), subscribe |
| `LiveNetworkMonitor` | `HyzerApp/Services/LiveNetworkMonitor.swift` | `NetworkMonitor` | `NWPathMonitor` wrapper; `AsyncStream<Bool>` for changes |
| `LiveICloudIdentityProvider` | `HyzerApp/Services/LiveICloudIdentityProvider.swift` | `ICloudIdentityProvider` | `CKContainer.accountStatus()` + `fetchUserRecordID` |
| `PhoneConnectivityService` | `HyzerApp/Services/PhoneConnectivityService.swift` | `WatchConnectivityClient` | WCSession phone-side: routes Watch messages, observation-based standings push |
| `VoiceRecognitionService` | `HyzerApp/Services/VoiceRecognitionService.swift` | `VoiceRecognitionServiceProtocol` | `SFSpeechRecognizer` on-device; `AVAudioEngine` tap |

---

## Protocol Abstractions

| Protocol | File | Implementations |
|----------|------|-----------------|
| `CloudKitClient` | `HyzerKit/Sync/CloudKitClient.swift` | `LiveCloudKitClient` (iOS), `MockCloudKitClient` (tests) |
| `NetworkMonitor` | `HyzerKit/Sync/NetworkMonitor.swift` | `LiveNetworkMonitor` (iOS), `MockNetworkMonitor` (tests) |
| `ICloudIdentityProvider` | `HyzerKit/Sync/ICloudIdentityProvider.swift` | `LiveICloudIdentityProvider` (iOS) |
| `WatchConnectivityClient` | `HyzerKit/Communication/WatchConnectivityClient.swift` | `PhoneConnectivityService` (iOS), `MockWatchConnectivityClient` (tests) |
| `WatchStandingsObservable` | `HyzerKit/Communication/WatchStandingsObservable.swift` | `WatchConnectivityService` (watchOS) |
| `VoiceRecognitionServiceProtocol` | `HyzerApp/Protocols/VoiceRecognitionServiceProtocol.swift` | `VoiceRecognitionService` (iOS), `MockVoiceRecognitionService` (tests) |

---

## Design System Tokens

### Colors (`ColorTokens.swift`)

| Token | Hex | Usage |
|-------|-----|-------|
| `backgroundPrimary` | `#0A0A0C` | Main background |
| `backgroundElevated` | `#1C1C1E` | Cards, sheets |
| `backgroundTertiary` | `#2C2C2E` | Nested surfaces |
| `textPrimary` | `#F5F5F7` | Primary text |
| `textSecondary` | `#8E8E93` | Secondary text |
| `accentPrimary` | `#30D5C8` | Interactive elements |
| `scoreUnderPar` | `#34C759` | Under par (green) |
| `scoreAtPar` | `#F5F5F7` | At par (white) |
| `scoreOverPar` | `#FF9F0A` | Over par (orange) |
| `scoreWayOver` | `#FF453A` | Way over par (red) |
| `warning` | `#FF9F0A` | Warnings |
| `destructive` | `#FF3B30` | Destructive actions |

### Typography (`TypographyTokens.swift`)

| Level | Style | Font |
|-------|-------|------|
| `hero` | Large Title / Bold | SF Pro Rounded |
| `h1` | Title | SF Pro Rounded |
| `h2` | Title 2 / Semibold | SF Pro Rounded |
| `h3` | Headline | SF Pro Rounded |
| `body` | Body | SF Pro Rounded |
| `caption` | Caption | SF Pro Rounded |
| `score` | Title 2 / Monospaced / Bold | SF Mono |
| `scoreLarge` | Title / Monospaced / Bold | SF Mono |

All levels support Dynamic Type scaling including AX3 via `@ScaledMetric`.

### Spacing (`SpacingTokens.swift`)

8pt grid: `xs=4`, `sm=8`, `md=16`, `lg=24`, `xl=32`, `xxl=48`. Touch targets: `minimumTouchTarget=44`, `scoringTouchTarget=52`.

### Animation (`AnimationTokens.swift` + `AnimationCoordinator.swift`)

- `springStiff`: `spring(response: 0.3, dampingFraction: 0.7)`
- `springGentle`: `spring(response: 0.5, dampingFraction: 0.8)`
- `scoreEntryDuration`: 0.2s
- `leaderboardReshuffleDuration`: 0.4s
- `AnimationCoordinator`: returns `.linear(duration: 0)` when reduce-motion is enabled

---

## Test Infrastructure

### Fixtures (6)

| Fixture | File | Purpose |
|---------|------|---------|
| `Player+Fixture` | `HyzerKitTests/Fixtures/Player+Fixture.swift` | Pre-built Player instances |
| `Course+Fixture` | `HyzerKitTests/Fixtures/Course+Fixture.swift` | Pre-built Course instances |
| `Round+Fixture` | `HyzerKitTests/Fixtures/Round+Fixture.swift` | Pre-built Round instances in various states |
| `ScoreEvent+Fixture` | `HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift` | Pre-built score events |
| `Discrepancy+Fixture` | `HyzerKitTests/Fixtures/Discrepancy+Fixture.swift` | Pre-built discrepancy instances |
| `SyncMetadata+Fixture` | `HyzerKitTests/Fixtures/SyncMetadata+Fixture.swift` | Pre-built sync metadata |

### Mocks (4)

| Mock | File | Mocks Protocol |
|------|------|----------------|
| `MockCloudKitClient` | `HyzerKitTests/Mocks/MockCloudKitClient.swift` | `CloudKitClient` |
| `MockNetworkMonitor` | `HyzerKitTests/Mocks/MockNetworkMonitor.swift` | `NetworkMonitor` |
| `MockWatchConnectivityClient` | `HyzerKitTests/Communication/MockWatchConnectivityClient.swift` | `WatchConnectivityClient` |
| `MockVoiceRecognitionService` | `HyzerAppTests/Mocks/MockVoiceRecognitionService.swift` | `VoiceRecognitionServiceProtocol` |

### Test Counts

| Test Target | Files | Tests |
|-------------|-------|-------|
| HyzerKitTests | 28 | 266 |
| HyzerAppTests | 11 | 141 |
| **Total** | **39** | **407** |

---

## CloudKit DTOs

| DTO | File | Status | Maps To |
|-----|------|--------|---------|
| `ScoreEventRecord` | `HyzerKit/Sync/DTOs/ScoreEventRecord.swift` | Complete | `ScoreEvent` ↔ `CKRecord` |
| `CourseRecord` | `HyzerKit/Sync/DTOs/CourseRecord.swift` | Stub | Identity-only CKRecord |
| `PlayerRecord` | `HyzerKit/Sync/DTOs/PlayerRecord.swift` | Stub | Identity-only CKRecord |
| `RoundRecord` | `HyzerKit/Sync/DTOs/RoundRecord.swift` | Stub | Identity-only CKRecord |
