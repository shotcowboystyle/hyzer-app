# HyzerApp — Repository Dossier

**Repository:** `shotcowboystyle/hyzer-app` — "Personal disc golf app for wearables and mobile"
**Compiled:** 2026-09-03 against `main` @ `089ce8f` (`feat(design): integrate iPhone + Watch design handoff (#118)`)
**Method:** static inspection of the working tree + GitHub API (Actions, PRs, issues, branches). No Swift toolchain exists in the compiling environment, so **no test or build was executed for this document** — every test count below is a static count of `@Test` declarations, not a run result. Statements marked _(claimed)_ come from repo documentation and were not independently verified; statements marked _(verified)_ were checked directly.

---

## 1. Snapshot

| Dimension | Value |
|---|---|
| Product | Native iOS 18 + watchOS 11 disc golf scoring app (multiplayer, shared rounds, voice scoring, watch companion) |
| Language / toolchain | Swift 6.0, `SWIFT_STRICT_CONCURRENCY = complete`, SwiftUI, SwiftData, CloudKit public DB |
| Third-party dependencies | **Zero.** No `Package.resolved`, no SPM remote deps, Apple frameworks only _(verified)_ |
| Project generation | XcodeGen (`project.yml` → `HyzerApp.xcodeproj`) |
| Targets | `HyzerApp` (iOS 18+), `HyzerWatch` (watchOS 11+), `HyzerKit` (SPM: iOS/watchOS/macOS 14), `TestSupport` (SPM), `HyzerKitTests`, `HyzerAppTests` |
| Source size | 122 non-test Swift files / ~14.7k lines; 111 test-target files (106 test files + 5 shared helpers) / ~19.9k lines _(verified)_ |
| Version | `MARKETING_VERSION 0.1.0`, `CURRENT_PROJECT_VERSION 2` |
| Ship state | Not shipped. No TestFlight or App Store build. APS entitlement already flipped to `production` |
| Repo activity | 50 commits on `main`, first 2026-05-11, last **2026-07-02**. Dormant ~2 months _(verified)_ |
| Contributors | Curtis Blanton (44 commits), shotcowboystyle (2), renovate[bot] (4) |
| **CI on `main`** | **RED.** Every push run since 2026-05-19 has failed — 13 consecutive failures _(verified, see §8)_ |

---

## 2. Read order for a new contributor

1. `CLAUDE.md` — conventions, layer rules, coding standards. Authoritative on intent; **stale in several factual claims** (§10).
2. `_bmad-output/planning-artifacts/architecture.md` — canonical architecture decisions and amendments (A6, A8 referenced throughout the code).
3. `docs/architecture.md`, `docs/data-models.md` — generated deep-scan docs. Accurate on structure, stale on counts.
4. `HyzerApp/App/HyzerApp.swift` + `HyzerApp/App/AppServices.swift` — the entire startup and wiring story lives in these two files (206 + 553 lines).
5. `_bmad-output/implementation-artifacts/sprint-status.yaml` — de facto story ledger.
6. `_bmad-output/implementation-artifacts/deferred-work.md` — the honest technical-debt register (145 lines). Read this before touching sync, history services, or CI.

---

## 3. Repository map

