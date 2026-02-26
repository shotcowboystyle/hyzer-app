---
stepsCompleted:
  - 1
  - 2
  - 3
  - 4
  - 5
  - 6
  - 7
  - 8
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/prd-validation-report.md
  - _bmad-output/planning-artifacts/product-brief-hyzer-app-2026-02-23.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
workflowType: 'architecture'
project_name: 'hyzer-app'
user_name: 'shotcowboystyle'
date: '2026-02-24'
lastStep: 8
status: 'complete'
completedAt: '2026-02-24'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

> **Note:** Section 7 (Architecture Validation) contains 10 amendments (A1-A10) that refine decisions from earlier sections. Read the complete document before implementing any component.

### Table of Contents

```
1. Project Context Analysis
2. Starter Template Evaluation
3. Core Architectural Decisions
4. Implementation Patterns & Consistency Rules
5. Project Structure & Boundaries
6. Architecture Validation Results
   6.1 Coherence Validation
   6.2 Requirements Coverage Validation
   6.3 Implementation Readiness Validation
   6.4 Gap Analysis Results
   6.5 Amendments to Prior Sections (A1-A10)
   6.6 Additional UX & Accessibility Patterns
   6.7 Journey-to-Architecture Traces
   6.8 Implementation Steps with Sub-Stories and Critical Path
   6.9 Additional Test Infrastructure
   6.10 Additional Anti-Patterns
   6.11 Architecture Completeness Checklist
   6.12 Architecture Readiness Assessment
   6.13 Implementation Handoff
   6.14 Quick Reference Card
```

## Project Context Analysis

### Requirements Overview

**Functional Requirements (64 FRs across 12 categories):**

| Category | Count | Architectural Significance |
|---|---|---|
| Onboarding & Identity | 4 | iCloud identity, local-first player creation, offline onboarding |
| Course Management | 5 | CRUD with CloudKit sync, seeded data from app bundle |
| Round Management | 8 | Round lifecycle state machine, player list immutability, organizer role designation, passive round discovery via sync |
| Tap Scoring | 4 | Inline picker UI, par-anchored defaults, auto-advance behavior |
| Voice Scoring | 9 | Speech recognition pipeline, fuzzy name matching, confirmation overlay with auto-commit, partial/failed recognition handling |
| Crown Scoring (Watch) | 5 | Digital Crown binding, haptic feedback, Watch-specific input layer |
| Cross-Cutting Scoring | 4 | Distributed scoring permission model, immutable ScoreEvent creation, event superseding for corrections |
| Live Leaderboard | 5 | Reactive standings computation, animated position changes, floating pill + expanded modal, partial round standings |
| Real-Time Sync | 5 | CloudKit subscriptions, offline-first writes, deferred sync, silent merge, discrepancy detection |
| Discrepancy Resolution | 4 | Organizer-only alerting, side-by-side conflict display, resolution as new authoritative ScoreEvent |
| Apple Watch Companion | 5 | Purpose-built Watch leaderboard, Crown + voice input, bidirectional WatchConnectivity, phone-routed speech recognition |
| Round Completion & History | 5 | Auto-detect + manual completion, round summary, reverse-chronological history, progressive disclosure drill-down, indefinite data retention |

**Non-Functional Requirements (21 NFRs across 4 categories):**

| Category | Key NFRs | Architectural Impact |
|---|---|---|
| Performance (7) | Voice-to-leaderboard <3s, cross-device sync <5s, tap feedback <100ms, Crown haptic <50ms, app launch <2s, animation <500ms | Requires local-first computation, efficient reactive queries, lightweight animation system |
| Reliability (5) | Zero data loss, zero crashes in active rounds, offline scoring parity, 4-hour offline recovery, guaranteed Watch-to-phone delivery | Drives offline-first architecture, robust sync recovery, WatchConnectivity fallback strategy |
| Accessibility (6) | 4.5:1 contrast, 44pt+ touch targets, reduce motion, Dynamic Type AX3, VoiceOver, no color-only info | Affects every UI component, requires systematic accessibility layer |
| Data Integrity (3) | Append-only event sourcing, deterministic merge logic, 5-year/250+ round retention under 50MB | Drives data model design, storage projections, query optimization |

**NFRs as Test Specifications:** Several NFRs include explicit measurement methods (NFR8: offline-to-online round-trip assertion, NFR9: crash log audit across 10 rounds, NFR19: database audit for zero UPDATE/DELETE). These are architectural constraints -- the system must be designed so these verifications are possible by construction, not retrofitted.

**Scale & Complexity:**

- Primary domain: Native mobile (iOS 18 + watchOS 11)
- Complexity level: Medium-High (domain-simple, technically complex)

### Architectural Layer Structure

Rather than a flat component count, the architecture organizes into four distinct layers:

| Layer | Responsibility | Key Components |
|---|---|---|
| **Data Layer** | Models, persistence, sync | SwiftData models, CloudKit sync engine, migration support |
| **Domain Layer** | Business logic, computation | Scoring service, standings engine, conflict detection, voice parser |
| **Communication Layer** | Cross-device coordination | WatchConnectivity manager, CloudKit subscription handler |
| **Presentation Layer** | Platform-specific UI | Phone UI (card stack, pill, overlays), Watch UI (leaderboard, Crown input), shared animation system |

Each layer contains 3-5 internal components. Cross-layer dependencies flow downward: Presentation -> Domain -> Data, with Communication bridging Data and Presentation across devices.

### Technical Constraints & Dependencies

| Constraint | Impact |
|---|---|
| iOS 18+ / watchOS 11+ only | Unlocks @Observable, SwiftData, improved SFSpeechRecognizer. No backward compatibility burden. |
| Swift 6 with strict concurrency | Sendable conformance, actor isolation, structured concurrency throughout. Affects all shared mutable state. |
| SwiftUI only (UIKit as last resort) | Component choices constrained to SwiftUI capabilities. Custom components built on SwiftUI primitives. |
| SwiftData for local persistence | New framework -- CloudKit integration is evolving. Fallback plan: raw CloudKit APIs if SwiftData+CloudKit integration unreliable. **This is the architectural pivot point** -- the event-sourced model should play well with append-only CloudKit sync, but derived state queries (latest score per player/hole) must be validated for reactive performance. |
| CloudKit public database, free tier | Zero infrastructure cost. Constrained by CloudKit rate limits, subscription quotas, and public database access patterns. |
| TestFlight distribution, 6 users | No App Store review. No scale concerns. Simplifies auth (iCloud identity only) and data partitioning. |
| Phone is sole CloudKit sync node | Watch architecture is definitively constrained: Watch -> Phone -> CloudKit. No direct Watch-to-cloud communication. |

### Cross-Cutting Concerns Identified

1. **Event Sourcing** -- The ScoreEvent model is the foundation. Touches: all three scoring paradigms, sync engine, conflict detection, discrepancy resolution, standings computation, round history, data retention. Every component that reads or writes score data must respect append-only immutability.

2. **Derived State Management** -- Standings, current scores per hole, and discrepancy detection are all computed from raw ScoreEvents. This is not just a query -- it's a persistent derived state layer consumed by: floating pill, expanded leaderboard, Watch leaderboard, round summary, history detail, and auto-advance logic. Where this computation lives (in-memory cache, SwiftData `@Query` with predicates, or a separate denormalized model) is a foundational architectural decision that shapes performance on every screen.

3. **Offline-First Persistence** -- SwiftData writes happen before any sync attempt. Affects: every write operation, UI feedback (must never wait for network), sync indicator state, recovery after extended offline. The architecture must ensure no code path blocks on CloudKit availability.

4. **CloudKit Sync & Conflict Resolution** -- The sync layer must handle: push-based updates via subscriptions, silent merge of identical scores, discrepancy detection for conflicts, organizer-only resolution flow, batch sync after extended offline. This is the highest-risk cross-cutting concern.

5. **Sync Layer Testability** -- CloudKit is difficult to test in isolation. The architecture requires a clean abstraction boundary between data persistence and CloudKit sync, enabling offline scenarios, conflict detection, and merge logic to be tested without hitting actual CloudKit infrastructure. Connectivity state must be observable and mockable.

6. **WatchConnectivity** -- Bridges all Watch features to the phone sync node. Bidirectional: phone pushes standings updates to Watch, Watch sends ScoreEvents to phone. Must handle: active session messaging, background transfer fallback, phone-unreachable scenarios, reconnection and queued delivery. Connectivity state must be exposed as an observable for both runtime behavior and testing.

7. **Type-Level Invariant Enforcement** -- Use Swift 6's type system to make illegal states unrepresentable. ScoreEvents should have no `update` or `delete` API surface. Round player lists should be immutable after start. This enforces NFR19 (append-only) and FR13 (player list immutability) at the compiler level, not by convention.

8. **Accessibility System** -- Every UI component on both platforms must implement: VoiceOver labels/hints/traits, Dynamic Type scaling, reduce motion alternatives, color-independent information, minimum touch targets. Requires systematic enforcement, not per-component ad hoc.

9. **Animation System** -- Shared spring configurations, timing curves, reduce-motion fallbacks. Used by: leaderboard reshuffles, pill pulses, score entry feedback, card transitions, voice overlay. Must be centralized to ensure consistency and global reduce-motion respect.

### Voice-to-Leaderboard Pipeline (Architectural Litmus Test)

The defining experience is a sequential pipeline with a <3s end-to-end latency budget (NFR1). Each stage must be measurable independently:

```
Speech Recognition (~1-1.5s) -> Custom Parser (~50ms) -> ScoreEvent Creation (~10ms)
-> SwiftData Write (~10ms) -> Standings Recomputation (~20ms) -> Animation Trigger (~500ms)
```

Total budget: <3000ms. If any stage adds unexpected latency, the "magic moment" fails. The architecture must treat this as a first-class pipeline with instrumented stage boundaries, not a series of loosely coupled components.

### Performance Envelopes

The app operates in two distinct performance contexts:

| Context | Profile | Tolerance |
|---|---|---|
| **On-course (active round)** | Competitive urgency. Every millisecond matters. Reactive, local-first, animation-driven. Standings recompute on every score. Sync is real-time push. | Tap <100ms, Voice-to-leaderboard <3s, Sync <5s, Animation <500ms |
| **Off-course (history browsing)** | Warm nostalgia. Latency tolerance is higher. Pagination, lazy loading, comfortable visual treatment. Data is read-only. | Standard list performance. Pagination at scale (50+ rounds/year). No real-time requirements. |

The architecture should optimize aggressively for on-course performance and treat off-course as a relaxed read path.

## Starter Template Evaluation

### Primary Technology Domain

Native iOS 18 + watchOS 11 application built with Swift 6 and SwiftUI. The Apple native ecosystem does not have "create-react-app" equivalents -- Xcode project templates are the starting point, with project organization decisions layered on top.

### Critical Discovery: SwiftData + CloudKit Public Database Incompatibility

**Finding:** SwiftData's built-in CloudKit sync only supports the user's private CloudKit database. The public and shared databases are not supported. This is confirmed by Apple engineers on the Developer Forums and documented in multiple independent sources.

**Impact on hyzer-app:** The PRD specifies "CloudKit (public database for shared data, free tier)" so all 6 users can see the same rounds, scores, and leaderboards. SwiftData's automatic sync cannot fulfill this requirement.

**Options Evaluated:**

| Option | Approach | Assessment |
|---|---|---|
| **A: SwiftData local + raw CloudKit APIs** | SwiftData handles local persistence. Manual CKRecord operations handle public database sync. | **Selected.** Full control over sync. SwiftData's `@Query` works for reactive local UI. Clean separation of concerns. |
| **B: NSPersistentCloudKitContainer + SwiftData coexistence** | Core Data handles public database sync. SwiftData reads from the same store. | Rejected. Complex dual-stack not recommended for a new project. |
| **C: CloudKit private database with CKShare** | Each round creator shares via CKShare invitation. | Rejected. SwiftData doesn't support shared DB either. Invitation model adds friction incompatible with the UX. |
| **D: SwiftData local + private database only** | Each user's scores sync to their own private DB. | Rejected. Doesn't solve the core problem -- users can't see each other's scores. |

**Decision: Option A -- SwiftData for local persistence, manual CloudKit public database API for sync.**

