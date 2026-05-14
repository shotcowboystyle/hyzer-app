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
  - _bmad-output/planning-artifacts/epics.md
workflowType: 'epics'
project_name: 'hyzer-app'
scope: 'Post-MVP (Phase 2 Polish, Phase 3 Memory, Phase 4 Social) + TestFlight Launch Readiness'
requirementPrefix: 'PMVP-FR / PMVP-NFR'
date: 2026-05-13
author: shotcowboystyle
relatedDocument: 'epics.md (Epics 1-8, complete)'
---

# hyzer-app - Post-MVP Epic Breakdown

## Overview

This document covers Post-MVP work for hyzer-app: TestFlight Launch Readiness plus the three Post-MVP phases defined in `prd.md` (lines 474-489). Epics 1-8 (the MVP) are documented in `epics.md` and are complete.

All requirements in this document use the **PMVP-** prefix to distinguish them from validated MVP requirements (FR1-FR62, NFR1-NFR21) in the original PRD. PMVP requirements were derived from the PRD's Post-MVP roadmap bullets and UX specification components and have not been through the BMAD PRD validation workflow.

## Requirements Inventory

### Functional Requirements (Derived)

**TestFlight Launch Readiness (5 PMVP-FRs)**
- PMVP-FR1: The Xcode project produces archived builds for iOS and watchOS targets with release configuration, proper bundle identifiers (`com.shotcowboystyle.hyzerapp` + `.watchkitapp`), version (CFBundleShortVersionString), and build number (CFBundleVersion).
- PMVP-FR2: The app includes a Privacy Manifest (`PrivacyInfo.xcprivacy`) declaring data collection types (iCloud identifier for sync, microphone audio for speech recognition — both processed on-device, not transmitted).
- PMVP-FR3: The iOS Info.plist includes localized usage strings for `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, and any other permission required by the live code.
- PMVP-FR4: The app includes complete icon sets for iOS (all required sizes including App Store 1024×1024) and watchOS (all required sizes), plus a launch screen.
- PMVP-FR5: An App Store Connect record exists with a TestFlight internal/external test group containing the closed friend group, capable of distributing builds without a public listing.

**Phase 2 Polish (8 PMVP-FRs)**
- PMVP-FR6: A user can view the polished round history feed as warm card-based previews (UX spec component #8) showing course name, date, player count, winner with score, and the user's finishing position and score. Cards render 3-4 per screen at standard iPhone width.
- PMVP-FR7: A round summary upon completion uses the screenshot-first design (UX spec component #7) with course name (H1), date, ranked player rows with position/medal indicator, final score (+/- par, SF Mono, score-state color), total strokes, and round metadata.
- PMVP-FR8: A user can share a round summary card via the system share sheet, producing a screenshot-optimized rendering suitable for group chat (high contrast, no interaction-dependent elements).
- PMVP-FR9: During round creation, the user is offered a one-tap "Same group as last round" option that pre-populates the player list from the most recently completed round. The user can edit before confirming.
- PMVP-FR10: Each scored player row on a hole card displays scoring attribution ("Scored by [name]") in de-emphasized typography (caption tier), reading from `ScoreEvent.reportedByPlayerID`.
- PMVP-FR11: When a round is created and the current user is added as a participant, a push notification is delivered ("[Organizer] started a round at [Course]"). User must grant notification permission; if denied, in-app discovery still works (existing FR16b).
- PMVP-FR12: When a round in which the user participated reaches `.completed` state, a push notification is delivered ("Round complete at [Course]. [Winner] won at [score].").
- PMVP-FR13: When the conflict detector flags a discrepancy and the current user is the round organizer, a push notification is delivered ("Score discrepancy on hole [n] needs review.").

**Phase 3 Memory (3 PMVP-FRs)**
- PMVP-FR14: A user can view a score trend visualization for any player showing their relative-to-par score across rounds in chronological order (line chart, Swift Charts).
- PMVP-FR15: A user can view personal-best records per course: the lowest absolute score and the best relative-to-par score the player has achieved on that course, with the date.
- PMVP-FR16: A user can view a head-to-head record between any two players in their history: rounds played together, wins (count and percentage), and average score differential.

**Phase 4 Social (2 PMVP-FRs)**
- PMVP-FR17: When the user opens the app on the same local network as another active hyzer-app device with an in-progress round that includes them as a player, the active round appears immediately without waiting for CloudKit subscription delivery. Implementation via MultipeerConnectivity Bonjour discovery.
- PMVP-FR18: A round summary card includes a generative visual signature (round-specific visual element derived deterministically from round data — course, players, scores) that is unique to each round and reproducible from the same input data.

### Non-Functional Requirements (Derived)

**Privacy & Distribution**
- PMVP-NFR1: Push notification payloads do not contain PII beyond first names (no iCloud identifiers, no email, no precise scores in the visible alert body — silent push or summary-only).
- PMVP-NFR2: MultipeerConnectivity discovery operates over local network only (Bonjour) and never transmits player data over the internet.

**Performance**
- PMVP-NFR3: History list pagination keeps scroll performance smooth at 250+ rounds (5-year horizon per existing NFR21) — frame time <16ms during scroll.
- PMVP-NFR4: Score trend chart renders within 500ms from view appear for player histories up to 250 rounds.

### Additional Requirements

**From Architecture (implementation considerations for Post-MVP):**
- APNs entitlement and push notification capability must be added to the iOS target.
- `UNUserNotificationCenter` permission flow must run lazily (not on launch) to keep launch path under 2s (NFR5).
- `MultipeerConnectivity` framework integration with proper `NSLocalNetworkUsageDescription` and `NSBonjourServices` Info.plist entries.
- Swift Charts framework usage for trend visualization (iOS 16+, already satisfied by iOS 18 minimum).
- `ImageRenderer` for screenshot-optimized round summary rendering.
- Memory-resident query caches for head-to-head computations to avoid recomputing on every view appearance.
- Push notification handling must be wired through a `NotificationService` protocol with mock for testing.

**Resolved tech debt (from CLAUDE.md, addressed alongside Post-MVP work):**
- `ColorTokens.border` referenced but never defined — must be defined before any new components reference it.

### UX Design Requirements

- UX-PMVP-DR1: Round Summary Card (UX spec §1097-1124, component #7) must be screenshot-first: high contrast, clean typography (H1 course name centered, H2 player names, SF Mono scores in score-state color), no interaction-dependent elements, designed to look good as a PNG in a message bubble.
- UX-PMVP-DR2: History Round Card (UX spec §1126-1147, component #8) must use the warm off-course emotional register — comfortable typography, unhurried spacing — and remain compact enough to show 3-4 cards per screen at 390pt width.
- UX-PMVP-DR3: Scoring attribution text must use caption tier and `secondaryText` color so it does not compete visually with the score itself.
- UX-PMVP-DR4: Push notifications on Watch use `.notification` haptic; in-app notification UI follows existing alert patterns (no new modal style).
- UX-PMVP-DR5: Phase 3 Memory views (trends, personal bests, head-to-head) use the off-course warm register, not the on-course competitive register — they are reflective surfaces, not active scoring.
- UX-PMVP-DR6: Visual round signature must be generative but restrained — no mascots, no confetti. Geometric or color-derived treatment that fits the existing dark-dominant palette.

### Requirements Coverage Map

- PMVP-FR1: Epic 9 — TestFlight archived build configuration for iOS + watchOS
- PMVP-FR2: Epic 9 — Privacy Manifest (`PrivacyInfo.xcprivacy`)
- PMVP-FR3: Epic 9 — Info.plist permission usage strings
- PMVP-FR4: Epic 9 — Complete app icon sets and launch screen
- PMVP-FR5: Epic 9 — App Store Connect record + TestFlight test group
- PMVP-FR6: Epic 11 — Polished history round card with course/date/winner/your-position
- PMVP-FR7: Epic 11 — Screenshot-first round summary card (UX component #7)
- PMVP-FR8: Epic 11 — System share sheet for round summary
- PMVP-FR9: Epic 10 — "Same group as last round" quick-add at round setup
- PMVP-FR10: Epic 10 — Scoring attribution display on hole card
- PMVP-FR11: Epic 12 — Push notification: round started (participants)
- PMVP-FR12: Epic 12 — Push notification: round complete (participants)
- PMVP-FR13: Epic 12 — Push notification: discrepancy detected (organizer)
- PMVP-FR14: Epic 13 — Score trend visualization per player (Swift Charts)
- PMVP-FR15: Epic 13 — Personal best per course
- PMVP-FR16: Epic 13 — Head-to-head record between any two players
- PMVP-FR17: Epic 14 — MultipeerConnectivity nearby active-round discovery
- PMVP-FR18: Epic 14 — Generative visual round signature on summary card
- PMVP-NFR1: Epic 12 — Push payload PII restraint
- PMVP-NFR2: Epic 14 — Multipeer local-network-only operation
- PMVP-NFR3: Epic 13 — History list scroll performance at 250+ rounds
- PMVP-NFR4: Epic 13 — Score trend chart render <500ms

## Epic List

### Epic 9: TestFlight Launch Readiness
The friend group can install hyzer-app via TestFlight. Establishes build configuration, privacy manifest, Info.plist usage strings, app icons/launch screen, and the App Store Connect record needed to distribute outside development. Also resolves the `ColorTokens.border` tech debt blocker.
**PMVP-FRs covered:** PMVP-FR1, PMVP-FR2, PMVP-FR3, PMVP-FR4, PMVP-FR5
**Dependencies:** Epics 1-8 (the codebase under test). No Post-MVP dependencies.

### Epic 10: Round Setup Quick-Add & Scoring Attribution
Two small Quality-of-Life wins inside the active-round flow: one-tap reuse of the previous round's player roster, and "Scored by [name]" attribution on each scored player row of the hole card. Fastest user-facing wins after the TestFlight unlock.
**PMVP-FRs covered:** PMVP-FR9, PMVP-FR10
**Dependencies:** Epic 9.

### Epic 11: Polished History & Shareable Round Summaries
Users see the polished history feed (warm card-based previews) and a screenshot-first round summary they can share via the system share sheet. Replaces the MVP's minimal summary and basic history list with UX spec components #7 and #8.
**PMVP-FRs covered:** PMVP-FR6, PMVP-FR7, PMVP-FR8
**Dependencies:** Epic 9. (Round summary is further elevated in Epic 14 with a visual signature.)

### Epic 12: Push Notifications
The group learns about round events without opening the app: round started, round complete, and (for organizers) discrepancy detected. Establishes the APNs pipeline, lazy permission flow, and `NotificationService` protocol abstraction.
**PMVP-FRs covered:** PMVP-FR11, PMVP-FR12, PMVP-FR13
**PMVP-NFRs covered:** PMVP-NFR1
**Dependencies:** Epic 9.

### Epic 13: Long-Term Memory — Trends, Personal Bests, Head-to-Head
Users see how they're doing over time: score trend per player, personal best per course, and head-to-head records between any two players. Pure read-side features over existing event-sourced data.
**PMVP-FRs covered:** PMVP-FR14, PMVP-FR15, PMVP-FR16
**PMVP-NFRs covered:** PMVP-NFR3, PMVP-NFR4
**Dependencies:** Epic 9. Soft dependency on Epic 11 (entry points sit in the polished history surface).

### Epic 14: Nearby Discovery & Visual Round Signature
The most technically novel work: MultipeerConnectivity-based local-network discovery surfaces in-progress rounds without waiting for CloudKit subscriptions, and the round summary card carries a generative visual signature unique to each round.
**PMVP-FRs covered:** PMVP-FR17, PMVP-FR18
**PMVP-NFRs covered:** PMVP-NFR2
**Dependencies:** Epic 9. Soft dependency on Epic 11 (PMVP-FR18 modifies the round summary built there).

---

## Epic 9: TestFlight Launch Readiness

The friend group can install hyzer-app via TestFlight. Establishes build configuration, privacy manifest, Info.plist usage strings, app icons/launch screen, and the App Store Connect record needed to distribute outside development. Also resolves the `ColorTokens.border` tech debt blocker.

### Story 9.1: Release Build Configuration & Signing

As the developer,
I want a properly configured Release build for both iOS and watchOS targets with stable bundle identifiers and version numbers,
So that I can produce archivable builds suitable for TestFlight upload.

**Scope:** Bundle identifiers (`com.shotcowboystyle.hyzerapp` for iOS, `com.shotcowboystyle.hyzerapp.watchkitapp` for watchOS), `CFBundleShortVersionString` and `CFBundleVersion`, Release configuration with proper signing (Automatic with the developer team ID), `project.yml` updates regenerated via XcodeGen, and CI/local archive validation.

**Acceptance Criteria:**

**Given** the developer runs `xcodegen generate` and opens the project
**When** the build configuration is inspected for both targets
**Then** the iOS target uses bundle identifier `com.shotcowboystyle.hyzerapp` and the watchOS target uses `com.shotcowboystyle.hyzerapp.watchkitapp` (PMVP-FR1)
**And** both targets share a `CFBundleShortVersionString` (initial value `0.1.0`) and a monotonically incrementing `CFBundleVersion`

**Given** the Release build configuration is selected
**When** the developer runs `xcodebuild archive` for the iOS target with the paired Watch app embedded
**Then** the archive completes without manual signing prompts using the configured developer team
**And** the resulting `.xcarchive` is valid for App Store / TestFlight upload (verifiable via `xcodebuild -exportArchive`)

**Given** strict concurrency and SwiftLint pre-build script are enabled
**When** the Release archive is produced
**Then** the build succeeds with zero warnings emitted by SwiftLint at the existing rule levels

### Story 9.2: Privacy Manifest, Permission Strings & App Icons

As a user,
I want the system to clearly disclose what permissions the app uses and to see a polished app icon on my home screen,
So that I can grant permissions with confidence and recognize the app at a glance.

**Scope:** `PrivacyInfo.xcprivacy` declaring iCloud identifier (used for sync) and microphone audio (processed on-device for speech recognition, not transmitted); Info.plist usage strings for `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, and `NSUserTrackingUsageDescription` if applicable; complete iOS app icon set (all required sizes including 1024×1024); complete watchOS app icon set; launch screen using existing design tokens.

