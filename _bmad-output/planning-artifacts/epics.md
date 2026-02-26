---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
workflowType: 'epics'
project_name: 'hyzer-app'
date: 2026-02-25
author: shotcowboystyle
---

# hyzer-app - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for hyzer-app, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Onboarding & Identity (4 FRs)**
- FR1: A new user can enter a display name on first launch to create their identity
- FR2: On first launch, the system reads the user's iCloud account identifier and stores it as the canonical player identity. If iCloud is unavailable, identity creation succeeds locally and the iCloud association is deferred until available.
- FR3: A new user can access pre-seeded local courses immediately after onboarding
- FR4: A user can complete onboarding without an active network connection

**Course Management (5 FRs)**
- FR5: A user can create a course with a name, hole count (9 or 18), and par per hole
- FR6: A user can set a default par (3) for all holes and adjust individual exceptions
- FR7: A user can edit an existing course's name, hole count, and par values
- FR8: A user can delete a course
- FR9: The system does not restrict course creation, editing, or deletion to any user role; all authenticated users have equal access

**Round Management (8 FRs)**
- FR10: A user can create a new round by selecting a course
- FR11: A user can add registered players to a round by searching by display name
- FR12: A user can add guest players to a round by typing a name (no account required)
- FR12b: Guest players are round-scoped labels with no persistent identity across rounds. No deduplication.
- FR13: Once a round is started, the system prevents adding or removing players
- FR14: The system can auto-detect round completion when all players have scores for all holes
- FR15: A user can manually finish a round at any point, with missing holes recorded as no-score
- FR16: The system designates the round creator as the round organizer
- FR16b: The system displays active rounds that include the current user as a participant, automatically updated via sync

**Scoring: Tap Input (4 FRs)**
- FR17: A user can tap a player row on the current hole to select a score value between 1 and 10, defaulting to par
- FR18: The score picker defaults to the par value for the current hole
- FR19: A user can tap a previously scored player row to correct their score
- FR20: The system auto-advances to the next hole after a brief delay when all players have scores for the current hole

**Scoring: Voice Input (9 FRs)**
- FR21: A user can activate voice input from the current hole's scoring view
- FR22: The system can parse a spoken sentence containing player names and scores against the known player list
- FR23: The system matches spoken name fragments to the known player list using phonetic similarity
- FR24: The system displays parsed scores in a transient confirmation overlay for verification
- FR25: The system auto-commits parsed scores after a 1.5-second timeout if no correction is made
- FR26: A user can tap any entry in the confirmation overlay to correct a misheard score
- FR27: The system can handle partial voice recognition (some names resolved, others unresolved)
- FR28: The system provides a retry and cancel option when voice recognition fails completely
- FR29: Voice input can record scores for all players or a subset in a single utterance

**Scoring: Crown Input - Watch (5 FRs)**
- FR30: A Watch user can select a player from the leaderboard to enter their score
- FR31: A Watch user can adjust a score value using Digital Crown rotation anchored at par
- FR32: The system provides haptic feedback for each Crown increment
- FR33: A Watch user can confirm a Crown-entered score to record it
- FR34: A Watch user can cancel Crown input without recording a score

**Scoring: Cross-Cutting (4 FRs)**
- FR35: Any participant can enter scores for any other participant in the round
- FR36: Each score entry creates an immutable ScoreEvent record
- FR37: A score correction creates a new ScoreEvent that supersedes the previous one (no destructive edits)
- FR38: A user can navigate to any previous hole to view or correct scores

**Live Leaderboard (5 FRs)**
- FR39: The system computes and displays real-time standings ranked by relative score to par
- FR40: The system displays a persistent condensed leaderboard (floating pill) during active rounds
- FR41: A user can expand the condensed leaderboard to view full standings with detailed player information
- FR42: The leaderboard animates position changes when standings shift
- FR43: The leaderboard displays partial round standings with holes-played count for each player

**Real-Time Sync (5 FRs)**
- FR44: The system syncs score data across all participants' devices via CloudKit
- FR45: The system saves all scores locally before attempting cloud sync (offline-first)
- FR46: The system syncs locally-saved scores when network connectivity returns
- FR47: The system silently merges matching scores from two or more devices
- FR48: The system detects score discrepancies when conflicting ScoreEvents arrive for the same player and hole

**Discrepancy Resolution (4 FRs)**
- FR49: The system alerts only the round organizer when a score discrepancy is detected
- FR50: The round organizer can view both conflicting scores with attribution (who recorded each)
- FR51: The round organizer can resolve a discrepancy by selecting the correct score with a single tap
- FR52: A discrepancy resolution creates a new authoritative ScoreEvent that supersedes both conflicting entries

**Apple Watch Companion (5 FRs)**
- FR53: The Watch app displays a purpose-built leaderboard showing current standings
- FR54: The Watch app supports Crown-based score entry
- FR55: The Watch app supports voice score entry using the same micro-language as FR22, routed to paired iPhone for recognition. Falls back to Crown if phone unreachable.
- FR56: The Watch app communicates score data to the phone bidirectionally
- FR57: The Watch app provides haptic confirmations for score actions

**Round Completion & History (5 FRs)**
- FR58: The system displays a round summary with final standings upon round completion
- FR59: A user can view a list of past completed rounds in reverse chronological order
- FR60: A user can tap a past round to view full final standings
- FR61: A user can tap a player in a past round to view their hole-by-hole breakdown
- FR62: The system persists all round data indefinitely for browsing

### NonFunctional Requirements

**Performance (7 NFRs)**
- NFR1: Voice-to-leaderboard: from end of speech to leaderboard reshuffle completing in <3 seconds
- NFR2: Cross-device sync: score entry to leaderboard update on all other devices in <5 seconds on normal connectivity
- NFR3: Tap score entry: picker selection to collapse and score display in <100ms
- NFR4: Crown increment: haptic tick within 50ms of each Crown detent
- NFR5: App launch to active round view in <2 seconds on subsequent launches
- NFR6: Leaderboard reshuffle animation completes in <500ms
- NFR7: Voice confirmation overlay appears within 500ms of speech completion