**Rationale:**
- SwiftData's `@Query` provides reactive standings computation for all UI surfaces
- Full control over CloudKit public database operations (subscriptions, push, conflict detection)
- Clean separation between "local persistence" and "cloud sync" -- required by Cross-Cutting Concern #5 (Sync Layer Testability)
- Aligns with the PRD's own fallback plan: "Have a fallback plan to use raw CloudKit APIs if SwiftData integration is unreliable"
- The event-sourced model, conflict detection, and discrepancy resolution requirements demand custom sync logic regardless

**SwiftData Model Constraints (for CloudKit compatibility):**
- No `@Attribute(.unique)` -- CloudKit doesn't support atomic uniqueness checks
- All properties must be optional or have default values
- Relationships must be optional; no `Deny` delete rules
- Schema changes restricted to lightweight migration once CloudKit is enabled
- Add-only schema evolution: never delete or rename entities/attributes in production

### Starter Options Considered

**Option 1: Xcode "iOS App with Watch App" Template (Selected)**

Standard Xcode template creating both an iOS target and a watchOS target in a single project. Apple's official starting point for companion app development.

**Option 2: Xcode Multiplatform Template + watchOS Target**

Starts with multiplatform template (iOS + macOS), adds watchOS manually. Rejected: adds macOS scaffolding not needed, more cleanup than value.

**Option 3: Swift Package-first with thin Xcode targets**

All shared code in a Swift Package, minimal Xcode app targets importing it. Maximum code sharing but more upfront setup complexity. Can evolve into this structure from Option 1.

### Selected Starter: Xcode iOS App with Watch App + Shared Swift Package

**Initialization:**

```
1. Create project in Xcode:
   File > New > Project > iOS App with Watch App
   Product Name: HyzerApp
   Interface: SwiftUI
   Storage: SwiftData
   Language: Swift
   Watch App: Include Watch App

2. Add local Swift Package:
   File > New > Package > HyzerKit
   Add as dependency to both iOS and watchOS targets

3. Enable capabilities (iOS target):
   - iCloud > CloudKit (create container)
   - Background Modes > Remote Notifications
   - App Groups (shared between iOS and watchOS)

4. Enable capabilities (watchOS target):
   - App Groups (same group as iOS)
```

**Project Structure:**

```
hyzer-app/
  HyzerApp/                    # iOS App target
    App/                       # App entry point, scene configuration
    Views/                     # SwiftUI views (phone-specific)
      Scoring/                 # Card stack, hole cards, voice overlay
      Leaderboard/             # Pill, expanded leaderboard
      History/                 # Round history, detail views
      Courses/                 # Course management
      Onboarding/              # First launch flow
    ViewModels/                # @Observable view models (phone-specific)
  HyzerWatch/                  # watchOS App target
    App/                       # Watch app entry point
    Views/                     # Watch-specific views
    ViewModels/                # Watch-specific view models
  HyzerKit/                    # Shared Swift Package (local)
    Models/                    # SwiftData @Model definitions
    Domain/                    # Scoring service, standings engine, voice parser
    Sync/                      # CloudKit sync engine (manual CKRecord operations)
    Communication/             # WatchConnectivity manager
    Design/                    # Shared design tokens, animation utilities
  HyzerKitTests/               # Unit tests for shared logic
```

**Architectural Decisions Provided by This Setup:**

| Decision | Value |
|---|---|
| **Language & Runtime** | Swift 6, strict concurrency enabled |
| **UI Framework** | SwiftUI (both platforms) |
| **Local Persistence** | SwiftData with `@Model`, `@Query` for reactive UI |
| **Cloud Sync** | Manual CloudKit public database API (not SwiftData auto-sync) |
| **Architecture Pattern** | MVVM with `@Observable` macro (iOS 17+) |
| **Code Sharing** | Local Swift Package (HyzerKit) shared between iOS and watchOS targets |
| **Testing** | XCTest for HyzerKit (models, domain, sync logic). XCUITest for integration. |
| **Build Tooling** | Xcode build system, Swift Package Manager for dependencies |
| **Minimum Deployment** | iOS 18.0, watchOS 11.0 |

**Note:** Project initialization using these steps should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Derived state computation strategy (StandingsEngine with explicit recompute trigger, emits StandingsChange)
- CloudKit sync direction model (push-on-write + subscription + periodic fallback tied to Round lifecycle)
- Conflict detection strategy (on-write in sync engine, four mechanically defined cases using supersedesEventID)
- WatchConnectivity message protocol (typed enum)
- Speech recognition mode (on-device only)
- Watch state management (JSON cache in app group with lastUpdatedAt staleness indicator)
- CloudKit container model (single container, public database, record type subscriptions)
- Protocol abstractions for testability (CloudKitClient, WatchConnectivityClient)
- Sync engine as architectural spike (validate happy path first)

**Important Decisions (Shape Architecture):**
- CloudKit record mapping (sync DTOs)
- Sync state machine (explicit enum)
- Offline queue (separate SyncMetadata table, append-only)
- Inter-component communication (@Observable + async/await)
- Voice parser architecture (token-based pipeline returning VoiceParseResult enum)
- Fuzzy name matching (alias map on Player model + Levenshtein fallback)
- ViewModel granularity (one per screen)

**Deferred Decisions (Post-MVP):**
- Migration strategy beyond add-only (Option C escape hatch if needed)
- Third-party crash reporting (revisit if distribution expands beyond TestFlight)
- Full test pyramid with integration layer (expand if codebase grows significantly)

### Minimum Viable Experience

The architecture is layered such that the minimum viable experience is a **single-device scorecard with local SwiftData persistence.** This functions without CloudKit sync, Watch companion, or voice input. Each subsequent layer adds capability:

1. **Layer 0:** Single-device scorecard (SwiftData local, tap input, local leaderboard)
2. **Layer 1:** CloudKit sync (multi-device shared scoring, real-time leaderboard)
3. **Layer 2:** Voice input (speech recognition pipeline)
4. **Layer 3:** Watch companion (WatchConnectivity, Crown input)

If the sync architectural spike fails or CloudKit public database proves unworkable, Layer 0 is a shippable single-device app. Sync can be added later without rearchitecting the local data model.

### Data Architecture

| Decision | Choice | Rationale |
|---|---|---|
| **Derived State** | `@Observable` StandingsEngine service with explicit `recompute(for roundID:)` method. Emits `StandingsChange` (previous standings, new standings, trigger: `.localScore` / `.remoteSync` / `.conflictResolution`). | Single computation, many consumers. Any source of new ScoreEvents calls the same recompute method. `StandingsChange` gives presentation layer context for animation differentiation. |
| **CloudKit Record Mapping** | Sync-specific DTO structs | Decouples SwiftData models from CloudKit schema. Compile-time safety on the translation boundary. DTOs document the CloudKit schema. |
| **Conflict Detection** | On-write detection in sync engine. Four mechanically unambiguous cases defined by `supersedesEventID` field: (1) Same {player, hole, strokeCount}, no supersedes link -> silent merge; (2) Same {player, hole}, different strokeCount, no supersedes link -> discrepancy; (3) Supersedes link to event from same device -> correction, not conflict; (4) Supersedes link to event from different device -> discrepancy. **Note:** Conflicts are low-frequency events (~handful per 250 rounds/year). The architectural spike should prioritize the happy path (push, pull, silent merge). Conflict resolution UI is important but not spike-blocking. | `supersedesEventID: UUID?` on ScoreEvent eliminates ambiguity. Prioritization reflects actual conflict frequency. |
| **Migration Strategy** | Schema-first, add-only evolution | Event-sourced model is inherently additive. CloudKit add-only constraint is a feature for event sourcing. Option C (versioned record types) is the escape hatch. |
| **Voice Alias Storage** | Aliases stored on Player model as `[String]`, synced via CloudKit | Syncs across devices. Small data, natural home on the Player model. |
| **Course Management** | Seed from JSON bundle on first launch, store in SwiftData, sync to CloudKit public database. Last-write-wins for conflicts. | Courses are reference data, not transactional. Change rarely. Conflicts are trivial. Low architectural priority -- don't over-architect. |

**ScoreEvent Data Model Fields (Architecturally Significant):**
- `supersedesEventID: UUID?` -- Links corrections to the event they replace. Enables mechanical conflict disambiguation.
- `reportedByPlayerID: UUID` -- Which player's device created this event. Required for discrepancy resolution UX ("Jake says 3, Sarah says 4" vs opaque "3 vs 4").
- `deviceID: String` -- Identifies the originating device. Used by conflict detection to distinguish same-device corrections from cross-device conflicts.

**Round Data Model Fields (Architecturally Significant):**
- `playerIDs: [String]` -- Array of iCloud user record names. Required for passive round discovery (FR16b): subscription or fetch filters on "rounds where my ID is in the player list." Without this field, non-organizers cannot discover rounds they've been added to.

**SwiftData Model Constraints for CloudKit Compatibility:**
- No `@Attribute(.unique)`
- All properties optional or have default values
- Relationships must be optional; no `Deny` delete rules
- Lightweight migration only once CloudKit schema is deployed
- Add-only schema evolution: never delete or rename entities/attributes
- Sync bookkeeping (SyncMetadata) must NOT live on domain models -- separate local-only table
- `supersedesEventID`, `reportedByPlayerID` are domain fields (sync to CloudKit); `syncStatus` is operational bookkeeping (does not sync)

### Sync Architecture