**Acceptance Criteria:**

**Given** the iOS target's Info.plist is inspected
**When** the privacy-related keys are reviewed
**Then** `NSMicrophoneUsageDescription` reads "Hyzer uses your microphone to record disc golf scores when you speak them aloud during a round." (PMVP-FR3)
**And** `NSSpeechRecognitionUsageDescription` reads "Hyzer recognizes scores on-device from your voice. Audio is not sent to a server." (PMVP-FR3)

**Given** the app's `PrivacyInfo.xcprivacy` file
**When** it is read
**Then** it declares the data categories the app actually collects (iCloud user identifier for sync, microphone audio for on-device speech recognition) per Apple's required disclosure schema (PMVP-FR2)
**And** the file is included in both iOS and watchOS targets

**Given** the app is installed on a device
**When** the user views the home screen and the watch face
**Then** the iOS app icon appears at all required sizes (Spotlight, Settings, home screen, Notification Center, App Store) (PMVP-FR4)
**And** the watchOS app icon appears in the Watch app list at all required sizes
**And** the launch screen uses `ColorTokens.background` (no white flash on launch)

### Story 9.3: App Store Connect Record, TestFlight Test Group & Border Token Debt

As a beta tester,
I want to receive a TestFlight invitation and install hyzer-app on my device,
So that I can play a round on real hardware before the developer ships further changes.