**Reliability (5 NFRs)**
- NFR8: Zero score data loss under any connectivity condition
- NFR9: Zero crashes during active rounds
- NFR10: Offline scoring parity: all three input paradigms function identically offline and online
- NFR11: CloudKit sync recovery after extended offline period (up to 4 hours) without data loss or duplication
- NFR12: Watch-to-phone score delivery is guaranteed with automatic fallback

**Accessibility (6 NFRs)**
- NFR13: All text meets minimum 4.5:1 contrast ratio against backgrounds (WCAG AA)
- NFR14: All interactive elements meet 44pt minimum touch target (48pt+ for primary scoring controls)
- NFR15: All custom animations respect accessibilityReduceMotion system setting
- NFR16: All screens support Dynamic Type scaling up to Accessibility XXL (AX3)
- NFR17: All interactive elements have meaningful VoiceOver labels and hints
- NFR18: Score state information conveyed by color AND numeric context (not color alone)

**Data Integrity (3 NFRs)**
- NFR19: Event-sourced scoring: no ScoreEvent is ever mutated or deleted
- NFR20: Discrepancy detection is deterministic: identical scores from multiple devices merge silently
- NFR21: Round history persists for at least 5 years (250+ rounds) on-device with CloudKit backup

### Additional Requirements

**From Architecture Document:**
- Starter template: Xcode "iOS App with Watch App" template + shared HyzerKit Swift Package. This is Epic 1 Story 1.
- SwiftData + CloudKit public database incompatibility requires manual CloudKit API for sync (not SwiftData auto-sync)
- Dual ModelConfiguration: domain store (synced models) + operational store (local-only SyncMetadata)
- SyncMetadata table with four-state enum: pending, inFlight, synced, failed (Amendment A1)
- CloudKit container: single container (iCloud.com.shotcowboystyle.hyzerapp), public database, default zone
- Protocol abstractions required: CloudKitClient, WatchConnectivityClient (for testability)
- Sync engine as architectural spike: validate happy path before building conflict complexity (Amendment A10)
- StandingsEngine with explicit recompute(for:trigger:) emitting StandingsChange for animation differentiation
- VoiceParser as nonisolated pure function pipeline: tokenize -> classify -> assemble
- Fuzzy name matching: alias map on Player model + Levenshtein distance fallback
- Current score resolution uses supersession chain (supersedesEventID), not timestamps (Amendment A7)
- Course-to-Hole relationship uses flat foreign key, not SwiftData @Relationship (Amendment A8)
- iCloud identity deferred off app launch path (Amendment A5)
- AppServices composition root with constructor injection, no singletons (Amendment A9)
- HyzerKit Package.swift with swift-tools-version: 6.0 for strict concurrency (Amendment A2)
- App Group ID must match between iOS and watchOS targets (Amendment A4)
- ModelContainer recovery path for corrupted stores (Amendments A3, A6)
- Platform-specific services live in target Services/ directories, not HyzerKit (Speech, WCSession)
- SwiftLint configuration for automated enforcement
- Concurrency boundaries: SyncEngine as actor, StandingsEngine as @MainActor, VoiceParser as nonisolated
- Typed Sendable errors per domain area
- Logger usage over print() throughout
- AnimationTokens + AnimationCoordinator for centralized animation system
- Implementation sequence: Models -> Sync Spike (parallel with StandingsEngine) -> WatchConnectivity -> Voice Parser (parallel with Views) -> Conflict Detection
- Critical path: Models -> StandingsEngine -> Voice Parser -> Scoring Views -> Voice Overlay -> Leaderboard Views
- Architecture recommends allowing any player to resolve discrepancies (PRD deviation, needs product owner approval)