```
project.yml                 XcodeGen spec — sole editable source for targets + merged Info.plist
HyzerApp.xcodeproj/         GENERATED but tracked in git (see §10, drift #9)
HyzerApp/                   iOS app — Views + ViewModels + Live* service impls only
  App/                      HyzerApp.swift (entry, dual-store container), AppServices.swift (composition root)
  ViewModels/               14 @MainActor @Observable ViewModels
  Views/                    31 SwiftUI views across Components/Courses/Discrepancy/History/Leaderboard/Onboarding/Rounds/Scoring
  Services/                 8 concrete impls: LiveCloudKitClient, LiveICloudIdentityProvider,
                            LiveNearbyDiscoveryClient, LiveNetworkMonitor, LiveNotificationService,
                            MetricKitObserver, PhoneConnectivityService, VoiceRecognitionService
  Protocols/                VoiceRecognitionServiceProtocol (the one app-level protocol)
HyzerWatch/                 watchOS app — 4 views + WatchConnectivityService (703 lines total)
HyzerKit/                   Local SPM package — all shared logic
  Sources/HyzerKit/
    Models/                 6 @Model domain types
    Domain/                 17 files: scoring, standings, conflict detection, lifecycle, history services
    Sync/                   17 files: SyncEngine (actor), SyncScheduler, CloudKitClient, DTOs, SyncMetadata
    Communication/          8 files: WatchMessage protocol, 3 watch ViewModels, cache manager
    Voice/                  5 files: VoiceParser, TokenClassifier, FuzzyNameMatcher
    Design/                 6 files: Color/Typography/Spacing/Animation tokens + HyzerBackground + AnimationCoordinator
    Notifications/          NotificationService protocol
  Tests/TestSupport/        Shared test helpers (SPM product): WaitUntil, ValueCollector, 3 mocks
  Tests/HyzerKitTests/      62 test files
HyzerAppTests/              44 test files: ViewModels/, Views/, Integration/, Mocks/, Fixtures/
docs/                       10 generated docs + 8 screenshots + annotated-screens.html
_bmad-output/               BMAD process artifacts: 50 story specs, 9 review-findings files,
                            sprint-status.yaml, deferred-work.md, planning artifacts, retro
_bmad/                      BMAD framework install (config, workflows)
scripts/                    ci-local.sh, test-changed.sh, install-hooks.sh, xcodegen-hook.sh,
                            archive-testflight.sh
.agent .agents .claude .cursor .gemini .opencode .serena .windsurf
                            ~2,200 files of AI-assistant configuration (7 assistants + BMAD skills)
```

**Note the ratio:** ~2,200 files of agent tooling config vs. 233 Swift files. This repo is as much an AI-development harness as an app.

---

## 4. Build, test, lint

| Task | Command |
|---|---|
| Regenerate project (after any `project.yml` edit) | `xcodegen generate` |
| Fast tests (no simulator, the only reliable path) | `swift test --package-path HyzerKit` |
| Full tests | `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=HyzerApp,OS=18.4'` |
| Lint | `swiftlint lint` (also a pre-build script on the `HyzerApp` target) |
| Local CI mirror | `scripts/ci-local.sh [--skip-lint] [--kit-only]` (3 stages: lint → kit tests → app tests) |
| Changed-file tests | `scripts/test-changed.sh [base-branch]` |
| Git hooks (auto-`xcodegen` on checkout/merge) | `scripts/install-hooks.sh` |
| TestFlight archive | `scripts/archive-testflight.sh [--upload]` |

**Environment trap.** The `HyzerApp` destination is a **hand-created paired simulator** (iOS 18.4 iPhone + watchOS 11.4 Watch) that must be installed once locally on macOS 15 + Xcode 26 (`xcodebuild -downloadPlatform iOS -buildVersion 18.4` plus the watchOS equivalent). CI does not have it — the workflow greps for any available iPhone runtime instead, which is how the iOS test job ends up on an iOS 26.x runtime it was never validated against. The `OS=18.4` pin exists because `OS=latest` resolves to iOS 26.x.