**Scope:** App Store Connect record created for `com.shotcowboystyle.hyzerapp` with required metadata fields populated (app name, primary category Sports, support URL placeholder); TestFlight internal/external test group containing the six friend testers; first archive uploaded and processed; resolve `ColorTokens.border` tech debt (defined but never referenced — define it now if any new component will use it, or remove the reference if dead code).

**Acceptance Criteria:**

**Given** App Store Connect access
**When** the developer logs in
**Then** an app record exists for `com.shotcowboystyle.hyzerapp` with the iOS + watchOS bundle pairing (PMVP-FR5)
**And** primary category is "Sports", subcategory is "Health & Fitness" or "Lifestyle" (developer choice)

**Given** the App Store Connect record exists
**When** the developer creates a TestFlight test group
**Then** the group contains the six testers' Apple IDs as either Internal (preferred) or External testers
**And** an archive uploaded from Story 9.1 is processed by App Store Connect and available for distribution to the group (PMVP-FR5)

**Given** a TestFlight invitation has been sent
**When** a tester accepts and installs via the TestFlight app on their iPhone (with paired Watch)
**Then** the iOS app launches to the onboarding screen and the Watch app is installable from the Watch app

**Given** the HyzerKit `ColorTokens` API
**When** the codebase is grep'd for `ColorTokens.border`
**Then** either the token is defined and resolves to a hex value consistent with the dark-first palette, or all stale references have been removed (CLAUDE.md tech debt resolved)

