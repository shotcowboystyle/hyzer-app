# HyzerApp — Source Tree Analysis

## Directory Structure

```
hyzer-app/
├── CLAUDE.md                          # AI development context and conventions
├── project.yml                        # XcodeGen project definition
├── .swiftlint.yml                     # SwiftLint configuration
├── HyzerApp.xcodeproj/               # Generated (do not edit directly)
│
├── HyzerApp/                          # iOS app target
│   ├── App/
│   │   ├── HyzerApp.swift            # @main entry point, dual ModelContainer, AppDelegate
│   │   └── AppServices.swift          # Composition root (@MainActor @Observable)
│   │
│   ├── Views/
│   │   ├── ContentView.swift          # Root router: onboarding vs. home
│   │   ├── HomeView.swift             # 3-tab shell (Scoring / History / Courses)
│   │   ├── Components/
│   │   │   └── SyncIndicatorView.swift          # Toolbar sync status indicator
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift             # First-launch name entry
│   │   ├── Courses/
│   │   │   ├── CourseListView.swift              # Course list with add/delete
│   │   │   ├── CourseDetailView.swift            # Read-only course + holes
│   │   │   └── CourseEditorView.swift            # Create/edit course sheet
│   │   ├── Rounds/
│   │   │   └── RoundSetupView.swift              # Course + player selection → start
│   │   ├── Scoring/
│   │   │   ├── ScorecardContainerView.swift      # Horizontal paging card stack
│   │   │   ├── HoleCardView.swift                # Per-hole card with player rows
│   │   │   ├── ScoreInputView.swift              # Inline stroke picker (1–10)
│   │   │   ├── VoiceOverlayView.swift            # Voice recognition overlay
│   │   │   └── RoundSummaryView.swift            # Post-round standings + share
│   │   ├── Leaderboard/
│   │   │   ├── LeaderboardPillView.swift         # Floating condensed standings
│   │   │   └── LeaderboardExpandedView.swift     # Full standings modal
│   │   ├── History/
│   │   │   ├── HistoryListView.swift             # Completed rounds list
│   │   │   ├── HistoryRoundDetailView.swift      # Round detail with standings
│   │   │   └── PlayerHoleBreakdownView.swift     # Hole-by-hole player drill-down
│   │   └── Discrepancy/
│   │       ├── DiscrepancyListView.swift         # Unresolved conflicts list
│   │       └── DiscrepancyResolutionView.swift   # Side-by-side conflict picker
│   │
│   ├── ViewModels/
│   │   ├── CourseEditorViewModel.swift            # Course CRUD operations
│   │   ├── DiscrepancyViewModel.swift             # Conflict resolution logic
│   │   ├── HistoryListViewModel.swift             # Round history queries
│   │   ├── LeaderboardViewModel.swift             # Standings display + animations
│   │   ├── OnboardingViewModel.swift              # Player creation
│   │   ├── PlayerHoleBreakdownViewModel.swift     # Per-player hole scores
│   │   ├── RoundSetupViewModel.swift              # Round configuration + start
│   │   ├── RoundSummaryViewModel.swift            # Post-round summary data
│   │   ├── ScorecardViewModel.swift               # Score entry + corrections
│   │   └── VoiceOverlayViewModel.swift            # Voice UI state machine
│   │
│   ├── Services/
│   │   ├── LiveCloudKitClient.swift               # CloudKit public DB implementation
│   │   ├── LiveICloudIdentityProvider.swift       # iCloud identity resolution
│   │   ├── LiveNetworkMonitor.swift               # NWPathMonitor wrapper
│   │   ├── PhoneConnectivityService.swift         # WCSession phone-side delegate
│   │   └── VoiceRecognitionService.swift          # SFSpeechRecognizer on-device
│   │
│   ├── Protocols/
│   │   └── VoiceRecognitionServiceProtocol.swift  # Internal mock protocol
│   │
│   ├── App/
│   │   └── HyzerApp.entitlements                  # Push notifications, iCloud
│   └── Resources/
│       └── Assets.xcassets/                       # AppIcon, AccentColor
│
├── HyzerWatch/                        # watchOS companion target
│   ├── App/
│   │   ├── HyzerWatchApp.swift        # watchOS entry point
│   │   └── HyzerWatch.entitlements    # Companion app pairing
│   ├── Services/
│   │   └── WatchConnectivityService.swift  # WCSession watch-side delegate
│   ├── Views/
│   │   ├── WatchLeaderboardView.swift      # Standings list, tap to score
│   │   ├── WatchScoringView.swift          # Digital Crown score entry
│   │   ├── WatchStaleIndicatorView.swift   # Stale data warning label
│   │   └── WatchVoiceOverlayView.swift     # Voice scoring overlay
│   └── Resources/
│       └── Assets.xcassets/                # AppIcon
│
├── HyzerKit/                          # Shared Swift package
│   ├── Package.swift                  # swift-tools-version: 6.0
│   ├── Sources/HyzerKit/
│   │   ├── Models/                    # SwiftData @Model classes
│   │   │   ├── Player.swift           # User identity, aliases for voice
│   │   │   ├── Course.swift           # Disc golf course metadata
│   │   │   ├── Hole.swift             # Individual hole (courseID FK, par)
│   │   │   ├── Round.swift            # Round lifecycle + state machine
│   │   │   ├── ScoreEvent.swift       # Append-only event log (NFR19)
│   │   │   └── Discrepancy.swift      # Cross-device score conflict
│   │   │
│   │   ├── Domain/                    # Business logic
│   │   │   ├── ScoringService.swift           # Create/correct score events
│   │   │   ├── StandingsEngine.swift          # Leaderboard computation
│   │   │   ├── RoundLifecycleManager.swift    # Round state transitions
│   │   │   ├── ConflictDetector.swift         # Stateless conflict classifier
│   │   │   ├── ScoreResolution.swift          # Leaf-node score resolution (A7)
│   │   │   ├── CourseSeeder.swift             # First-launch course seeding
│   │   │   ├── Standing.swift                 # Leaderboard entry value type
│   │   │   ├── Standing+Formatting.swift      # Score formatting + colors
│   │   │   ├── StandingsChange.swift          # Standings diff with position deltas
│   │   │   ├── StandingsChangeTrigger.swift   # local/remote/conflict trigger enum
│   │   │   └── HoleScore.swift                # Per-hole score value type
│   │   │
│   │   ├── Sync/                      # CloudKit sync layer
│   │   │   ├── SyncEngine.swift       # Actor: push/pull pipeline
│   │   │   ├── SyncScheduler.swift    # Actor: scheduling, polling, notifications
│   │   │   ├── CloudKitClient.swift   # Protocol: CloudKit abstraction
│   │   │   ├── NetworkMonitor.swift   # Protocol: network state abstraction
│   │   │   ├── ICloudIdentityProvider.swift  # Protocol: iCloud identity
│   │   │   ├── SyncMetadata.swift     # @Model: per-record sync tracking
│   │   │   ├── SyncState.swift        # Enum: idle/syncing/offline/error
│   │   │   ├── SyncError.swift        # Typed sync errors
│   │   │   └── DTOs/
│   │   │       ├── ScoreEventRecord.swift  # ScoreEvent ↔ CKRecord mapping
│   │   │       ├── CourseRecord.swift      # Stub (deferred)
│   │   │       ├── PlayerRecord.swift      # Stub (deferred)
│   │   │       └── RoundRecord.swift       # Stub (deferred)
│   │   │
│   │   ├── Voice/                     # Platform-independent NLP
│   │   │   ├── VoiceParser.swift      # Tokenize → classify → assemble → match
│   │   │   ├── TokenClassifier.swift  # Word → number/name/noise
│   │   │   ├── FuzzyNameMatcher.swift # Levenshtein-based player matching
│   │   │   ├── VoiceParseResult.swift # Result types + Codable union
│   │   │   └── VoiceParseError.swift  # Permission/availability errors
│   │   │
│   │   ├── Communication/             # Watch ↔ Phone messaging
│   │   │   ├── WatchConnectivityClient.swift    # Protocol: WCSession abstraction
│   │   │   ├── WatchMessage.swift               # Codable discriminated union
│   │   │   ├── StandingsSnapshot.swift          # Standings + staleness tracking
│   │   │   ├── WatchCacheManager.swift          # App group JSON cache
│   │   │   ├── WatchStandingsObservable.swift   # Protocol: observable standings
│   │   │   ├── WatchLeaderboardViewModel.swift  # Watch leaderboard VM
│   │   │   ├── WatchScoringViewModel.swift      # Watch scoring VM (Crown)
│   │   │   └── WatchVoiceViewModel.swift        # Watch voice relay VM
│   │   │
│   │   ├── Design/                    # Design system tokens
│   │   │   ├── ColorTokens.swift      # 11 named colors (dark-first)
│   │   │   ├── TypographyTokens.swift # 8 font levels (SF Pro Rounded)
│   │   │   ├── SpacingTokens.swift    # 8pt grid system
│   │   │   ├── AnimationTokens.swift  # Spring presets + durations
│   │   │   └── AnimationCoordinator.swift  # Reduce-motion support
│   │   │
│   │   └── Resources/
│   │       └── SeededCourses.json     # 3 pre-built courses (Morley, Maple Hill, DeLaveaga)
│   │
│   └── Tests/HyzerKitTests/
│       ├── Domain/                    # Model + domain logic tests (80+ tests)
│       ├── Communication/             # Watch messaging tests (75+ tests)
│       ├── Voice/                     # Voice tests (via separate files)
│       ├── Integration/               # VoiceToStandingsIntegrationTests
│       ├── Fixtures/                  # 6 fixture extensions
│       ├── Mocks/                     # MockCloudKitClient, MockNetworkMonitor
│       ├── ConflictDetectorTests.swift
│       ├── ScoreResolutionTests.swift
│       ├── SyncEngineTests.swift
│       ├── SyncEngineConflictTests.swift
│       ├── SyncSchedulerTests.swift
│       ├── SyncMetadataTests.swift
│       ├── SyncRecoveryTests.swift
│       ├── ScoreEventRecordTests.swift
│       └── NetworkMonitorTests.swift
│
├── HyzerAppTests/                     # iOS ViewModel tests
│   ├── Mocks/
│   │   └── MockVoiceRecognitionService.swift
│   ├── ViewModels/
│   │   ├── HistoryListViewModelTests.swift
│   │   └── PlayerHoleBreakdownViewModelTests.swift
│   ├── CourseEditorViewModelTests.swift
│   ├── DiscrepancyViewModelTests.swift
│   ├── ICloudIdentityResolutionTests.swift
│   ├── LeaderboardViewModelTests.swift
│   ├── OnboardingViewModelTests.swift
│   ├── RoundSetupViewModelTests.swift
│   ├── RoundSummaryViewModelTests.swift
│   ├── ScorecardViewModelTests.swift
│   └── VoiceOverlayViewModelTests.swift
│
├── _bmad-output/                      # BMAD project management artifacts
│   ├── planning-artifacts/            # Architecture, epics, PRD, tech stack
│   └── implementation-artifacts/      # Story files, sprint status, retro
│
├── _bmad/                             # BMAD framework configuration
│   ├── bmm/                           # Workflows, configs
│   └── _config/                       # Agent manifest
│
└── docs/                              # Generated project documentation
    ├── index.md
    ├── project-overview.md
    ├── architecture.md
    ├── data-models.md
    ├── source-tree-analysis.md        # (this file)
    ├── component-inventory.md
    └── development-guide.md
```