| Decision | Choice | Rationale |
|---|---|---|
| **Sync Direction** | Push-on-write + CKSubscription pull + periodic fallback (30-60s during active round) | Real-time for common case. Periodic fallback catches missed APNs. Fallback timer tied to Round lifecycle: starts when Round enters `.active`, stops on `.completed` or app backgrounds. |
| **Sync State Machine** | Explicit `SyncState` enum (`idle`, `syncing`, `offline`, `error(Error)`) as `@Observable` | Type-safe, exhaustive. SwiftUI reads state directly for sync indicator. Trivially mockable for testing. |
| **Offline Queue** | Separate `SyncMetadata` table mapping record IDs to sync status (`pending`, `synced`, `failed`). Append-only -- never garbage-collected. Remote events written directly as `synced`. | Domain models stay clean. Grows at ~27,000 entries/year (trivial). Serves as NFR8 audit trail. |
| **CloudKit Container** | Single container (`iCloud.com.shotcowboystyle.hyzerapp`), public database, default zone | All record types (`ScoreEvent`, `Round`, `Player`, `Course`) in the default zone. Subscriptions are per-record-type (public DB doesn't support zone subscriptions). |
| **Testability Boundary** | `CloudKitClient` protocol abstraction | Real implementation wraps `CKDatabase`. Test implementation is in-memory mock. Protocol defines: `save`, `fetch`, `subscribe`, `delete`. |
| **Architectural Spike** | Sync engine is the highest-risk component -- build and validate first. **Spike scope: happy path only** (push ScoreEvent from device A, pull on device B, silent merge of identical scores). Conflict resolution is validated after the spike. | First milestone validates the fundamental CloudKit public database integration before investing in conflict detection, Watch connectivity, or voice processing. |
| **CloudKit Capacity** | Expected peak: ~1,500 CloudKit operations per round (18 holes x 7 players x 6 devices pushing + subscription-triggered fetches), spread over 2-3 hours. Approximately 8-12 operations per minute. **Well within CloudKit public database rate limits.** | Documented to prevent future rate-limit concerns. If the app scales beyond 6 users, revisit capacity. |

### Simplification Opportunity: Organizer Role

**PRD states:** Discrepancy resolution is organizer-only (FR49-FR52).

**Architectural recommendation:** Allow any player to resolve discrepancies. Log the resolver's identity on the resolution ScoreEvent (`reportedByPlayerID`).

**Rationale:** The organizer's phone is a single point of failure. If it dies mid-round (dead battery, dropped in water -- outdoor sport), discrepancies pile up with no resolution path. For 6 friends who trust each other, the "only organizer resolves" constraint adds friction without real security benefit. Any-player resolution removes the failure mode while maintaining full auditability via `reportedByPlayerID`.

**Status:** Flagged as PRD deviation. Requires product owner approval before implementation. Architecture supports either model -- the difference is a single authorization check in the discrepancy resolution flow.

### Communication Architecture

| Decision | Choice | Rationale |
|---|---|---|
| **WatchConnectivity Protocol** | Typed `WatchMessage` enum with `Codable` payloads | Type-safe contract. ScoreEvents via `transferUserInfo` (guaranteed), standings via `sendMessage` (best-effort). |
| **Inter-Component Communication** | `@Observable` for view layer + `async/await` with `AsyncSequence` for domain/sync layers | Each tool where it's strongest. Aligned with Swift 6 concurrency model. |
| **Testability Boundary** | `WatchConnectivityClient` protocol abstraction | Enables unit testing Watch communication logic without physical device pair. |

### Voice Processing Architecture

| Decision | Choice | Rationale |
|---|---|---|
| **Speech Recognition** | On-device only (`requiresOnDeviceRecognition = true`) | Micro-language of ~16 tokens. Eliminates network dependency. Enables offline parity (NFR10). |
| **Voice Parser** | Token-based pipeline: tokenize -> classify -> assemble. Returns `VoiceParseResult` enum: `.success([ScoreCandidate])`, `.partial(recognized: [Token], unresolved: [Token])`, `.failed(transcript: String)`. | Each stage independently testable. Explicit result types for presentation layer. |
| **Fuzzy Name Matching** | Pre-built alias map (stored on Player model, synced) + Levenshtein distance fallback | Deterministic for common cases, fuzzy for edge cases. |

### UI & State Architecture

| Decision | Choice | Rationale |
|---|---|---|
| **ViewModel Granularity** | One `@Observable` ViewModel per screen | Clear ownership, independently testable. Thin projections of domain state. |
| **Watch State Management** | JSON file in app group container + `transferUserInfo` queue. `StandingsSnapshot` includes `lastUpdatedAt` timestamp. | Stale data indicator when snapshot >30s old. No SwiftData on Watch. `transferUserInfo` guarantees ScoreEvent delivery. |

### Infrastructure & Development

| Decision | Choice | Rationale |
|---|---|---|
| **Error Reporting** | Xcode Organizer + `Logger` (os_log) | Zero dependencies. TestFlight crash logs automatic. Revisit if distribution expands. |
| **Testing Strategy** | Unit tests for HyzerKit + XCUITest for critical flows | Protocol abstractions (`CloudKitClient`, `WatchConnectivityClient`) enable mock injection. |

### Decision Impact Analysis

**Implementation Sequence:**
1. Project setup (Xcode template + HyzerKit package + capabilities + CloudKit container)
2. SwiftData models (including `supersedesEventID`, `reportedByPlayerID`, `playerIDs`) + sync DTOs + SyncMetadata table
3. **Architectural spike:** `CloudKitClient` protocol + sync engine -- validate happy path: "create ScoreEvent on device A, see it on device B." Silent merge only. No conflict resolution in spike.
4. StandingsEngine with `recompute(for:)` and `StandingsChange` emission (parallel with step 3 -- uses local-only ScoreEvents)
5. `WatchConnectivityClient` protocol + WatchConnectivity manager with typed protocol
6. Voice parser pipeline + Player alias map (parallel with UI development)
7. Platform-specific ViewModels + Views
8. Conflict detection + discrepancy resolution (after spike validates sync fundamentals)

**Parallel Development Opportunities:**
- Steps 3 and 4 can run in parallel (StandingsEngine is a pure function, doesn't depend on sync)
- Step 6 can run in parallel with step 7 (voice parser is domain logic, independent of views)
- Step 8 is deliberately sequenced after step 3 (spike validates sync before building conflict complexity)

**Cross-Component Dependencies:**

```
SwiftData Models ──── used by ────> StandingsEngine, SyncEngine, ViewModels
Sync DTOs ────────── used by ────> SyncEngine <──> CloudKit (via CloudKitClient protocol)
SyncMetadata ─────── owned by ───> SyncEngine (local-only, append-only bookkeeping)
SyncEngine ───────── calls ──────> StandingsEngine.recompute(for:)
StandingsEngine ──── emits ──────> StandingsChange (observed by Leaderboard VM, Watch cache, Round Summary VM)
WatchMessage enum ── used by ────> WatchConnectivity Manager (via WatchConnectivityClient protocol)
VoiceParser ──────── returns ────> VoiceParseResult -> ScoreEvents -> SwiftData -> StandingsEngine
Player.aliases ───── used by ────> VoiceParser token classifier
Round.playerIDs ──── used by ────> Passive round discovery (CKQuery filter)
Round lifecycle ──── controls ───> Sync periodic fallback timer
StandingsSnapshot ── includes ───> lastUpdatedAt (consumed by Watch stale indicator)
ScoreEvent ───────── includes ───> supersedesEventID (conflict detection), reportedByPlayerID (discrepancy resolution UX)
```

## Implementation Patterns & Consistency Rules

### Naming Patterns

**SwiftData Models:**
- Plain Swift names, no prefixes or suffixes: `ScoreEvent`, `Round`, `Player`, `Course`
- Live in `HyzerKit/Models/`

**Sync DTOs:**
- `Record` suffix: `ScoreEventRecord`, `RoundRecord`, `PlayerRecord`, `CourseRecord`
- Live in `HyzerKit/Sync/Records/`
- CloudKit record type string matches DTO name: `static let recordType = "ScoreEventRecord"`

**Protocols:**
- Describe capability, no suffix: `CloudKitClient`, `WatchConnectivityClient`
- Concrete implementations: `LiveCloudKitClient`, `MockCloudKitClient`

**ViewModels:**
- `ViewModel` suffix: `ScorecardViewModel`, `LeaderboardViewModel`
- File name matches type name: `ScorecardViewModel.swift`

**Views:**
- `View` suffix for screens, descriptive for components: `ScorecardView`, `LeaderboardPillView`, `HoleCardView`
- One primary view per file. Small helpers can co-locate if only used by that view.

**Extensions:**
- File naming: `{TypeName}+{Capability}.swift` (e.g., `CKRecord+TypedAccess.swift`, `Date+RelativeFormatting.swift`)
- Extensions on Apple types -> `HyzerKit/Extensions/`
- Extensions adding protocol conformance to our types -> same file as the type
- Extensions adding feature-specific logic to our types -> same directory as the consumer

### File Placement Rules

| Type | Location | Example |
|---|---|---|
| SwiftData `@Model` | `HyzerKit/Models/` | `ScoreEvent.swift` |
| Domain service | `HyzerKit/Domain/` | `StandingsEngine.swift` |
| Sync DTO | `HyzerKit/Sync/Records/` | `ScoreEventRecord.swift` |
| Sync engine | `HyzerKit/Sync/` | `SyncEngine.swift` |
| Protocol definition | Same directory as primary consumer | `CloudKitClient.swift` in `Sync/` |
| Live implementation | Same directory as protocol | `LiveCloudKitClient.swift` in `Sync/` |
| Extensions on Apple types | `HyzerKit/Extensions/` | `Date+RelativeFormatting.swift` |
| Shared design tokens | `HyzerKit/Design/` | `AnimationTokens.swift`, `ColorTokens.swift` |
| Animation coordinator | `HyzerKit/Design/` | `AnimationCoordinator.swift` |
| Phone ViewModel | `HyzerApp/ViewModels/` | `ScorecardViewModel.swift` |
| Phone View | `HyzerApp/Views/{Feature}/` | `Views/Scoring/ScorecardView.swift` |
| Watch ViewModel | `HyzerWatch/ViewModels/` | `WatchLeaderboardViewModel.swift` |
| Watch View | `HyzerWatch/Views/` | `WatchLeaderboardView.swift` |
| Unit tests | `HyzerKitTests/{MirroredPath}/` | `HyzerKitTests/Domain/StandingsEngineTests.swift` |
| Test fixtures | `HyzerKitTests/Fixtures/` | `ScoreEvent+Fixture.swift` |
| Mock implementations | `HyzerKitTests/Mocks/` | `MockCloudKitClient.swift` |
| UI tests | `HyzerAppUITests/` | `ScoringFlowTests.swift` |
| SwiftLint config | Project root | `.swiftlint.yml` |

**Feature grouping in Views:** By feature (`Scoring/`, `Leaderboard/`, `History/`), not by component type.

### Dependency Injection Pattern

**Composition Root: `AppServices`**

```swift
@MainActor @Observable
final class AppServices {
    let standingsEngine: StandingsEngine
    let syncEngine: SyncEngine
    let scoringService: ScoringService
    let watchManager: WatchConnectivityManager
    // ... constructed once in @main App, injected via .environment()
}
```

**Rules:**
- `AppServices` is `@MainActor @Observable`. Created once in the `@main` App struct, passed via `.environment()`. It is the composition root -- the only object that holds references to all services.
- ViewModels receive individual services via constructor injection, not the container.
- No singletons. No global mutable state. No service locators.
- Test targets inject mock implementations via the same constructors.

### SwiftData Configuration Pattern

**Dual ModelConfiguration for local-only models:**

The app uses two `ModelConfiguration`s within the same `ModelContainer`:
- **Domain store:** SwiftData models (`ScoreEvent`, `Round`, `Player`, `Course`) -- synced via manual CloudKit operations.
- **Operational store:** Local-only models (`SyncMetadata`) -- never leaves the device, never syncs.

This separation is required because `SyncMetadata` tracks per-device sync status that is meaningless on other devices. The domain store and operational store use the same `ModelContainer` but different backing stores.

### SwiftUI View Patterns

**State ownership:**
- `@State` in Views: transient UI state only (sheet presentation, text field input, scroll position)
- `@Observable` ViewModels: business-related state and actions
- `@Query` in Views: reactive SwiftData reads. `@Query` must live in the View (SwiftUI lifecycle requirement). Views pass query results to ViewModel methods or read them directly for display. ViewModels handle *actions*, `@Query` handles *reactive reads*.

**View body complexity:**
- Extract subviews when body exceeds ~40 lines.

**Dynamic Type:**
- Use `@ScaledMetric` for spacing and custom sizes.
- Layouts must support Accessibility Extra Extra Extra Large (AX3) per NFR16.
- Use `ViewThatFits` or manual size-class checks to provide alternative layouts when text exceeds container bounds (e.g., horizontal player row reflowing to vertical stack at large sizes).

**Accessibility:**
- Every interactive element gets `.accessibilityLabel()` and `.accessibilityHint()`.
- Use `.accessibilityAddTraits()` for semantic roles.
- **Labels describe semantic meaning using disc golf language, not UI component names:**
  - Hole card showing "3" -> "Hole 3, par 4, score not entered"
  - Leaderboard pill -> "Leaderboard: Jake leads at 2 under par"
  - Voice button -> "Score by voice. Double tap to start listening"
- Respect `@Environment(\.accessibilityReduceMotion)` in all animations.

### Animation Patterns

**Shared tokens in `HyzerKit/Design/AnimationTokens.swift`:**

```swift
enum AnimationTokens {
    static let springStiff = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let scoreEntryDuration: TimeInterval = 0.2
    static let leaderboardReshuffleDuration: TimeInterval = 0.4
    static let pillPulseDelay: TimeInterval = 0.2
}
```

**AnimationCoordinator (`HyzerKit/Design/AnimationCoordinator.swift`):**

Cross-component animation sequences use a shared `AnimationCoordinator` that provides timing offsets and coordinates the sequence. Example sequence after a new score:

1. Score confirmation (immediate, on the card)
2. Pill pulse (after `AnimationTokens.pillPulseDelay`, drawing attention)
3. Leaderboard reshuffle (concurrent with pill, spring physics)

The coordinator doesn't own the animations -- it provides timing offsets and sequencing.

**Rules:**
- No magic animation values in views. Reference `AnimationTokens`.
- Every animation checks `accessibilityReduceMotion` and provides a reduced-motion alternative (instant transition or fade-only).

### Error Handling Patterns

**Domain errors use typed enums per area:**

```swift
enum SyncError: Error, Sendable {
    case networkUnavailable
    case cloudKitFailure(CKError)
    case recordConflict(localRecord: ScoreEventRecord, remoteRecord: ScoreEventRecord)
    case quotaExceeded
}

enum VoiceParseError: Error, Sendable {
    case microphonePermissionDenied
    case recognitionUnavailable
    case noSpeechDetected
}
```

**Rules:**
- Typed `Sendable` errors for every domain area. No generic `Error` in public APIs.
- Never swallow errors silently. Every `catch` either logs + rethrows, or has an explicit comment.
- Domain services throw typed errors. ViewModels catch and map to user-facing state.

**Logger usage (no `print()`):**

```swift
private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "SyncEngine")
```

Each component gets its own Logger with a descriptive `category`.

### Concurrency Patterns

**Actor isolation boundaries:**

| Component | Isolation | Rationale |
|---|---|---|
| `SyncEngine` | `actor` | Serializes access to SyncMetadata and in-flight operations. |
| `StandingsEngine` | `@MainActor` | Emits `@Observable` state consumed by SwiftUI views. |
| `WatchConnectivityManager` | `@MainActor` | State must be main-actor for UI observation. |
| `VoiceParser` | `nonisolated` | Stateless pure functions. No mutable state between calls. Can be called from any context without `await`. |
| All ViewModels | `@MainActor` | Exist to serve SwiftUI. |
| `ModelContext` (view) | `@MainActor` | View queries use the main context. |
| `ModelContext` (background) | `@ModelActor` | Sync writes use a background context. |
| `AppServices` | `@MainActor` | Composition root. |

**Cross-isolation calls require `await`:** When `SyncEngine` (actor) calls `StandingsEngine.recompute()` (@MainActor), this is an `await` call. This is by design -- the standings update is dispatched to the main actor for UI observation.

**`Sendable` conformance:** All types crossing isolation boundaries must conform to `Sendable`:
- Sync DTOs: `ScoreEventRecord`, `RoundRecord`, `PlayerRecord`, `CourseRecord`
- Communication types: `WatchMessage`, `StandingsChange`, `VoiceParseResult`, `SyncState`
- All error enums

Use value types (structs, enums) for cross-boundary data. Never send reference types across isolation boundaries.

**Calling convention for StandingsEngine:** When calling `StandingsEngine.recompute(for:trigger:)`, always pass the appropriate `StandingsChangeTrigger` (`.localScore`, `.remoteSync`, `.conflictResolution`). The presentation layer depends on this for animation selection.

### Testing Patterns

Three core rules:

**1. Test naming:** `test_{method}_{scenario}_{expectedBehavior}`

```swift
func test_recompute_withConflictingScores_flagsDiscrepancy() { ... }
func test_parse_withPartialRecognition_returnsPartialResult() { ... }
```

**2. Test structure:** Given/When/Then

```swift
func test_recompute_withNewScore_updatesStandings() {
    // Given
    let engine = StandingsEngine()
    let events = [ScoreEvent.fixture(player: "Jake", hole: 1, strokes: 3)]

    // When
    let change = engine.recompute(for: roundID, trigger: .localScore, events: events)

    // Then
    XCTAssertEqual(change.newStandings.first?.playerName, "Jake")
    XCTAssertEqual(change.newStandings.first?.totalStrokes, 3)
}
```

**3. Test fixtures:** Every model gets a `.fixture()` factory in `HyzerKitTests/Fixtures/`:

```swift
extension ScoreEvent {
    static func fixture(
        player: String = "TestPlayer",
        hole: Int = 1,
        strokes: Int = 3,
        supersedesEventID: UUID? = nil,
        reportedByPlayerID: UUID = UUID()
    ) -> ScoreEvent { ... }
}
```

**Anti-pattern:** No test coupling to implementation internals. Assert on observable behavior, not private state.

### Enforcement Guidelines (Tiered)

**Tier 1 -- Structural (causes organizational debt if violated):**
1. Place files per the file placement table
2. Use established naming conventions
3. Inject dependencies via constructors through `AppServices`
4. `@Query` in Views, not ViewModels

**Tier 2 -- Correctness (causes bugs or compilation errors):**
5. Define typed `Sendable` errors for new error conditions
6. Annotate concurrency isolation on all public async functions
7. `Sendable` conformance on all cross-boundary types
8. Pass `StandingsChangeTrigger` on every recompute call

**Tier 3 -- Quality (causes inconsistency, caught by review):**
9. Accessibility labels with domain-appropriate semantic language
10. AnimationTokens for all animations, reduce-motion alternatives
11. Logger over print
12. Given/When/Then tests with `.fixture()` factories

**If an agent can only remember three things:** file placement, naming conventions, and constructor injection.

### Automated Enforcement

**SwiftLint:** Include a `.swiftlint.yml` in the project root configured to enforce naming conventions and basic code style. Run SwiftLint as an Xcode build phase. This catches naming violations, unused imports, and formatting inconsistencies mechanically rather than through documentation review.

### Anti-Patterns

| Anti-Pattern | Do This Instead |
|---|---|
| `print("debug: \(value)")` | `logger.debug("\(value)")` |
| `try? riskyOperation()` | `do { try ... } catch { logger.error("\(error)"); throw error }` |
| `class Singleton { static let shared = ... }` | Constructor injection via `AppServices` |
| Inline animation values | `AnimationTokens.springStiff` |
| `@State var scores: [ScoreEvent]` in View | Business state in ViewModel |
| ViewModel in `HyzerKit/` | `HyzerApp/ViewModels/` or `HyzerWatch/ViewModels/` |
| `@Query` in ViewModel | `@Query` in View, pass to ViewModel |
| `class MyDTO { }` crossing isolation | `struct MyDTO: Sendable { }` |
| Synchronous cross-isolation call | `await` the call |
| Test asserting on private cache state | Assert on observable output |
| `.accessibilityLabel("LeaderboardPillView")` | `.accessibilityLabel("Leaderboard: Jake leads at 2 under par")` |
| `recompute(for: roundID)` without trigger | `recompute(for: roundID, trigger: .localScore)` |

## Project Structure & Boundaries

### Platform Compilation Constraints

**Key constraint:** HyzerKit is imported by both the iOS and watchOS targets. Any file in HyzerKit that imports a platform-specific framework unavailable on watchOS (e.g., `Speech`) will cause a compilation error. Platform-specific service implementations live in the consuming target's `Services/` directory, not in HyzerKit.

- `VoiceRecognitionService` (imports `Speech`) -> `HyzerApp/Services/` (iOS only)
- `PhoneConnectivityClient` (iOS side of `WCSession`) -> `HyzerApp/Services/`
- `WatchConnectivityClientImpl` (watchOS side of `WCSession`) -> `HyzerWatch/Services/`

HyzerKit contains only platform-independent code: protocols, data types, pure domain logic, and sync DTOs.

### Complete Project Directory Structure

```
hyzer-app/
├── .gitignore
├── .swiftlint.yml
├── HyzerApp.xcodeproj/
│
├── HyzerApp/                                    # ── iOS App Target ──
│   ├── App/
│   │   ├── HyzerApp.swift                       # @main, AppServices composition root
│   │   └── HyzerApp.entitlements                # iCloud, CloudKit, Background Modes, App Groups
│   │
│   ├── Services/                                # Platform-specific service implementations
│   │   ├── VoiceRecognitionService.swift         # SFSpeechRecognizer wrapper (Speech framework, iOS only)
│   │   └── PhoneConnectivityClient.swift         # LiveWatchConnectivityClient for iOS side
│   │
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift              # FR1-FR4
│   │   │   └── PlayerSetupView.swift             # FR2: display name, alias entry
│   │   │
│   │   ├── Courses/
│   │   │   ├── CourseListView.swift               # FR5-FR6
│   │   │   ├── CourseDetailView.swift             # FR7
│   │   │   └── CourseEditorView.swift             # FR8-FR9
│   │   │
│   │   ├── Rounds/
│   │   │   ├── RoundSetupView.swift               # FR10-FR12
│   │   │   └── RoundListView.swift                # FR16b: passive round discovery
│   │   │
│   │   ├── Scoring/
│   │   │   ├── ScorecardContainerView.swift       # FR10-FR16: orchestrates card stack + overlays
│   │   │   ├── CardStackView.swift                # Horizontal paging/stack behavior
│   │   │   ├── HoleCardView.swift                 # FR17-FR20: tap scoring, par-anchored picker
│   │   │   ├── ScoreInputView.swift               # Tap picker component
│   │   │   ├── VoiceOverlayView.swift             # FR21-FR29: voice confirmation, auto-commit
│   │   │   └── ScoreEntryAccessoryView.swift      # FR35-FR38: cross-cutting score entry UI
│   │   │
│   │   ├── Leaderboard/
│   │   │   ├── LeaderboardPillView.swift           # FR39-FR40: floating pill
│   │   │   └── LeaderboardExpandedView.swift       # FR41-FR43: expanded modal
│   │   │
│   │   ├── Discrepancy/
│   │   │   ├── DiscrepancyAlertView.swift          # FR49-FR50
│   │   │   └── DiscrepancyResolutionView.swift     # FR51-FR52
│   │   │
│   │   ├── History/
│   │   │   ├── HistoryListView.swift               # FR58-FR59
│   │   │   ├── RoundSummaryView.swift              # FR60-FR61
│   │   │   └── RoundDetailView.swift               # FR62
│   │   │
│   │   └── Shared/
│   │       ├── SyncIndicatorView.swift             # FR44
│   │       └── EmptyStateView.swift
│   │
│   ├── ViewModels/
│   │   ├── OnboardingViewModel.swift
│   │   ├── CourseListViewModel.swift
│   │   ├── RoundSetupViewModel.swift
│   │   ├── ScorecardViewModel.swift
│   │   ├── VoiceOverlayViewModel.swift
│   │   ├── LeaderboardViewModel.swift
│   │   ├── DiscrepancyViewModel.swift
│   │   ├── HistoryListViewModel.swift
│   │   └── RoundSummaryViewModel.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── SeededCourses.json
│       └── Info.plist
│
├── HyzerWatch/                                   # ── watchOS App Target ──
│   ├── App/
│   │   ├── HyzerWatchApp.swift
│   │   └── HyzerWatch.entitlements                # App Groups
│   │
│   ├── Services/                                  # Platform-specific service implementations
│   │   └── WatchConnectivityClientImpl.swift       # LiveWatchConnectivityClient for watchOS side
│   │
│   ├── Views/
│   │   ├── WatchLeaderboardView.swift              # FR53
│   │   ├── WatchScoringView.swift                  # FR54-FR55: Crown input, voice trigger
│   │   └── WatchStaleIndicatorView.swift           # lastUpdatedAt staleness display
│   │
│   ├── ViewModels/
│   │   ├── WatchLeaderboardViewModel.swift
│   │   └── WatchScoringViewModel.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Info.plist
│
├── HyzerKit/                                     # ── Shared Swift Package ──
│   ├── Package.swift
│   │
│   ├── Sources/HyzerKit/
│   │   ├── Models/
│   │   │   ├── ScoreEvent.swift                    # @Model: supersedesEventID, reportedByPlayerID, deviceID
│   │   │   ├── Round.swift                         # @Model: lifecycle state, playerIDs, organizerID
│   │   │   ├── Player.swift                        # @Model: iCloud identity, displayName, aliases
│   │   │   ├── Course.swift                        # @Model: name, holes, par values
│   │   │   ├── Hole.swift                          # @Model: hole number, par, distance
│   │   │   └── SyncMetadata.swift                  # @Model: local-only, recordID -> syncStatus
│   │   │
│   │   ├── Domain/
│   │   │   ├── StandingsEngine.swift               # @MainActor @Observable: recompute(for:trigger:)
│   │   │   ├── StandingsChange.swift               # Sendable struct
│   │   │   ├── StandingsChangeTrigger.swift        # Sendable enum
│   │   │   ├── ScoringService.swift                # ScoreEvent creation, validation, superseding
│   │   │   ├── ConflictDetector.swift              # Four-case conflict detection
│   │   │   ├── RoundLifecycleManager.swift         # Round state machine
│   │   │   └── CourseSeeder.swift                  # First-launch JSON import
│   │   │
│   │   ├── Voice/                                  # Platform-independent parsing only
│   │   │   ├── VoiceParser.swift                   # nonisolated: tokenize -> classify -> assemble
│   │   │   ├── VoiceParseResult.swift              # Sendable enum
│   │   │   ├── TokenClassifier.swift               # Name/number/noise classification
│   │   │   └── FuzzyNameMatcher.swift              # Alias map + Levenshtein fallback
│   │   │
│   │   ├── Sync/
│   │   │   ├── SyncEngine.swift                    # actor: push, pull, periodic fallback
│   │   │   ├── SyncState.swift                     # Sendable enum
│   │   │   ├── CloudKitClient.swift                # Protocol
│   │   │   ├── LiveCloudKitClient.swift            # CKDatabase wrapper
│   │   │   ├── SubscriptionManager.swift           # CKSubscription setup per record type
│   │   │   └── Records/
│   │   │       ├── ScoreEventRecord.swift          # Sendable DTO
│   │   │       ├── RoundRecord.swift
│   │   │       ├── PlayerRecord.swift
│   │   │       └── CourseRecord.swift
│   │   │
│   │   ├── Communication/
│   │   │   ├── WatchConnectivityClient.swift       # Protocol (shared)
│   │   │   ├── WatchMessage.swift                  # Sendable enum (shared)
│   │   │   ├── StandingsSnapshot.swift             # Sendable struct (shared)
│   │   │   └── WatchCacheManager.swift             # JSON file read/write in app group
│   │   │
│   │   ├── Design/
│   │   │   ├── AnimationTokens.swift
│   │   │   ├── AnimationCoordinator.swift
│   │   │   └── ColorTokens.swift
│   │   │
│   │   └── Extensions/
│   │       ├── Date+RelativeFormatting.swift
│   │       └── CKRecord+TypedAccess.swift
│   │
│   └── Tests/HyzerKitTests/
│       ├── Domain/
│       │   ├── StandingsEngineTests.swift
│       │   ├── ConflictDetectorTests.swift
│       │   ├── ScoringServiceTests.swift
│       │   ├── RoundLifecycleManagerTests.swift
│       │   └── CourseSeederTests.swift
│       │
│       ├── Voice/
│       │   ├── VoiceParserTests.swift
│       │   ├── TokenClassifierTests.swift
│       │   └── FuzzyNameMatcherTests.swift
│       │
│       ├── Sync/
│       │   ├── SyncEngineTests.swift
│       │   ├── SyncMetadataTests.swift
│       │   └── RecordTranslationTests.swift
│       │
│       ├── Communication/
│       │   ├── WatchMessageTests.swift
│       │   └── WatchCacheManagerTests.swift
│       │
│       ├── Integration/
│       │   └── SyncToStandingsIntegrationTests.swift
│       │
│       ├── Fixtures/
│       │   ├── ScoreEvent+Fixture.swift
│       │   ├── Round+Fixture.swift
│       │   ├── Player+Fixture.swift
│       │   └── Course+Fixture.swift
│       │
│       └── Mocks/
│           ├── MockCloudKitClient.swift
│           └── MockWatchConnectivityClient.swift
│
└── HyzerAppUITests/
    ├── ScoringFlowTests.swift
    ├── VoiceScoringFlowTests.swift
    ├── OfflineSyncFlowTests.swift
    └── DiscrepancyResolutionFlowTests.swift
```

### Architectural Boundaries

```
┌──────────────────────────────────────────────────────────┐
│                   Presentation Layer                      │
│  ┌────────────────────┐    ┌───────────────────────────┐ │
│  │  HyzerApp (iOS)    │    │  HyzerWatch (watchOS)     │ │
│  │  Views + VMs       │    │  Views + VMs              │ │
│  │  Services/         │    │  Services/                │ │
│  │  (VoiceRecognition,│    │  (WatchConnectivity       │ │
│  │   PhoneConnectivity│    │   Impl)                   │ │
│  └─────────┬──────────┘    └─────────────┬─────────────┘ │
│            │ @Observable                  │ JSON cache     │
├────────────┼──────────────────────────────┼───────────────┤
│            ▼           Domain Layer       ▼               │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  HyzerKit (platform-independent)                     │ │
│  │  ┌──────────────┐ ┌───────────┐ ┌─────────────────┐ │ │
│  │  │ Standings    │ │ Scoring   │ │ VoiceParser     │ │ │
│  │  │ Engine       │ │ Service   │ │ (nonisolated)   │ │ │
│  │  └──────┬───────┘ └─────┬─────┘ └─────────────────┘ │ │
│  │         │               │                             │ │
│  │  ┌──────┴───────────────┴──────────────────────────┐ │ │
│  │  │              Data Layer                          │ │ │
│  │  │  SwiftData Models (domain)                       │ │ │
│  │  │  SyncMetadata (local-only, separate config)      │ │ │
│  │  └──────────────┬──────────────────────────────────┘ │ │
│  │                 │                                     │ │
│  │  ┌──────────────┴──────────────────────────────────┐ │ │
│  │  │         Communication Layer                      │ │ │
│  │  │  SyncEngine ◄──► CloudKitClient (protocol)       │ │ │
│  │  │  WatchConnectivityClient (protocol)              │ │ │
│  │  │  WatchMessage, StandingsSnapshot (shared types)  │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  └──────────────────────────────────────────────────────┘ │
├───────────────────────────────────────────────────────────┤
│                    External Services                       │
│  ┌───────────────────┐    ┌─────────────────────────────┐ │
│  │ CloudKit Public   │    │ WCSession (Bluetooth/WiFi)  │ │
│  │ Database          │    │                             │ │
│  └───────────────────┘    └─────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

**Dependency Rules:**
- Presentation -> Domain: allowed (ViewModels depend on domain services)
- Domain -> Data: allowed (services depend on SwiftData models)
- Communication -> Domain: allowed (SyncEngine calls StandingsEngine.recompute)
- Communication -> External: allowed (via protocol implementations in target Services/)
- Presentation -> Communication: read-only (observe SyncState, connectivity state)
- **Domain -> Presentation: NEVER** (domain must not import UIKit/SwiftUI view types)
- **Data -> Domain: NEVER** (models don't depend on services)
- **HyzerKit -> Speech framework: NEVER** (platform-specific, lives in HyzerApp/Services/)
- **HyzerKit -> WCSession directly: NEVER** (protocol in HyzerKit, implementation in target Services/)

### Requirements to Structure Mapping

| FR Category | Primary Files | Supporting Files |
|---|---|---|
| **Onboarding (FR1-4)** | `Views/Onboarding/`, `ViewModels/OnboardingViewModel` | `Models/Player.swift`, `Sync/Records/PlayerRecord.swift` |
| **Courses (FR5-9)** | `Views/Courses/`, `ViewModels/CourseListViewModel` | `Models/Course.swift`, `Domain/CourseSeeder.swift`, `Resources/SeededCourses.json` |
| **Round Mgmt (FR10-16)** | `Views/Rounds/`, `Views/Scoring/ScorecardContainerView` | `Models/Round.swift`, `Domain/RoundLifecycleManager.swift` |
| **Tap Scoring (FR17-20)** | `Views/Scoring/HoleCardView`, `Views/Scoring/ScoreInputView` | `ViewModels/ScorecardViewModel`, `Domain/ScoringService.swift` |
| **Voice Scoring (FR21-29)** | `Views/Scoring/VoiceOverlayView`, `ViewModels/VoiceOverlayViewModel` | `Services/VoiceRecognitionService.swift`, `Voice/*` |
| **Crown Scoring (FR30-34)** | `HyzerWatch/Views/WatchScoringView` | `HyzerWatch/ViewModels/WatchScoringViewModel`, `Communication/WatchMessage.swift` |
| **Cross-Cutting Scoring (FR35-38)** | `Domain/ScoringService.swift` | `Models/ScoreEvent.swift` |
| **Leaderboard (FR39-43)** | `Views/Leaderboard/`, `ViewModels/LeaderboardViewModel` | `Domain/StandingsEngine.swift`, `Domain/StandingsChange.swift` |
| **Real-Time Sync (FR44-48)** | `Sync/SyncEngine.swift`, `Views/Shared/SyncIndicatorView` | `Sync/CloudKitClient.swift`, `Sync/Records/*`, `Models/SyncMetadata.swift` |
| **Discrepancy (FR49-52)** | `Views/Discrepancy/`, `ViewModels/DiscrepancyViewModel` | `Domain/ConflictDetector.swift` |
| **Watch (FR53-57)** | `HyzerWatch/Views/*`, `HyzerWatch/ViewModels/*` | `Communication/*`, `HyzerWatch/Services/WatchConnectivityClientImpl.swift` |
| **History (FR58-62)** | `Views/History/`, `ViewModels/HistoryListViewModel`, `ViewModels/RoundSummaryViewModel` | `Models/Round.swift`, `Models/ScoreEvent.swift` |

**Cross-Cutting Concern -> Files:**

| Concern | Primary Files |
|---|---|
| **Event Sourcing** | `Models/ScoreEvent.swift`, `Domain/ScoringService.swift`, `Domain/ConflictDetector.swift` |
| **Derived State** | `Domain/StandingsEngine.swift`, `Domain/StandingsChange.swift`, `Domain/StandingsChangeTrigger.swift` |
| **Offline-First** | `Sync/SyncEngine.swift`, `Sync/SyncState.swift`, `Models/SyncMetadata.swift` |
| **CloudKit Sync** | `Sync/SyncEngine.swift`, `Sync/CloudKitClient.swift`, `Sync/LiveCloudKitClient.swift`, `Sync/Records/*`, `Sync/SubscriptionManager.swift` |
| **Sync Testability** | `Sync/CloudKitClient.swift` (protocol), `Mocks/MockCloudKitClient.swift`, `Integration/SyncToStandingsIntegrationTests.swift` |
| **WatchConnectivity** | `Communication/WatchConnectivityClient.swift` (protocol), `HyzerApp/Services/PhoneConnectivityClient.swift`, `HyzerWatch/Services/WatchConnectivityClientImpl.swift` |
| **Type-Level Invariants** | `Models/ScoreEvent.swift` (no update/delete API), `Models/Round.swift` (immutable playerIDs) |
| **Accessibility** | Every file in `Views/` and `HyzerWatch/Views/` |
| **Animation** | `Design/AnimationTokens.swift`, `Design/AnimationCoordinator.swift` |

### Implementation Step to Directory Mapping

| Impl Step | Directories Touched |
|---|---|
| 1. Project setup | Root config, `.entitlements`, `Package.swift`, `.swiftlint.yml` |
| 2. Models + DTOs | `Models/`, `Sync/Records/` |
| 3. Sync spike | `Sync/`, `HyzerApp/Services/` (CloudKit only) |
| 4. StandingsEngine (parallel with 3) | `Domain/StandingsEngine.swift`, `Domain/StandingsChange.swift`, `Domain/StandingsChangeTrigger.swift` |
| 5. WatchConnectivity | `Communication/`, `HyzerApp/Services/PhoneConnectivityClient.swift`, `HyzerWatch/Services/WatchConnectivityClientImpl.swift` |
| 6. Voice parser (parallel with 7) | `Voice/`, `HyzerApp/Services/VoiceRecognitionService.swift` |
| 7. Views + VMs | `Views/`, `ViewModels/`, `HyzerWatch/Views/`, `HyzerWatch/ViewModels/` |
| 8. Conflict detection (after 3) | `Domain/ConflictDetector.swift`, `Views/Discrepancy/` |

### Data Flow Diagrams

**Score Entry Flow (Tap):**

```
User taps score on HoleCardView
  → ScorecardViewModel.enterScore(player:hole:strokes:)
    → ScoringService.createScoreEvent() → SwiftData write
      → SyncEngine.pushPending() → CloudKitClient.save() → CloudKit
    → StandingsEngine.recompute(for:trigger:.localScore) → StandingsChange
      → LeaderboardViewModel observes → AnimationCoordinator sequences:
        1. ScoreInputView confirmation (immediate)
        2. LeaderboardPillView pulse (after pillPulseDelay)
        3. LeaderboardExpandedView reshuffle (concurrent spring)
```

**Score Entry Flow (Voice):**

```
User taps mic on ScorecardContainerView
  → VoiceOverlayViewModel.startListening()
    → VoiceRecognitionService.recognize() → transcript (HyzerApp/Services/, iOS only)
      → VoiceParser.parse(transcript:players:) → VoiceParseResult (HyzerKit, nonisolated)
        → .success: VoiceOverlayView shows confirmation, auto-commit timer
        → .partial: VoiceOverlayView shows "did you mean...?"
        → .failed: VoiceOverlayView shows manual entry fallback
  → On confirm: ScoringService.createScoreEvent() → (same as tap flow)
```

**Remote Sync Flow:**

```
CKSubscription delivers silent push notification
  → SyncEngine receives notification
    → CloudKitClient.fetch() → new CKRecords
      → Translate via ScoreEventRecord DTO → SwiftData write
      → SyncMetadata entry created as .synced
      → ConflictDetector.check() → silent merge or discrepancy
        → If discrepancy: notify DiscrepancyViewModel
      → await StandingsEngine.recompute(for:trigger:.remoteSync) → StandingsChange
        → All observing ViewModels update
```

**Watch Communication Flow:**

```
Phone → Watch (standings update):
  StandingsEngine emits StandingsChange
    → PhoneConnectivityClient.send(.standingsUpdate(snapshot)) (HyzerApp/Services/)
      → WCSession.sendMessage (best-effort)
    → WatchCacheManager.write(snapshot) to app group JSON
    → Watch receives → WatchLeaderboardViewModel updates

Watch → Phone (score entry):
  User enters score via Crown on WatchScoringView
    → WatchScoringViewModel creates ScoreEvent data
      → WatchConnectivityClientImpl.transfer(.scoreEvent(dto)) (HyzerWatch/Services/)
        → WCSession.transferUserInfo (guaranteed)
    → Phone receives → ScoringService.createScoreEvent()
      → (same as tap flow from here)
```

## Architecture Validation Results

_Validated through 4 rounds of multi-agent review (12 agents, 35 findings). All critical and important findings are integrated below._

### Coherence Validation ✅

**Decision Compatibility:**

All technology choices are mutually compatible. Swift 6 strict concurrency + SwiftUI + SwiftData + manual CloudKit APIs form a coherent stack targeting iOS 18 / watchOS 11. The `@Observable` macro (iOS 17+) is available at the minimum deployment target. Actor isolation boundaries (`SyncEngine` as `actor`, `StandingsEngine` as `@MainActor`, `VoiceParser` as `nonisolated`) are mechanically correct under Swift 6's strict concurrency model. The dual `ModelConfiguration` approach for separating domain models from `SyncMetadata` is supported by SwiftData's `ModelContainer` API. No contradictory decisions found.

**Pattern Consistency:**

Naming conventions are applied uniformly: models (plain names), DTOs (`Record` suffix), protocols (capability names), ViewModels (`ViewModel` suffix), views (`View` suffix). File placement rules are consistent with the directory structure. Constructor injection via `AppServices` is the universal DI pattern. Testing patterns (naming, Given/When/Then, fixtures) are internally consistent. Tiered enforcement guidelines provide clear priority ordering.

**Structure Alignment:**

The project structure supports every architectural decision. HyzerKit contains only platform-independent code — Speech framework and WCSession implementations are in target `Services/` directories. Boundary diagram dependency rules are mechanically enforced by the Swift Package structure.

### Requirements Coverage Validation ✅

**Functional Requirements Coverage (64/64):**

| FR Category | FRs | Architectural Support | Status |
|---|---|---|---|
| Onboarding & Identity (FR1-4) | 4 | `Models/Player.swift` + iCloud identity + `Domain/CourseSeeder.swift` + offline-first | ✅ |
| Course Management (FR5-9) | 5 | `Models/Course.swift` + `Domain/CourseSeeder.swift` + `Views/Courses/` | ✅ |
| Round Management (FR10-16b) | 9 | `Models/Round.swift` (playerIDs, organizerID) + `Domain/RoundLifecycleManager.swift` + passive discovery | ✅ |
| Tap Scoring (FR17-20) | 4 | `Views/Scoring/HoleCardView.swift` + `Views/Scoring/ScoreInputView.swift` + par-anchored picker + auto-advance | ✅ |
| Voice Scoring (FR21-29) | 9 | `HyzerApp/Services/VoiceRecognitionService.swift` + `Voice/VoiceParser.swift` pipeline + `Voice/VoiceParseResult.swift` | ✅ |
| Crown Scoring (FR30-34) | 5 | `HyzerWatch/Views/WatchScoringView.swift` + Crown binding + haptic feedback | ✅ |
| Cross-Cutting Scoring (FR35-38) | 4 | `Domain/ScoringService.swift` + immutable `Models/ScoreEvent.swift` + supersedesEventID | ✅ |
| Live Leaderboard (FR39-43) | 5 | `Domain/StandingsEngine.swift` + `Domain/StandingsChange.swift` + `Design/AnimationCoordinator.swift` | ✅ |
| Real-Time Sync (FR44-48) | 5 | `Sync/SyncEngine.swift` + `Sync/CloudKitClient.swift` + `Models/SyncMetadata.swift` + four-case conflict detection | ✅ |
| Discrepancy Resolution (FR49-52) | 4 | `Domain/ConflictDetector.swift` + `Views/Discrepancy/DiscrepancyResolutionView.swift` + reportedByPlayerID | ✅ |
| Watch Companion (FR53-57) | 5 | `HyzerWatch/Views/` + Crown/voice input + `Communication/WatchConnectivityClient.swift` protocol | ✅ |
| Round Completion & History (FR58-62) | 5 | `Views/History/RoundSummaryView.swift` + `Views/History/HistoryListView.swift` + append-only retention | ✅ |

**Non-Functional Requirements Coverage (21/21):**

| NFR | Requirement | Architectural Support | Status |
|---|---|---|---|
| NFR1 | Voice-to-leaderboard <3s | Instrumented pipeline with per-stage budget. **Applies to no-correction happy path only.** Correction path (~6-7s) is user-controlled and has no latency target. | ✅ |
| NFR2 | Cross-device sync <5s | Push-on-write + CKSubscription + periodic fallback | ✅ |
| NFR3 | Tap feedback <100ms | Local-first SwiftData write, no network in path | ✅ |
| NFR4 | Crown haptic <50ms | Direct `.digitalCrownRotation` binding | ✅ |
| NFR5 | App launch <2s | iCloud identity deferred off launch path (A5). No network calls before first frame. | ✅ |
| NFR6 | Animation <500ms | `AnimationTokens.leaderboardReshuffleDuration = 0.4` | ✅ |
| NFR7 | Voice overlay <500ms | On-device recognition, local parser | ✅ |
| NFR8 | Zero data loss | Offline-first + SyncMetadata audit trail + `.inFlight` guard prevents duplicate pushes | ✅ |
| NFR9 | Zero crashes | Logger + Xcode Organizer crash logs + `ModelContainer` recovery path (A3, A6) | ✅ |
| NFR10 | Offline parity | Offline-first architecture, all three paradigms local | ✅ |
| NFR11 | 4-hour offline recovery | SyncMetadata + push-on-reconnect | ✅ |
| NFR12 | Watch delivery guarantee | `transferUserInfo` guaranteed delivery | ✅ |
| NFR13 | 4.5:1 contrast | `Design/ColorTokens.swift` centralized | ✅ |
| NFR14 | 44pt touch targets | SwiftUI view patterns | ✅ |
| NFR15 | Reduce motion | `Design/AnimationTokens.swift` + `accessibilityReduceMotion` checks | ✅ |
| NFR16 | Dynamic Type AX3 | `@ScaledMetric` + `ViewThatFits` patterns | ✅ |
| NFR17 | VoiceOver labels | Semantic accessibility pattern with domain language + voice overlay VoiceOver pattern | ✅ |
| NFR18 | Color-independent | Numeric context + color reinforcement pattern | ✅ |
| NFR19 | Append-only events | Type-level invariants: no update/delete API surface | ✅ |
| NFR20 | Deterministic merge | Four-case conflict detection with `supersedesEventID` | ✅ |
| NFR21 | 5-year retention | CloudKit capacity estimate, storage projection under 50MB | ✅ |

### Implementation Readiness Validation ✅

**Decision Completeness:**
- All critical decisions documented with rationale ✅
- Actor reentrancy hazard identified and mitigated (`.inFlight`) ✅
- `Package.swift` fully specified with `swift-tools-version: 6.0` ✅
- `ModelContainer` recovery path documented (operational and domain stores) ✅
- iCloud identity deferred-resolution pattern documented ✅
- `AppServices` constructor dependency graph documented ✅
- Code examples provided for all major patterns ✅

**Structure Completeness:**
- Complete directory tree with 70+ files + additional test files ✅
- Every FR mapped to primary and supporting files ✅
- Implementation steps broken into 18 parallelizable sub-stories with acceptance criteria ✅
- Data flow diagrams for all 4 major flows ✅
- Critical path designated for voice-to-leaderboard pipeline ✅

**Pattern Completeness:**
- Concurrency boundaries fully specified ✅
- Two animation sequences documented (tap and voice) ✅
- Voice overlay VoiceOver pattern specified ✅
- Anti-patterns table extended ✅
- Mock behavior contracts specified ✅
- UI test launch argument pattern documented ✅

### Gap Analysis Results

**Critical Gaps: None** (all critical issues resolved through Party Mode amendments)

**Remaining Minor Gaps (3):**

1. **SwiftLint `.swiftlint.yml` rule specification** — file exists in structure but rules are not enumerated. Standard Swift naming/style rules. Low risk.
2. **`RoundLifecycleManager` → `SyncEngine` fallback timer calling convention** — described conceptually ("starts when Round enters `.active`") but not as explicit code pattern. Implementable from the description.
3. **iCloud account switch mid-round** — edge case not addressed. Extremely unlikely for 6-user TestFlight group. Post-MVP if ever.

### Amendments to Prior Architecture Sections

The following amendments refine decisions documented in earlier steps. They are recorded here so the full decision trail is preserved.

**Amendment A1 — SyncMetadata requires `.inFlight` status (amends Core Architectural Decisions: Sync Architecture):**

The `SyncMetadata` sync status must be a four-state enum:

```swift
enum SyncStatus: String, Codable, Sendable {
    case pending    // Written locally, not yet pushed
    case inFlight   // Push attempt in progress
    case synced     // Confirmed in CloudKit
    case failed     // Push attempt failed, will retry
}
```

**Rationale:** `SyncEngine` is an `actor`. Swift actors are reentrant — when `pushPending()` suspends at `await CloudKitClient.save()`, a second `pushPending()` call can enter the actor. Without `.inFlight`, both calls read the same `.pending` entries and push duplicates to CloudKit. Pattern: mark entries `.inFlight` before the `await`, transition to `.synced` on success, revert to `.failed` on error. `.failed` entries are retried on the next push cycle.

**Amendment A2 — HyzerKit `Package.swift` specification (amends Starter Template Evaluation):**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HyzerKit",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "HyzerKit", targets: ["HyzerKit"])
    ],
    targets: [
        .target(name: "HyzerKit", path: "Sources/HyzerKit"),
        .testTarget(name: "HyzerKitTests", dependencies: ["HyzerKit"], path: "Tests/HyzerKitTests")
    ]
)
```

`swift-tools-version: 6.0` enables strict concurrency by default for both the library and test targets. Without this, test files will not enforce actor isolation contracts and mock implementations can silently drift from production concurrency requirements.

**Amendment A3 — `ModelContainer` operational store recovery path (amends Implementation Patterns):**

When constructing the `ModelContainer` with dual `ModelConfiguration`, the operational store (SyncMetadata) may fail to initialize. Recovery pattern:

```swift
do {
    modelContainer = try ModelContainer(for: schema, configurations: [domainConfig, operationalConfig])
} catch {
    // Operational store corrupted — delete and retry
    // Safe: SyncMetadata is reconstructed from CloudKit state on next sync
    try? FileManager.default.removeItem(at: operationalStoreURL)
    modelContainer = try ModelContainer(for: schema, configurations: [domainConfig, operationalConfig])
}
```

SyncMetadata is reconstructible — on next sync cycle, all CloudKit records are re-fetched and their SyncMetadata entries recreated as `.synced`. Domain data is unaffected.

**Amendment A4 — Explicit App Group ID in capabilities setup (amends Starter Template Evaluation):**

```
3. Enable capabilities (iOS target):
   - iCloud > CloudKit (container: iCloud.com.shotcowboystyle.hyzerapp)
   - Background Modes > Remote Notifications
   - App Groups (group.com.shotcowboystyle.hyzerapp)

4. Enable capabilities (watchOS target):
   - App Groups (group.com.shotcowboystyle.hyzerapp)  ← must match iOS
```

Without matching App Group IDs in both entitlements, `WatchCacheManager` cannot read/write the shared JSON file and fails silently.

**Amendment A5 — iCloud identity deferred off launch path (amends Implementation Patterns):**

`CKContainer.default().fetchUserRecordID()` and `CKContainer.accountStatus()` are network calls that must never execute on the app launch path.

- `AppServices` initializes with `iCloudIdentity: nil`
- Root view `.task` modifier calls `AppServices.resolveICloudIdentity()` asynchronously
- Player record saves locally on first launch with a local UUID; iCloud record name associated when async resolution completes
- If iCloud is unavailable, the app functions fully with local identity (per FR2, FR4)

**Amendment A6 — Startup sequence and domain store recovery (amends Implementation Patterns):**

Explicit startup sequence:

```
1. Create ModelContainer (domain + operational config)
   → If operational store fails: delete operational store + recreate (A3)
   → If domain store fails: delete BOTH stores + recreate
     (Safe: CloudKit public database holds complete event history.
      All data re-syncs on next SyncEngine cycle.)
2. Create AppServices with ModelContainer (iCloudIdentity: nil)
3. Render root view
4. .task: resolve iCloud identity asynchronously (A5)
5. .task: SyncEngine.start()
```

Domain store corruption is the nuclear case. Recovery deletes all local data and rebuilds from CloudKit. This is safe because the event-sourced model means CloudKit has the complete history.

**Amendment A7 — Current score resolution uses supersession chain, not timestamp (amends Core Architectural Decisions: Data Architecture):**

The "current score" for a {player, hole} is defined as: **the ScoreEvent that no other ScoreEvent points to via `supersedesEventID`** (the leaf node in the supersession chain). This is a graph traversal, not a timestamp comparison.

Rationale: Timestamps can diverge across devices with clock skew. The supersession chain is device-independent and deterministic. For expected data volume (≤10 events per {player, hole} in extreme cases), leaf-node resolution is trivial.

`StandingsEngine.recompute()` must use this leaf-node resolution, not "most recent by createdAt."

**Amendment A8 — Course-to-Hole relationship uses flat foreign key (amends Core Architectural Decisions: Data Architecture):**

`Hole` references its parent via `courseID: UUID` (flat foreign key), not a SwiftData `@Relationship`.

Rationale: SwiftData relationships must be optional with no `Deny` delete rules for CloudKit compatibility. A flat foreign key is simpler, avoids relationship cascade issues, and queries via `#Predicate { $0.courseID == targetCourseID }` are straightforward.

**Amendment A9 — `AppServices` constructor dependency graph (amends Implementation Patterns: Dependency Injection):**

```
ModelContainer
├── ModelContext (main, @MainActor) ─────────────────────────┐
├── ModelContext (background, @ModelActor) ──────────┐       │
│                                                    │       │
StandingsEngine() ← standalone, no deps              │       │
RoundLifecycleManager(modelContext:) ◄───────────────┼───────┤
                                                     │       │
CloudKitClient = LiveCloudKitClient(container:)      │       │
SyncEngine(cloudKitClient:, standingsEngine:,  ◄─────┘       │
           modelContext: background)                          │
                                                             │
ScoringService(standingsEngine:, lifecycleManager:,  ◄───────┘
               modelContext: main)

WatchConnectivityClient = PhoneConnectivityClient()
WatchConnectivityManager(connectivityClient:, standingsEngine:)
```

`AppServices` constructs in this order: `ModelContainer` → `StandingsEngine` → `RoundLifecycleManager` → `CloudKitClient` → `SyncEngine` → `ScoringService` → `WatchConnectivityManager`. No circular dependencies.

**Amendment A10 — Spike boundary and failure plan (amends Core Architectural Decisions: Sync Architecture):**

**Spike scope:** Implement `CloudKitClient` protocol + `LiveCloudKitClient` + `SyncEngine.pushPending()` + `SyncEngine.pullRecords()` for `ScoreEvent` record type only. Single record type. No subscriptions, no periodic fallback, no conflict detection. Two physical devices (or simulators with different iCloud accounts).

**Spike exit criteria:** A `ScoreEvent` created in SwiftData on device A appears in SwiftData on device B within 10 seconds.

**Spike failure plan:** If CloudKit public database proves unworkable (rate limits, API restrictions, sandbox issues), fall back to Layer 0 (single-device scorecard with local SwiftData). Reassess sync strategy. The minimum viable experience layers already support graceful degradation.

### Additional UX & Accessibility Patterns

**Voice Overlay Animation Sequence:**

The `AnimationCoordinator` manages two distinct post-score animation sequences:

```
Tap sequence:
  ScoreInputView confirmation (immediate)
  → LeaderboardPillView pulse (after pillPulseDelay)
  → LeaderboardExpandedView reshuffle (concurrent spring)

Voice sequence:
  VoiceOverlayView appear (<500ms per NFR7)
  → Auto-commit countdown (3s, resets on tap)
  → VoiceOverlayView dismiss
  → LeaderboardPillView pulse (after pillPulseDelay)
  → LeaderboardExpandedView reshuffle (concurrent spring)
```

The voice sequence is longer because the overlay is the trust-building mechanism — it shows users what was parsed before committing. Even when recognition is perfect, the overlay builds confidence in the system. **It is trust UX, not error handling.** Implementing agents should prioritize overlay clarity and polish.

**Watch Stale Indicator UX:**

`WatchStaleIndicatorView` displays relative time since last standings update (e.g., "2m ago") with reduced opacity on the standings list when `StandingsSnapshot.lastUpdatedAt` exceeds 30 seconds. Relative time format, not color-only.

**Voice Overlay VoiceOver Pattern:**

The voice confirmation overlay (FR24-FR26) is the most accessibility-critical transient screen. Required behaviors:

1. **Announce on appear:** VoiceOver reads all parsed scores immediately when the overlay appears
2. **Announce timer:** "Committing in 3 seconds" announced after scores are read
3. **Explicit commit button:** VoiceOver users cannot rely on the auto-commit timer while navigating entries. An explicit "Commit Scores" button must be present (can be visually de-emphasized since sighted users rely on the timer)
4. **Pause timer during navigation:** If VoiceOver focus is on any entry in the overlay (user is reviewing or correcting), the auto-commit timer pauses. Timer resumes when focus leaves the overlay entries.

**App-Foreground Round Discovery Fetch (FR16b hardening):**

CKSubscription silent push notifications are throttled by iOS (Low Power Mode, background-killed app). When the app enters foreground outside an active round, perform a single `CKQuery` for rounds where the current user's ID is in `playerIDs` and `status == .active`. This lightweight query covers missed subscription notifications. During an active round, the periodic fallback timer already handles this.

**FR14 Auto-Completion Trigger:**

`ScoringService.createScoreEvent()` calls `RoundLifecycleManager.checkCompletion(for: roundID)` after every successful write. The lifecycle manager queries SwiftData for score count vs. (player count × hole count). If all scores present, it transitions the round to `.awaitingFinalization`. `ScorecardViewModel` observes the round state and prompts "All scores recorded. Finalize round?"

**FR11 Player Search Pattern:**

Player search in `RoundSetupView` uses `@Query` with a dynamic string predicate in the View (consistent with the "@Query in Views" rule). The View passes the selected `Player` to `RoundSetupViewModel.addPlayer()`.

### Journey-to-Architecture Traces

Each user journey maps to a sequence of architectural components. These traces serve as integration test roadmaps.

| Journey | Component Sequence |
|---|---|
| **J1: First Round** | `Views/Onboarding/OnboardingView` → `Models/Player` → `Domain/CourseSeeder` → `Views/Rounds/RoundListView` (passive discovery) → `Views/Scoring/ScorecardContainerView` → `Views/Scoring/VoiceOverlayView` → `Voice/VoiceParser` → `Domain/ScoringService` → `Domain/StandingsEngine` → `Views/Leaderboard/LeaderboardPillView` → `Views/History/RoundSummaryView` |
| **J2: Voice Correction** | `Views/Scoring/VoiceOverlayView` → `Voice/VoiceParser` (`.success`) → overlay tap-to-correct → `Domain/ScoringService` → `Domain/StandingsEngine` → pill pulse. Alt: `.partial` → player picker → manual entry. Alt: `.failed` → retry/cancel → tap fallback |
| **J3: Round Organizer** | `Views/Rounds/RoundSetupView` → `Models/Round` (playerIDs, organizerID) → `Sync/SyncEngine` push → remote devices pull → ... → `Domain/ConflictDetector` → `Views/Discrepancy/DiscrepancyAlertView` → `Views/Discrepancy/DiscrepancyResolutionView` → `Domain/ScoringService` (resolution ScoreEvent) |
| **J4: Guest Player** | `Views/Rounds/RoundSetupView` (add guest name) → `Models/Round` (guest as string in player list) → scoring flows unchanged → `Views/History/RoundSummaryView` (guest appears identically) |
| **J5: History Browsing** | `Views/History/HistoryListView` → `Views/History/RoundSummaryView` → `Views/History/RoundDetailView` (hole-by-hole) |
| **S6: Dead Zone (Offline)** | All scoring flows → `Models/SyncMetadata` (entries accumulate as `.pending`) → reconnect → `Sync/SyncEngine.pushPending()` (`.inFlight` guard) → `Domain/ConflictDetector` (silent merge) → `Domain/StandingsEngine` (remote sync trigger) |
| **S7: Watch Experience** | `HyzerWatch/Views/WatchLeaderboardView` → `HyzerWatch/Views/WatchScoringView` (Crown) → `HyzerWatch/Services/WatchConnectivityClientImpl` → phone receives → `Domain/ScoringService` → `Domain/StandingsEngine` → `HyzerApp/Services/PhoneConnectivityClient` sends snapshot → Watch updates. Alt: phone unreachable → voice unavailable, Crown works locally, `transferUserInfo` queues scores |

### Implementation Steps with Sub-Stories and Critical Path

**Critical Path** (highest value — proves the thesis):

```
Models (2) → StandingsEngine (4) → Voice Parser (6) → Scoring Views (7d)
→ Voice Overlay (7e) → Leaderboard Views (7f)
```

This is the voice-to-leaderboard pipeline. If an implementing agent must choose between polishing a critical-path component and a non-critical-path component, the critical path wins.

**Highest Risk** (parallel track): Sync spike (3). Validates CloudKit public database viability.

**Demo Build:** Steps 2 + 4 + 6 + 7d + 7e + 7f constitute the minimum "prove it works" build. One pre-seeded course, round creation with hard-coded players, voice scoring on one hole, leaderboard pill update. Compilable and runnable without sync, Watch, history, or discrepancy resolution.

| Step | Description | Done When | Deps | Critical Path? |
|---|---|---|---|---|
| 1 | Project setup | Both targets build, tests run green, capabilities configured (incl. `group.com.shotcowboystyle.hyzerapp`), `--ui-testing` launch argument hook | — | — |
| 2 | Models + DTOs + Fixtures | All `@Model` definitions compile, four-state `SyncStatus`, flat `courseID` on Hole, chain fixtures for corrections and discrepancies | After 1 | ✅ |
| 3 | Sync spike | ScoreEvent on device A appears on device B within 10s. Single record type only. No subscriptions, no conflict detection. | After 2 | Risk track |
| 4 | StandingsEngine | `recompute()` produces correct standings from fixtures using leaf-node supersession resolution | After 2, ∥ with 3 | ✅ |
| 5 | WatchConnectivity | `WatchMessage` round-trips between simulator targets | After 2 | — |
| 6 | Voice parser | Correct `VoiceParseResult` for 10+ test transcripts (success/partial/failed) | After 2, ∥ with 7 | ✅ |
| 7a | Onboarding views | `OnboardingView` + `PlayerSetupView` render with fixture Player | After 2 | — |
| 7b | Course views | `CourseListView` + `CourseDetailView` + `CourseEditorView` render with fixture Courses | After 2 | — |
| 7c | Round setup views | `RoundSetupView` + `RoundListView` render, player `@Query` search works | After 2 | — |
| 7d | Scoring views | `ScorecardContainerView` + `CardStackView` + `HoleCardView` + `ScoreInputView`, tap scoring functional with StandingsEngine | After 4 | ✅ |
| 7e | Voice overlay | `VoiceOverlayView` + VoiceOver pattern, auto-commit timer, tap-to-correct, timer pause during VoiceOver | After 6 | ✅ |
| 7f | Leaderboard views | `LeaderboardPillView` + `LeaderboardExpandedView` with both animation sequences (tap and voice) | After 4 | ✅ |
| 7g | Discrepancy views | `DiscrepancyAlertView` + `DiscrepancyResolutionView` with fixture conflicts | After 8 | — |
| 7h | History views | `HistoryListView` + `RoundSummaryView` + `RoundDetailView` with fixture rounds | After 2 | — |
| 7i | Watch views | All 3 Watch views + VMs with fixture `StandingsSnapshot` | After 5 | — |
| 7j | Shared views | `SyncIndicatorView` + `EmptyStateView` | After 3 | — |
| 8 | Conflict detection | All four conflict cases correct, FR14 auto-completion triggers correctly | After 3 | — |

### Additional Test Infrastructure

**Updated Test Directory (amends Project Structure):**

```
HyzerKitTests/
├── Domain/
│   ├── StandingsEngineTests.swift
│   ├── ConflictDetectorTests.swift
│   ├── ScoringServiceTests.swift
│   ├── RoundLifecycleManagerTests.swift
│   └── CourseSeederTests.swift
│
├── Voice/
│   ├── VoiceParserTests.swift
│   ├── TokenClassifierTests.swift
│   └── FuzzyNameMatcherTests.swift
│
├── Sync/
│   ├── SyncEngineTests.swift              # Includes concurrent push test (.inFlight guard)
│   ├── SyncMetadataTests.swift
│   └── RecordTranslationTests.swift
│
├── Communication/
│   ├── WatchMessageTests.swift
│   └── WatchCacheManagerTests.swift
│
├── Infrastructure/
│   └── ModelContainerTests.swift           # Dual config lifecycle tests
│
├── Integration/
│   ├── SyncToStandingsIntegrationTests.swift
│   └── VoiceToStandingsIntegrationTests.swift  # Parser-to-standings pipeline
│
├── Fixtures/
│   ├── ScoreEvent+Fixture.swift            # Includes .correctionChain() and .discrepancyPair()
│   ├── Round+Fixture.swift
│   ├── Player+Fixture.swift
│   └── Course+Fixture.swift
│
└── Mocks/
    ├── MockCloudKitClient.swift
    └── MockWatchConnectivityClient.swift
```

**Chain Fixtures (`HyzerKitTests/Fixtures/ScoreEvent+Fixture.swift`):**

```swift
extension ScoreEvent {
    /// Creates original → correction chain
    static func correctionChain(
        player: String, hole: Int,
        originalStrokes: Int, correctedStrokes: Int
    ) -> (original: ScoreEvent, correction: ScoreEvent)

    /// Creates two conflicting events from different reporters
    static func discrepancyPair(
        player: String, hole: Int,
        strokesA: Int, reporterA: UUID,
        strokesB: Int, reporterB: UUID
    ) -> (eventA: ScoreEvent, eventB: ScoreEvent)
}
```

**`MockCloudKitClient` Behavior Contract:**

- `save(_:)` stores records in an in-memory `[CKRecord.ID: CKRecord]` dictionary
- `fetch(matching:)` returns records matching a predicate from the dictionary
- `savedRecords: [CKRecord]` — inspection property for assertions
- `shouldSimulateError: CKError?` — when set, all operations throw this error
- `simulatedLatency: Duration?` — when set, operations sleep before executing (for `.inFlight` timing tests)

**`SyncEngineTests` Concurrent Push Test:**

Create two `.pending` SyncMetadata entries, call `pushPending()` twice concurrently via `TaskGroup`, assert each entry results in exactly one `CloudKitClient.save()` call. Validates the `.inFlight` guard against duplicate pushes.

**`ModelContainerTests`:**

Verify (a) domain models and SyncMetadata coexist in the same container, (b) SyncMetadata is isolated to the operational store, (c) deleting/recreating the operational store does not affect domain data.

**`VoiceToStandingsIntegrationTests`:**

Feed a transcript string into `VoiceParser.parse()`, assert `VoiceParseResult`, create ScoreEvents via `ScoringService`, call `StandingsEngine.recompute()`, assert correct `StandingsChange`. No `SFSpeechRecognizer` needed.

**UI Test Launch Argument Pattern (`HyzerApp/App/HyzerApp.swift`):**

```swift
@main struct HyzerApp: App {
    init() {
        if CommandLine.arguments.contains("--ui-testing") {
            // Use in-memory ModelContainer (no persistent store)
            // Inject MockCloudKitClient
            // Pre-populate with fixture data via AppServices.configureForTesting()
        }
    }
}
```

### Additional Anti-Patterns

Added to the anti-patterns table from Implementation Patterns:

| Anti-Pattern | Do This Instead |
|---|---|
| Reading `.pending` records during active push without `.inFlight` guard | Mark `.inFlight` before `await`, revert to `.failed` on error |
| Resolving "current score" by timestamp (`createdAt`) | Resolve by supersession chain leaf node (no inbound `supersedesEventID` reference) |
| Using `@Relationship` for Course-to-Hole | Flat `courseID: UUID` foreign key on Hole for CloudKit compatibility |
| Building full SyncEngine as "spike" | Spike is single record type, two devices, push/pull only. No subscriptions, no conflict detection. |

### Architecture Completeness Checklist

**✅ Requirements Analysis**
- [x] Project context thoroughly analyzed (64 FRs, 21 NFRs, 7 user journeys)
- [x] Scale and complexity assessed (medium-high, 6 users, CloudKit free tier)
- [x] Technical constraints identified (SwiftData + CloudKit public DB incompatibility)
- [x] Cross-cutting concerns mapped (9 concerns)

**✅ Architectural Decisions**
- [x] Critical decisions documented with rationale
- [x] Technology stack fully specified (Swift 6, SwiftUI, SwiftData, CloudKit public DB)
- [x] Integration patterns defined (CloudKitClient, WatchConnectivityClient protocols)
- [x] Performance considerations addressed (voice pipeline budget, performance envelopes)
- [x] Actor reentrancy hazard addressed (`.inFlight` SyncMetadata status)
- [x] NFR1 scope clarified (no-correction happy path only)
- [x] Supersession chain resolution defined (leaf node, not timestamp)
- [x] Course-to-Hole relationship defined (flat foreign key)
- [x] Sync spike boundary and failure plan defined

**✅ Implementation Patterns**
- [x] Naming conventions established
- [x] Structure patterns defined (file placement table, feature grouping)
- [x] Communication patterns specified
- [x] Process patterns documented (error handling, concurrency, animation, testing)
- [x] `ModelContainer` recovery path documented (operational and domain stores)
- [x] iCloud identity deferred-resolution pattern documented
- [x] App startup sequence documented
- [x] `AppServices` constructor dependency graph documented
- [x] Two animation sequences documented (tap and voice)
- [x] Voice overlay VoiceOver pattern specified
- [x] Mock behavior contracts specified
- [x] UI test launch argument pattern documented

**✅ Project Structure**
- [x] Complete directory structure defined (70+ files + additional test files)
- [x] Component boundaries established
- [x] Integration points mapped (data flow diagrams for 4 major flows)
- [x] Requirements to structure mapping complete
- [x] `Package.swift` fully specified with strict concurrency
- [x] Journey-to-architecture traces for all 7 journeys
- [x] Implementation steps broken into 18 sub-stories with acceptance criteria
- [x] Critical path and demo build designated

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Validation Provenance:** 4 rounds of multi-agent review, 12 agents, 35 findings (1 critical, 27 important, 7 minor). All critical and important findings resolved.

**Key Strengths:**
- CloudKit public database discovery caught early, shaped entire sync architecture
- Event-sourced data model with `supersedesEventID` provides mechanical conflict disambiguation via supersession chain leaf-node resolution
- Protocol abstractions enable comprehensive testing without devices or CloudKit
- Platform compilation constraints properly handled — HyzerKit stays platform-independent
- Voice-to-leaderboard pipeline has explicit per-stage latency budgets and is designated as the critical path
- Actor reentrancy hazard identified and mitigated with `.inFlight` guard before implementation
- `Package.swift` fully specified with `swift-tools-version: 6.0` to prevent concurrency drift
- Voice overlay VoiceOver pattern prevents accessibility regression on the most critical transient screen
- Journey-to-architecture traces provide integration test roadmap for all 7 user journeys
- Minimum viable experience layers (0-3) and demo build provide graceful degradation
- `AppServices` dependency graph and startup sequence eliminate initialization ambiguity
- Mock behavior contracts and chain fixtures enable productive testing from day one
- Spike boundary prevents scope creep on the highest-risk component

**Areas for Future Enhancement:**
- SwiftLint `.swiftlint.yml` rule specification
- iCloud account switch mid-round edge case
- `RoundLifecycleManager` → `SyncEngine` fallback timer as explicit code pattern

### Implementation Handoff

**AI Agent Guidelines:**
- Read the complete document before implementing any component (10 amendments refine earlier decisions)
- Follow all architectural decisions exactly as documented, including amendments A1-A10
- Use implementation patterns consistently across all components
- Respect project structure and boundaries (HyzerKit → no platform-specific frameworks)
- The voice confirmation overlay is trust UX, not error handling — prioritize overlay clarity and polish
- Critical path components (voice-to-leaderboard pipeline) get priority over non-critical-path components
- When in doubt: file placement → naming → constructor injection

**First Implementation Priority:**
1. Create Xcode project using "iOS App with Watch App" template with specified capabilities (including `group.com.shotcowboystyle.hyzerapp` in both targets, `--ui-testing` launch argument hook)
2. Add HyzerKit local Swift Package with the specified `Package.swift` (`swift-tools-version: 6.0`)
3. Define SwiftData models with all architecturally significant fields (including four-state `SyncStatus`, flat `courseID` on Hole) + chain fixtures
4. Begin sync architectural spike (parallel): `CloudKitClient` protocol + `LiveCloudKitClient` + push/pull for ScoreEvent only, with `.inFlight` guard
5. Begin StandingsEngine (parallel with spike): leaf-node supersession resolution
6. Proceed along critical path: Voice Parser → Scoring Views → Voice Overlay → Leaderboard Views

### Quick Reference Card

```
QUICK REFERENCE — hyzer-app Architecture
═════════════════════════════════════════

THE PRODUCT IS THE LEADERBOARD. Score entry is infrastructure.
Voice-to-leaderboard < 3s is the defining experience.
Critical path: Models → StandingsEngine → VoiceParser → ScoringViews → VoiceOverlay → LeaderboardViews

FILE PLACEMENT
  Models:     HyzerKit/Sources/HyzerKit/Models/           Plain names (ScoreEvent, Round, Player, Course, Hole, SyncMetadata)
  DTOs:       HyzerKit/Sources/HyzerKit/Sync/Records/     Record suffix (ScoreEventRecord, RoundRecord)
  Domain:     HyzerKit/Sources/HyzerKit/Domain/            Services, engines, lifecycle manager, seeder
  Voice:      HyzerKit/Sources/HyzerKit/Voice/             Parser only — NO Speech framework
  Sync:       HyzerKit/Sources/HyzerKit/Sync/              SyncEngine (actor), CloudKitClient protocol, SubscriptionManager
  Comms:      HyzerKit/Sources/HyzerKit/Communication/     WatchConnectivityClient protocol, WatchMessage, StandingsSnapshot
  Design:     HyzerKit/Sources/HyzerKit/Design/            AnimationTokens, AnimationCoordinator, ColorTokens
  Views:      {Target}/Views/{Feature}/                    View suffix, grouped by feature
  VMs:        {Target}/ViewModels/                         ViewModel suffix, one per screen
  Services:   {Target}/Services/                           Platform-specific (VoiceRecognition, Connectivity)
  Tests:      HyzerKitTests/{MirroredPath}/                test_method_scenario_expected
  Fixtures:   HyzerKitTests/Fixtures/                      .fixture() factories + chain fixtures (.correctionChain, .discrepancyPair)
  Mocks:      HyzerKitTests/Mocks/                         Mock{Protocol} with in-memory store + error simulation

CORE RULES
  DI:            Constructor injection via AppServices. No singletons. No service locators.
  @Query:        In Views only. Never in ViewModels.
  Concurrency:   SyncEngine = actor | StandingsEngine = @MainActor | VoiceParser = nonisolated | All VMs = @MainActor
  Errors:        Typed Sendable enums per domain area. Never swallow silently.
  Animations:    AnimationTokens constants only. Always check accessibilityReduceMotion.
  Sync status:   .pending → .inFlight → .synced | .failed (four states, never skip .inFlight)
  Current score: Leaf node in supersedesEventID chain (not by timestamp)
  Relationships: Flat foreign keys (courseID on Hole), not @Relationship, for CloudKit compatibility

CALLING CONVENTIONS
  After ScoringService.createScoreEvent():
    → StandingsEngine.recompute(for: roundID, trigger: .localScore)
    → RoundLifecycleManager.checkCompletion(for: roundID)
  After SyncEngine receives remote records:
    → ConflictDetector.check()
    → await StandingsEngine.recompute(for: roundID, trigger: .remoteSync)
  After discrepancy resolution:
    → StandingsEngine.recompute(for: roundID, trigger: .conflictResolution)

APPSERVICES INIT ORDER
  ModelContainer → StandingsEngine → RoundLifecycleManager → CloudKitClient
  → SyncEngine(background ctx) → ScoringService(main ctx) → WatchConnectivityManager

BOUNDARIES — NEVER CROSS
  HyzerKit → Speech framework: NEVER
  HyzerKit → WCSession directly: NEVER
  Data → Domain: NEVER
  Domain → Presentation: NEVER
```