---

## Epic 10: Round Setup Quick-Add & Scoring Attribution

Two small Quality-of-Life wins inside the active-round flow: one-tap reuse of the previous round's player roster, and "Scored by [name]" attribution on each scored player row of the hole card.

### Story 10.1: "Same Group as Last Round" Quick-Add

As a user starting a round with the usual group,
I want a one-tap option to reuse the player list from my most recent completed round,
So that I don't retype six names every Saturday.

**Scope:** `RoundSetupViewModel` extended with `loadPreviousRoundPlayers()` query (most recent `Round` where `lifecycleState == .completed` and current user is in `playerIDs`); a "Same group as last round" button on the Add Players screen; visual preview of the proposed player list before commit; editability before tapping Start Round.

**Acceptance Criteria:**

**Given** the user has at least one completed round in their local history
**When** the Add Players screen is shown during new round creation
**Then** a "Same group as last round" button is visible above the manual add controls (PMVP-FR9)
**And** the button label includes a preview of how many players will be added (e.g., "Same group as last round (6 players)")

**Given** the user taps "Same group as last round"
**When** the action commits
**Then** all registered players from the most recent completed round are added to the current round
**And** all guest players from that round are added as new guest entries (round-scoped, no deduplication — consistent with FR12b)
**And** the user can still remove individual players, add more players, or add additional guests before tapping Start Round

**Given** the user has no completed rounds in history
**When** the Add Players screen is shown
**Then** the "Same group as last round" button is hidden (no fallback to seeded suggestion)

**Given** VoiceOver is active
**When** the "Same group as last round" button receives focus
**Then** the announced label includes the player count and a hint ("Adds 6 players. Double-tap to apply.")

### Story 10.2: Scoring Attribution on Hole Card

As a player in a round,
I want to see who entered each score on the hole card,
So that I can verify scores socially and resolve any "did you record this?" questions without opening discrepancy resolution.

**Scope:** `HoleCardView` and the scored player row component updated to read `ScoreEvent.reportedByPlayerID` and display "Scored by [name]" in caption-tier typography below the score; uses `Player.displayName` lookup for the attribution; respects `UX-PMVP-DR3` (de-emphasized typography, `secondaryText` color); no change to data model (field already exists per Story 3.2).