**From UX Design Specification:**
- Dark-dominant color palette with competitive accents (specific hex values defined)
- SF Pro Rounded as primary typeface, SF Mono for score numbers
- 8pt base spacing unit with defined token scale
- Card Stack + Floating Pill as chosen design direction
- Floating leaderboard pill: .ultraThinMaterial blur, 32pt height, horizontal scroll, pulse animation on standings change
- Expanded leaderboard as modal sheet, not navigation push
- Hole scoring cards in horizontal TabView(.page) paging
- Voice confirmation overlay: 1.5-second auto-commit timer (aligned -- UX spec value adopted over PRD's original 3-second)
- Position change indicators (up/down arrows) in pill and expanded leaderboard
- Auto-advance to next hole after 0.5-1 second delay when all scores entered
- Watch: leaderboard-first layout, Crown anchored at par, hero-size score display
- Watch stale indicator when StandingsSnapshot.lastUpdatedAt exceeds 30 seconds
- Voice overlay requires explicit "Commit Scores" button for VoiceOver users (accessibility)
- Voice overlay auto-commit timer pauses during VoiceOver navigation
- App-foreground CKQuery for round discovery to cover missed subscription notifications
- Empty states as invitations -- every dead end chains to a creation flow
- Scoring attribution ("Scored by [name]") on hole card for trust-building
- Round summary card designed for screenshot sharing
- Progressive disclosure: leaderboard -> player detail -> hole-by-hole

### FR Coverage Map

- FR1: Epic 1 - Display name entry on first launch
- FR2: Epic 1 - iCloud identity capture (deferred if unavailable)
- FR3: Epic 1 - Pre-seeded local courses available after onboarding
- FR4: Epic 1 - Offline onboarding support
- FR5: Epic 2 - Create course with name, hole count, par per hole
- FR6: Epic 2 - Default par with individual exceptions
- FR7: Epic 2 - Edit existing course
- FR8: Epic 2 - Delete course
- FR9: Epic 2 - Equal access to course management (no role restriction)
- FR10: Epic 3 - Create round by selecting course
- FR11: Epic 3 - Add registered players by name search
- FR12: Epic 3 - Add guest players by typed name
- FR12b: Epic 3 - Guest players as round-scoped labels, no deduplication
- FR13: Epic 3 - Player list immutable after round start
- FR14: Epic 3 - Auto-detect round completion
- FR15: Epic 3 - Manual finish with missing holes as no-score
- FR16: Epic 3 - Round creator designated as organizer
- FR16b: Epic 3 (enhanced in Epic 4) - Active round discovery via sync
- FR17: Epic 3 - Tap player row to score (1-10, default par)
- FR18: Epic 3 - Score picker defaults to par
- FR19: Epic 3 - Tap scored player to correct
- FR20: Epic 3 - Auto-advance to next hole when all scored
- FR21: Epic 5 - Activate voice input from scoring view
- FR22: Epic 5 - Parse spoken sentence with player names and scores
- FR23: Epic 5 - Phonetic fuzzy name matching
- FR24: Epic 5 - Transient confirmation overlay
- FR25: Epic 5 - Auto-commit after 1.5-second timeout
- FR26: Epic 5 - Tap-to-correct in confirmation overlay
- FR27: Epic 5 - Partial voice recognition handling
- FR28: Epic 5 - Retry and cancel on complete voice failure
- FR29: Epic 5 - Voice scores for all or subset of players
- FR30: Epic 7 - Watch: select player from leaderboard to score
- FR31: Epic 7 - Watch: Digital Crown rotation anchored at par
- FR32: Epic 7 - Watch: haptic feedback per Crown increment
- FR33: Epic 7 - Watch: confirm Crown-entered score
- FR34: Epic 7 - Watch: cancel Crown input
- FR35: Epic 3 - Any participant can score for any other participant
- FR36: Epic 3 - Each score creates immutable ScoreEvent
- FR37: Epic 3 - Corrections create new superseding ScoreEvent
- FR38: Epic 3 - Navigate to any previous hole to view/correct
- FR39: Epic 3 - Real-time standings ranked by relative score to par
- FR40: Epic 3 - Persistent floating leaderboard pill
- FR41: Epic 3 - Expand pill to full standings
- FR42: Epic 3 - Animated position changes on standings shift
- FR43: Epic 3 - Partial round standings with holes-played count
- FR44: Epic 4 - Sync score data across devices via CloudKit
- FR45: Epic 4 - Save scores locally before cloud sync (offline-first)
- FR46: Epic 4 - Sync locally-saved scores when connectivity returns
- FR47: Epic 4 - Silent merge of matching scores from multiple devices
- FR48: Epic 4 - Detect score discrepancies for conflicting ScoreEvents
- FR49: Epic 6 - Alert only round organizer on discrepancy
- FR50: Epic 6 - View both conflicting scores with attribution
- FR51: Epic 6 - Resolve discrepancy with single tap
- FR52: Epic 6 - Resolution creates authoritative superseding ScoreEvent
- FR53: Epic 7 - Watch: purpose-built leaderboard display
- FR54: Epic 7 - Watch: Crown-based score entry
- FR55: Epic 7 - Watch: voice entry routed to phone, Crown fallback
- FR56: Epic 7 - Watch: bidirectional score data communication
- FR57: Epic 7 - Watch: haptic confirmations for score actions
- FR58: Epic 3 - Round summary with final standings on completion
- FR59: Epic 8 - List past rounds in reverse chronological order
- FR60: Epic 8 - Tap past round for full final standings
- FR61: Epic 8 - Tap player in past round for hole-by-hole breakdown
- FR62: Epic 8 - Persist all round data indefinitely

## Epic List

### Epic 1: Project Foundation & First Launch
A user installs the app, enters their display name, and sees pre-seeded courses ready to use. This epic establishes the project structure, SwiftData models, design system tokens, and the zero-friction onboarding experience.
**FRs covered:** FR1, FR2, FR3, FR4
**Dependencies:** None

### Epic 2: Course Management
A user can create custom disc golf courses with hole count and par per hole, set default par with individual exceptions, edit existing courses, and delete courses they no longer need. All users have equal access.
**FRs covered:** FR5, FR6, FR7, FR8, FR9
**Dependencies:** Epic 1

### Epic 3: Round Scoring & Live Leaderboard
A user can create a round, add players and guests, score every hole via tap with a par-anchored picker, see live standings on the floating leaderboard pill and expanded view with animated reshuffles, and complete the round with a summary. This is the complete single-device disc golf scoring experience -- the Architecture's "Layer 0."
**FRs covered:** FR10, FR11, FR12, FR12b, FR13, FR14, FR15, FR16, FR16b, FR17, FR18, FR19, FR20, FR35, FR36, FR37, FR38, FR39, FR40, FR41, FR42, FR43, FR58
**Dependencies:** Epic 1, Epic 2

### Epic 4: Cross-Device Sync
Scores entered on one device appear on all participants' devices in real time. The group shares a live, synced leaderboard. Offline scoring syncs automatically when connectivity returns. Matching scores merge silently; conflicting scores are flagged for resolution.
**FRs covered:** FR44, FR45, FR46, FR47, FR48 (+ FR16b passive round discovery enhancement)
**Dependencies:** Epic 3

### Epic 5: Voice Scoring
A user can speak player names and scores in a natural sentence, verify parsed results in a confirmation overlay, correct misheard entries with a single tap, and auto-commit hands-free while walking. This is the defining experience that proves the app's thesis.
**FRs covered:** FR21, FR22, FR23, FR24, FR25, FR26, FR27, FR28, FR29
**Dependencies:** Epic 3

### Epic 6: Score Discrepancy Resolution
When two people record different scores for the same player on the same hole, the round organizer sees a clear side-by-side comparison with attribution and resolves the conflict with a single tap. All other participants' leaderboards update silently.
**FRs covered:** FR49, FR50, FR51, FR52
**Dependencies:** Epic 3, Epic 4

### Epic 7: Apple Watch Companion
A Watch user can see live standings on their wrist, score any player via Crown rotation with haptic feedback, and trigger voice scoring routed to the paired phone. The Watch works independently when the phone is unreachable, with guaranteed score delivery when reconnected.
**FRs covered:** FR30, FR31, FR32, FR33, FR34, FR53, FR54, FR55, FR56, FR57
**Dependencies:** Epic 3, Epic 4, Epic 5 (for Watch voice)

### Epic 8: Round History & Memory
A user can browse past completed rounds in reverse chronological order, tap into any round to see full final standings, and drill down to any player's hole-by-hole breakdown. History is a scrapbook of competitive memories, not a stats dashboard.
**FRs covered:** FR59, FR60, FR61, FR62
**Dependencies:** Epic 3

---

## Epic 1: Project Foundation & First Launch

A user installs the app, enters their display name, and sees pre-seeded courses ready to use. This epic establishes the project structure, SwiftData models, design system tokens, and the zero-friction onboarding experience.

### Story 1.1: App Shell, Design System & Display Name Onboarding

As a new user,
I want to open the app and enter my display name,
So that I have an identity and can start using the app immediately.

**Scope:** Xcode project creation (iOS + watchOS targets), HyzerKit Swift Package with `Package.swift` (swift-tools-version: 6.0), SwiftData `Player` model, `AppServices` composition root with constructor injection, design system tokens (`ColorTokens`, `AnimationTokens`, typography scale, spacing tokens), `OnboardingView` with single text field, `.swiftlint.yml`.

**Acceptance Criteria:**

**Given** the user opens the app for the first time
**When** the onboarding screen appears
**Then** a single text field with prompt "What should we call you?" is displayed
**And** no other onboarding steps, tutorials, or permission prompts are presented

**Given** the user has entered a display name and tapped done
**When** the player record is created
**Then** the player is saved to SwiftData locally
**And** the user is navigated to the home screen
**And** the interaction completes without any network dependency (FR4)

**Given** the device has no network connectivity
**When** the user completes onboarding
**Then** onboarding succeeds identically to the online case (FR4)

**Given** the Xcode project is built
**When** both iOS and watchOS targets compile
**Then** HyzerKit is imported successfully by both targets
**And** strict concurrency is enforced (Swift 6)
**And** design tokens (colors, typography, spacing, animation) are accessible from HyzerKit

### Story 1.2: iCloud Identity Association

As a user,
I want my identity linked to my iCloud account,
So that my player record persists across devices.

**Scope:** `CKContainer.fetchUserRecordID()` and `CKContainer.accountStatus()` deferred off launch path (A5). Player record initially uses local UUID; iCloud record name associated asynchronously when available. Entitlements: iCloud/CloudKit container, App Groups matching between iOS and watchOS (A4).

**Acceptance Criteria:**

**Given** the user has completed onboarding and iCloud is available
**When** the app resolves iCloud identity asynchronously (via `.task` modifier)
**Then** the Player record is updated with the iCloud user record name
**And** this resolution does not block app launch or first frame rendering (NFR5)

**Given** iCloud is unavailable at launch
**When** the app attempts iCloud identity resolution
**Then** the Player record retains its local UUID
**And** the app functions fully with local identity (FR2, FR4)
**And** iCloud association is retried on subsequent launches

**Given** the iOS and watchOS targets
**When** the entitlements are configured
**Then** both targets share the same App Group ID (`group.com.shotcowboystyle.hyzerapp`) (A4)
**And** the CloudKit container (`iCloud.com.shotcowboystyle.hyzerapp`) is configured on the iOS target

### Story 1.3: Pre-Seeded Courses & Home Screen

As a new user,
I want to see familiar local courses available immediately after onboarding,
So that I can start a round without first creating a course manually.

**Scope:** SwiftData `Course` model and `Hole` model (with flat `courseID` foreign key per A8), `SeededCourses.json` in app bundle, `CourseSeeder` domain service, home screen showing available courses with empty state for no active round.

**Acceptance Criteria:**

**Given** the user has completed onboarding
**When** the home screen loads for the first time
**Then** at least 3 pre-seeded local courses are displayed
**And** courses were loaded from the app bundle, not from CloudKit (FR3)

**Given** the device has no network connectivity
**When** the home screen loads
**Then** seeded courses are still available (loaded from bundle, not network) (FR3, FR4)

**Given** no active round exists
**When** the home screen is displayed
**Then** an empty state invites the user to start their first round or add a course
**And** the empty state chains to a creation flow (not a dead end)

**Given** the Course model
**When** a course with holes is persisted
**Then** Hole records reference their parent Course via `courseID: UUID` (flat foreign key, not @Relationship) (A8)
**And** all model properties are optional or have defaults (CloudKit compatibility)

---

## Epic 2: Course Management

A user can create custom disc golf courses with hole count and par per hole, set default par with individual exceptions, edit existing courses, and delete courses they no longer need. All users have equal access.

### Story 2.1: Create a New Course

As a user,
I want to create a disc golf course with a name, hole count, and par per hole,
So that I can set up courses I play at that aren't pre-seeded.

**Acceptance Criteria:**

**Given** the user is on the course list or home screen
**When** they tap "Add Course"
**Then** a course creation form is presented with fields for course name, hole count (9 or 18), and par per hole (FR5)

**Given** the user is creating a new course
**When** they select a hole count
**Then** all holes default to par 3 (FR6)
**And** the user can adjust individual hole par values as exceptions (FR6)

**Given** the user has entered a valid course name and hole configuration
**When** they save the course
**Then** the course is persisted to SwiftData
**And** the course appears in the course list immediately
**And** no role restriction prevents any authenticated user from creating a course (FR9)

### Story 2.2: Edit and Delete Courses

As a user,
I want to edit or delete existing courses,
So that I can keep my course list accurate and up to date.

**Acceptance Criteria:**

**Given** the user is viewing a course in the course list
**When** they select edit
**Then** the course name, hole count, and par values are editable (FR7)
**And** changes are saved to SwiftData on confirmation

**Given** the user wants to remove a course
**When** they select delete
**Then** a confirmation is presented (system `.confirmationDialog`)
**And** upon confirmation the course is removed from SwiftData (FR8)

**Given** any authenticated user
**When** they attempt to edit or delete any course
**Then** the operation succeeds regardless of who created the course (FR9)

---

## Epic 3: Round Scoring & Live Leaderboard

A user can create a round, add players and guests, score every hole via tap with a par-anchored picker, see live standings on the floating leaderboard pill and expanded view with animated reshuffles, and complete the round with a summary. This is the complete single-device disc golf scoring experience -- the Architecture's "Layer 0."

### Story 3.1: Round Creation & Player Setup

As a user,
I want to create a round by selecting a course and adding players,
So that my group can start playing.

**Scope:** SwiftData `Round` model (playerIDs, organizerID, lifecycle state), `RoundSetupView`, `RoundSetupViewModel`, player search by display name, guest player addition.

**Acceptance Criteria:**

**Given** the user taps "New Round" from the home screen
**When** the round setup flow begins
**Then** a course selection list is presented with seeded and user-created courses (FR10)

**Given** the user has selected a course
**When** the add players screen appears
**Then** the user can search existing players by display name with results appearing after 2-3 characters typed (FR11)
**And** the user can tap "Add Guest" to enter a typed name with no account required (FR12)

**Given** a guest player is added
**When** the round is created
**Then** the guest exists as a round-scoped label with no persistent identity (FR12b)
**And** no deduplication is attempted across rounds (FR12b)

**Given** all players are added
**When** the user taps "Start Round"
**Then** a Round record is created in SwiftData with the creator designated as organizer (FR16)
**And** the round includes a `playerIDs` array for all participants
**And** the scoring view (Hole 1 card) appears immediately

### Story 3.2: Hole Card Tap Scoring & ScoreEvent Creation

As a user,
I want to tap a player's row on a hole card to enter their score,
So that I can record scores quickly and accurately during a round.

**Scope:** `ScorecardContainerView` with `TabView(.page)` horizontal paging, `HoleCardView`, `ScoreInputView` (inline picker), `ScorecardViewModel`, `ScoringService`, SwiftData `ScoreEvent` model (with `supersedesEventID`, `reportedByPlayerID`, `deviceID`).

**Acceptance Criteria:**

**Given** an active round on a hole card
**When** the user taps a player row
**Then** an inline score picker appears with values 1-10, defaulting to par for the current hole (FR17, FR18)

**Given** the user selects a score from the picker
**When** the selection is made
**Then** the picker collapses, the score displays on the player row, and a haptic confirmation fires
**And** an immutable ScoreEvent is created and saved to SwiftData (FR36)
**And** the response completes in <100ms (NFR3)

**Given** any participant in the round
**When** they tap any other participant's row
**Then** they can enter a score for that player (FR35)

**Given** the scoring view
**When** it is displayed
**Then** hole cards are arranged in a horizontal swipeable card stack (TabView page style)
**And** each card shows hole number, par, and all player rows with scores or dashes for unscored

### Story 3.3: Score Corrections & Hole Navigation

As a user,
I want to correct a previously entered score and navigate to any hole,
So that mistakes can be fixed without disrupting the round.

**Acceptance Criteria:**

**Given** a player row already has a score
**When** the user taps the scored row
**Then** the picker reopens with the current score pre-selected (FR19)

**Given** the user selects a new score value
**When** the correction is confirmed
**Then** a new ScoreEvent is created with `supersedesEventID` pointing to the previous event (FR37)
**And** the previous ScoreEvent is never mutated or deleted (NFR19)

**Given** the user is on any hole card
**When** they swipe right
**Then** the previous hole card is displayed for review or correction (FR38)

**Given** all players have scores for the current hole
**When** the last score is entered
**Then** the card auto-advances to the next hole after a 0.5-1 second delay (FR20)
**And** the user can swipe back to the previous hole to review or correct

### Story 3.4: Live Leaderboard -- Floating Pill & Expanded View

As a user,
I want to see live standings in a floating pill and expand to a full leaderboard,
So that I always know who's winning without leaving the scoring view.

**Scope:** `StandingsEngine` with `recompute(for:trigger:)` emitting `StandingsChange`, `LeaderboardPillView` (`.ultraThinMaterial`, horizontal scroll), `LeaderboardExpandedView` (modal sheet), `AnimationCoordinator`, `LeaderboardViewModel`.

**Acceptance Criteria:**

**Given** an active round with at least one score entered
**When** the standings are computed
**Then** players are ranked by relative score to par (FR39)
**And** partial round standings show holes-played count per player (FR43)

**Given** the scoring view during an active round
**When** it is displayed
**Then** a persistent floating leaderboard pill overlays the top of the screen (FR40)
**And** the pill shows condensed standings with position, name, and +/- par score
**And** the pill horizontally scrolls to keep the current user visible

**Given** the user taps the floating pill
**When** the expanded leaderboard appears
**Then** it presents as a modal sheet (not navigation push) with full standings (FR41)
**And** the user can dismiss by swiping down, returning to the exact hole card

**Given** a new score changes the standings
**When** the StandingsEngine recomputes
**Then** the pill pulses briefly (scale 1.0 to 1.03, 0.3s) and position change arrows appear
**And** the expanded leaderboard (if open) animates rows to new positions with spring timing <500ms (FR42, NFR6)
**And** all animations respect `accessibilityReduceMotion` (NFR15)

**Given** `StandingsEngine.recompute(for:trigger:)` is called
**When** the trigger is `.localScore`
**Then** `StandingsChange` includes previous and new standings for animation differentiation

### Story 3.5: Round Lifecycle & Player Immutability

As a user,
I want the round to manage itself -- locking the player list once started, detecting completion, and allowing manual finish,
So that the round progresses reliably without manual housekeeping.

**Scope:** `RoundLifecycleManager`, round state machine, auto-completion detection, manual finish flow.

**Acceptance Criteria:**

**Given** a round has been started
**When** the active round view is displayed
**Then** add-player and remove-player controls are hidden (FR13)
**And** the data layer rejects player list mutations for active rounds (FR13)

**Given** all players have scores for all holes
**When** `ScoringService.createScoreEvent()` completes the last missing score
**Then** `RoundLifecycleManager.checkCompletion()` transitions the round to `.awaitingFinalization`
**And** the user is prompted "All scores recorded. Finalize round?" (FR14)

**Given** the user wants to end a round early
**When** they tap "Finish Round" from the round menu
**Then** if missing scores exist, a warning is shown: "Some holes have missing scores. Finish anyway?" (FR15)
**And** upon confirmation, missing holes are recorded as no-score and the round completes (FR15)

**Given** a round is active and the current user is a participant
**When** the home screen is displayed
**Then** the active round appears in the user's round list (FR16b, local discovery -- enhanced with sync in Epic 4)

### Story 3.6: Round Completion & Summary

As a user,
I want to see a polished round summary with final standings when the round ends,
So that the round lands with satisfying closure and I can share the results.

**Acceptance Criteria:**

**Given** a round has been finalized (auto-detect or manual)
**When** the round summary is generated
**Then** a round summary card displays: course name, date, final standings with +/- par for all players (FR58)

**Given** the round summary is displayed
**When** the user views it
**Then** the layout is clean and screenshot-ready (course name, date, ranked standings)
**And** the summary uses the warm off-course visual register (comfortable typography, unhurried spacing)

**Given** the user dismisses the summary
**When** they return to the home screen
**Then** the home screen shows no active round
**And** the completed round is accessible from the round list

---

## Epic 4: Cross-Device Sync

Scores entered on one device appear on all participants' devices in real time. The group shares a live, synced leaderboard. Offline scoring syncs automatically when connectivity returns. Matching scores merge silently; conflicting scores are flagged for resolution.

### Story 4.1: CloudKit Sync Engine & Architectural Spike

As a user,
I want scores I enter to appear on my friends' devices,
So that the group shares a live leaderboard during the round.

**Scope:** `CloudKitClient` protocol + `LiveCloudKitClient`, `SyncEngine` actor with `pushPending()` and `pullRecords()`, `SyncMetadata` model (local-only, separate `ModelConfiguration`), sync DTOs (`ScoreEventRecord`, `RoundRecord`, `PlayerRecord`, `CourseRecord`), `SyncState` enum as `@Observable`. Spike scope: ScoreEvent push/pull only, no subscriptions, no conflict detection.

**Acceptance Criteria:**

**Given** a ScoreEvent is created on device A
**When** `SyncEngine.pushPending()` executes
**Then** the ScoreEvent is translated to a `ScoreEventRecord` DTO and saved to CloudKit public database (FR44)
**And** a `SyncMetadata` entry tracks the sync status

**Given** device B is running the app
**When** `SyncEngine.pullRecords()` executes
**Then** new ScoreEvents from CloudKit are translated from DTOs, saved to local SwiftData, and reflected in the leaderboard
**And** `StandingsEngine.recompute(for:trigger:.remoteSync)` is called

**Given** a ScoreEvent is created locally
**When** it is saved to SwiftData
**Then** the local write completes before any sync attempt (FR45)
**And** the UI updates immediately from local data

**Given** `SyncEngine` is an `actor`
**When** `pushPending()` suspends at `await CloudKitClient.save()`
**Then** `.inFlight` status prevents duplicate pushes from actor reentrancy (A1)
**And** failed pushes revert to `.failed` for retry

**Given** the `ModelContainer` is constructed
**When** the dual `ModelConfiguration` is created
**Then** domain models and `SyncMetadata` use separate backing stores (A3)
**And** operational store corruption is recoverable by deletion and reconstruction (A3)

### Story 4.2: Offline Queue & Sync Recovery

As a user,
I want scores I enter without connectivity to sync automatically when I'm back online,
So that no scores are ever lost, even on courses with no signal.

**Scope:** `SyncMetadata` four-state enum (pending/inFlight/synced/failed), `CKSubscription` per record type for push-based sync, periodic fallback timer (30-60s during active rounds tied to round lifecycle), `SyncIndicatorView`, app-foreground round discovery CKQuery.

**Acceptance Criteria:**

**Given** the device has no network connectivity
**When** a score is entered
**Then** the ScoreEvent saves to SwiftData and a `SyncMetadata` entry is created as `.pending` (FR45)
**And** scoring functions identically to the online case (NFR10)

**Given** network connectivity returns after an offline period
**When** the `SyncEngine` detects connectivity
**Then** all `.pending` and `.failed` entries are pushed to CloudKit (FR46)
**And** all entries sync successfully without data loss or duplication (NFR8, NFR11)

**Given** an active round is in progress
**When** the periodic fallback timer fires (30-60s)
**Then** `SyncEngine.pullRecords()` fetches any missed updates
**And** the timer stops when the round completes or the app backgrounds

**Given** the device is offline
**When** the scoring view is displayed
**Then** a subtle sync indicator (cloud-slash icon) is visible in the toolbar
**And** the indicator clears when sync completes

**Given** the app enters foreground outside an active round
**When** the home screen loads
**Then** a single CKQuery fetches active rounds where the current user's ID is in `playerIDs` (FR16b enhancement)
**And** this covers missed CKSubscription notifications

### Story 4.3: Silent Merge & Discrepancy Detection

As a user,
I want matching scores from multiple devices to merge silently and conflicting scores to be flagged,
So that the leaderboard stays accurate without unnecessary alerts.

**Scope:** `ConflictDetector` with four-case mechanical detection using `supersedesEventID`, CKSubscription setup via `SubscriptionManager`.

**Acceptance Criteria:**

**Given** two devices submit ScoreEvents for the same {player, hole} with the same strokeCount and no `supersedesEventID`
**When** the sync engine processes both events
**Then** the scores merge silently with no user notification (FR47)
**And** the leaderboard reflects a single score

**Given** two devices submit ScoreEvents for the same {player, hole} with different strokeCount values and no `supersedesEventID`
**When** the sync engine processes both events
**Then** a discrepancy is detected and flagged (FR48)
**And** the discrepancy is stored for resolution (handled in Epic 6)

**Given** a ScoreEvent has a `supersedesEventID` pointing to an event from the same device
**When** the sync engine processes it
**Then** it is treated as a correction, not a conflict

**Given** a ScoreEvent has a `supersedesEventID` pointing to an event from a different device
**When** the sync engine processes it
**Then** it is treated as a discrepancy requiring resolution

**Given** CKSubscriptions are configured
**When** a new record is saved to CloudKit by another device
**Then** a silent push notification triggers `SyncEngine.pullRecords()`
**And** cross-device leaderboard updates arrive within <5 seconds on normal connectivity (NFR2)

---

## Epic 5: Voice Scoring

A user can speak player names and scores in a natural sentence, verify parsed results in a confirmation overlay, correct misheard entries with a single tap, and auto-commit hands-free while walking. This is the defining experience that proves the app's thesis.

### Story 5.1: Voice Recognition & Parser Pipeline

As a user,
I want to speak player names and scores and have the system understand them,
So that I can enter scores without touching the screen.

**Scope:** `VoiceRecognitionService` (iOS-only SFSpeechRecognizer wrapper in HyzerApp/Services/), `VoiceParser` (nonisolated, in HyzerKit/Voice/) with tokenize -> classify -> assemble pipeline, `TokenClassifier`, `FuzzyNameMatcher` (alias map on Player model + Levenshtein distance fallback), `VoiceParseResult` enum (.success/.partial/.failed).

**Acceptance Criteria:**

**Given** the user taps the microphone button on a hole card
**When** the voice input activates
**Then** a listening indicator appears and on-device speech recognition begins (FR21)
**And** the voice confirmation overlay appears within 500ms of speech completion (NFR7)

**Given** the user speaks "Mike 3, Jake 4, Sarah 2"
**When** the transcript is processed by `VoiceParser`
**Then** the parser tokenizes the input, classifies tokens as names or numbers, and assembles player-score pairs (FR22)
**And** player names are matched against the known player list using fuzzy matching (FR23)

**Given** a spoken name fragment like "Mike" when the display name is "Michael"
**When** `FuzzyNameMatcher` processes the token
**Then** the alias map is checked first, then Levenshtein distance fallback matches within threshold (FR23)

**Given** `VoiceParser` is in HyzerKit
**When** it processes a transcript
**Then** it executes as a `nonisolated` pure function with no platform imports (no Speech framework dependency)
**And** it can be called from any isolation context without `await`

### Story 5.2: Voice Confirmation Overlay & Auto-Commit

As a user,
I want to see what the system heard, verify it's correct, and have it commit automatically,
So that scoring is fast and hands-free in the common case.

**Scope:** `VoiceOverlayView`, `VoiceOverlayViewModel`, confirmation overlay with parsed scores, 1.5-second auto-commit timer, tap-to-correct inline editing, VoiceOver accessibility (explicit commit button, timer pause during VoiceOver navigation).

**Acceptance Criteria:**

**Given** `VoiceParser` returns `.success` with all names resolved
**When** the confirmation overlay appears
**Then** all parsed player-score pairs are displayed (e.g., "Mike .... 3, Jake .... 4, Sarah ... 2") (FR24)
**And** a 1.5-second auto-commit timer begins (FR25)

**Given** the auto-commit timer is running
**When** the timer expires without user interaction
**Then** all parsed scores are committed as ScoreEvents via `ScoringService` (FR25)
**And** the overlay dismisses and the leaderboard pill updates

**Given** the user taps an entry in the confirmation overlay
**When** the entry becomes editable
**Then** an inline picker or number pad appears for correction (FR26)
**And** the auto-commit timer resets to 1.5 seconds after each correction

**Given** the user speaks scores for a subset of players (e.g., "Jake 4" only)
**When** the overlay appears
**Then** only the spoken player-score pairs are shown and committed (FR29)
**And** unmentioned players remain unscored on the hole card

**Given** VoiceOver is active
**When** the confirmation overlay appears
**Then** all parsed scores are announced immediately
**And** an explicit "Commit Scores" button is present (visually de-emphasized) for VoiceOver users
**And** the auto-commit timer pauses when VoiceOver focus is on any overlay entry

**Given** the voice-to-leaderboard pipeline completes (no corrections)
**When** measured end-to-end from speech completion to leaderboard reshuffle
**Then** the total time is under 3 seconds (NFR1)

### Story 5.3: Partial & Failed Recognition Handling

As a user,
I want graceful handling when voice recognition doesn't fully work,
So that I can still score efficiently without starting over.

**Acceptance Criteria:**

**Given** `VoiceParser` returns `.partial` (some names resolved, others not)
**When** the confirmation overlay appears
**Then** resolved names display their scores normally
**And** unresolved entries are highlighted with "?" for manual correction (FR27)
**And** the user can tap unresolved entries to select the correct player from a picker

**Given** `VoiceParser` returns `.failed` (no names resolved)
**When** the error state appears
**Then** the user sees "Couldn't understand. Try again?" with retry and cancel options (FR28)
**And** retry returns to listening mode
**And** cancel dismisses the overlay and returns to the hole card for tap scoring

**Given** any voice recognition failure
**When** the user cancels or falls back
**Then** no ScoreEvents are created
**And** the scoring view is in the same state as before voice input was activated

---

## Epic 6: Score Discrepancy Resolution

When two people record different scores for the same player on the same hole, the round organizer sees a clear side-by-side comparison with attribution and resolves the conflict with a single tap. All other participants' leaderboards update silently.

### Story 6.1: Discrepancy Alert & Resolution Flow

As a round organizer,
I want to see conflicting scores side-by-side with who recorded each and resolve the conflict with a single tap,
So that score disputes are handled fairly without disrupting the round.

**Scope:** `DiscrepancyAlertView`, `DiscrepancyResolutionView`, `DiscrepancyViewModel`. Integrates with `ConflictDetector` (built in Epic 4, Story 4.3) for discrepancy detection and `ScoringService` for resolution ScoreEvent creation.

**Acceptance Criteria:**

**Given** the `ConflictDetector` flags a discrepancy for a {player, hole}
**When** the discrepancy is detected
**Then** only the round organizer receives an in-app notification badge (FR49)
**And** non-organizer participants are not notified about the conflict

**Given** the organizer opens the discrepancy view
**When** the conflicting scores are displayed
**Then** both values are shown with attribution: player name, hole number, score A recorded by Person X, score B recorded by Person Y, with timestamps (FR50)

**Given** the organizer taps the correct score
**When** the resolution is confirmed
**Then** a new authoritative ScoreEvent is created that supersedes both conflicting events (FR52)
**And** the resolution ScoreEvent is marked as "resolved by organizer"
**And** the event is synced to all devices via CloudKit

**Given** a discrepancy is resolved
**When** other participants' devices sync the resolution
**Then** their leaderboards update silently with no notification about the conflict (FR51)
**And** the discrepancy badge clears on the organizer's device

**Given** multiple discrepancies exist
**When** the organizer views the discrepancy list
**Then** each discrepancy is listed separately and can be resolved independently

---

## Epic 7: Apple Watch Companion

A Watch user can see live standings on their wrist, score any player via Crown rotation with haptic feedback, and trigger voice scoring routed to the paired phone. The Watch works independently when the phone is unreachable, with guaranteed score delivery when reconnected.

### Story 7.1: Watch App Shell & Leaderboard Display

As a Watch user,
I want to see live standings on my wrist during a round,
So that I can track the competition without pulling out my phone.

**Scope:** `WatchConnectivityClient` protocol (shared in HyzerKit), `PhoneConnectivityClient` (iOS side), `WatchConnectivityClientImpl` (watchOS side), `WatchMessage` enum, `StandingsSnapshot`, `WatchCacheManager` (JSON read/write in app group), `WatchLeaderboardView`, `WatchLeaderboardViewModel`, `WatchStaleIndicatorView`.

**Acceptance Criteria:**

**Given** a round is active on the paired phone
**When** the Watch app launches
**Then** a purpose-built leaderboard displays current standings with position, player name, and +/- par score (FR53)
**And** each player gets a full-width row with no horizontal scrolling

**Given** the phone sends a standings update via `WatchConnectivity`
**When** the Watch receives the message
**Then** the leaderboard updates with the new standings (FR56)
**And** standings reshuffles animate to match the phone's competitive moment

**Given** the phone is unreachable
**When** the Watch app loads
**Then** the leaderboard displays the last known standings from the app group JSON cache
**And** a stale indicator shows relative time since last update (e.g., "2m ago") when `lastUpdatedAt` exceeds 30 seconds

**Given** the phone sends standings
**When** the delivery method is chosen
**Then** `sendMessage` is used for instant delivery when both apps are active
**And** `WatchCacheManager` writes to app group JSON as a persistent fallback

### Story 7.2: Crown Score Entry

As a Watch user,
I want to enter a score by rotating the Digital Crown,
So that I can score from my wrist without touching the screen.

**Scope:** `WatchScoringView`, `WatchScoringViewModel`, `.digitalCrownRotation` binding, haptic feedback per increment, score color coding.

**Acceptance Criteria:**

**Given** the Watch leaderboard is displayed
**When** the user taps a player name
**Then** the Crown input screen appears with a large centered number defaulting to par for the current hole (FR30, FR31)
**And** the player name is displayed at top

**Given** the Crown input screen is active
**When** the user rotates the Digital Crown
**Then** the score increments or decrements by 1 per detent, anchored at par (FR31)
**And** a haptic tick fires within 50ms of each Crown detent (FR32, NFR4)
**And** the large number updates in real time with score-state color (green under par, amber over par, white at par)

**Given** the user has selected a score
**When** they tap to confirm
**Then** the score is recorded with a strong haptic confirmation pulse (FR33, FR57)
**And** the Watch returns to the leaderboard with updated standings

**Given** the user wants to cancel
**When** they navigate back
**Then** no score is recorded and the leaderboard is unchanged (FR34)

**Given** the Crown score entry is confirmed
**When** the Watch processes the score
**Then** a ScoreEvent is created and sent to the phone (FR54)
**And** `transferUserInfo` is used for guaranteed delivery (NFR12)

### Story 7.3: Watch Voice Scoring & Bidirectional Communication

As a Watch user,
I want to speak scores from my wrist and have them processed by the phone,
So that I have the same voice scoring experience without pulling out my phone.

**Scope:** Watch microphone button triggering voice input routed to paired phone, `WatchMessage` score event transfer, bidirectional communication hardening, haptic confirmations.

**Acceptance Criteria:**

**Given** the Watch scoring view is active
**When** the user taps the microphone button
**Then** the voice input is routed to the paired phone for recognition and parsing (FR55)
**And** parsed results are sent back to the Watch for display

**Given** the paired phone is unreachable
**When** the user taps the microphone button on the Watch
**Then** voice input is unavailable with a clear message
**And** the Crown input remains available as fallback (FR55)

**Given** a score is entered on the Watch (Crown or voice)
**When** the score is transmitted to the phone
**Then** the phone processes it through `ScoringService.createScoreEvent()` (FR56)
**And** the score syncs to all other devices via CloudKit

**Given** standings change on the phone
**When** the phone sends an update to the Watch
**Then** the Watch leaderboard updates bidirectionally (FR56)
**And** a haptic confirmation fires on the Watch for score-related actions (FR57)

---

## Epic 8: Round History & Memory

A user can browse past completed rounds in reverse chronological order, tap into any round to see full final standings, and drill down to any player's hole-by-hole breakdown. History is a scrapbook of competitive memories, not a stats dashboard.

### Story 8.1: History List & Round Detail

As a user,
I want to browse my past rounds and see who won each one,
So that I can revisit competitive memories and settle friendly debates.

**Scope:** `HistoryListView`, `HistoryListViewModel`, `RoundSummaryView` (reused from Epic 3 Story 3.6 for detail), reverse-chronological card feed.

**Acceptance Criteria:**

**Given** the user navigates to the history view (home screen with no active round, or history tab)
**When** the round history loads
**Then** completed rounds are displayed in reverse chronological order as a card feed (FR59)
**And** each card shows: course name, date, player count, winner and their score, the user's finishing position and score

**Given** the user taps a round card
**When** the round detail view loads
**Then** full final standings are displayed with all players, their +/- par scores, and finishing positions (FR60)
**And** round metadata is visible: date, course name, who organized

**Given** rounds accumulate over time (~50 rounds/year)
**When** the history list is scrolled
**Then** performance remains smooth with SwiftData pagination
**And** all round data persists indefinitely on-device (FR62, NFR21)

### Story 8.2: Player Hole-by-Hole Breakdown

As a user,
I want to tap a player in a past round to see their score on every hole,
So that I can review individual performance in detail.

**Acceptance Criteria:**

**Given** the user is viewing a past round's final standings
**When** they tap a player row
**Then** the player's hole-by-hole breakdown is displayed (FR61)
**And** each hole shows: hole number, par, the player's score, and +/- par for that hole

**Given** the hole-by-hole breakdown is displayed
**When** the user reviews it
**Then** scores use the same score-state color coding as the active scoring view (green under par, amber over par, white at par)
**And** the progressive disclosure pattern is complete: history list -> round detail -> player breakdown -> hole-by-hole