**Lint rules that will bite you** (`.swiftlint.yml`): `line_length` error at 160, `function_body_length` error at 100, `file_length` error at 600 (this one broke PR #118 and forced the `ScorecardHoleCardStack` extraction), plus four custom regex rules — `try?` without justification comment, hardcoded `.foregroundStyle(.white/.black)`, hardcoded animation `duration: 0.x`, and unbounded `FetchDescriptor<T>()`.

---

## 5. Architecture

### Layer boundaries (enforced by convention + review, not by tooling)

```
HyzerApp (Views + ViewModels + Live* services)  ─┐
HyzerWatch (Views + WatchConnectivityService)   ─┴──► HyzerKit (Models, Domain, Sync, Design, protocols)
```

- ViewModels receive **individual services**, never the `AppServices` container.
- `AppServices` (`@MainActor @Observable`) is the only place concrete impls are wired. Construction order is documented and load-bearing: `ModelContainer → StandingsEngine → RoundLifecycleManager → CloudKitClient → NetworkMonitor → SyncEngine → SyncScheduler → ScoringService → PhoneConnectivityService → NotificationService`.
- It is injected once via `.environment(appServices)`; it also owns `pendingDeepLink` with an explicit precedence ladder (`discrepancyResolution` 2 > `roundSummary` 1 > `activeRound` 0) so a lower-priority notification tap cannot clobber an unconsumed higher-priority one.

### Protocol seams (9 in HyzerKit, 1 in the app)

`CloudKitClient`, `NetworkMonitor`, `ICloudIdentityProvider`, `NearbyDiscoveryClient`, `NotificationService`, `UserDefaultsStorage`, `WatchConnectivityClient`, `WatchStandingsObservable`, `HeadToHeadServicing`, `VoiceRecognitionServiceProtocol`. **Tests must use these, never the `Live*` implementations.**

### Persistence — two SwiftData stores

| Store | Schema | Sync |
|---|---|---|
| `DomainStore` | `Player`, `Course`, `Hole`, `Round`, `ScoreEvent`, `Discrepancy` | Manual CloudKit **public** DB push/pull |
| `OperationalStore` | `SyncMetadata` | Local-only, never synced, safely deletable |

Both configured with `cloudKitDatabase: .none` — **deliberately disabling SwiftData's built-in mirroring**, because the built-in path only supports the private DB and this app needs the public DB for shared rounds. Forgetting this flag re-enables `NSPersistentCloudKitContainer`, which fails with `CKAccountStatusNoAccount` on any CI simulator and marks `xcodebuild test` FAILED even when all suites pass.

**Three-attempt container recovery** (Amendment A6, in `HyzerApp.makeModelContainer()`): normal → delete + recreate `OperationalStore` → delete both and start fresh. Safe because CloudKit holds the authoritative event history.

**CloudKit model constraints** (apply to every domain model): no `@Attribute(.unique)`, no `@Relationship` (flat FK fields per Amendment A8), every property optional or defaulted, enums stored as `String`.

**Event sourcing:** `ScoreEvent` is append-only and immutable — no update/delete API surface (NFR19). A correction inserts a new event with `supersedesEventID` set. Conflict resolution likewise produces a new authoritative event.

### Sync topology

- **The phone is the sole CloudKit node.** The watch never touches CloudKit.
- Watch → Phone over `WatchConnectivity`: `scoreEvent`, `voiceRequest`.
- Phone → Watch: `standingsUpdate` (a `StandingsSnapshot`), `voiceResult`.
- `SyncEngine` is a `public actor SyncEngine: ModelActor` (546 lines) exposing `start()`, `pushRound(...)`, `pushPending()`, `retryFailed()`, `pullRecords()`, extended by `SyncEngine+Discrepancy` and `SyncEngine+RoundCompletion`.
- `SyncScheduler` (356 lines) drives cadence and CKQuerySubscription registration.
- Nearby round discovery uses MultipeerConnectivity/Bonjour (`_hyzer-rounds._tcp`) behind `NearbyDiscoveryClient`.

### Concurrency

Swift 6 complete strict concurrency. All ViewModels and `AppServices` are `@MainActor`; `SyncEngine` is an actor; no `DispatchQueue` anywhere. All async work is `async/await`.

### Design system (HyzerKit/Design — shared iOS + watchOS)

- `ColorTokens`: **21 static color tokens + 4 `LinearGradient` tokens** (dark-first, `#0A0A0C` base, 4.5:1 contrast target, `UIUserInterfaceStyle = Dark` pinned app-wide).
- `TypographyTokens`: 10 `Font` levels (hero/h1/h2/h2Bold/h3/body/caption/pageTitle/score/scoreMedium/scoreLarge) plus fixed base metrics intended to be wrapped in `@ScaledMetric` at call sites.
- `SpacingTokens`: 8pt grid (`xs` 4 → `xxl` 48), `minimumTouchTarget` 44, `scoringTouchTarget` 52, `voiceTouchTarget` 56, corner-radius tokens.
- `AnimationTokens` + `AnimationCoordinator`: all animation funnels through the coordinator so Reduce Motion degrades to instant.
- `HyzerBackground`: gradient + three radial glows + noise, accessibility-hidden.

Rule, enforced as a bug: **never hardcode a color, font size, spacing value, or animation duration.**

---

## 6. Domain model reference

| Model | Key fields | Notes |
|---|---|---|
| `Player` | `id`, `displayName`, `iCloudRecordName?`, `aliases[]`, `createdAt` | `aliases` feeds `FuzzyNameMatcher` for voice scoring |
| `Course` | `id`, `name`, `holeCount` (18), `isSeeded`, `createdAt` | Seeded set installed on first launch by `CourseSeeder` |
| `Hole` | `id`, `courseID`, `number`, `par` (default 3) | Flat FK to Course |
| `Round` | `id`, `courseID`, `organizerID`, `playerIDs[]`, `guestIDs[]`, `guestNames[]`, `status`, `holeCount`, `createdAt`, `startedAt?`, `completedAt?` | Status is a String: `setup → active → awaitingFinalization → completed`. Lifecycle methods `start()`/`awaitFinalization()`/`complete()` use `precondition` — an illegal transition **crashes**, by design. `guestNames` never syncs; only opaque `guest:<uuid>` IDs do |
| `ScoreEvent` | `id`, `roundID`, `holeNumber`, `playerID`, `strokeCount`, `supersedesEventID?`, `reportedByPlayerID`, `deviceID`, `createdAt` | Immutable. `maxEventsPerRound = 20` is the shared fetch-bound multiplier for all history services |
| `Discrepancy` | `id`, `roundID`, `playerID`, `holeNumber`, `eventID1`, `eventID2`, `status`, `resolvedByEventID?` | `DiscrepancyStatus: String, Codable, Sendable, CaseIterable` |
| `SyncMetadata` | `id`, `recordID`, `recordType`, `syncStatus`, `lastAttempt?` | Operational store only |

`playerID` is polymorphic: a `Player.id` UUID string for registered players, or `guest:<uuid>` for guests. Resolve through `GuestIdentifier` plus the owning `Round`.

---

## 7. Test topology

| Suite | Files | `@Suite` | `@Test` decls | Runner |
|---|---|---|---|---|
| `HyzerKitTests` | 62 | 54 | **446** | `swift test` — no simulator, works everywhere |
| `HyzerAppTests` | 44 | 39 | **305** | `xcodebuild test` — needs a simulator, currently failing in CI |
| `HyzerWatch` | 0 | — | — | **No test target exists** |

Framework is **Swift Testing** (`@Suite`/`@Test`), not XCTest. SwiftData tests use `ModelConfiguration(isStoredInMemoryOnly: true)`.

Shared helpers live in `HyzerKit/Tests/TestSupport/` (an SPM product, Story 15.7): `WaitUntil.swift` (deterministic async-propagation wait — use this instead of `Task.sleep`), `ValueCollector.swift`, `MockNotificationService`, `MockNearbyDiscoveryClient`, `MockWatchConnectivityClient`. New shared helpers belong here.

Integration suites (Story 15.11, PR #113) exist on both sides:
- `HyzerAppTests/Integration/`: `FullRoundLifecycleTests`, `MultiplayerSyncTests`, `ScoreCorrectionDiscrepancyTests`, `WatchPhoneSyncTests`, `HistoryAnalyticsTests`, driven by `IntegrationTestHarness` + `StubCloudKitClient`/`StubICloudIdentityProvider`/`StubNetworkMonitor`.
- `HyzerKitTests/Integration/`: `FullRoundLifecycleKitTests`, `RemoteScoreEventArrivalTests`, `ScoreCorrectionConflictTests`, `VoiceToStandingsIntegrationTests`, via `IntegrationKitHarness`.

`HyzerApp.swift` skips live identity resolution, course seeding, and sync when hosting an xctest bundle (`Self.isHostingTests`) — the real `LiveCloudKitClient` + `SyncScheduler` racing in-memory test contexts previously SIGILL'd the process mid-run.

**Linkage landmine:** `HyzerAppTests` deliberately depends on `product: TestSupport` only, *not* `product: HyzerKit`. HyzerKit arrives transitively through the app host. Adding it explicitly double-links HyzerKit into the test bundle and signal-traps at bootstrap (`Class _TtC8HyzerKit… is implemented in both …`). Do not "fix" that dependency list.

---

## 8. CI/CD — the actual state

Two workflows:

**`.github/workflows/test.yml`** — on PR and push to `main`/`develop`, three jobs on `macos-15`, Xcode 26.2:
1. `SwiftLint` — passing.
2. `HyzerKit Tests (swift test)` — passing.
3. `HyzerApp ViewModel Tests (xcodebuild)` — **failing.** Runs ~12 minutes, then fails inside the `Run HyzerApp tests` step. Ad-hoc signed (`CODE_SIGN_IDENTITY=-`) so the CloudKit entitlement survives; simulator is auto-discovered by a Python inline script that grabs any available iPhone, which lands on iOS 26.x.

**`.github/workflows/bmad-story-sync.yml`** — on issue close, resolves the BMAD output folder and updates story status. Requires `contents: write` + `issues: write`.

### Verified CI history on `main` (push runs)

| Run | Date | Result |
|---|---|---|
| 179 (`089ce8f`, current HEAD) | 2026-07-02 | failure |
| 171, 164, 157, 151, 148, 147, 145, 143, 139, 137 | 2026-05-19 → 2026-07-02 | failure |
| 135 | 2026-05-19 | cancelled |
| 127 | 2026-05-19 | failure — first run after `set -o pipefail` landed |
| 123 and earlier | ≤ 2026-05-19 | "success" — **false greens**: no `pipefail`, so `xcodebuild … \| tee` reported `tee`'s exit code |

**Read that carefully: the iOS test job has never been observed green under honest reporting.** The green runs predate PR #102, which added `set -o pipefail`; before that, a failing `xcodebuild test` piped into `tee` returned 0 and the check passed. Six Wave-1 PRs merged 2026-05-19 under that false green.

Root cause is open, documented in `deferred-work.md`: the HyzerApp test host reports `Early unexpected exit, operation never finished bootstrapping … Test crashed with signal trap before establishing connection` before any test method runs. The earlier duplicate-class cause is confirmed fixed; this is a different crash. Candidates listed: SwiftData/CloudKit container init in the test env, a missing entitlement/Info.plist key under the iOS 26.2 SDK, an Xcode 26.2 Swift runtime issue, or a crash in `HyzerApp.init`/`AppServices` setup. Diagnosis needs the CI `xcresult` artifact (retained 30 days — **the referenced runs' artifacts have long expired**) or a local run on a Mac with a matching runtime.

### Open PRs — all 5 are Renovate, all red

| PR | Title | Opened |
|---|---|---|
| [#115](https://github.com/shotcowboystyle/hyzer-app/pull/115) | update actions/cache to v6 | 2026-06-27 |
| [#114](https://github.com/shotcowboystyle/hyzer-app/pull/114) | update actions/cache digest | 2026-06-27 |
| [#112](https://github.com/shotcowboystyle/hyzer-app/pull/112) | update actions/checkout to v7 | 2026-06-20 |
| [#111](https://github.com/shotcowboystyle/hyzer-app/pull/111) | update actions/checkout digest | 2026-06-06 |
| [#109](https://github.com/shotcowboystyle/hyzer-app/pull/109) | update dependency macos to v26 | 2026-05-23 |

They fail on the same pre-existing app-test job, not on their own changes. Dependency maintenance is fully blocked behind one broken job. Open issues: **zero**.

---

## 9. Process machinery (BMAD)

Work is planned and tracked in `_bmad-output/`:

- **49 story spec files** in `implementation-artifacts/`, named `<epic>-<story>-<slug>.md`, spanning Epics 1–15.
- **`sprint-status.yaml`** — the story ledger. 49 story entries. Statuses: `ready-for-dev`, `in-progress`, `review`, `done`, `blocked-on-human-ops` (a status introduced 2026-05-19 for stories whose remaining work needs Apple credentials, the Apple web UI, or physical hardware; **not eligible for agent pickup**).
- **8 `review-*-findings.md`** files — adversarial code-review output per story.
- **`deferred-work.md`** — the running debt register, appended per code review. Highest-signal document in the repo.
- **Planning artifacts**: `prd.md`, `architecture.md`, `epics.md`, `epics-post-mvp.md`, `ux-design-specification.md`, `implementation-readiness-report-2026-05-13.md`, `product-brief-…`, `prd-validation-report.md`.
- **Retro**: `epics-1-8-retro-2026-04-07.md`.

### Current story state (from `sprint-status.yaml`)

Epics 1–14: all `done`. Epic 15 (pre-launch hardening):

| Story | Status |
|---|---|
| 15.1 APS production flip / ASC privacy | done |
| **15.2 Canonical test baseline validation** | **blocked-on-human-ops** — this is the red-CI story |
| **15.3 Story 14.2 signature ship-gate verification** | **blocked-on-human-ops** — needs simulator + human eyes |
| **15.4 On-device history-services performance** | **ready-for-dev** — needs a physical iPhone 12+ |
| **15.5 Launch screen polish** | **blocked-on-human-ops** |
| 15.6–15.10 | done |
| 15.11 ViewModel integration test suite | **merged in `8f840d4` / PR #113 but absent from the ledger** |

So: three of Epic 15's stories are parked on human/hardware dependencies, one needs hardware nobody has supplied, and the ledger is one story behind reality. Nothing has moved in two months.

### Frozen Artifact Policy (read before editing any planning doc)

Retrospectives, PRDs, epic narratives, the planning `architecture.md`, and one-off planning reports are **append-only**. When you find an outdated claim: append one italicized annotation beneath it — `_Resolved by Story X.Y — <summary>. (Story <cleanup-story>, YYYY-MM-DD)_` — and **do not rewrite the original**. If you find an in-place rewrite that bypassed annotation, restore the original from git history and annotate instead. Story files and `sprint-status.yaml` are *not* frozen; they are live status records. Rationale: preserve the decision audit trail (same convention as IETF RFCs / PEPs / JEPs).

---

## 10. Documentation-vs-reality drift (verified)

These are the traps. Each was checked against the tree or the GitHub API on 2026-09-03.

1. **`CLAUDE.md`: "Branch protection enforces Git Flow… Direct push to `main` or `develop` is blocked."** False on both halves. The GitHub API reports `main` as `protected: false`, and **no `develop` branch exists** — while `test.yml` triggers on `[main, develop]`. Live branch names (`renovate/*`, `claude/*`) do not match the documented `feature/|release/|hotfix/` scheme either. Either restore the protection rules or delete the claim; right now it reads as a control that does not exist.
2. **`CLAUDE.md`: "GitHub issues (via `github-issue-map.json`) are the source of truth for story completion status."** The map holds **23 entries, Epics 1–8 only**, and the repo has **zero open issues**. Stories 9.x–15.x were never issue-mapped. `sprint-status.yaml` is the real source of truth — and it is edited by the `bmad-story-sync` workflow that fires on issue close, a path that no longer receives events.
3. **`sprint-status.yaml` is malformed.** Three story keys are literally `\"10.1\"`, `\"10.2\"`, `\"11.1\"` — backslash-escaped quotes inside a YAML file, so a parser yields the keys `\"10.1\"` etc. instead of `10.1`. Any tooling that looks up `10.1` misses those three stories. Fix is mechanical.
4. **Story 15.11 is missing from `sprint-status.yaml`** despite being merged (`8f840d4`, PR #113) and having added the entire integration-test layer.
5. **`CLAUDE.md` test baseline (432 HyzerKit tests) is stale.** Static count is 446 `@Test` declarations, matching PR #118's own commit message ("446 total, +4"). The doc was not updated with that commit.
6. **`CLAUDE.md`: "`ColorTokens` — 11 named colors" and "`TypographyTokens` — 8 levels."** Post-#118 reality: 21 color tokens + 4 gradients, 10 font levels + 6 base-size metrics.
7. **`docs/index.md` "Codebase at a Glance" is materially wrong**: it claims ~88 source files (actual 122), 407 tests across 39 files (actual 446 + 305 across 106 files), 10 iOS ViewModels (actual 14), ~25 iOS views (actual 31), 6 service implementations (actual 8).
8. **`docs/index.md`'s table omits three docs that exist**: `knowledgebase.md`, `hardware-test-plan.md`, `project-scan-report.json`.
9. **Generated-artifact policy is inconsistent.** `HyzerApp/App/Info.plist` is gitignored because XcodeGen owns it — correct. But `HyzerApp.xcodeproj/project.pbxproj`, generated by the same tool from the same spec, **is tracked**, and PR #118 carried a 20-line pbxproj diff. Pick one rule; tracking a generated pbxproj is a standing merge-conflict generator.
10. **The dominant iOS ViewModel test suite has no verified passing run.** `CLAUDE.md` states this honestly ("not verifiable in the current build environment"), but the framing suggests an environment quirk. The observable fact is stronger: 305 test declarations whose last 13 CI attempts all failed, with the pre-`pipefail` greens being artifacts of a broken exit-code pipeline.

---

## 11. Known technical debt (from `CLAUDE.md` + `deferred-work.md`)

**Resolved since the Epics 1–8 retro:** shared test helpers consolidated into `TestSupport` (15.7); `waitUntil` deterministic wait helper (15.8); history-service constants centralized (15.10).

**Still open, code-level:**
- `ShareSheetRepresentable` duplicated across two History views — extract.
- `ConflictResult` lacks `Equatable`.
- `SyncScheduler` reads `UserDefaults.standard` directly (a `UserDefaultsStorage` protocol exists — use it).
- DTO stubs `CourseRecord` / `PlayerRecord` / `RoundRecord` are identity-only.
- `RoundSignature` palette includes `backgroundTertiary` at **1.21:1** contrast against `backgroundElevated` — a real WCAG AA failure affecting ~37.5% of generated signatures. Three remediation options are written up in `deferred-work.md`; the recommended one is dropping to a 7-color palette.
- `#Predicate { ids.contains($0.id) }` with large ID sets across `PlayerTrendService` / `PersonalBestService` / `HeadToHeadService` may hit SQLite `IN`-clause limits and/or fall back to in-memory filtering; `fetchLimit` is applied *before* the predicate. `PersonalBestService`'s `maxRounds * 20` ScoreEvent bound under-counts multi-course users (10 courses × 60 rounds × 18 holes = 10,800 events vs. a 10,000 cap) and silently drops the oldest events.
- No `Task.isCancelled` checks in the per-round loops of the history services.
- `StandingsEngine.recompute` failure is indistinguishable from "player not in round" (both yield empty standings) and is unlogged — a transient SwiftData error silently demotes a personal best.
- CloudKit push paths have no partial-failure / quota / rate-limit backoff; non-network errors are marked `.failed` with no retry. Stale `.inFlight` detection logs but proceeds.
- `SyncScheduler` does not re-register CKQuerySubscriptions on iCloud identity change (sign-out/sign-in leaves stale predicates).
- DTO `init(from: CKRecord)` reads Int fields directly with no `NSNumber` fallback.
- Stacked `fullScreenCover` modifiers in `HomeView` depend on undocumented SwiftUI ordering; deep-link consumption can race an unhydrated `@Query`.
- Test-only ViewModel initializers are gated by doc comment rather than access control or `#if DEBUG`.

---

## 12. If you are picking this up cold

The app is feature-complete through Epic 14 with a large, structured test suite and clean layering. It is blocked by exactly one thing, and everything else is downstream of it:

1. **Get the `HyzerApp ViewModel Tests` job green.** Reproduce locally on a Mac with the paired `HyzerApp` (iOS 18.4) simulator; if it passes locally, the delta is the runtime version CI picks. The cheapest structural fix is to stop auto-discovering "any iPhone" in CI and pin the runtime the project actually targets — install the iOS 18.x runtime on the runner, or move the deployment target to a runtime `macos-15` ships. Until this is green, 305 tests are decorative, the five Renovate PRs cannot merge, and Story 15.2 stays parked.
2. **Fix the ledger** — the three escaped-quote keys, and add 15.11.
3. **Reconcile or delete the false claims in `CLAUDE.md`** (branch protection, issue-based story tracking, token counts, test baseline) and regenerate `docs/index.md`'s metrics. An AI-heavy workflow makes stale context expensive: seven assistants read those files as ground truth.
4. **Close the WCAG failure in `RoundSignature`** — it is a known, quantified, user-visible defect with a written fix.
5. Then Epic 15's human-ops stories (15.3, 15.4, 15.5) need a human with a device and Apple credentials. No amount of agent work advances them.