**Acceptance Criteria:**

**Given** a hole card with a player who has been scored
**When** the row is displayed
**Then** the player's score is shown in the primary score-state color
**And** below the score in caption-tier typography (`secondaryText` color), the text "Scored by [name]" appears, where `[name]` is the display name of the player referenced by `ScoreEvent.reportedByPlayerID` of the current authoritative event for this {player, hole} (PMVP-FR10)

**Given** a player has corrected their own score (the original event has `supersedesEventID` set)
**When** the row is displayed
**Then** the attribution shows the name from the authoritative (most recent) ScoreEvent, not the superseded one (NFR19 supersession chain respected)

**Given** the score was entered via Watch (`reportedByPlayerID` resolves to the Watch user)
**When** the row is displayed
**Then** the attribution renders identically (no "via Watch" suffix; attribution is by person, not device)

**Given** VoiceOver is active and focused on a scored player row
**When** the row is announced
**Then** the attribution is included in the announcement after the score (e.g., "Mike, 3, one under par. Scored by Jake.")

**Given** the hole card is rendered at Dynamic Type AX3
**When** the attribution line is laid out
**Then** the row height grows to accommodate without truncating the score or the attribution name (NFR16)

---

## Epic 11: Polished History & Shareable Round Summaries

Users see the polished history feed (warm card-based previews) and a screenshot-first round summary they can share via the system share sheet. Replaces the MVP's minimal summary and basic history list with UX spec components #7 and #8.

### Story 11.1: Polished History Round Card

As a user browsing past rounds,
I want each round to appear as a polished memory card,
So that I can scan my history at a glance and recognize the rounds I want to revisit.

**Scope:** Replace the minimal history list row from Story 8.1 with the UX spec component #8 layout — course name (H3), date (caption), player count, winner with score, your finishing position with score; warm off-course visual register; 3-4 cards per screen at 390pt width; preserves existing tap-to-detail behavior.

**Acceptance Criteria:**

**Given** the user navigates to the history feed with at least one completed round
**When** the list renders
**Then** each round is displayed as a card with: course name in H3 typography, date in caption-tier text, player count ("6 players"), winner attribution ("[name] won at [score]"), and the current user's position attribution ("You finished [nth] at [score]") (PMVP-FR6)
**And** the cards use the off-course warm visual register (UX-PMVP-DR2)

**Given** the standard iPhone width (390pt)
**When** the history feed is scrolled
**Then** 3-4 cards are visible on screen at a time (UX-PMVP-DR2)
**And** scroll performance maintains <16ms frame time at 250+ rounds (PMVP-NFR3)

**Given** the current user is the winner of a round
**When** the card is displayed
**Then** the winner attribution and the user attribution collapse into a single line ("You won at [score]")

**Given** VoiceOver is active and focused on a history card
**When** the card is announced
**Then** the announcement matches the UX spec: "[Course], [date]. [Winner] won. You finished [position]." (UX spec §1146)

### Story 11.2: Screenshot-First Round Summary Card

As a user finishing a round,
I want a polished summary screen designed to look good as a screenshot,
So that I can immediately share the round into the group chat.

**Scope:** Replace the minimal `RoundSummaryView` from Story 3.6 with UX spec component #7 — H1 centered course name, date caption, ranked player rows (position number + subtle medal indicator for 1st/2nd/3rd, H2 player name, +/- par in SF Mono score-state color, total strokes in caption), divider, round metadata footer (holes played, organizer name); static layout (no animation on the card itself, only the entry transition); high contrast for screenshot legibility.

**Acceptance Criteria:**

**Given** a round has been finalized
**When** the round summary appears
**Then** the card displays: course name (H1, centered), date (caption, secondary, below course name), ranked player rows with position/medal/name/+/- par score/total strokes, divider, round metadata footer (PMVP-FR7, UX-PMVP-DR1)
**And** all typography uses existing design tokens (SF Pro Rounded for text, SF Mono for scores)

**Given** the summary card is rendered
**When** evaluated for screenshot readability
**Then** all text meets 4.5:1 contrast (NFR13) and 7:1 for the prominent score values (AAA)
**And** no element relies on interaction (hover, expansion) to convey information

**Given** positions 1-3
**When** the rows are rendered
**Then** the position number receives a subtle medal-style typographic treatment (confident weight differential, no confetti, no illustrations per UX-PMVP-DR1)

**Given** the round had a guest player
**When** the summary is rendered
**Then** the guest's name appears identically to registered players (consistent with FR12b — guests are first-class round participants in history)

**Given** the user is on a small screen device (iPhone SE at 375pt)
**When** the summary card is rendered
**Then** all rows fit without horizontal scroll
**And** card vertical extent fits within a standard share-screenshot height

