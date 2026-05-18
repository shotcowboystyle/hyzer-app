# Story 13.3: Head-to-Head Record Between Two Players

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user with a long-time rival in the group,
I want to see our head-to-head record across all rounds we've played together,
so that I can settle competitive debates with data.

## Acceptance Criteria

1. **Given** two REGISTERED players (`playerID` is a UUID string, NOT prefixed `"guest:"`) have at least one `.completed` round in common (both players appear in `Round.playerIDs` AND both have at least one resolved `ScoreEvent` for that round), **when** the user taps "Compare" on `PlayerHoleBreakdownView`, picks the second player from the opponent picker sheet, and the head-to-head view appears, **then** the view renders exactly four data elements (PMVP-FR16):
   - **Rounds played together** — total count of `.completed` rounds where both players have `holesPlayed > 0`.
   - **Wins for player A** — count of shared rounds where `standingA.totalStrokes < standingB.totalStrokes`, plus a percentage formatted via `NumberFormatter` with `numberStyle = .percent` and `maximumFractionDigits = 0` (e.g. `"43%"`). Percentage denominator is `roundsPlayedTogether`.
   - **Wins for player B** — same shape as A's wins. Note: `winsA + winsB + ties == roundsPlayedTogether` (ties exist when `totalStrokes` are equal — counted as neither side's win).
   - **Average score differential** — mean of `(standingA.scoreRelativeToPar - standingB.scoreRelativeToPar)` across all shared rounds where both `holesPlayed > 0`. Display formatted via `Standing.formatScore(_:)` after rounding to nearest integer (`Int(diff.rounded())`), e.g. `-2` (A averages 2 strokes better), `E` (dead even), `+1` (A averages 1 stroke worse). Same convention as `PlayerTrendViewModel.averageFormattedScore`.

2. **Given** the head-to-head query for two players, **when** the service executes, **then** the SwiftData fetch pipeline uses an explicit `fetchLimit` on every `FetchDescriptor` (PMVP-FR16, CLAUDE.md "Bounded queries"). The implementation MUST mirror the proven two-step bounded pattern from `PlayerTrendService.computeTrend` (`HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift:52-124`) and `PersonalBestService.computeBest` (`HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift:54-132`):
   - (a) Fetch `ScoreEvent` rows where `playerID == playerA` → derive participant-A round IDs (bounded `fetchLimit = maxRounds * 20`, sorted `\.createdAt` descending).
   - (b) Fetch `ScoreEvent` rows where `playerID == playerB` → derive participant-B round IDs (same bounded fetch shape).
   - (c) Intersect the two participant sets in memory → `sharedRoundIDs`.
   - (d) Fetch `Round` rows where `sharedRoundIDs.contains($0.id) && $0.status == "completed"` (bounded `fetchLimit = maxRounds`, sorted `\.completedAt` descending so truncation retains most-recent rounds).
   - **Do NOT** attempt `#Predicate { $0.playerIDs.contains(playerAID) && $0.playerIDs.contains(playerBID) }` against `Round.playerIDs`. SwiftData's `#Predicate` translation of `Array<String>.contains(String)` against a stored model field is unreliable across iOS 18 minor versions (this was the dropped path during Story 13.1's design — see `deferred-work.md:5` `participantRoundIDs.contains($0.id)` note). The intersection-of-event-sets approach uses only the bounded-array contains direction that ScoreEvent/Round fetches already prove out.

3. **Given** two REGISTERED players have zero `.completed` rounds in common, **when** the head-to-head view is presented for that pair, **then** an empty state is rendered with the exact copy `"<PlayerA> and <PlayerB> haven't played a round together yet."` in `TypographyTokens.body` / `Color.textSecondary` on `Color.backgroundPrimary`. No skeleton, no placeholder numbers, no icons, no retry button. This is the **off-course warm register** per UX-PMVP-DR5 (PMVP-FR16).