---

## File Counts by Directory

| Directory | Swift Files | Purpose |
|-----------|-------------|---------|
| `HyzerApp/App/` | 2 | Entry point + composition root |
| `HyzerApp/Views/` | 17 | SwiftUI views (organized by feature) |
| `HyzerApp/ViewModels/` | 10 | View model layer |
| `HyzerApp/Services/` | 5 | Live service implementations |
| `HyzerApp/Protocols/` | 1 | Internal mock protocol |
| `HyzerWatch/App/` | 1 | watchOS entry point |
| `HyzerWatch/Services/` | 1 | Watch connectivity |
| `HyzerWatch/Views/` | 4 | watchOS UI |
| `HyzerKit/Models/` | 6 | SwiftData models |
| `HyzerKit/Domain/` | 11 | Business logic |
| `HyzerKit/Sync/` | 12 | CloudKit sync (incl. DTOs) |
| `HyzerKit/Voice/` | 5 | Voice parsing pipeline |
| `HyzerKit/Communication/` | 8 | Watch ↔ Phone messaging |
| `HyzerKit/Design/` | 5 | Design system tokens |
| **Total source** | **~88** | |
| `HyzerKitTests/` | 28 test + 9 support | Domain + sync + comms tests |
| `HyzerAppTests/` | 11 test + 1 mock | ViewModel tests |
| **Total test** | **~49** | |

---

## Key Conventions

- **Feature-based grouping** in Views: `Scoring/`, `Leaderboard/`, `History/`, `Courses/`, `Discrepancy/`, `Onboarding/`, `Components/`
- **Test files mirror source structure**: `Domain/`, `Communication/`, `Voice/`, `Integration/`, `Mocks/`, `Fixtures/`
- **No storyboards or XIBs** — 100% SwiftUI
- **No third-party dependencies** — only Apple frameworks + HyzerKit local package
- **Generated project** — `HyzerApp.xcodeproj` is generated from `project.yml` via XcodeGen; never edit the `.xcodeproj` directly