### Story 11.3: Share Round Summary via System Share Sheet

As a user who just finished a round,
I want to tap a share button and send the round summary directly to my group chat,
So that the result lands in the conversation while the round is still warm.

**Scope:** Share button on the round summary card (primary CTA, bottom placement per UX action hierarchy); `ImageRenderer` produces a PNG of the summary card optimized for messaging apps; system `UIActivityViewController` / `ShareLink` integration; share content includes both the PNG and a one-line text caption ("Round at [course] — [winner] won at [score]"); analytics not required.

**Acceptance Criteria:**

**Given** the user is viewing the round summary card
**When** they tap the share button (primary CTA, bottom of card)
**Then** the system share sheet appears with both an image attachment (PNG render of the card) and a text caption (PMVP-FR8)

**Given** the user selects Messages or another social app from the share sheet
**When** the share is dispatched
**Then** the PNG renders correctly in the receiving app's message bubble (verified visually on Messages and one third-party app)
**And** the PNG has aspect ratio and resolution suitable for inline message display (no awkward cropping)

**Given** the share sheet is presented
**When** the user cancels it
**Then** the round summary card remains in its previous state with no side effects

**Given** the user has the Watch app foregrounded with a completed round
**When** the summary card appears on the iPhone
**Then** the share button is present (Watch never participates in share — share is iPhone-only)

---

## Epic 12: Push Notifications

The group learns about round events without opening the app: round started, round complete, and (for organizers) discrepancy detected. Establishes the APNs pipeline and `NotificationService` protocol abstraction.

### Story 12.1: Notification Foundation & "Round Started" Push

As a participant added to a round,
I want a push notification to let me know the round has started,
So that I can open the app and join the live leaderboard without waiting to be told in person.

**Scope:** `NotificationService` protocol in HyzerKit with `LiveNotificationService` (iOS-only, in HyzerApp/Services/) and mock implementation for tests; APNs entitlement added to iOS target; lazy `UNUserNotificationCenter.requestAuthorization` flow triggered first time a round is created (not on app launch per NFR5); CloudKit-server-triggered notification when a `RoundRecord` is saved with `lifecycleState == .active` — payload uses `apns-priority: 5` with `content-available: 1` plus an alert body containing only organizer first name and course name (PMVP-NFR1); registration deferred to `.task` modifier.

**Acceptance Criteria:**

**Given** the user has previously granted notification permission
**When** another participant creates a round that includes the current user as a player
**Then** within 30 seconds of the round being saved to CloudKit, a push notification is delivered to the current user's device (PMVP-FR11)
**And** the notification body reads "[Organizer first name] started a round at [Course name]"

**Given** the notification payload is inspected
**When** the alert body is read
**Then** it contains only first names and course name — no last names, no iCloud identifiers, no email, no scores (PMVP-NFR1)

**Given** the user has not yet been prompted for notification permission
**When** they tap "New Round" for the first time
**Then** the `UNUserNotificationCenter.requestAuthorization` prompt appears
**And** if the user denies, round creation succeeds and in-app FR16b discovery continues to work without notifications

**Given** the user taps the "Round Started" notification
**When** the app opens
**Then** the active round view (Hole 1) appears directly (deep link to current scoring context)

**Given** the user is the organizer of the round they just created
**When** the CloudKit save triggers notification dispatch
**Then** the organizer's own device does not receive the notification (self-exclusion)

**Given** a notification is delivered while the user is wearing a paired Apple Watch
**When** the haptic fires
**Then** the haptic uses `UNNotificationInterruptionLevel.active` (default) with no custom critical category — the Watch surfaces the standard `.notification` haptic pattern (UX-PMVP-DR4)

### Story 12.2: "Round Complete" Push Notification

As a participant in a completed round,
I want a push notification when the round finalizes,
So that I see the result even if I closed the app before the last hole was scored.

**Scope:** CloudKit-server-triggered notification when a `RoundRecord` transitions to `lifecycleState == .completed`; payload contains winner first name and final score; tapping the notification opens the round summary card (Epic 11 Story 11.2) directly.

**Acceptance Criteria:**

**Given** the user was a participant in a round that just transitioned to `.completed`
**When** the round is saved to CloudKit with the new state
**Then** within 30 seconds a push notification is delivered to all participants (PMVP-FR12)
**And** the alert body reads "Round complete at [Course]. [Winner first name] won at [+/- par score]."

**Given** the user taps the "Round Complete" notification
**When** the app opens
**Then** the round summary card for that round is presented directly (not the home screen)

**Given** the user was the winner of the round
**When** the notification is dispatched
**Then** the user still receives the notification (no self-exclusion for completion — celebrating your own win is valid)

**Given** the user already saw the in-app round summary before the notification arrived
**When** the notification is delivered
**Then** tapping it still opens the summary card (idempotent; no error from re-viewing)