4. **Given** the user is viewing `PlayerHoleBreakdownView` for a player whose `playerID` is prefixed `"guest:"` (round-scoped guest per FR12b — `GuestIdentifier.isGuest(playerID) == true`), **when** the view renders, **then** the "Compare" navigation/button row is NOT rendered at all (not visible, not focusable by VoiceOver, not in the accessibility tree). The "View score trend" row continues to render unchanged. Rationale: guests have no persistent identity across rounds, so a head-to-head record across rounds is undefined for them. (PMVP-FR16 AC #3.)

5. **Given** the user taps "Compare" on `PlayerHoleBreakdownView` for a REGISTERED player (let this be "player A"), **when** the opponent picker sheet appears, **then** the picker lists every REGISTERED player who has at least one `.completed` round in common with player A, **excluding** player A themselves and **excluding** all guests. Each row shows the candidate's `Player.displayName` and a secondary label `"<n> rounds together"` where `n >= 1` (singular `"1 round together"` when exactly 1). Rows are sorted ascending by `displayName` (case-insensitive). If the candidate list is empty (player A has never played a `.completed` round with another registered player), the sheet renders the exact empty-state copy `"No one to compare with yet. Play a round with someone else first."` and no list rows.

6. **Given** the head-to-head query is executed, **when** the implementation derives per-round standings for each shared round, **then** a **fresh** `StandingsEngine` is constructed on every loop iteration (the same regression guard Story 13.1 patch P2 / Story 13.2 Task 1.2 step 2 established). Sharing one engine across iterations leaks `currentStandings` from a previous successful round into iterations where `recompute(for:trigger:)` errored internally — for H2H this would silently corrupt BOTH winner counts AND the average differential.

7. **Given** the implementation has computed shared-round standings, **when** any single shared round produces `standingA == nil`, `standingB == nil`, `standingA.holesPlayed == 0`, or `standingB.holesPlayed == 0`, **then** that round is **skipped entirely** — it does NOT contribute to `roundsPlayedTogether`, `winsA`, `winsB`, or `averageDifferential`. This is the same `holesPlayed > 0` skip guard `PlayerTrendService.swift:104-107` and `PersonalBestService.swift:109-113` apply. Documented rationale: a round where one player participated but produced no resolved score (all events superseded, aborted partial scoring) is not a meaningful head-to-head data point.

8. **Given** the view loads while the user has a slow SwiftData store (or any throw from `computeRecord(...)`), **when** `compute()` fails, **then** the view renders the same empty-state copy as AC #3 (UX-PMVP-DR5 reflective register — do NOT present a scary error). The error is logged via `Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "HeadToHeadViewModel")` for engineering visibility. The accessibility label MUST match the visible empty state (no sighted/VoiceOver mismatch — same fix Story 13.2 patch enforced for `PersonalBestCardView`).

9. **Given** any VoiceOver user navigates to a populated head-to-head view, **when** the view's primary metrics container receives focus, **then** a single `.accessibilityElement(children: .combine)` reads the entire summary in one statement: `"Head-to-head, <PlayerA> versus <PlayerB>. <n> rounds played. <PlayerA> wins <winsA>, <percentA> percent. <PlayerB> wins <winsB>, <percentB> percent. Average differential <formattedDiff>."`. Empty state reads as `"<PlayerA> and <PlayerB> haven't played a round together yet."` exactly.

## Tasks / Subtasks

- [x] Task 1: Add `HeadToHeadService` and value types in HyzerKit (AC: 1, 2, 6, 7)
  - [x] 1.1 Create `HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift` as a `@MainActor` `final class` (matches `StandingsEngine`, `PlayerTrendService`, and `PersonalBestService` isolation — all consume the main-actor `ModelContext`). Expose:
    ```swift
    /// Aggregated head-to-head record across all completed rounds two players share.
    /// Derived, never persisted. Value-type pattern mirrors `Standing`, `TrendSummary`, `PersonalBest`.
    public struct HeadToHeadRecord: Sendable, Equatable {
        public let playerAID: String
        public let playerBID: String
        public let roundsPlayedTogether: Int
        /// Wins counted when `standingA.totalStrokes < standingB.totalStrokes`. Ties contribute to neither side.
        public let winsA: Int
        public let winsB: Int
        public let ties: Int
        /// Mean of `(standingA.scoreRelativeToPar - standingB.scoreRelativeToPar)` across shared rounds where
        /// both players have `holesPlayed > 0`. `nil` when `roundsPlayedTogether == 0`.
        public let averageDifferential: Double?
    }

    /// A potential opponent for player A in the head-to-head picker.
    /// `playerID` is always a registered Player UUID string (never `"guest:<uuid>"`).
    public struct HeadToHeadCandidate: Sendable, Equatable, Identifiable {
        public let playerID: String
        public let playerName: String
        public let roundsTogether: Int
        public var id: String { playerID }
    }

    @MainActor
    public final class HeadToHeadService {
        public init(modelContext: ModelContext)

        /// Computes the head-to-head record between `playerAID` and `playerBID`.
        /// Returns a record with all-zero counts and `averageDifferential == nil` if they have no shared completed rounds.
        public func computeRecord(
            for playerAID: String,
            against playerBID: String,
            maxRounds: Int = 500
        ) throws -> HeadToHeadRecord

        /// Returns every REGISTERED player who has at least one `.completed` round with `playerAID`.
        /// Excludes `playerAID` itself and all guests (`GuestIdentifier.isGuest` filter).
        /// Sorted ascending by `playerName` (case-insensitive). Empty array when no candidates.
        public func findOpponentCandidates(
            for playerAID: String,
            maxRounds: Int = 500
        ) throws -> [HeadToHeadCandidate]
    }
    ```
    `HeadToHeadRecord` and `HeadToHeadCandidate` MUST be value types — both are derived, never persisted. Same pattern as `Standing`, `TrendPoint`/`TrendSummary`, `PersonalBest`. Public API surface is exactly these two methods plus the two value types — no other entry points.

  - [x] 1.2 `computeRecord(for:against:maxRounds:)` implementation outline (mirrors the two-step bounded fetch pattern, adapted for two players):
    1. Bounded ScoreEvent fetch for player A — `fetchLimit = maxRounds * 20`, sorted `\.createdAt` descending so truncation keeps most-recent events. Wrap in `do/catch` with `logger.error(...); throw error` (CLAUDE.md "No silent `try?`").
       ```swift
       let playerAIDLocal = playerAID
       let playerBIDLocal = playerBID

       var eventsADesc = FetchDescriptor<ScoreEvent>(
           predicate: #Predicate { $0.playerID == playerAIDLocal },
           sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
       )
       eventsADesc.fetchLimit = maxRounds * 20
       let eventsA: [ScoreEvent]
       do {
           eventsA = try modelContext.fetch(eventsADesc)
       } catch {
           logger.error("HeadToHeadService: ScoreEvent fetch failed for player A \(playerAID): \(error)")
           throw error
       }
       ```
    2. Same shape for player B, with its own `do/catch` block. Two separate fetches — do NOT attempt a single `playerID == playerAIDLocal || playerID == playerBIDLocal` predicate (the post-fetch intersection step depends on having two clean sets).
    3. Derive `sharedRoundIDs` by intersecting the two participant-id sets:
       ```swift
       let roundIDsA = Set(eventsA.map(\.roundID))
       let roundIDsB = Set(eventsB.map(\.roundID))
       let sharedRoundIDs = Array(roundIDsA.intersection(roundIDsB))
       guard !sharedRoundIDs.isEmpty else {
           return HeadToHeadRecord(
               playerAID: playerAID,
               playerBID: playerBID,
               roundsPlayedTogether: 0,
               winsA: 0, winsB: 0, ties: 0,
               averageDifferential: nil
           )
       }
       ```
       Use `Set.intersection` (O(min(m,n))) — NOT nested `.contains` (O(m*n)). The two ScoreEvent fetches are already bounded so the cardinality of each set is bounded by `maxRounds * 20`.
    4. Bounded Round fetch on the intersection:
       ```swift
       var roundDesc = FetchDescriptor<Round>(
           predicate: #Predicate { sharedRoundIDs.contains($0.id) && $0.status == "completed" },
           sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
       )
       roundDesc.fetchLimit = maxRounds
       let rounds: [Round]
       do {
           rounds = try modelContext.fetch(roundDesc)
       } catch {
           logger.error("HeadToHeadService: Round fetch failed for pair (\(playerAID), \(playerBID)): \(error)")
           throw error
       }
       ```
       Note `sharedRoundIDs.contains($0.id)` — same supported predicate direction as `PlayerTrendService.swift:80` and `PersonalBestService.swift:84`. This is the proven path; DO NOT switch to the unsupported `Array<String>.contains(value)` against the stored model `playerIDs` field.
    5. Per-round aggregation with a **fresh** `StandingsEngine` per iteration (Task 6 / AC #6):
       ```swift
       var winsA = 0
       var winsB = 0
       var ties = 0
       var diffs: [Int] = []
       diffs.reserveCapacity(rounds.count)

       for round in rounds {
           // Fresh engine per round — sharing one engine leaks stale currentStandings on
           // recompute failure. See PlayerTrendService.swift:97-103 and Story 13.2 Dev Notes.
           let engine = StandingsEngine(modelContext: modelContext)
           engine.recompute(for: round.id, trigger: .localScore)

           guard let standingA = engine.currentStandings.first(where: { $0.playerID == playerAIDLocal }),
                 standingA.holesPlayed > 0,
                 let standingB = engine.currentStandings.first(where: { $0.playerID == playerBIDLocal }),
                 standingB.holesPlayed > 0 else {
               // Round skipped — at least one player has no resolved score (AC #7).
               continue
           }

           if standingA.totalStrokes < standingB.totalStrokes {
               winsA += 1
           } else if standingB.totalStrokes < standingA.totalStrokes {
               winsB += 1
           } else {
               ties += 1
           }
           diffs.append(standingA.scoreRelativeToPar - standingB.scoreRelativeToPar)
       }
       ```
    6. Build the result:
       ```swift
       let roundsPlayedTogether = winsA + winsB + ties
       let average: Double? = diffs.isEmpty ? nil : Double(diffs.reduce(0, +)) / Double(diffs.count)

       return HeadToHeadRecord(
           playerAID: playerAID,
           playerBID: playerBID,
           roundsPlayedTogether: roundsPlayedTogether,
           winsA: winsA,
           winsB: winsB,
           ties: ties,
           averageDifferential: average
       )
       ```
       Note the invariant `winsA + winsB + ties == roundsPlayedTogether == diffs.count` — pin this in a test (Task 6.3 `test_computeRecord_winsPlusTiesEqualsRoundsPlayed`).

  - [x] 1.3 `findOpponentCandidates(for:maxRounds:)` implementation outline (different fetch shape — one player only, with a Player join):
    1. Bounded ScoreEvent fetch for player A (same shape as Step 1.2 step 1).
    2. Derive `roundIDsA = Array(Set(eventsA.map(\.roundID)))`. Early-return `[]` if empty.
    3. Bounded `.completed` Round fetch where `roundIDsA.contains($0.id)`:
       ```swift
       var roundDesc = FetchDescriptor<Round>(
           predicate: #Predicate { roundIDsA.contains($0.id) && $0.status == "completed" },
           sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
       )
       roundDesc.fetchLimit = maxRounds
       let rounds = try modelContext.fetch(roundDesc)
       ```
       Wrap in `do/catch` with `logger.error`. Same pattern.
    4. Collect peer IDs from `Round.playerIDs`:
       ```swift
       var peerCounts: [String: Int] = [:]
       for round in rounds {
           for peerID in round.playerIDs where peerID != playerAIDLocal && !GuestIdentifier.isGuest(peerID) {
               peerCounts[peerID, default: 0] += 1
           }
       }
       guard !peerCounts.isEmpty else { return [] }
       ```
       `GuestIdentifier.isGuest(_:)` (`HyzerKit/Sources/HyzerKit/Domain/GuestIdentifier.swift:24-26`) filters round-scoped guests — they have no cross-round identity and are explicitly out of scope (AC #4, AC #5).
    5. Resolve peer `Player.displayName` via a bounded fetch:
       ```swift
       let peerIDStrings = Array(peerCounts.keys)
       let peerUUIDs = peerIDStrings.compactMap(UUID.init)  // skip malformed strings defensively
       var playerDesc = FetchDescriptor<Player>(
           predicate: #Predicate { peerUUIDs.contains($0.id) }
       )
       playerDesc.fetchLimit = peerUUIDs.count  // bounded by peerCounts size (max ≈ playerIDs across maxRounds rounds)
       let players = try modelContext.fetch(playerDesc)
       ```
       Wrap in `do/catch`. `fetchLimit` is bounded by the number of distinct peer IDs (in turn bounded by `maxRounds * playersPerRound`).
    6. Build candidate list, drop any peer for whom no `Player` row was found (orphan ID — defensive but rare):
       ```swift
       let nameByID = Dictionary(uniqueKeysWithValues: players.map { ($0.id.uuidString, $0.displayName) })
       var candidates: [HeadToHeadCandidate] = []
       for (peerID, count) in peerCounts {
           guard let name = nameByID[peerID] else { continue }  // orphan peer ID, skip
           candidates.append(HeadToHeadCandidate(playerID: peerID, playerName: name, roundsTogether: count))
       }
       candidates.sort { $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending }
       return candidates
       ```
       `localizedCaseInsensitiveCompare` matches the existing project sort convention (used in `ScorecardContainerView.swift:355`). No `localizedStandardCompare` — that one also adds numeric collation that is irrelevant here.

  - [x] 1.4 Concurrency: `@MainActor`, synchronous `throws` API. No `actor`, no `DispatchQueue`, no `Task.sleep`. Swift 6 strict concurrency is enabled project-wide (`project.yml:17`).

  - [x] 1.5 No data-model changes. No CloudKit DTO changes. No migrations. No new SwiftData models. Pure read-side derivation over existing `Round`, `ScoreEvent`, `Player`, and `Hole` (par resolved transitively via `StandingsEngine`).

  - [x] 1.6 Logging: `private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "HeadToHeadService")`. Every `try modelContext.fetch(...)` is wrapped in `do/catch` with `logger.error` and rethrow. No silent `try?` anywhere in this file. **Additionally:** when the per-round loop skips a round because `standingA == nil || standingA.holesPlayed == 0 || standingB == nil || standingB.holesPlayed == 0`, emit a `logger.notice("HeadToHeadService: round \(round.id) skipped — no resolved score for one or both players")`. This addresses the deferred-work concern at `deferred-work.md:5` ("No PersonalBestService-level logging when StandingsEngine.recompute silently fails") — apply the same observability discipline here from the start.

  - [x] 1.7 Doc-comment on `computeRecord(for:against:)` MUST state the tie semantics, the differential sign convention, and the holesPlayed > 0 skip guard explicitly:
    > "Wins for A" are counted when `standingA.totalStrokes < standingB.totalStrokes`. Tied totalStrokes contribute to `ties` and to neither side's win count, but DO contribute one round to `roundsPlayedTogether` and one sample to `averageDifferential`. The differential is signed: a NEGATIVE `averageDifferential` means player A averages a LOWER (better) score relative to par than player B. Rounds where either player has `holesPlayed == 0` are skipped entirely (do not affect any output count).

- [x] Task 2: Add `HeadToHeadViewModel` in HyzerApp (AC: 1, 3, 8, 9)
  - [x] 2.1 Create `HyzerApp/ViewModels/HeadToHeadViewModel.swift` as `@MainActor @Observable final class`. Same shape as `PersonalBestViewModel` (`HyzerApp/ViewModels/PersonalBestViewModel.swift:10-12`) and `PlayerTrendViewModel` (`HyzerApp/ViewModels/PlayerTrendViewModel.swift:10-12`).

  - [x] 2.2 Required public surface:
    ```swift
    @MainActor
    @Observable
    final class HeadToHeadViewModel {
        let playerAID: String
        let playerAName: String
        let playerBID: String
        let playerBName: String

        private(set) var record: HeadToHeadRecord?
        private(set) var errorMessage: String?
        private(set) var hasComputed: Bool = false

        var isLoading: Bool { !hasComputed && errorMessage == nil }
        var hasNoData: Bool {
            // Empty state covers both the "no shared rounds" case AND the error fallback (AC #8).
            hasComputed && (errorMessage != nil || (record?.roundsPlayedTogether ?? 0) == 0)
        }
        var hasData: Bool { hasComputed && errorMessage == nil && (record?.roundsPlayedTogether ?? 0) > 0 }

        var roundsPlayedFormatted: String? {
            guard let r = record, r.roundsPlayedTogether > 0 else { return nil }
            return r.roundsPlayedTogether == 1 ? "1 round" : "\(r.roundsPlayedTogether) rounds"
        }
        var winsAFormatted: String? { record.map { "\($0.winsA)" } }
        var winsBFormatted: String? { record.map { "\($0.winsB)" } }
        var winsAPercentFormatted: String? { percentString(numerator: record?.winsA, denominator: record?.roundsPlayedTogether) }
        var winsBPercentFormatted: String? { percentString(numerator: record?.winsB, denominator: record?.roundsPlayedTogether) }

        /// Average differential displayed via `Standing.formatScore(_:)` after rounding (AC #1).
        var averageDifferentialFormatted: String? {
            guard let avg = record?.averageDifferential else { return nil }
            return Standing.formatScore(Int(avg.rounded()))
        }

        /// VoiceOver summary (AC #9). Empty state reads as the AC #3 copy verbatim.
        var accessibilityLabel: String {
            if isLoading { return "Head-to-head loading." }
            if hasData,
               let record,
               let rounds = roundsPlayedFormatted,
               let winsA = winsAFormatted, let pctA = winsAPercentFormatted,
               let winsB = winsBFormatted, let pctB = winsBPercentFormatted,
               let diff = averageDifferentialFormatted
            {
                return "Head-to-head, \(playerAName) versus \(playerBName). \(rounds) played. \(playerAName) wins \(winsA), \(pctA). \(playerBName) wins \(winsB), \(pctB). Average differential \(diff)."
            }
            // hasNoData branch — error path collapses to no-data copy per AC #8.
            return "\(playerAName) and \(playerBName) haven't played a round together yet."
        }

        init(modelContext: ModelContext,
             playerAID: String, playerAName: String,
             playerBID: String, playerBName: String)

        /// Testing injection initializer. NOT used in production. Wired to at least one test
        /// (`test_viewModel_serviceErrorPath_collapsesToNoData`) so it is not dead code.
        init(service: HeadToHeadService,
             playerAID: String, playerAName: String,
             playerBID: String, playerBName: String)

        func compute() async
    }
    ```
    Reuse `Standing.formatScore(_:)` (`HyzerKit/Sources/HyzerKit/Domain/Standing+Formatting.swift:11-15`) for the differential — do NOT redefine the `-2`/`E`/`+1` convention. Same anti-duplication rule that Stories 13.1 and 13.2 enforced.

  - [x] 2.3 Percent formatter is a `private static let`:
    ```swift
    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    private func percentString(numerator: Int?, denominator: Int?) -> String? {
        guard let n = numerator, let d = denominator, d > 0 else { return nil }
        let fraction = Double(n) / Double(d)
        return Self.percentFormatter.string(from: NSNumber(value: fraction))
    }
    ```
    Allocating `NumberFormatter` is non-trivial (`~10ms` first call per Apple docs); amortize via `static let`. Same allocation pattern as `PersonalBestViewModel.dateFormatter`.

  - [x] 2.4 `compute()` is `async` so the View's first paint renders `isLoading` before the SwiftData pass begins (Story 13.1 review patch D3 / Story 13.2 Task 2.4):
    ```swift
    func compute() async {
        do {
            record = try service.computeRecord(for: playerAID, against: playerBID)
            hasComputed = true
        } catch {
            logger.error("HeadToHeadViewModel.compute failed for pair (\(playerAID), \(playerBID)): \(error)")
            errorMessage = "Unable to load head-to-head record."
            hasComputed = true
        }
    }
    ```
    The service is `@MainActor` so the work still happens on the main actor — the async boundary defers it past first paint, not off-main. Off-main work would require a background `ModelContext` and is out of scope.

  - [x] 2.5 No analytics, no `@AppStorage`, no `UserDefaults`. Pure read-only projection of one `(playerAID, playerBID)` pair.

- [x] Task 3: Add `HeadToHeadOpponentPickerViewModel` in HyzerApp (AC: 5)
  - [x] 3.1 Create `HyzerApp/ViewModels/HeadToHeadOpponentPickerViewModel.swift` as `@MainActor @Observable final class`. The picker has different state than the H2H view (a list of candidates instead of a single record), so a separate VM is cleaner than overloading `HeadToHeadViewModel`.

  - [x] 3.2 Required public surface:
    ```swift
    @MainActor
    @Observable
    final class HeadToHeadOpponentPickerViewModel {
        let playerAID: String

        private(set) var candidates: [HeadToHeadCandidate] = []
        private(set) var errorMessage: String?
        private(set) var hasComputed: Bool = false

        var isLoading: Bool { !hasComputed && errorMessage == nil }
        var hasNoCandidates: Bool { hasComputed && candidates.isEmpty && errorMessage == nil }
        var hasError: Bool { errorMessage != nil }

        init(modelContext: ModelContext, playerAID: String)
        init(service: HeadToHeadService, playerAID: String)  // testing

        func loadCandidates() async
    }
    ```
    `loadCandidates()` follows the same `async` shape — wraps `service.findOpponentCandidates(for: playerAID)` in `do/catch` and assigns `errorMessage = "Unable to load opponents."` on failure. Mirror `compute()` from Task 2.4.

  - [x] 3.3 Secondary-label helper for the picker view:
    ```swift
    static func roundsTogetherCopy(_ count: Int) -> String {
        count == 1 ? "1 round together" : "\(count) rounds together"
    }
    ```
    Static so the picker view can use it without keeping a VM reference per row.

- [x] Task 4: Add `HeadToHeadOpponentPickerSheet` and `HeadToHeadView` (AC: 1, 3, 5, 8, 9)
  - [x] 4.1 Create `HyzerApp/Views/History/HeadToHeadView.swift`. Lives in `Views/History/` (NOT `Views/Components/`) because it's only reachable from the History flow and has no second consumer surface — unlike `PersonalBestCardView` which lives in `Views/Components/` because it's used by BOTH `CourseDetailView` and `PlayerHoleBreakdownView`. Single-consumer = History-scoped per established project pattern (`PlayerTrendView.swift` lives in `Views/History/` for the same reason).

  - [x] 4.2 `HeadToHeadView` body matches the `PlayerTrendView` shape (`HyzerApp/Views/History/PlayerTrendView.swift:11-52`):
    ```swift
    struct HeadToHeadView: View {
        let playerAID: String
        let playerAName: String
        let playerBID: String
        let playerBName: String

        @Environment(\.modelContext) private var modelContext
        @State private var viewModel: HeadToHeadViewModel?

        var body: some View {
            Group {
                if let vm = viewModel {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.hasNoData {
                        emptyState
                    } else {
                        populatedContent(vm: vm)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Head-to-Head")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(playerAID)|\(playerBID)") {
                let vm = HeadToHeadViewModel(
                    modelContext: modelContext,
                    playerAID: playerAID, playerAName: playerAName,
                    playerBID: playerBID, playerBName: playerBName
                )
                viewModel = vm
                await vm.compute()
            }
        }

        private var emptyState: some View {
            Text("\(playerAName) and \(playerBName) haven't played a round together yet.")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel?.accessibilityLabel ?? "")
        }
    }
    ```
    Use `.task(id: "\(playerAID)|\(playerBID)")` (not `.onAppear { guard viewModel == nil ... }`) so SwiftUI re-runs compute if the user pops back to the picker and chooses a different opponent within the same navigation stack (`HeadToHeadView` identity could be reused). This is the same fix Story 13.2 patch applied to `PersonalBestCardView`. Empty-state copy is verbatim AC #3.

  - [x] 4.3 `populatedContent(vm:)` renders the four data elements from AC #1. Layout (off-course warm register per UX-PMVP-DR5 — `Color.backgroundPrimary` page, `Color.backgroundElevated` card, 3-tier score colors only, no animations beyond `AnimationTokens.springGentle`):
    ```swift
    private func populatedContent(vm: HeadToHeadViewModel) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xl) {
                headerSection(vm: vm)
                roundsCountSection(vm: vm)
                winsRowSection(vm: vm)
                differentialSection(vm: vm)
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(vm.accessibilityLabel)
    }
    ```
    Single `.accessibilityElement(children: .combine)` at the ScrollView level (AC #9). Subviews should each set `.accessibilityHidden(true)` so VoiceOver does NOT redundantly read the per-stat children when the combined label already says everything.

  - [x] 4.4 `headerSection(vm:)` — player names side-by-side with a "vs" separator:
    ```swift
    private func headerSection(vm: HeadToHeadViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text("\(vm.playerAName) vs \(vm.playerBName)")
                .font(TypographyTokens.h1)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
        }
        .accessibilityHidden(true)
    }
    ```

  - [x] 4.5 `roundsCountSection(vm:)` — single centered metric:
    ```swift
    private func roundsCountSection(vm: HeadToHeadViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(vm.roundsPlayedFormatted ?? "—")
                .font(TypographyTokens.score)
                .foregroundStyle(Color.textPrimary)
            Text("played together")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .accessibilityHidden(true)
    }
    ```

  - [x] 4.6 `winsRowSection(vm:)` — symmetrical two-column wins (NEVER tint either side green/red; this is OFF-COURSE warm register, both columns use `Color.textPrimary` for score):
    ```swift
    private func winsRowSection(vm: HeadToHeadViewModel) -> some View {
        HStack(spacing: SpacingTokens.md) {
            winsColumn(name: vm.playerAName, wins: vm.winsAFormatted ?? "—", percent: vm.winsAPercentFormatted ?? "—")
            winsColumn(name: vm.playerBName, wins: vm.winsBFormatted ?? "—", percent: vm.winsBPercentFormatted ?? "—")
        }
        .accessibilityHidden(true)
    }

    private func winsColumn(name: String, wins: String, percent: String) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(name)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
            Text(wins)
                .font(TypographyTokens.score)
                .foregroundStyle(Color.textPrimary)
            Text(percent)
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
    }
    ```
    Both columns share the same neutral color treatment — the H2H view is reflective, not competitive. Tinting "winner" green or "loser" amber would mix the off-course register with on-course chrome (UX-PMVP-DR5).

  - [x] 4.7 `differentialSection(vm:)` — single labeled metric with the same neutral color treatment:
    ```swift
    private func differentialSection(vm: HeadToHeadViewModel) -> some View {
        VStack(spacing: SpacingTokens.xs) {
            Text(vm.averageDifferentialFormatted ?? "—")
                .font(TypographyTokens.score)
                .foregroundStyle(Color.textPrimary)
            Text("average differential")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
        .accessibilityHidden(true)
    }
    ```
    **Do NOT** color the differential green-if-negative / amber-if-positive. Both players' identities are treated symmetrically; the sign convention is documented in the service doc-comment and explained in the VoiceOver label, but the visual treatment stays neutral. (If product later wants to highlight "player A is ahead", that's a separate story.)

  - [x] 4.8 Create `HyzerApp/Views/History/HeadToHeadOpponentPickerSheet.swift`. Lives in `Views/History/` for the same single-consumer reason as `HeadToHeadView`. The picker is presented as a `.sheet` from `PlayerHoleBreakdownView` (Task 5). On row selection, the sheet dismisses AND pushes a `HeadToHeadView` onto the parent NavigationStack. Sheet shape:
    ```swift
    struct HeadToHeadOpponentPickerSheet: View {
        let playerAID: String
        let playerAName: String
        let onSelect: (HeadToHeadCandidate) -> Void
        let onCancel: () -> Void

        @Environment(\.modelContext) private var modelContext
        @State private var viewModel: HeadToHeadOpponentPickerViewModel?

        var body: some View {
            NavigationStack {
                Group {
                    if let vm = viewModel {
                        if vm.isLoading {
                            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if vm.hasError {
                            emptyState  // AC #8 — error collapses to empty-state treatment.
                        } else if vm.hasNoCandidates {
                            emptyState
                        } else {
                            candidatesList(vm: vm)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(Color.backgroundPrimary)
                .navigationTitle("Compare with…")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
            }
            .task(id: playerAID) {
                let vm = HeadToHeadOpponentPickerViewModel(modelContext: modelContext, playerAID: playerAID)
                viewModel = vm
                await vm.loadCandidates()
            }
        }

        private var emptyState: some View {
            Text("No one to compare with yet. Play a round with someone else first.")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func candidatesList(vm: HeadToHeadOpponentPickerViewModel) -> some View {
            List(vm.candidates) { candidate in
                Button {
                    onSelect(candidate)
                } label: {
                    HStack(spacing: SpacingTokens.md) {
                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text(candidate.playerName)
                                .font(TypographyTokens.body)
                                .foregroundStyle(Color.textPrimary)
                            Text(HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(candidate.roundsTogether))
                                .font(TypographyTokens.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(minHeight: SpacingTokens.minimumTouchTarget)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Compare with \(candidate.playerName), \(HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(candidate.roundsTogether))")
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
    ```
    Empty-state copy is verbatim AC #5. Error path collapses to empty-state (AC #8 — same UX-PMVP-DR5 reflective register). Minimum-touch-target row height (44pt) per CLAUDE.md "Accessibility first" (`SpacingTokens.minimumTouchTarget`). VoiceOver label combines name + rounds-together count per row.

  - [x] 4.9 **No animations beyond `AnimationTokens.springGentle`** on either view (UX-PMVP-DR5). Specifically: do NOT add `.transition(...)` to the empty-state ↔ populated-state switch, do NOT add `.animation(...)` to numeric value changes. The H2H view is static after first compute; the picker sheet is a standard system sheet presentation.

- [x] Task 5: Integrate "Compare" entry point into `PlayerHoleBreakdownView` (AC: 4, 5)
  - [x] 5.1 Modify `HyzerApp/Views/History/PlayerHoleBreakdownView.swift` to add the "Compare" navigation row immediately BELOW the existing "View score trend" row (added by Story 13.1) and above the `Divider()` that precedes the hole list. The Compare row is **gated** on `!GuestIdentifier.isGuest(playerID)` (AC #4):
    ```swift
    NavigationLink(destination: PlayerTrendView(playerID: playerID, playerName: playerName)) {
        Label("View score trend", systemImage: "chart.line.uptrend.xyaxis")
            // ... unchanged from Story 13.1
    }

    if !GuestIdentifier.isGuest(playerID) {
        Button {
            isShowingOpponentPicker = true
        } label: {
            Label("Compare", systemImage: "person.2.fill")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.md)
                .frame(minHeight: SpacingTokens.minimumTouchTarget)
                .accessibilityLabel("Compare \(playerName) with another player")
        }
        .buttonStyle(.plain)
    }

    Divider()
        .overlay(Color.backgroundElevated)
    ```
    Wrap the entire Compare block in `if !GuestIdentifier.isGuest(playerID) { ... }` (AC #4 — NOT just hidden via `.opacity(0)` or `.disabled(true)`, which would still expose the row to VoiceOver). Use a `Button` with `buttonStyle(.plain)` for sheet presentation — `NavigationLink` would deep-link directly, but we need an intermediate picker. SF Symbol `"person.2.fill"` distinguishes the Compare entry from `"chart.line.uptrend.xyaxis"` above it.

  - [x] 5.2 Add the view-level state and sheet presenter at the top of `PlayerHoleBreakdownView`:
    ```swift
    @State private var isShowingOpponentPicker = false
    @State private var selectedOpponent: HeadToHeadCandidate?
    ```
    And attach the sheet plus a `NavigationLink` driven by `selectedOpponent` onto the view body's outer container:
    ```swift
    .sheet(isPresented: $isShowingOpponentPicker) {
        HeadToHeadOpponentPickerSheet(
            playerAID: playerID,
            playerAName: playerName,
            onSelect: { candidate in
                isShowingOpponentPicker = false
                selectedOpponent = candidate
            },
            onCancel: {
                isShowingOpponentPicker = false
            }
        )
    }
    .navigationDestination(item: $selectedOpponent) { opponent in
        HeadToHeadView(
            playerAID: playerID,
            playerAName: playerName,
            playerBID: opponent.playerID,
            playerBName: opponent.playerName
        )
    }
    ```
    `.navigationDestination(item:)` requires `HeadToHeadCandidate: Hashable` — already satisfied because `Identifiable` + `Equatable` + value type. **Add `Hashable` conformance to `HeadToHeadCandidate` in Task 1.1** if Swift cannot synthesize it (all stored properties are `Hashable`-conforming so synthesis should work; if not, add an explicit `Hashable` conformance).

    Order of operations on row tap: `onSelect` fires → sheet dismisses → `selectedOpponent` set → `.navigationDestination(item:)` pushes `HeadToHeadView`. Do NOT push directly from inside the sheet (the sheet would have to coordinate with the parent NavigationStack across modal boundaries — anti-pattern). The "sheet-dismiss-then-push" pattern is what `HomeView.swift:373` and `ScorecardContainerView.swift:106` use.

  - [x] 5.3 No changes to `PlayerHoleBreakdownViewModel.swift`. The "Compare" entry point is view-level navigation state, not VM state. Same pattern Story 13.2 used for adding the `courseID` parameter (view-level only).

  - [x] 5.4 **Preserve all existing behaviors:** "View score trend" navigates as before, the `PersonalBestCardView` (Story 13.2) still renders above, the hole-by-hole list and `SummaryFooterRow` are unchanged. The Compare row is purely additive between "View score trend" and the divider.

- [x] Task 6: HyzerKit tests for `HeadToHeadService` (AC: 1, 2, 5, 6, 7)
  - [x] 6.1 Create `HyzerKit/Tests/HyzerKitTests/Domain/HeadToHeadServiceTests.swift` using Swift Testing (`@Suite`, `@Test` macros — NOT XCTest). Use `TestContainerFactory.makeSyncContainer()` (`HyzerKit/Tests/HyzerKitTests/Fixtures/TestContainerFactory.swift:10-16`) — same factory `PlayerTrendServiceTests` and `PersonalBestServiceTests` use; already includes `Round`, `ScoreEvent`, `Course`, `Hole`, `Player`, `SyncMetadata`.

  - [x] 6.2 Helper: factor a private `insertRound(context:course:playerAID:playerBID:strokesA:strokesB:completedAt:)` that inserts a `.completed` round with both players in `playerIDs` and one `ScoreEvent` per hole per player. Mirror the shape of `PlayerTrendServiceTests.insertRound` (`HyzerKit/Tests/HyzerKitTests/Domain/PlayerTrendServiceTests.swift:19-54`). Do NOT extract a cross-file shared helper — `ValueCollector` extraction debt (CLAUDE.md "Known Technical Debt") is the canonical fix-target for cross-file test-helper consolidation; piggybacking that work onto this story is out of scope. Mirror the existing pattern.

    Also add a `insertRegisteredPlayer(context:displayName:)` helper that inserts a `Player` and returns its UUID string — needed for `findOpponentCandidates` tests which require Player rows for the display-name fetch.

  - [x] 6.3 Required tests for `computeRecord(for:against:)`:
    - `test_computeRecord_emptyStore_returnsZeroCounts`: empty store → `record.roundsPlayedTogether == 0`, all win counts 0, `averageDifferential == nil`. **DOES NOT throw.**
    - `test_computeRecord_noSharedRounds_returnsZeroCounts`: player A and player B have completed rounds but NONE in common → same all-zero record. Asserts that the function correctly identifies non-overlapping participants.
    - `test_computeRecord_oneSharedRound_aWins`: insert one shared round where A scored `[3, 3]` and B scored `[4, 4]` on 2 par-3 holes → `roundsPlayedTogether == 1`, `winsA == 1`, `winsB == 0`, `ties == 0`, `averageDifferential == -2.0`.
    - `test_computeRecord_oneSharedRound_bWins`: mirror of the above with B better than A → `winsB == 1`, `averageDifferential == +2.0`. Pin the sign convention (Task 1.7).
    - `test_computeRecord_oneSharedRound_tied`: A scored `[3, 3]`, B scored `[3, 3]` → `winsA == 0`, `winsB == 0`, `ties == 1`, `roundsPlayedTogether == 1`, `averageDifferential == 0.0`. Pin tie semantics (AC #1, Task 1.7).
    - `test_computeRecord_multipleRounds_aggregatesCorrectly` (AC #1, AC #2): 5 shared rounds — A wins 3, B wins 1, tie 1, differentials `[-2, -1, -1, +1, 0]`. Assert `winsA == 3, winsB == 1, ties == 1, roundsPlayedTogether == 5, averageDifferential == (-2-1-1+1+0)/5 == -0.6`.
    - `test_computeRecord_winsPlusTiesEqualsRoundsPlayed` (invariant pin): construct any mix of shared rounds (use the 5-round fixture from the previous test). Assert `record.winsA + record.winsB + record.ties == record.roundsPlayedTogether`. Future refactors will fail this if the loop accounting drifts.
    - `test_computeRecord_excludesNonCompletedRounds`: insert a `.active` round between A and B with A winning, and a `.completed` round between A and B with B winning → record returns only the completed round; `winsA == 0, winsB == 1, roundsPlayedTogether == 1`. The active round MUST NOT leak in.
    - `test_computeRecord_skipsRoundsWithMissingResolvedScoreForA` (AC #7): insert a shared round where A is in `playerIDs` but has zero `ScoreEvent`s (B has events). Service skips the round; `roundsPlayedTogether == 0`. Then insert one round where both have events → that one round is the only result. Pins the `holesPlayed > 0` skip guard.
    - `test_computeRecord_skipsRoundsWithMissingResolvedScoreForB`: mirror with B missing events. Same assertion.
    - `test_computeRecord_freshEngineNoStaleStateLeak` (AC #6 regression guard): construct a fixture with TWO shared rounds. Round 1 has clean data (A wins by 2). Round 2 has a deliberately corrupted hole set (course has 18 holes declared but no `Hole` records inserted for hole numbers, so `parByHole[n] ?? 3` falls back). Compute. Assert that any per-round failure of `StandingsEngine.recompute` produces `currentStandings == []` on the fresh engine (so the round is skipped) and DOES NOT bleed Round 1's standings into Round 2's aggregation. If the engine's internal failure mode cannot be reliably reproduced with in-memory fixtures (Story 13.2 ran into this — see `13-2-personal-best-per-course.md:459` fallback), follow the documented spec fallback: a comment-only test that asserts a `StandingsEngine` is constructed on each loop iteration by reading the `HeadToHeadService` source via `#expect(URL(fileURLWithPath: #file)...)`. Pragmatic, not gold-standard, but documents intent.
    - `test_computeRecord_includesGuestPairOK_butGuestsAreRoundScoped`: insert a shared round between registered player A (UUID) and a guest with playerID `"guest:<uuid>"`. Call `computeRecord(for: playerAID, against: guestID)` → returns a valid record (one round, A wins, etc.). The service does NOT filter at this level — the filtering happens at the UI layer (Compare button hidden for guests, picker excludes guests). Document in Dev Notes: the service treats `playerID` as opaque; callers prevent guest-as-opponent invocations.
    - `test_computeRecord_respectsFetchLimit_eventsA` (AC #2 bound A's events): insert 600 completed rounds where ONLY player A has events. Call `computeRecord(for: playerAID, against: playerBID, maxRounds: 500)` → returns zero shared rounds (B has no events), no throw. The `eventsA` fetch must not throw at the `maxRounds * 20 = 10_000` cap.
    - `test_computeRecord_respectsFetchLimit_truncatesToMostRecent` (AC #2 truncation correctness): insert 600 shared rounds with `completedAt` ascending; place one decisive A-wins round at the OLDEST timestamp (index 0) and ensure all other 599 are ties. Call `computeRecord(for: playerAID, against: playerBID, maxRounds: 500)` → result MUST NOT contain the oldest A-win (it falls outside the most-recent 500). Asserts `winsA == 0, ties == 500`. This is the critical fetchLimit-correctness test that 13.2 Story patch flagged as missing in PB's original tests (`13-2-personal-best-per-course.md:738` patch item).

  - [x] 6.4 Required tests for `findOpponentCandidates(for:)`:
    - `test_findCandidates_emptyStore_returnsEmpty`: empty store → `[]`.
    - `test_findCandidates_noPeersBecauseAllRoundsSoloOrGuestOnly`: player A has 3 completed rounds, all solo or with guests only → `[]`.
    - `test_findCandidates_excludesSelf`: A has rounds with B and C; query for A → returns `[B, C]`, never `A` itself.
    - `test_findCandidates_excludesGuests` (AC #5 + AC #4): A has rounds with B (registered) AND with a guest `"guest:<uuid>"` → returns `[B]` only, never the guest.
    - `test_findCandidates_excludesNonCompletedRounds`: A has an `.active` round with B and a `.completed` round with C → returns `[C]` only.
    - `test_findCandidates_countsRoundsTogetherCorrectly`: A plays 3 rounds with B and 1 round with C → returns `[(B, 3), (C, 1)]` sorted alphabetically.
    - `test_findCandidates_sortedAlphabeticallyCaseInsensitive` (AC #5): A plays with players "alice" (lowercase), "Bob", "charlie", "DAVE" → returned order is `[alice, Bob, charlie, DAVE]` (locale-aware case-insensitive ascending).
    - `test_findCandidates_dropsOrphanPeerIDs`: insert a round with a `playerIDs` entry that has NO matching `Player` row in the store (synthetic orphan UUID) → that peer is silently dropped from the result. No throw.

  - [x] 6.5 No performance test in HyzerKit — `HeadToHeadService` consumes the same `StandingsEngine.recompute` pass per round as `PlayerTrendService` and `PersonalBestService`. Story 13.1 already pins the 250-round correctness baseline; duplicating perf gating in 13.3 adds noise without insight. Perf gating is on-device manual verification (Task 8 below).

- [x] Task 7: HyzerApp tests for `HeadToHeadViewModel` and `HeadToHeadOpponentPickerViewModel` (AC: 1, 3, 5, 8, 9)
  - [x] 7.1 Create `HyzerAppTests/ViewModels/HeadToHeadViewModelTests.swift` using Swift Testing. Use the inline `ModelConfiguration(isStoredInMemoryOnly: true)` pattern from `HyzerAppTests/ViewModels/PlayerTrendViewModelTests.swift:14-19` (which does NOT depend on `HyzerKit.TestContainerFactory` — that factory is internal to the HyzerKit test target). Do NOT cross the target boundary.

  - [x] 7.2 Required tests for `HeadToHeadViewModel`:
    - `test_viewModel_initialState_isLoading`: `vm.isLoading == true`, `vm.hasData == false`, `vm.hasNoData == false`.
    - `test_viewModel_noSharedRounds_setsHasNoData`: empty store, `await vm.compute()` → `vm.hasNoData == true`, `vm.hasData == false`, `vm.errorMessage == nil`.
    - `test_viewModel_oneSharedRound_populates` (AC #1): insert one shared round (A wins by 2 on 2 par-3 holes). After compute → `vm.hasData == true`, `vm.roundsPlayedFormatted == "1 round"`, `vm.winsAFormatted == "1"`, `vm.winsBFormatted == "0"`, `vm.winsAPercentFormatted == "100%"`, `vm.winsBPercentFormatted == "0%"`, `vm.averageDifferentialFormatted == "-2"`.
    - `test_viewModel_roundsPlayedFormatted_singularVsPlural`: 1 round → `"1 round"`; 2 rounds → `"2 rounds"`. Pin singular/plural copy.
    - `test_viewModel_percentString_zeroDenominator_returnsNil`: numerator 0, denominator 0 → `winsAPercentFormatted == nil`. The `hasNoData` branch should be tripped before this is read; pin the guard.
    - `test_viewModel_averageDifferentialFormatted_matchesStandingConvention` (Standing.formatScore pin): differential `-2` → `"-2"`, `0` → `"E"`, `+1` → `"+1"`. Same convention guard as `PlayerTrendViewModelTests` from Story 13.1.
    - `test_viewModel_accessibilityLabel_loadingState`: `vm.accessibilityLabel == "Head-to-head loading."` before compute.
    - `test_viewModel_accessibilityLabel_emptyState` (AC #3 + AC #9): empty store, after compute → label matches `"<PlayerA> and <PlayerB> haven't played a round together yet."` exactly.
    - `test_viewModel_accessibilityLabel_populated` (AC #9): one shared round, after compute → label matches `"Head-to-head, <A> versus <B>. 1 round played. <A> wins 1, 100%. <B> wins 0, 0%. Average differential -2."` exactly.
    - `test_viewModel_serviceErrorPath_collapsesToNoData` (AC #8): use the `init(service:)` testing initializer with a `HeadToHeadService` connected to a context whose container has been intentionally configured to throw on fetch (e.g., wrong-schema container missing `ScoreEvent.self`). After `await vm.compute()` → `vm.errorMessage != nil`, `vm.hasNoData == true` (per the `errorMessage != nil || roundsPlayedTogether == 0` condition), `vm.accessibilityLabel` matches the empty-state copy (NOT a separate error string — same sighted/VoiceOver coherence fix Story 13.2 patch enforced for PersonalBestCardView). If the throw cannot be reliably reproduced in-memory (same gotcha 13.2 hit — `13-2-personal-best-per-course.md:476`), wire the testing initializer to a stub service that throws synchronously. **The point is to make the `init(service:)` overload non-dead-code**; Story 13.2 review flagged a dead-code overload (`13-2-personal-best-per-course.md:740`) — do not repeat.

  - [x] 7.3 Required tests for `HeadToHeadOpponentPickerViewModel`:
    - `test_pickerVM_initialState_isLoading`: `isLoading == true`, `hasNoCandidates == false`.
    - `test_pickerVM_emptyStore_setsHasNoCandidates`: empty store, after `await vm.loadCandidates()` → `hasNoCandidates == true`, `candidates == []`.
    - `test_pickerVM_populatesCandidates`: insert one round between A and B, both registered → `vm.candidates.count == 1`, `vm.candidates[0].playerID == bID`, `vm.candidates[0].roundsTogether == 1`.
    - `test_pickerVM_excludesGuests` (AC #5): insert one round between A and a guest → `vm.candidates == []`.
    - `test_pickerVM_roundsTogetherCopy_singular`: assert `HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(1) == "1 round together"`.
    - `test_pickerVM_roundsTogetherCopy_plural`: assert `HeadToHeadOpponentPickerViewModel.roundsTogetherCopy(2) == "2 rounds together"` and `roundsTogetherCopy(7) == "7 rounds together"`.

  - [x] 7.4 Do NOT use `Task.sleep` in any test. `await vm.compute()` / `await vm.loadCandidates()` complete synchronously from the test's perspective when the model container is in-memory. CLAUDE.md "Known Technical Debt" explicitly calls out `Task.sleep(for: .milliseconds(100))` as flaky.

- [x] Task 8: Visual & manual verification (AC: 1, 3, 4, 5)
  - [x] 8.1 Run `xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp -destination 'platform=iOS Simulator,name=iPhone 17 with Watch'`. Build must succeed with zero SwiftLint warnings (CLAUDE.md: max line length 160 error, max function body 100 lines error).

  - [x] 8.2 Regenerate the Xcode project after adding new files: `xcodegen generate`. New files added in this story:
    - `HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift`
    - `HyzerKit/Tests/HyzerKitTests/Domain/HeadToHeadServiceTests.swift`
    - `HyzerApp/ViewModels/HeadToHeadViewModel.swift`
    - `HyzerApp/ViewModels/HeadToHeadOpponentPickerViewModel.swift`
    - `HyzerApp/Views/History/HeadToHeadView.swift`
    - `HyzerApp/Views/History/HeadToHeadOpponentPickerSheet.swift`
    - `HyzerAppTests/ViewModels/HeadToHeadViewModelTests.swift`
    All must be included in `HyzerApp.xcodeproj/project.pbxproj`. Same xcodegen requirement as Stories 13.1 and 13.2.

  - [x] 8.3 Manual flow on iOS Simulator (iPhone 17 with Watch destination):
    - **Compare hidden for guests (AC #4):** Open History → tap any round that includes a guest → tap the guest player row → verify the "View score trend" row is visible but the "Compare" row is NOT visible. Toggle VoiceOver and swipe — the Compare row must not be in the accessibility tree (not just visually hidden).
    - **Compare visible for registered players:** Open History → tap any round with multiple registered players → tap a registered player → verify the "Compare" row is visible immediately below "View score trend".
    - **Empty opponent picker (AC #5 empty state):** Tap "Compare" for a player who has never played a `.completed` round with another registered player → verify the sheet shows the exact copy `"No one to compare with yet. Play a round with someone else first."` with no list rows.
    - **Populated opponent picker (AC #5 populated):** Tap "Compare" for a player who has played with at least one other registered player → verify the sheet lists all registered peers with their "<n> rounds together" secondary label. Verify alphabetical sort.
    - **Empty H2H view (AC #3):** Add a registered player who played a round with player A but only `.active` (no `.completed`) — they should not appear in the picker. To force this state for manual test: complete only one round between A and B, then open the picker. (For the literal AC #3 empty-state path: the picker filters them out before reaching H2H view; the H2H view's empty state is the defensive fallback path. To trigger it, ad-hoc navigate via deeplink with two registered player IDs who have no shared completed rounds.)
    - **Populated H2H view (AC #1):** Complete two rounds between two registered players where A wins one and B wins one with a known differential → verify the view shows "2 rounds played together", "<A> 1, 50%", "<B> 1, 50%", and the correct `Standing.formatScore` for the avg differential. Page background is `Color.backgroundPrimary`, cards are `Color.backgroundElevated`, both wins columns use `Color.textPrimary` for score (NOT green/amber — UX-PMVP-DR5).
    - **VoiceOver (AC #9):** Enable VoiceOver, focus the H2H view content → assert the announced label matches `"Head-to-head, <A> versus <B>. <n> rounds played. <A> wins <winsA>, <pctA> percent. <B> wins <winsB>, <pctB> percent. Average differential <diff>."` exactly. For empty state, announced label matches `"<A> and <B> haven't played a round together yet."`.

  - [x] 8.4 Dynamic Type AX3 verification: launch with `Environment(\.dynamicTypeSize, .accessibility3)` previews or simulator → Settings → Accessibility → Display & Text Size → Larger Accessibility Sizes. Verify:
    - Header "<A> vs <B>" wraps cleanly (does not truncate)
    - The wins row `HStack` may wrap or stack to two lines at AX3 — acceptable as long as no numeric value is clipped
    - The picker sheet rows scale without clipping `playerName` or `"<n> rounds together"`

  - [x] 8.5 Per CLAUDE.md "Measurement Over Estimation": the H2H computation adds one `StandingsEngine.recompute` pass per shared completed round (bounded at 500). For typical use (≤30 rounds with any one peer) this is well under perceptual threshold. Do NOT claim a specific ms budget unless measured; if visible jank surfaces during 8.3 manual flow, document the observation in Completion Notes — do NOT fabricate numbers.

## Dev Notes

### Architecture & Patterns

- **`HeadToHeadService` lives in HyzerKit**; ViewModels and Views live in HyzerApp. Same Layer Boundary split as `StandingsEngine` (HyzerKit) ↔ `LeaderboardViewModel` (HyzerApp), `PlayerTrendService` ↔ `PlayerTrendViewModel`, and `PersonalBestService` ↔ `PersonalBestViewModel`. HyzerKit holds pure domain logic; HyzerApp holds SwiftUI presentation. CLAUDE.md "Layer Boundaries".
- **HyzerKit must continue to build for macOS** (`HyzerKit/Package.swift:6-10` declares iOS / watchOS / macOS targets; `swift test --package-path HyzerKit` is part of the CLAUDE.md build commands). Do NOT add `import SwiftUI` to `HeadToHeadService.swift` — keep it Foundation + SwiftData + os.log. Color and SwiftUI types belong in the ViewModel layer.
- **No data-model changes.** Read-side derivation over existing `Round` + `ScoreEvent` + `Player` + `Hole`. No CloudKit DTO, no migration, no schema change. All of Epic 13 follows this constraint per the epic narrative (`epics-post-mvp.md:497`).
- **Concurrency:** `@MainActor` for `HeadToHeadService`, `HeadToHeadViewModel`, and `HeadToHeadOpponentPickerViewModel` — identical to `StandingsEngine` / `PlayerTrendService` / `PersonalBestService`. Swift 6 strict concurrency is enabled project-wide (`project.yml:17`); no `DispatchQueue`; no `Task.sleep` in tests.
- **Why a fresh `StandingsEngine` per iteration:** Story 13.1 review patch P2 (`13-1-score-trend-visualization-per-player.md:413`), `PlayerTrendService.swift:97-103`, and `PersonalBestService.swift:102-108` already encoded this lesson. For H2H the stakes are higher: a stale-engine leak would corrupt BOTH winner counts AND the differential — silently producing wrong numbers a user will share to "settle a debate". Same fix as predecessors.
- **Why the intersection-of-event-sets fetch pattern** (and NOT a direct `playerIDs.contains` predicate on `Round`): SwiftData's `#Predicate` translation of `Array<String>.contains(String)` against a stored model field has historically been unreliable across iOS minor versions (see `deferred-work.md:5, 78` notes about the inverse direction). The intersection pattern uses only `String == String` predicate against `ScoreEvent.playerID` (well-proven) plus `Array<UUID>.contains(model.id)` (well-proven), then a Swift `Set.intersection` in pure memory. This is the path 13.1 and 13.2 chose; 13.3 inherits it. The epics-file AC text `"a compound predicate on Round.playerIDs containing both player IDs"` is satisfied in spirit (bounded query that filters to rounds containing both players) without using the unreliable predicate shape.
- **Guest filtering is a UI concern, not a service concern.** `HeadToHeadService.computeRecord(for:against:)` treats `playerID` as opaque — it does not check `GuestIdentifier.isGuest`. Guests being excluded from the Compare entry point (AC #4) and from the opponent picker (AC #5 + `findOpponentCandidates`) is enforced at the View and Picker-VM layers. This keeps the service composable (a future tooling story could compare two guests within the same round if the product ever wanted that).

### Existing Code to Reuse (DO NOT Recreate)

| What | Location | How to Reuse |
|------|----------|--------------|
| Score formatting | `HyzerKit/Sources/HyzerKit/Domain/Standing+Formatting.swift:11-15` | `Standing.formatScore(_:)` for `averageDifferentialFormatted` |
| Standings computation | `HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift:38-61` | `recompute(for: roundID, trigger:)` per round, then `currentStandings.first(where:)` for each player |
| Guest identifier filter | `HyzerKit/Sources/HyzerKit/Domain/GuestIdentifier.swift:24-26` | `GuestIdentifier.isGuest(_ playerID: String) -> Bool` — gates Compare button and filters picker candidates |
| Two-fetch bounded service pattern | `HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift:52-124`, `HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift:54-132` | Bounded ScoreEvent fetch → derive participantRoundIDs → bounded Round fetch with `fetchLimit` + `.reverse` sort by `completedAt` |
| Local player resolution | `HyzerApp/App/AppServices.swift:249-258` | `AppServices.resolveLocalPlayerID(from: ModelContext) -> UUID?` — not used in this story (the View already has `playerID` from `PlayerHoleBreakdownView`); reference only |
| Card / ViewModel pattern | `HyzerApp/Views/History/PlayerTrendView.swift:11-52`, `HyzerApp/ViewModels/PlayerTrendViewModel.swift:10-72`, `HyzerApp/Views/Components/PersonalBestCardView.swift:18-37` | `@State private var viewModel: HeadToHeadViewModel?` + `.task(id: ...) { ... await vm.compute() }`; `@MainActor @Observable final class` VM with `async compute()` |
| Sheet-then-push navigation | `HyzerApp/Views/HomeView.swift:373`, `HyzerApp/Views/Scoring/ScorecardContainerView.swift:106` | `.sheet(isPresented:)` to present picker; on selection, dismiss sheet AND set `selectedOpponent` state to drive `.navigationDestination(item:)` push |
| Sheet shape for picker | `HyzerApp/Views/Scoring/VoiceOverlayView.swift:414-434` (`PlayerPickerSheet`) | List of selectable players with `Button` + `buttonStyle(.plain)` + min touch target — same structural pattern; OUR picker has the additional empty-state branch and a richer per-row label |
| Test container | `HyzerKit/Tests/HyzerKitTests/Fixtures/TestContainerFactory.swift:10-16` | `makeSyncContainer()` — already includes all relevant models including `Player` |
| Test fixture pattern | `HyzerKit/Tests/HyzerKitTests/Domain/PlayerTrendServiceTests.swift:19-54`, `HyzerKit/Tests/HyzerKitTests/Domain/PersonalBestServiceTests.swift` | Adapt the `insertRound(...)` helper for TWO players' strokes (`strokesA`/`strokesB`) |

### File Structure

**Files to add (NEW):**
```
HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift              # @MainActor service + HeadToHeadRecord + HeadToHeadCandidate
HyzerKit/Tests/HyzerKitTests/Domain/HeadToHeadServiceTests.swift
HyzerApp/ViewModels/HeadToHeadViewModel.swift                         # @MainActor @Observable VM (record view)
HyzerApp/ViewModels/HeadToHeadOpponentPickerViewModel.swift           # @MainActor @Observable VM (picker)
HyzerApp/Views/History/HeadToHeadView.swift                           # Record view + subview composition
HyzerApp/Views/History/HeadToHeadOpponentPickerSheet.swift            # Sheet that lists candidates
HyzerAppTests/ViewModels/HeadToHeadViewModelTests.swift               # Both VMs share this file (consistent with PlayerTrend/PB tests)
```

**Files to modify (UPDATE):**
```
HyzerApp/Views/History/PlayerHoleBreakdownView.swift                  # Add "Compare" button + sheet presentation + navigationDestination
HyzerApp.xcodeproj/project.pbxproj                                    # Auto-regenerated by xcodegen
_bmad-output/implementation-artifacts/sprint-status.yaml              # 13.3 → ready-for-dev (and on completion → done)
```

**Files to NOT modify (regression risk):**
- `HyzerApp/Views/Components/PersonalBestCardView.swift` — Story 13.2 surface; the Compare entry point is added on `PlayerHoleBreakdownView` only, NOT on the PB card.
- `HyzerApp/Views/History/PlayerTrendView.swift` — Story 13.1 surface; H2H is a peer feature, NOT embedded inside the trend chart.
- `HyzerApp/Views/History/HistoryListView.swift`, `HistoryRoundDetailView.swift` — no new top-level H2H surface from these. The PRD scope (`epics-post-mvp.md:553-578`) places H2H only as a "Compare" action on the player drill-down view.
- `HyzerApp/Views/Courses/CourseDetailView.swift` — no change. H2H is per-pair-of-players, not per-course; no Compare entry from the course surface.
- `HyzerApp/Views/HomeView.swift` — no change. No new tab, no new top-level home surface.
- `HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift` — read-only consumer. Do NOT add a `computeStandings(forMultipleRoundsForTwoPlayers:)` batch helper even if appealing. Out of scope, premature abstraction.
- `HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift`, `PersonalBestService.swift` — read-only neighbors; do NOT factor out a common base class for "score-deriving services". Three services is not yet a pattern (one would expect a 4th before factoring).
- `HyzerKit/Sources/HyzerKit/Models/Round.swift`, `Player.swift`, `Course.swift`, `Hole.swift`, `ScoreEvent.swift` — no model changes per Epic 13 scope.
- `project.yml` — no dependency or target change. H2H is pure SwiftData + Foundation in HyzerKit, pure SwiftUI in HyzerApp.
- `HyzerKit/Package.swift` — no change. HyzerKit must continue to build for macOS.
- `HyzerApp/ViewModels/PlayerHoleBreakdownViewModel.swift` — no change. The Compare entry point is view-level navigation state, not VM state (same approach Story 13.2 used for adding the `courseID` parameter).

### UX Spec Compliance (UX-PMVP-DR5)

- **Off-course warm register.** Page background `Color.backgroundPrimary`; card backgrounds `Color.backgroundElevated`. No on-course chrome — no floating leaderboard pill, no score-state-colored backgrounds. The H2H view is reflective, not competitive.
- **Neutral color treatment for wins columns.** Do NOT tint either player's wins green-or-amber-or-anything. Both columns use `Color.textPrimary` for score and `Color.textSecondary` for the player-name and percent caption. The H2H view shows symmetry between two players, not adversarial competition. (If product later wants a "winning" highlight, that's a separate story.)
- **No mascots, no confetti, no emoji** in card copy or layout. Same constraint family as UX-PMVP-DR1 (round summary), UX-PMVP-DR5 (memory views), UX-PMVP-DR6 (round signature). Reflective surface.
- **3-tier score-state convention for the differential ONLY** if a future redesign wants it. For 13.3 as scoped, the differential renders in `Color.textPrimary` regardless of sign. Story 13.1's "Best column always green" decision (`deferred-work.md:79`) is a known wart specifically for that view; do NOT propagate it here.
- **Dynamic Type AX3.** All typography uses `TypographyTokens.score` (SF Mono, `.title2`-based) and `TypographyTokens.caption` (SF Pro Rounded, `.footnote`-based) — both honor Dynamic Type without override. Test at AX3 per Task 8.4.
- **No animations.** UX-PMVP-DR5 says reflective surfaces use `AnimationTokens.springGentle` AT MOST. Neither the H2H view nor the picker animates content changes. Do NOT add `.transition(.opacity)` or `.animation(...)` modifiers.

### Scope Boundaries — Do NOT Implement

- **Three-way+ head-to-head comparison.** AC #1 is pair-wise only. Do NOT implement a "Compare three players" surface. Out of scope.
- **Head-to-head over a date range** ("last 30 days", "this season"). All shared `.completed` rounds, all time. Date filtering is out of scope.
- **Head-to-head per course.** Spec is across ALL shared rounds regardless of course. Do NOT add a course filter — that's a different feature.
- **Live "head-to-head while in round".** H2H is a memory view (Epic 13 — past completed rounds). Live two-player diff is the live leaderboard's job (Epic 3 / Story 3.4).
- **Highlighting tie counts.** Tie count is included in the model (`HeadToHeadRecord.ties`) for testability and invariant pinning, but is NOT displayed in the populated UI for 13.3 (only `winsA`, `winsB`, `roundsPlayedTogether`, and `averageDifferential` per AC #1). A future story can surface ties if product wants it.
- **Sharing H2H as an image.** Out of scope. Screenshot-share path is Story 11.3 for the summary card only.
- **Comparing to a guest.** AC #4 hides the Compare entry for guest players entirely. Do NOT add an "include guests" toggle, a "compare with this guest from this round" affordance, or any cross-round guest reconciliation. Guest IDs are round-scoped per FR12b — this is a known limitation, not a bug.
- **Best-of-N-rounds streak detection** ("A is on a 3-game winning streak vs B"). Out of scope.
- **Push notification on new H2H lead change** ("A just took the lead vs B!"). Out of scope. Epic 12 push notifications are scoped to round-started / round-complete / discrepancy-detected only.
- **Tie-break for "best matchup of all time".** Not a deliverable; the H2H view is a single-pair summary, not a leaderboard.
- **Localization.** Hardcoded English copy ("Head-to-Head", "vs", "played together", "average differential", "Compare", "Compare with…", "rounds together", "<A> and <B> haven't played a round together yet.", "No one to compare with yet. Play a round with someone else first.") is acceptable per the codebase-wide pattern documented in `deferred-work.md:30-32, 39, 63`.

### Previous Story Intelligence (Stories 13.1 and 13.2)

Stories 13.1 (merged 2026-05-17, commit `a95abf7`) and 13.2 (merged 2026-05-18, commit `97171a7`) established the entire pattern this story extends.

1. **`@MainActor` service + per-iteration fresh `StandingsEngine`.** Both predecessors proved this. Do NOT share an engine across the H2H loop — same regression guard, higher stakes (H2H corrupts BOTH winner counts AND differential on a stale leak).

2. **`async compute()` is mandatory (Story 13.1 review patch D3, Story 13.2 Task 2.4).** Synchronous `compute()` blocks the main thread and prevents `ProgressView` from rendering during the SwiftData fetch + aggregation pass. The pattern is: `vm.compute()` is `async`; the View uses `.task(id: ...) { viewModel = vm; await vm.compute() }` so the `isLoading` body branch renders before the work begins. `HeadToHeadViewModel.compute()` and `HeadToHeadOpponentPickerViewModel.loadCandidates()` follow the same shape.

3. **`.task(id:)` not `.task { guard viewModel == nil ... }` (Story 13.2 review patch).** Replaced `.task` with `.task(id: "\(playerID)|\(courseID)")` to re-run compute when SwiftUI reuses view identity across navigation. H2H view uses `.task(id: "\(playerAID)|\(playerBID)")`; picker uses `.task(id: playerAID)`.

4. **Fetch-limit tests must place "decisive" data OUTSIDE the most-recent window (Story 13.2 review patch).** A tautological test where the best/winning data is at index 599 (most recent) passes whether `fetchLimit` works or not. `test_computeRecord_respectsFetchLimit_truncatesToMostRecent` (Task 6.3) places the decisive A-win at the OLDEST index and asserts it is NOT included.

5. **Error path collapses to no-data treatment AND accessibility label matches (Story 13.2 review patch).** When `errorMessage != nil`, the View renders `noDataState` AND `accessibilityLabel` returns the no-data string — sighted and VoiceOver users see the same state. `HeadToHeadViewModel.hasNoData` and `accessibilityLabel` enforce this.

6. **Testing initializer must not be dead code (Story 13.2 review patch).** Story 13.2 added `init(service:)` per spec then never wired it to a test, producing a dead-code patch item. `HeadToHeadViewModel.init(service:)` MUST be exercised by `test_viewModel_serviceErrorPath_collapsesToNoData` (Task 7.2). If the throw cannot be reliably triggered with in-memory containers, wire the testing initializer to a tiny stub `HeadToHeadService` subclass that throws synchronously — anything but dead code.

7. **No `Task.sleep` in tests.** CLAUDE.md "Known Technical Debt" explicitly calls this out; Stories 13.1 and 13.2 reaffirmed.

8. **xcodegen regeneration after new files.** Required (Story 13.1 Completion Note #9, Story 13.2 Completion Note #12). New `*.swift` files must be added to `HyzerApp.xcodeproj/project.pbxproj` via `xcodegen generate`.

9. **Per-round skip-when-no-resolved-score logging (Story 13.2 deferred work — `deferred-work.md:5`).** When `StandingsEngine.recompute` produces empty `currentStandings` despite the player having events for the round, the H2H service emits `logger.notice` so engineering has visibility into silent drops. Apply this discipline from the start in 13.3 (do not punt to a future review cycle).

10. **`Round.completedAt` may be nil for CloudKit-hydrated `.completed` rounds (Story 13.2 deferred — `deferred-work.md:6`).** The H2H service's per-round loop does not require `completedAt` (unlike `PersonalBest` which surfaces it). The `Round` fetch sort by `\.completedAt` is for `fetchLimit`-truncation behavior; nil values sort to the bottom (oldest) per SwiftData semantics, which is acceptable — they'll be dropped first when `fetchLimit` is exceeded. No special-casing required.

### Git Intelligence Summary

Recent commits (most recent first, 2026-05-18 state):

```
97171a7  feat(history): Story 13.2 — personal best per course (#89)
a95abf7  feat(history): Story 13.1 — score trend visualization per player (#88)
ad6b518  feat(notifications): Story 12.3 — Organizer-only Discrepancy Detected push (#87)
adac268  feat(notifications): Story 12.2 — Round Complete push notification (#86)
ed117eb  fix(hooks): allow heredoc commit messages in conventional-commits PreToolUse hook (#85)
```

Patterns established in Epic 12 (notifications) that DO NOT apply here (read-side feature):
- No CloudKit DTO, no `SyncEngine`, no `SyncScheduler`, no `NotificationService` integration.
- No CKQuerySubscription, no APNs payload, no `pendingDeepLink` routing.
- No actor reentrancy concerns — `HeadToHeadService` is `@MainActor` (not a Swift `actor`).

Patterns from Stories 13.1 and 13.2 (just merged) that DO apply (see "Previous Story Intelligence" above):
- Two-fetch bounded service pattern.
- Fresh engine per iteration.
- `async compute()` with `.task(id:)` modifier.
- `fetchLimit + .reverse sort` + truncation-aware fetch-limit tests.
- Error-collapses-to-no-data + accessibility-label-matches.
- Testing initializer must be non-dead-code.

### Latest Tech Information

- **No new dependencies.** No `import Charts`, no SPM additions. H2H is plain SwiftData + Foundation in HyzerKit, plain SwiftUI + HyzerKit in HyzerApp.
- **Deployment target unchanged.** iOS 18 / watchOS 11 / macOS 15 (`project.yml:8-10`, `HyzerKit/Package.swift:6-10`).
- **`NumberFormatter` allocation.** Same expensive-first-call gotcha as `DateFormatter` (~10ms per Apple docs). Use `private static let percentFormatter` to amortize across instances (Task 2.3).
- **SwiftData `#Predicate` for `Array<UUID>.contains(model.id)`.** Proven path for `sharedRoundIDs.contains($0.id)` (Round fetch in Task 1.2 step 4). Same direction Story 13.1/13.2 use. Bounded `maxRounds = 500` keeps it in SwiftData's predicate-translation budget.
- **SwiftUI `.navigationDestination(item:)`.** Available iOS 17+, so iOS 18+ is fine. Requires `Hashable` on the item type — `HeadToHeadCandidate` should synthesize `Hashable` automatically since all stored properties are `Hashable`-conforming (`String`, `Int`). Verify with the build; if synthesis fails, add an explicit `extension HeadToHeadCandidate: Hashable {}`.

### Testing Requirements

- **Framework:** Swift Testing (`@Suite`, `@Test` macros — NOT XCTest). Per CLAUDE.md "Testing".
- **In-memory containers:** Use `TestContainerFactory.makeSyncContainer()` for HyzerKit tests; for HyzerApp tests use the inline `ModelConfiguration(isStoredInMemoryOnly: true)` pattern from `PlayerTrendViewModelTests.swift:14-19` (which does NOT depend on `HyzerKit.TestContainerFactory` — that factory is internal to the HyzerKit test target). Do NOT introduce a parallel factory; do NOT cross the HyzerKit/HyzerApp test-target boundary.
- **Determinism:** Use fixed timestamps (`Date(timeIntervalSinceReferenceDate: ...)`) for all sort-order-dependent fixtures, ESPECIALLY for `test_computeRecord_respectsFetchLimit_truncatesToMostRecent`. The "near-identical timestamps for sibling inserts" gotcha (`deferred-work.md:7`) bites tests that need explicit oldest-vs-newest ordering. Do NOT rely on `Date()` / `Date.now`.
- **Coverage targets:** Match the existing project density — each AC has at least one passing test asserting its observable behavior. There is no enforced numeric coverage threshold, but the create-story checklist treats "AC without a test" as a critical miss.
- **Bug-fix-with-test rule:** N/A for this story (greenfield), but if the dev hits an existing bug while wiring the entry point, the fix MUST include a regression test per `~/.claude/rules/code-quality.md` "Bug Fixes Require Tests".

### Coding Standards (CLAUDE.md — Enforce, Do Not Just Reference)

These are the patterns code review will fail you on, listed in order of prior-commit recurrence across Epics 1–13:

- **No silent `try?`** — every `try?` requires a comment explaining why it's safe. Use `do { ... } catch { logger.error(...); throw error }` otherwise. `HeadToHeadService` has zero acceptable `try?` sites; all SwiftData fetches MUST be `do/catch` with logging (Task 1.6).
- **Bounded queries** — every SwiftData fetch must have `fetchLimit` or equivalent (AC #2, Task 1.2, Task 1.3). Reviewers grep for `FetchDescriptor` and reject any unbounded fetch. Three fetches in `computeRecord` (ScoreEventsA, ScoreEventsB, Rounds) + three in `findOpponentCandidates` (ScoreEventsA, Rounds, Players) — every one MUST be bounded.
- **Accessibility first** — VoiceOver labels are required for both the H2H view (AC #9) and the picker rows (Task 4.8). The H2H view's primary container is non-interactive but the `.accessibilityElement(children: .combine)` + `.accessibilityLabel(vm.accessibilityLabel)` combination is mandatory. The picker rows include a combined `.accessibilityLabel("Compare with <name>, <n> rounds together")` per Task 4.8.
- **Design tokens only** — no hardcoded colors, fonts, spacing, or animation durations. Use `Color.backgroundElevated`, `TypographyTokens.score`, `SpacingTokens.lg`, `SpacingTokens.cornerRadiusCard`, `SpacingTokens.minimumTouchTarget`. If a needed token doesn't exist, **add a token first** — never inline a hex/CGFloat. Same warning Stories 11.2, 13.1, 13.2 enforced.

### References

- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#Epic 13, Story 13.3] — user story, scope, ACs, PMVP-FR16
- [Source: _bmad-output/planning-artifacts/epics-post-mvp.md#UX-PMVP-DR5] — off-course warm register for memory views
- [Source: CLAUDE.md#Coding Standards] — no silent `try?`, bounded queries, accessibility first, design tokens only
- [Source: CLAUDE.md#Architecture / Layer Boundaries] — HyzerApp vs HyzerKit split; ViewModels never see `AppServices`
- [Source: HyzerKit/Sources/HyzerKit/Domain/PlayerTrendService.swift] — service shape, two-fetch pattern, fresh-engine-per-iteration to mirror
- [Source: HyzerKit/Sources/HyzerKit/Domain/PersonalBestService.swift] — single-player ↔ single-course parallel; shape to extend to two players
- [Source: HyzerKit/Sources/HyzerKit/Domain/StandingsEngine.swift:38-61] — `recompute(for:trigger:)` public API to call per round
- [Source: HyzerKit/Sources/HyzerKit/Domain/Standing.swift] — value-type shape to mirror in `HeadToHeadRecord` and `HeadToHeadCandidate`
- [Source: HyzerKit/Sources/HyzerKit/Domain/Standing+Formatting.swift:11-15] — `Standing.formatScore(_:)` static helper to reuse for `averageDifferentialFormatted`
- [Source: HyzerKit/Sources/HyzerKit/Domain/GuestIdentifier.swift:23-26] — `GuestIdentifier.isGuest(_:)` filter for Compare button (AC #4) and picker candidates (AC #5)
- [Source: HyzerKit/Sources/HyzerKit/Models/Round.swift] — `Round.status`, `playerIDs`, `completedAt` properties
- [Source: HyzerKit/Sources/HyzerKit/Models/ScoreEvent.swift] — `ScoreEvent.playerID` (registered UUID or `guest:<uuid>`)
- [Source: HyzerKit/Sources/HyzerKit/Models/Player.swift] — `Player.id`, `Player.displayName` resolved in `findOpponentCandidates`
- [Source: HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift] — `backgroundPrimary`, `backgroundElevated`, `textPrimary`, `textSecondary` tokens
- [Source: HyzerKit/Sources/HyzerKit/Design/TypographyTokens.swift] — `h1`, `body`, `caption`, `score` font tokens
- [Source: HyzerKit/Sources/HyzerKit/Design/SpacingTokens.swift] — `lg`, `md`, `sm`, `xs`, `xl`, `cornerRadiusCard`, `minimumTouchTarget`
- [Source: HyzerApp/Views/History/PlayerHoleBreakdownView.swift] — UPDATE target (Task 5)
- [Source: HyzerApp/Views/History/PlayerTrendView.swift:11-52] — View shape with `.task(id:)` modifier to mirror
- [Source: HyzerApp/Views/Components/PersonalBestCardView.swift:18-37] — `.task(id:)` keyed-input pattern (post-13.2-review)
- [Source: HyzerApp/Views/Scoring/VoiceOverlayView.swift:414-434] — `PlayerPickerSheet` structural reference for picker sheet
- [Source: HyzerApp/ViewModels/PlayerTrendViewModel.swift] — VM shape to mirror
- [Source: HyzerApp/ViewModels/PersonalBestViewModel.swift] — `private static let` formatter pattern; error-collapses-to-no-data accessibility coherence
- [Source: HyzerApp/Views/HomeView.swift:373-396] — sheet-then-push navigation pattern reference (Task 5.2)
- [Source: HyzerKit/Tests/HyzerKitTests/Fixtures/TestContainerFactory.swift:10-16] — `makeSyncContainer()` for HyzerKit tests
- [Source: HyzerKit/Tests/HyzerKitTests/Domain/PlayerTrendServiceTests.swift:19-54] — `insertRound` test helper to mirror
- [Source: HyzerKit/Tests/HyzerKitTests/Domain/PersonalBestServiceTests.swift] — tie-break test pattern; fetchLimit-truncation test pattern
- [Source: HyzerAppTests/ViewModels/PlayerTrendViewModelTests.swift] — VM-test shape (in-memory container, async compute, Standing.formatScore convention pinning)
- [Source: _bmad-output/implementation-artifacts/13-1-score-trend-visualization-per-player.md] — Story 13.1 (Score Trend), previous-story intelligence
- [Source: _bmad-output/implementation-artifacts/13-2-personal-best-per-course.md] — Story 13.2 (Personal Best), previous-story intelligence; review patches that inform 13.3 from the start (`.task(id:)` keyed on inputs, error-collapses-to-no-data accessibility, tautological-fetchLimit-test fix, dead-code init avoidance)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — known cross-story technical debt to avoid recreating; logging on silent StandingsEngine recompute failure (line 5), nil `completedAt` after CloudKit hydration (line 6), localization deferral (lines 30-32, 39, 63)

### Project Structure Notes

- Alignment with unified project structure:
  - `HyzerKit/Sources/HyzerKit/Domain/*Service.swift` is the established naming pattern (`StandingsEngine`, `ScoringService`, `ConflictDetector`, `CourseSeeder`, `PlayerTrendService`, `PersonalBestService`). `HeadToHeadService` fits this pattern.
  - `HyzerApp/Views/History/` is the established home for History-flow-only views (`HistoryListView`, `HistoryRoundDetailView`, `PlayerHoleBreakdownView`, `PlayerTrendView`). `HeadToHeadView` and `HeadToHeadOpponentPickerSheet` fit — both are single-consumer (History flow only). `PersonalBestCardView` lives in `Views/Components/` because it is cross-feature (Courses + History); H2H surfaces are NOT cross-feature.
  - `HyzerApp/ViewModels/*ViewModel.swift` is the established naming pattern. `HeadToHeadViewModel` and `HeadToHeadOpponentPickerViewModel` fit.
- Detected conflicts or variances: NONE.
- New directory created: NONE — all paths use existing directories.

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Sonnet 4.6)

### Debug Log References

1. Swift strict concurrency (Swift 6): `@MainActor` async function `compute()` / `loadCandidates()` — `os.Logger.error()` uses `@autoclosure`; referencing `self.playerAID` / `self.playerBID` inside the message literal triggered "requires explicit use of 'self'" error. Fixed by matching the existing project pattern (PersonalBestViewModel, PlayerTrendViewModel): omit property IDs from the ViewModel-level error log. The service already logs with full pair context.

### Completion Notes List

1. `HeadToHeadService` implemented with two-fetch bounded pattern (AC #2): ScoreEventsA → ScoreEventsB → Set.intersection → Rounds. Mirrors `PersonalBestService` / `PlayerTrendService` shape exactly.
2. Fresh `StandingsEngine` per round loop iteration — same regression guard as Story 13.1 patch P2 and Story 13.2 Task 1.2 step 2. Applied from day 1 (not a patch).
3. `logger.notice` on round-skip when `holesPlayed == 0` — resolves the observability debt from `deferred-work.md:5` applied proactively (not deferred).
4. `HeadToHeadViewModel` and `HeadToHeadOpponentPickerViewModel` follow `async compute()` / `async loadCandidates()` pattern with `.task(id:)` so first paint shows `ProgressView` before the SwiftData pass (Story 13.1 review patch D3).
5. `HeadToHeadCandidate` conforms to `Hashable` (synthesized — all stored properties are `String` and `Int`) for `.navigationDestination(item:)` in `PlayerHoleBreakdownView`.
6. Compare button is gated on `!GuestIdentifier.isGuest(playerID)` — full exclusion from view tree, not just `.opacity(0)`. VoiceOver cannot focus it (AC #4).
7. Sheet-then-push navigation pattern: `HeadToHeadOpponentPickerSheet` on row select → `isShowingOpponentPicker = false` + `selectedOpponent = candidate` → `.navigationDestination(item:)` pushes `HeadToHeadView`. Consistent with `HomeView.swift:373` and `ScorecardContainerView.swift:106`.
8. `init(service:)` testing initializer exercised by `test_viewModel_serviceErrorPath_collapsesToNoData` — non-dead-code (Story 13.2 review patch applied proactively).
9. `xcodegen generate` run after all new files added — `HyzerApp.xcodeproj/project.pbxproj` updated.
10. Build: `** BUILD SUCCEEDED **`, zero SwiftLint violations.
11. Tests: 22 HyzerKit service tests (all pass), 10 HeadToHeadViewModel tests (all pass), 6 HeadToHeadOpponentPickerViewModel tests (all pass). Pre-existing `WatchVoiceViewModel "auto-commit timer"` failure confirmed pre-dates this story (verified via `git stash`).
12. `averageDifferential` sign convention pinned in tests: negative = A averages better; `"E"` for 0.0 differential (via `Standing.formatScore`).
13. `fetchLimit` truncation test places decisive A-win at OLDEST index (index 0 of 600), verifies it is excluded from the most-recent 500 window. Correct direction (not tautological) per Story 13.2 review patch guidance.

### File List

- `HyzerKit/Sources/HyzerKit/Domain/HeadToHeadService.swift` (new)
- `HyzerKit/Tests/HyzerKitTests/Domain/HeadToHeadServiceTests.swift` (new)
- `HyzerApp/ViewModels/HeadToHeadViewModel.swift` (new)
- `HyzerApp/ViewModels/HeadToHeadOpponentPickerViewModel.swift` (new)
- `HyzerApp/Views/History/HeadToHeadView.swift` (new)
- `HyzerApp/Views/History/HeadToHeadOpponentPickerSheet.swift` (new)
- `HyzerAppTests/ViewModels/HeadToHeadViewModelTests.swift` (new)
- `HyzerApp/Views/History/PlayerHoleBreakdownView.swift` (modified — Compare button + sheet + navigationDestination)
- `HyzerApp.xcodeproj/project.pbxproj` (auto-regenerated by xcodegen)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — 13.3 in-progress → review)
- `_bmad-output/implementation-artifacts/13-3-head-to-head-record-between-two-players.md` (status updated)

### Change Log

- 2026-05-18: Story 13.3 implemented — HeadToHeadService (HyzerKit), HeadToHeadViewModel + HeadToHeadOpponentPickerViewModel (HyzerApp), HeadToHeadView + HeadToHeadOpponentPickerSheet (History views), Compare entry point on PlayerHoleBreakdownView (guest-gated), 38 new tests (22 HyzerKit + 16 HyzerApp).

### Review Findings

Code review on 2026-05-18 by `bmad-code-review` skill. Sources: Blind Hunter (adversarial), Edge Case Hunter (path enumeration), Acceptance Auditor (spec-aware). Triage: 1 decision-needed, 10 patches, 8 defers, ~15 dismissed as noise/spec-mandated.

- [x] [Review][Decision-Resolved] AC #9 spec template ambiguity for VoiceOver percent — **Resolved 2026-05-18: keep current `"100%"` behavior.** Spec AC #1 vs AC #9 internal contradiction noted (`<percentA>` is pre-formatted `"43%"` per AC #1; AC #9 template `<percentA> percent` would yield awkward `"100% percent"` under strict substitution). Current implementation drops the redundant literal `"percent"` word and relies on iOS VoiceOver to pronounce the `%` glyph. No code change. [`HeadToHeadViewModel.swift:56`]
- [x] [Review][Patch] `playerAName` is a dead parameter in `HeadToHeadOpponentPickerSheet` — fixed: now used as `"Compare \(playerAName) with…"` in the nav title. [`HeadToHeadOpponentPickerSheet.swift:37`]
- [x] [Review][Patch] Fabricated `"~10ms first call per Apple docs"` benchmark in `percentFormatter` comment — fixed: replaced with a qualitative note. [`HeadToHeadViewModel.swift:64`]
- [x] [Review][Patch] `Dictionary(uniqueKeysWithValues:)` traps on duplicate Player UUIDs which CloudKit replay can legitimately produce — fixed: switched to `Dictionary(_:uniquingKeysWith: { first, _ in first })`. [`HeadToHeadService.swift:241-245`]
- [x] [Review][Patch] `compute()` and `loadCandidates()` retry leaves stale `errorMessage` and `hasComputed` from prior failure — fixed: both methods now reset `errorMessage = nil` and `hasComputed = false` at the top. Picker also clears `candidates`. [`HeadToHeadViewModel.swift:100-112`, `HeadToHeadOpponentPickerViewModel.swift:39-52`]
- [x] [Review][Patch] `computeRecord(for:against:)` does not guard `playerAID == playerBID` self-compare — fixed: early-return with empty record + `logger.notice`. [`HeadToHeadService.swift:71-80`]
- [x] [Review][Patch] `findOpponentCandidates` iterates `round.playerIDs` ([String]) — fixed: wrapped with `Set(round.playerIDs)` to avoid inflating `roundsTogether` on duplicate IDs. [`HeadToHeadService.swift:219`]
- [x] [Review][Patch] Non-UUID `peerID` strings are silently dropped — fixed: `compactMap` now logs via `logger.notice` when parsing fails. [`HeadToHeadService.swift:226-232`]
- [x] [Review][Patch] Orphan peer silently dropped at `guard let name = nameByID[peerID] else { continue }` — fixed: now logs via `logger.notice`. [`HeadToHeadService.swift:253-256`]
- [x] [Review][Patch] AC #5 sort test missing lowercase `"alice"` — fixed: added the case-boundary candidate; test now asserts `alice < Bob < charlie < DAVE`. [`HeadToHeadServiceTests.swift:728-752`]
- [x] [Review][Patch] AC #8 error-path test only exercised the empty-store branch — fixed: introduced `HeadToHeadServicing` protocol; test now uses `ThrowingHeadToHeadServiceStub` to actually exercise the `catch` branch (`errorMessage == "Unable to load head-to-head record."` + `hasNoData == true`). [`HeadToHeadViewModelTests.swift:269-308`, `HeadToHeadService.swift:29-34`]
- [x] [Review][Defer] `#Predicate { sharedRoundIDs.contains($0.id) }` may approach SQLite IN-clause limits when `sharedRoundIDs.count` is large — pre-existing PlayerTrendService/PersonalBestService pattern. Needs systematic review across all three services.
- [x] [Review][Defer] `fetchLimit = maxRounds * 20` magic multiplier assumes ~18-hole rounds with limited conflict resolution — pre-existing PlayerTrendService/PersonalBestService pattern; deserves a single shared, documented constant.
- [x] [Review][Defer] `StandingsEngine.recompute` failure cannot be distinguished from "player legitimately not in round" (both produce empty `currentStandings`) — pre-existing pattern; reconsider when the engine surfaces a recoverable error signal.
- [x] [Review][Defer] `trigger: .localScore` passed when recomputing historical rounds is semantically inaccurate — pre-existing pattern; risk surfaces only if a future side-effect is keyed on `.localScore`.
- [x] [Review][Defer] No `Task.isCancelled` checks inside the per-round loop in `computeRecord` — pre-existing pattern; user navigating away pays full compute cost.
- [x] [Review][Defer] `init(service:)` "NOT used in production" relies on doc comment only — could be `#if DEBUG` gated. Pre-existing pattern from Stories 13.1/13.2.
- [x] [Review][Defer] Tests rely on `parByHole[n] ?? 3` fallback in `StandingsEngine` instead of inserting `Hole` rows — project-wide test pattern; coupling that would silently green-test through an engine refactor.
- [x] [Review][Defer] `Standing.formatScore`'s `"E"` is pronounced as the letter "E" by VoiceOver rather than "even par" — pre-existing tech debt acknowledged in CLAUDE.md.
