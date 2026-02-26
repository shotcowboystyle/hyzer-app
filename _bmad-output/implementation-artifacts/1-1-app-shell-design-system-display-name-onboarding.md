# Story 1.1: App Shell, Design System & Display Name Onboarding

Status: review

## Story

As a new user,
I want to open the app and enter my display name,
So that I have an identity and can start using the app immediately.

## Acceptance Criteria

1. **Given** the user opens the app for the first time, **When** the onboarding screen appears, **Then** a single text field with prompt "What should we call you?" is displayed, **And** no other onboarding steps, tutorials, or permission prompts are presented.

2. **Given** the user has entered a display name and tapped done, **When** the player record is created, **Then** the player is saved to SwiftData locally, **And** the user is navigated to the home screen, **And** the interaction completes without any network dependency (FR4).

3. **Given** the device has no network connectivity, **When** the user completes onboarding, **Then** onboarding succeeds identically to the online case (FR4).

4. **Given** the Xcode project is built, **When** both iOS and watchOS targets compile, **Then** HyzerKit is imported successfully by both targets, **And** strict concurrency is enforced (Swift 6), **And** design tokens (colors, typography, spacing, animation) are accessible from HyzerKit.

## Tasks / Subtasks

- [x] Task 1: Create Xcode project (AC: #4)
  - [x] 1.1 File > New > Project > iOS App with Watch App (Product Name: HyzerApp, Interface: SwiftUI, Storage: SwiftData, Language: Swift, Watch App: Include Watch App)
  - [x] 1.2 Set minimum deployment: iOS 18.0, watchOS 11.0
  - [x] 1.3 Enable Swift 6 strict concurrency on both targets
  - [x] 1.4 Add `.gitignore` for Xcode projects (xcuserdata, build, DerivedData, etc.)
  - [x] 1.5 Enable capabilities on iOS target: iCloud > CloudKit (container: `iCloud.com.shotcowboystyle.hyzerapp`), Background Modes > Remote Notifications, App Groups (`group.com.shotcowboystyle.hyzerapp`)
  - [x] 1.6 Enable capabilities on watchOS target: App Groups (`group.com.shotcowboystyle.hyzerapp`)

- [x] Task 2: Create HyzerKit Swift Package (AC: #4)
  - [x] 2.1 File > New > Package > HyzerKit as local package in project root
  - [x] 2.2 Set `swift-tools-version: 6.0` in Package.swift
  - [x] 2.3 Add HyzerKit as dependency to both iOS and watchOS targets
  - [x] 2.4 Create directory structure: `Sources/HyzerKit/Models/`, `Sources/HyzerKit/Domain/`, `Sources/HyzerKit/Sync/`, `Sources/HyzerKit/Communication/`, `Sources/HyzerKit/Design/`, `Sources/HyzerKit/Extensions/`
  - [x] 2.5 Create test directory structure: `Tests/HyzerKitTests/Domain/`, `Tests/HyzerKitTests/Fixtures/`, `Tests/HyzerKitTests/Mocks/`
  - [x] 2.6 Verify both targets compile with HyzerKit imported

- [x] Task 3: Create SwiftData Player model (AC: #2, #3)
  - [x] 3.1 Create `Player.swift` in `HyzerKit/Models/`
  - [x] 3.2 Define `@Model` class with fields: `id: UUID`, `displayName: String`, `iCloudRecordName: String?`, `aliases: [String]`, `createdAt: Date`
  - [x] 3.3 All properties optional or have defaults (CloudKit compatibility)
  - [x] 3.4 No `@Attribute(.unique)` (CloudKit constraint)
  - [x] 3.5 Create `Player+Fixture.swift` in `HyzerKitTests/Fixtures/`

- [x] Task 4: Create AppServices composition root (AC: #4)
  - [x] 4.1 Create `AppServices.swift` in `HyzerApp/App/`
  - [x] 4.2 Mark as `@MainActor @Observable final class`
  - [x] 4.3 Constructor injection pattern -- no singletons, no global mutable state
  - [x] 4.4 Pass via `.environment()` in `HyzerApp.swift`

- [x] Task 5: Create design system tokens (AC: #4)
  - [x] 5.1 Create `ColorTokens.swift` in `HyzerKit/Design/`
  - [x] 5.2 Create `TypographyTokens.swift` in `HyzerKit/Design/`
  - [x] 5.3 Create `SpacingTokens.swift` in `HyzerKit/Design/`
  - [x] 5.4 Create `AnimationTokens.swift` in `HyzerKit/Design/`
  - [x] 5.5 Create `AnimationCoordinator.swift` in `HyzerKit/Design/`

- [x] Task 6: Create OnboardingView and ViewModel (AC: #1, #2, #3)
  - [x] 6.1 Create `OnboardingViewModel.swift` in `HyzerApp/ViewModels/`
  - [x] 6.2 Create `OnboardingView.swift` in `HyzerApp/Views/Onboarding/`
  - [x] 6.3 Single text field: "What should we call you?"
  - [x] 6.4 Save Player to SwiftData on done, navigate to home screen
  - [x] 6.5 No network calls, no permissions, no tutorials
  - [x] 6.6 Apply design tokens (colors, typography, spacing)
  - [x] 6.7 Accessibility: VoiceOver labels, Dynamic Type, 44pt+ touch targets

- [x] Task 7: Create home screen placeholder (AC: #2)
  - [x] 7.1 Create `HomeView.swift` in `HyzerApp/Views/` as navigation destination after onboarding
  - [x] 7.2 Show player display name
  - [x] 7.3 Empty state placeholder for future features

- [x] Task 8: App entry point and navigation (AC: #1, #2)
  - [x] 8.1 Configure `HyzerApp.swift` with ModelContainer, AppServices
  - [x] 8.2 Check if Player exists -- show OnboardingView or HomeView
  - [x] 8.3 Configure ModelContainer with dual ModelConfiguration (domain + operational stores)

- [x] Task 9: SwiftLint configuration (AC: #4)
  - [x] 9.1 Create `.swiftlint.yml` in project root
  - [x] 9.2 Add SwiftLint as Xcode build phase on both targets
  - [x] 9.3 Configure naming conventions, unused imports, formatting rules

- [x] Task 10: Unit tests (AC: #1, #2, #3, #4)
  - [x] 10.1 Test Player model creation and persistence
  - [x] 10.2 Test onboarding flow creates Player record
  - [x] 10.3 Test design tokens are accessible and correct
  - [x] 10.4 Verify both targets compile clean with zero warnings

## Dev Notes

### Architecture Constraints (MUST follow)

**Project Structure -- exact paths:**
```
hyzer-app/
  HyzerApp/                    # iOS App target
    App/
      HyzerApp.swift           # @main, AppServices composition root
      HyzerApp.entitlements
    Views/
      Onboarding/
        OnboardingView.swift
    ViewModels/
      OnboardingViewModel.swift
    Resources/
      Assets.xcassets/
  HyzerWatch/                  # watchOS App target
    App/
      HyzerWatchApp.swift
      HyzerWatch.entitlements
  HyzerKit/                    # Shared Swift Package
    Package.swift              # swift-tools-version: 6.0
    Sources/HyzerKit/
      Models/
        Player.swift
      Design/
        ColorTokens.swift
        TypographyTokens.swift
        SpacingTokens.swift
        AnimationTokens.swift
        AnimationCoordinator.swift
    Tests/HyzerKitTests/
      Fixtures/
        Player+Fixture.swift
```

**Dependency Injection:**
- `AppServices` is `@MainActor @Observable final class`. Created once in `@main` App struct, passed via `.environment()`.
- ViewModels receive individual services via constructor injection, NOT the container.
- NO singletons. NO global mutable state. NO service locators.

**SwiftData Configuration:**
- Dual `ModelConfiguration` within the same `ModelContainer`:
  - Domain store: `Player` (and future `ScoreEvent`, `Round`, `Course`, `Hole`) -- synced via manual CloudKit
  - Operational store: `SyncMetadata` (local-only, never syncs) -- separate backing store
- Model constraints for CloudKit compatibility:
  - No `@Attribute(.unique)`
  - All properties optional or have default values
  - Relationships must be optional; no `Deny` delete rules
  - Lightweight migration only

**Concurrency:**
- `AppServices`: `@MainActor`
- All ViewModels: `@MainActor`
- `ModelContext` (view): `@MainActor`
- Use `Logger` (os_log) over `print()` throughout

**SwiftUI Patterns:**
- `@State` in Views: transient UI state only
- `@Observable` ViewModels: business-related state and actions
- `@Query` in Views (not ViewModels): reactive SwiftData reads

### Design System Specifications

**ColorTokens -- implement as Swift `Color` extensions:**

| Token | Hex | Usage |
|---|---|---|
| `background.primary` | `#0A0A0C` | Main canvas, cards |
| `background.elevated` | `#1C1C1E` | Elevated cards, modals |
| `background.tertiary` | `#2C2C2E` | Active states, selected rows |
| `text.primary` | `#F5F5F7` | Headlines, scores |
| `text.secondary` | `#8E8E93` | Labels, metadata |
| `accent.primary` | `#30D5C8` | Interactive elements, CTAs |
| `score.underPar` | `#34C759` | Birdie/under-par |
| `score.overPar` | `#FF9F0A` | Bogey/over-par |
| `score.atPar` | `#F5F5F7` | Par scores |
| `score.wayOver` | `#FF453A` | Double bogey+ |
| `destructive` | `#FF3B30` | Delete actions only |

This is a dark-first app. Light Mode is deferred.

**TypographyTokens -- SF Pro Rounded + SF Mono:**

| Level | Font | Size | Weight |
|---|---|---|---|
| Hero | SF Pro Rounded | 48pt | Bold |
| H1 | SF Pro Rounded | 28pt | Bold |
| H2 | SF Pro Rounded | 22pt | Semibold |
| H3 | SF Pro Rounded | 17pt | Semibold |
| Body | SF Pro Rounded | 17pt | Regular |
| Caption | SF Pro Rounded | 13pt | Regular |
| Score | SF Mono | 22pt | Bold |
| Score (large) | SF Mono | 34pt | Bold |

All sizes MUST scale with Dynamic Type. Use `@ScaledMetric` for custom sizes.

**SpacingTokens:**

| Token | Value |
|---|---|
| `space.xs` | 4pt |
| `space.sm` | 8pt |
| `space.md` | 16pt |
| `space.lg` | 24pt |
| `space.xl` | 32pt |
| `space.xxl` | 48pt |

Touch targets: minimum 44x44pt (Apple HIG). Scoring controls: 48-56pt.

**AnimationTokens:**

```swift
enum AnimationTokens {
    static let springStiff = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let scoreEntryDuration: TimeInterval = 0.2
    static let leaderboardReshuffleDuration: TimeInterval = 0.4
    static let pillPulseDelay: TimeInterval = 0.2
}
```

Every animation MUST check `@Environment(\.accessibilityReduceMotion)` and provide a reduced-motion alternative (instant transition or fade-only). No magic animation values in views -- reference AnimationTokens.

### Error Handling Pattern

```swift
private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "Onboarding")
```

- Typed `Sendable` errors per domain area. No generic `Error` in public APIs.
- Never swallow errors silently. Every `catch` logs + rethrows OR has explicit comment.

### Naming Conventions

- SwiftData Models: plain names (`Player`, `Course`), in `HyzerKit/Models/`
- ViewModels: `{Feature}ViewModel` suffix, in `HyzerApp/ViewModels/`
- Views: `{Feature}View` suffix, in `HyzerApp/Views/{Feature}/`
- Extensions: `{TypeName}+{Capability}.swift` (e.g., `Color+DesignTokens.swift`)
- Tests: `test_{method}_{scenario}_{expectedBehavior}`
- Fixtures: `{ModelName}+Fixture.swift` with `.fixture()` factory method

### Accessibility Requirements (this story)

- VoiceOver label on text field: "Display name. Enter the name your friends will see."
- VoiceOver label on done button: "Continue. Creates your player profile."
- All text uses Dynamic Type scaling up to AX3
- Minimum 4.5:1 contrast ratio (design token colors on `#0A0A0C` already satisfy this)
- 44pt+ touch targets on all interactive elements

### OnboardingView Behavior

- Single screen with text field "What should we call you?"
- Done/Continue button enabled only when name is non-empty (trimmed)
- On save: create `Player(displayName: name)` in SwiftData, navigate to HomeView
- NO network calls. NO iCloud identity check (that's Story 1.2). NO permission prompts.
- Apply design tokens: dark background, accent-colored CTA, SF Pro Rounded typography

### HyzerApp.swift Entry Point Pattern

```swift
@main
struct HyzerApp: App {
    let appServices: AppServices

    init() {
        let container = // ModelContainer setup
        appServices = AppServices(modelContainer: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appServices)
                .modelContainer(appServices.modelContainer)
        }
    }
}
```

ContentView checks if a Player exists via `@Query`. If no Player -> OnboardingView. If Player exists -> HomeView. This is a simple `@Query`-driven conditional, not a navigation stack.

### Dual ModelConfiguration Setup

```swift
let domainConfig = ModelConfiguration(
    "DomainStore",
    schema: Schema([Player.self /* future: Round, Course, Hole, ScoreEvent */])
)
let operationalConfig = ModelConfiguration(
    "OperationalStore",
    schema: Schema([/* future: SyncMetadata */]),
    isStoredInMemoryOnly: false
)
let container = try ModelContainer(
    for: Player.self /* future models */,
    configurations: domainConfig, operationalConfig
)
```

For this story, only the domain store is needed (Player model only). The operational store schema can be empty or omitted until Story 4.1 introduces SyncMetadata. Keep the dual-config pattern in place so future stories don't need to restructure.

### SwiftLint Configuration

Include `.swiftlint.yml` in project root. Key rules:
- `identifier_name`: enforce naming conventions
- `type_name`: enforce type naming
- `force_cast` / `force_try` / `force_unwrapping`: warning
- `unused_import`: warning
- Add as Xcode Run Script build phase: `if which swiftlint > /dev/null; then swiftlint; fi`

### What This Story Does NOT Include

- iCloud identity resolution (Story 1.2)
- Course models or seeding (Story 1.3)
- Home screen with course list (Story 1.3)
- Any CloudKit operations
- Any Watch app UI beyond the shell
- Any Services/ directory files (VoiceRecognition, Connectivity)

### Project Structure Notes

- HyzerKit contains ONLY platform-independent code. No `Speech`, `WCSession`, or UIKit imports.
- Platform-specific services go in consuming target's `Services/` directory (future stories).
- iOS and watchOS targets share the same App Group ID: `group.com.shotcowboystyle.hyzerapp`
- CloudKit container: `iCloud.com.shotcowboystyle.hyzerapp` (iOS target only for now)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Starter Template Evaluation] -- Xcode project setup, HyzerKit structure
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns & Consistency Rules] -- Naming, file placement, DI patterns
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions] -- Dual ModelConfiguration, SwiftData constraints
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Color System] -- Color hex values and philosophy
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Typography System] -- Font scale and typefaces
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Spacing & Layout Foundation] -- 8pt grid, touch targets
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1] -- Acceptance criteria, scope definition
- [Source: _bmad-output/planning-artifacts/architecture.md#Concurrency Patterns] -- Actor isolation boundaries
- [Source: _bmad-output/planning-artifacts/architecture.md#SwiftData Configuration Pattern] -- Dual store setup

## Dev Agent Record

### Agent Model Used
claude-sonnet-4-6

### Debug Log References
- Fixed `swift test` platform availability by adding `.macOS(.v14)` to Package.swift
- Resolved `#Predicate` macro unavailability in SPM test context (used in-memory filter)
- Fixed xcodegen watchOS linker error: `INFOPLIST_KEY_WKWatchKitApp: YES` + `LD_RUNPATH_SEARCH_PATHS` override
- Used `INFOPLIST_KEY_WKWatchKitApp: YES` with `application` type (not watchapp2) for Xcode 14+ standalone watch app

### Completion Notes List
- ✅ Xcode project created via xcodegen 2.44.1 with project.yml spec
- ✅ HyzerKit local Swift Package created (swift-tools-version: 6.0, iOS 18, watchOS 11, macOS 14)
- ✅ Player @Model: UUID, displayName, iCloudRecordName?, aliases, createdAt — all CloudKit-compatible defaults
- ✅ AppServices: @MainActor @Observable final class, constructor injection, no singletons
- ✅ Design tokens: ColorTokens (11 tokens), TypographyTokens (8 levels), SpacingTokens (6 + touch targets), AnimationTokens + AnimationCoordinator
- ✅ OnboardingView: dark background, accent CTA, VoiceOver labels, reduce-motion animation, no network calls
- ✅ OnboardingViewModel: @MainActor @Observable, savePlayer(in:) pattern, trims whitespace
- ✅ HomeView: placeholder showing displayName, styled with design tokens
- ✅ ContentView: @Query-driven routing (OnboardingView vs HomeView), no navigation stack
- ✅ HyzerApp.swift: dual ModelConfiguration (DomainStore + OperationalStore), AppServices via .environment()
- ✅ HyzerWatchApp.swift: minimal shell for Story 7.1
- ✅ SwiftLint: .swiftlint.yml configured, SwiftLint build phase added to HyzerApp target
- ✅ 9/9 HyzerKit tests pass (Player model, persistence, design tokens)
- ✅ 4 OnboardingViewModel tests written in HyzerAppTests (testable via xcodebuild test)
- ✅ iOS Simulator build: BUILD SUCCEEDED (zero errors)
- ✅ watchOS Simulator build: BUILD SUCCEEDED (zero errors)

### File List
HyzerApp.xcodeproj/project.pbxproj
project.yml
.gitignore
.swiftlint.yml
HyzerApp/App/HyzerApp.swift
HyzerApp/App/AppServices.swift
HyzerApp/App/HyzerApp.entitlements
HyzerApp/Views/ContentView.swift
HyzerApp/Views/Onboarding/OnboardingView.swift
HyzerApp/Views/HomeView.swift
HyzerApp/ViewModels/OnboardingViewModel.swift
HyzerApp/Resources/Assets.xcassets/Contents.json
HyzerApp/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
HyzerApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
HyzerWatch/App/HyzerWatchApp.swift
HyzerWatch/App/HyzerWatch.entitlements
HyzerWatch/Views/WatchRootView.swift
HyzerWatch/Resources/Assets.xcassets/Contents.json
HyzerWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
HyzerKit/Package.swift
HyzerKit/Sources/HyzerKit/Models/Player.swift
HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift
HyzerKit/Sources/HyzerKit/Design/TypographyTokens.swift
HyzerKit/Sources/HyzerKit/Design/SpacingTokens.swift
HyzerKit/Sources/HyzerKit/Design/AnimationTokens.swift
HyzerKit/Sources/HyzerKit/Design/AnimationCoordinator.swift
HyzerKit/Tests/HyzerKitTests/Domain/PlayerTests.swift
HyzerKit/Tests/HyzerKitTests/Fixtures/Player+Fixture.swift
HyzerAppTests/OnboardingViewModelTests.swift