### Story 12.3: Organizer-Only "Discrepancy Detected" Push Notification

As a round organizer,
I want a push notification when a score discrepancy needs my review,
So that I can resolve conflicts without checking the app on every hole.

**Scope:** CloudKit-server-triggered notification when a `Discrepancy` record is saved AND the current user is the organizer of the parent round; non-organizer participants do not receive the notification (FR49 organizer-only alert pattern preserved); payload identifies the hole and player; tapping opens the discrepancy resolution view (Epic 6 Story 6.1).

**Acceptance Criteria:**

**Given** the conflict detector flags a discrepancy and the current user is the round organizer
**When** the discrepancy record syncs to CloudKit
**Then** within 30 seconds a push notification is delivered to the organizer's device (PMVP-FR13)
**And** the alert body reads "Score discrepancy on hole [n] needs review."

**Given** a discrepancy is flagged in a round where the current user is a participant but not the organizer
**When** the discrepancy syncs to the device
**Then** no push notification is delivered (FR49 organizer-only alert pattern preserved)

**Given** the organizer taps the discrepancy notification
**When** the app opens
**Then** the discrepancy resolution view for that specific {player, hole} appears directly

**Given** the organizer has already resolved the discrepancy in-app before the notification arrives
**When** the notification is delivered
**Then** tapping the notification opens the resolved discrepancy view (read-only state) with a "Already resolved" indicator
**And** no duplicate resolution events are created

---

## Epic 13: Long-Term Memory — Trends, Personal Bests, Head-to-Head

Users see how they're doing over time: score trend per player, personal best per course, and head-to-head records between any two players. Pure read-side features over existing event-sourced data.

### Story 13.1: Score Trend Visualization Per Player

As a user looking at a player's profile,
I want to see their relative-to-par scores across rounds as a line chart,
So that I can spot streaks, slumps, and overall trajectory.

**Scope:** New `PlayerTrendView` accessed from a player drill-down in the history surface (entry point in the polished history of Epic 11); Swift Charts line chart plotting `Round.completedAt` (x-axis) against final `+/- par` score from that round (y-axis); only includes rounds where the player participated and the round is `.completed`; uses score-state colors for points (green/white/amber); off-course warm register per UX-PMVP-DR5; chart renders in <500ms at 250 rounds (PMVP-NFR4).

**Acceptance Criteria:**

**Given** a player has 3 or more completed rounds in history
**When** the user opens the player's trend view
**Then** a line chart is rendered showing relative-to-par score per round in chronological order (PMVP-FR14)
**And** each data point is colored by score-state (green under par, white at par, amber over par)

**Given** a player has fewer than 3 completed rounds
**When** the user opens the trend view
**Then** an empty state is shown ("Not enough rounds yet. Trends appear after 3 rounds.") instead of a meaningless chart

**Given** the player has 250 completed rounds
**When** the trend view first appears
**Then** the chart is rendered in <500ms from view appear to first paint (PMVP-NFR4)
**And** scrolling/zooming the chart remains responsive (<16ms frame time)

**Given** VoiceOver is active
**When** the trend view is focused
**Then** an `accessibilityChartDescriptor` summary is read ("Score trend for [player]: [n] rounds, best [score], worst [score], average [score]")

### Story 13.2: Personal Best Per Course

As a user revisiting a course in history,
I want to see my personal best on that course,
So that I have a goal to chase when I play it again.

**Scope:** `PersonalBestService` computing per-player, per-course best absolute strokes and best relative-to-par score with the date of that round; displayed on the course detail view (existing) and on the player drill-down in history; query is bounded with explicit `fetchLimit` per CLAUDE.md coding standards.

**Acceptance Criteria:**

**Given** a player has at least one completed round on a course
**When** the user opens that course's detail view
**Then** the user's personal best on that course is displayed: lowest absolute strokes, best relative-to-par score, and the date of that round (PMVP-FR15)

**Given** a player has multiple rounds tied for the same best score on a course
**When** the personal best is computed
**Then** the earliest date with that score is reported (the first time they achieved it)

**Given** the personal best query
**When** it is executed
**Then** the SwiftData fetch uses an explicit `fetchLimit` ordered by score ascending, then date ascending (per CLAUDE.md: every fetch must have `fetchLimit`)

**Given** a player has no completed rounds on a course
**When** the user opens that course's detail view
**Then** the personal best section shows "No rounds yet on this course" (UX-PMVP-DR5 off-course register)

### Story 13.3: Head-to-Head Record Between Two Players

As a user with a long-time rival in the group,
I want to see our head-to-head record across all rounds we've played together,
So that I can settle competitive debates with data.

**Scope:** `HeadToHeadService` computing for any two players: rounds played together (both `.completed`), wins for each (count + percentage), and average score differential (player A's score minus player B's score, averaged); UI accessed via a "Compare" action on a player's drill-down view that opens a player picker; query is bounded with explicit `fetchLimit`.

**Acceptance Criteria:**

**Given** two players have played in at least 3 rounds together
**When** the user selects "Compare" and picks the second player
**Then** the head-to-head view displays: rounds played together, wins per player (count and percentage), and average score differential (PMVP-FR16)

**Given** two players have never played a round together
**When** the user opens the head-to-head view for that pair
**Then** an empty state is shown ("[Player A] and [Player B] haven't played a round together yet.")

**Given** a guest player (round-scoped, FR12b)
**When** the user attempts to open a head-to-head view for a guest
**Then** the "Compare" action is hidden for guest entries (no persistent identity to compare across rounds)

**Given** the head-to-head query
**When** it is executed
**Then** the SwiftData fetch uses an explicit `fetchLimit` and a compound predicate on `Round.playerIDs` containing both player IDs and `lifecycleState == .completed`

---

## Epic 14: Nearby Discovery & Visual Round Signature

The most technically novel work: MultipeerConnectivity-based local-network discovery and a generative visual round signature.

### Story 14.1: MultipeerConnectivity Nearby Active-Round Discovery

As a user opening the app on the same Wi-Fi as the round organizer's phone,
I want my active round to appear immediately,
So that I don't wait for a CloudKit subscription notification to learn the round has started.

**Scope:** `NearbyDiscoveryClient` protocol in HyzerKit with `LiveNearbyDiscoveryClient` (iOS-only); MultipeerConnectivity `MCNearbyServiceAdvertiser` (organizer's phone) and `MCNearbyServiceBrowser` (participants' phones); service type `hyzer-rounds`; `NSLocalNetworkUsageDescription` and `NSBonjourServices` entries in Info.plist; payload contains only `Round.id` and `Round.playerIDs` (no scores, no PII beyond first names already in player records); discovery starts when app foregrounds and stops when round becomes `.completed` or app backgrounds.

**Acceptance Criteria:**

**Given** the organizer has just started a round and remains on Wi-Fi/Bluetooth
**When** a participant opens the app within range
**Then** the active round appears on the participant's home screen within 5 seconds — not waiting for a CloudKit subscription delivery (PMVP-FR17)
**And** the round still appears via existing CloudKit sync (FR16b) when the participant is not on the same local network

**Given** the Multipeer service is operating
**When** network traffic is inspected
**Then** all communication occurs over local network (Bonjour) — no traffic to public internet for the discovery payload (PMVP-NFR2)

**Given** the user has not yet been prompted for local network permission
**When** the app first attempts to advertise or browse on Wi-Fi
**Then** the iOS local network permission prompt appears with the configured `NSLocalNetworkUsageDescription`
**And** denying the permission does not break the app — falls back to CloudKit subscription discovery (FR16b)

**Given** the round transitions to `.completed`
**When** the lifecycle state change is observed
**Then** the `MCNearbyServiceAdvertiser` stops advertising
**And** browsers stop receiving updates for that round

**Given** two devices both running hyzer-app are on the same network and both have active rounds where they're organizer
**When** browsers run
**Then** each device sees only the rounds that include them as a participant (no leakage of unrelated rounds — verified by inclusion check on `playerIDs`)

### Story 14.2: Generative Visual Round Signature on Summary Card

As a user revisiting a memorable round,
I want the round summary to carry a unique visual element that's recognizable from a glance,
So that round summaries feel like keepsakes rather than receipts.

**Scope:** New `RoundSignature` component on the round summary card (added to Epic 11 Story 11.2 layout); deterministic generative visual derived from round data (course ID, sorted player IDs, sorted final scores) via a stable hash; rendering is geometric/color-derived only (no mascots, no confetti per UX-PMVP-DR6); respects existing dark-dominant palette; same input data always produces the same signature.

**Acceptance Criteria:**

**Given** the same round (identical course, players, scores)
**When** the visual signature is generated on two different devices or two different invocations
**Then** the rendered output is pixel-identical (deterministic from round data) (PMVP-FR18)

**Given** two rounds with different data
**When** their signatures are compared
**Then** they are visibly distinct (not necessarily proven unique, but visually distinguishable in practice)

**Given** the signature is rendered
**When** evaluated against the design system
**Then** it uses only colors from `ColorTokens` palette and geometric primitives (lines, circles, gradients)
**And** no illustration, no mascot, no confetti, no emoji (UX-PMVP-DR6)
**And** total render area is bounded to a fixed proportion of the summary card (does not push other elements off-screen)

**Given** Reduce Motion is enabled
**When** the signature renders
**Then** any subtle animation is replaced with a static rendering (consistent with NFR15)

**Given** the summary card is shared via Story 11.3
**When** the PNG is exported
**Then** the signature is included in the exported image (it is part of the screenshot-first design surface)
