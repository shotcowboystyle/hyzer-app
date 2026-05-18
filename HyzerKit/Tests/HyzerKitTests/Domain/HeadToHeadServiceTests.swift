import Testing
import SwiftData
import Foundation
@testable import HyzerKit

@Suite("HeadToHeadService")
@MainActor
struct HeadToHeadServiceTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        try TestContainerFactory.makeSyncContainer()
    }

    /// Inserts a completed round with per-hole strokes for BOTH players.
    ///
    /// All holes default to par 3 via `StandingsEngine`'s `parByHole[n] ?? 3` fallback.
    /// Insert explicit `Hole` rows only if the test requires a non-default par.
    @discardableResult
    private func insertRound(
        context: ModelContext,
        course: Course,
        playerAID: String,
        playerBID: String,
        strokesA: [Int],
        strokesB: [Int],
        completedAt: Date = Date(timeIntervalSinceNow: -1)
    ) throws -> Round {
        precondition(strokesA.count == strokesB.count, "Both players must have the same hole count")
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerAID, playerBID],
            guestNames: [],
            holeCount: strokesA.count
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = completedAt

        for (index, strokes) in strokesA.enumerated() {
            context.insert(ScoreEvent(
                roundID: round.id,
                holeNumber: index + 1,
                playerID: playerAID,
                strokeCount: strokes,
                reportedByPlayerID: UUID(),
                deviceID: "test"
            ))
        }
        for (index, strokes) in strokesB.enumerated() {
            context.insert(ScoreEvent(
                roundID: round.id,
                holeNumber: index + 1,
                playerID: playerBID,
                strokeCount: strokes,
                reportedByPlayerID: UUID(),
                deviceID: "test"
            ))
        }
        try context.save()
        return round
    }

    /// Inserts a `Player` and returns its UUID string for use as a registered playerID.
    @discardableResult
    private func insertRegisteredPlayer(context: ModelContext, displayName: String) throws -> String {
        let player = Player(displayName: displayName)
        context.insert(player)
        try context.save()
        return player.id.uuidString
    }

    // MARK: - computeRecord: empty / zero cases

    @Test("empty store returns all-zero record, no throw")
    func test_computeRecord_emptyStore_returnsZeroCounts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let service = HeadToHeadService(modelContext: context)

        let record = try service.computeRecord(for: UUID().uuidString, against: UUID().uuidString)

        #expect(record.roundsPlayedTogether == 0)
        #expect(record.winsA == 0)
        #expect(record.winsB == 0)
        #expect(record.ties == 0)
        #expect(record.averageDifferential == nil)
    }

    @Test("two players with completed rounds but no rounds in common returns all-zero record")
    func test_computeRecord_noSharedRounds_returnsZeroCounts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let playerC = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // A played with C; B played with C — but A and B never played each other.
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerC,
                        strokesA: [3, 3], strokesB: [3, 3])
        try insertRound(context: context, course: course, playerAID: playerB, playerBID: playerC,
                        strokesA: [3, 3], strokesB: [3, 3])

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.roundsPlayedTogether == 0)
        #expect(record.winsA == 0)
        #expect(record.winsB == 0)
        #expect(record.ties == 0)
        #expect(record.averageDifferential == nil)
    }

    // MARK: - computeRecord: single-round outcomes

    @Test("one shared round where A has lower strokes → winsA=1, averageDifferential=-2.0")
    func test_computeRecord_oneSharedRound_aWins() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // A=[3,3] (6 total, relToPar=0); B=[4,4] (8 total, relToPar=2); diff=0-2=-2; A wins
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [4, 4])

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.roundsPlayedTogether == 1)
        #expect(record.winsA == 1)
        #expect(record.winsB == 0)
        #expect(record.ties == 0)
        if let diff = record.averageDifferential {
            #expect(abs(diff - (-2.0)) < 0.001)
        } else {
            Issue.record("averageDifferential should not be nil for a completed shared round")
        }
    }

    @Test("one shared round where B has lower strokes → winsB=1, averageDifferential=+2.0")
    func test_computeRecord_oneSharedRound_bWins() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // A=[4,4] (8 total, relToPar=2); B=[3,3] (6 total, relToPar=0); diff=2-0=+2; B wins
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [4, 4], strokesB: [3, 3])

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.roundsPlayedTogether == 1)
        #expect(record.winsA == 0)
        #expect(record.winsB == 1)
        #expect(record.ties == 0)
        if let diff = record.averageDifferential {
            #expect(abs(diff - 2.0) < 0.001)
        } else {
            Issue.record("averageDifferential should not be nil for a completed shared round")
        }
    }

    @Test("one shared round with equal strokes → ties=1, roundsPlayedTogether=1, averageDifferential=0.0")
    func test_computeRecord_oneSharedRound_tied() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // Both [3,3] → tied
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [3, 3])

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.roundsPlayedTogether == 1)
        #expect(record.winsA == 0)
        #expect(record.winsB == 0)
        #expect(record.ties == 1)
        if let diff = record.averageDifferential {
            #expect(abs(diff - 0.0) < 0.001)
        } else {
            Issue.record("averageDifferential should not be nil for a tied shared round")
        }
    }

    // MARK: - computeRecord: multi-round aggregation (AC #1, AC #2)

    @Test("5 shared rounds — A wins 3, B wins 1, tie 1; differential = -0.6")
    func test_computeRecord_multipleRounds_aggregatesCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // differentials: [-2, -1, -1, +1, 0]
        // diff=-2: A=[3,3], B=[4,4]; A wins
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [4, 4],
                        completedAt: Date(timeIntervalSinceReferenceDate: 1000))
        // diff=-1: A=[3,3], B=[3,4]; A wins
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [3, 4],
                        completedAt: Date(timeIntervalSinceReferenceDate: 2000))
        // diff=-1: A=[3,3], B=[3,4]; A wins
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [3, 4],
                        completedAt: Date(timeIntervalSinceReferenceDate: 3000))
        // diff=+1: A=[3,4], B=[3,3]; B wins
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 4], strokesB: [3, 3],
                        completedAt: Date(timeIntervalSinceReferenceDate: 4000))
        // diff=0: A=[3,3], B=[3,3]; tie
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [3, 3],
                        completedAt: Date(timeIntervalSinceReferenceDate: 5000))

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.winsA == 3)
        #expect(record.winsB == 1)
        #expect(record.ties == 1)
        #expect(record.roundsPlayedTogether == 5)
        // averageDifferential = (-2 + -1 + -1 + 1 + 0) / 5 = -3/5 = -0.6
        if let avg = record.averageDifferential {
            #expect(abs(avg - (-0.6)) < 0.001)
        } else {
            Issue.record("averageDifferential should not be nil")
        }
    }

    @Test("invariant: winsA + winsB + ties == roundsPlayedTogether")
    func test_computeRecord_winsPlusTiesEqualsRoundsPlayed() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [4, 4],
                        completedAt: Date(timeIntervalSinceReferenceDate: 1000))
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [3, 4],
                        completedAt: Date(timeIntervalSinceReferenceDate: 2000))
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [3, 4],
                        completedAt: Date(timeIntervalSinceReferenceDate: 3000))
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 4], strokesB: [3, 3],
                        completedAt: Date(timeIntervalSinceReferenceDate: 4000))
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [3, 3],
                        completedAt: Date(timeIntervalSinceReferenceDate: 5000))

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.winsA + record.winsB + record.ties == record.roundsPlayedTogether)
    }

    // MARK: - computeRecord: completed-only filter

    @Test("active round is excluded; only completed round contributes to record")
    func test_computeRecord_excludesNonCompletedRounds() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // Active round: A would win (lower strokes) — must be excluded
        let activeRound = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerA, playerB],
            guestNames: [],
            holeCount: 2
        )
        context.insert(activeRound)
        activeRound.start()  // NOT completed
        context.insert(ScoreEvent(roundID: activeRound.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 2, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: activeRound.id, holeNumber: 2, playerID: playerA,
                                  strokeCount: 2, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: activeRound.id, holeNumber: 1, playerID: playerB,
                                  strokeCount: 4, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: activeRound.id, holeNumber: 2, playerID: playerB,
                                  strokeCount: 4, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        // Completed round: B wins
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [4, 4], strokesB: [3, 3])

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.roundsPlayedTogether == 1)
        #expect(record.winsA == 0)
        #expect(record.winsB == 1)
    }

    // MARK: - computeRecord: holesPlayed > 0 skip guard (AC #7)

    @Test("round where player A has no ScoreEvents is skipped entirely")
    func test_computeRecord_skipsRoundsWithMissingResolvedScoreForA() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // Round 1: A is in playerIDs but has zero ScoreEvents; B has events — should be skipped
        let round1 = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerA, playerB],
            guestNames: [],
            holeCount: 2
        )
        context.insert(round1)
        round1.start()
        round1.complete()
        round1.completedAt = Date(timeIntervalSinceReferenceDate: 1000)
        // Only B has events; A has none
        context.insert(ScoreEvent(roundID: round1.id, holeNumber: 1, playerID: playerB,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: round1.id, holeNumber: 2, playerID: playerB,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        let skippedResult = try service.computeRecord(for: playerA, against: playerB)
        #expect(skippedResult.roundsPlayedTogether == 0)

        // Round 2: both have events — contributes normally
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3, 3], strokesB: [4, 4],
                        completedAt: Date(timeIntervalSinceReferenceDate: 2000))

        let finalResult = try service.computeRecord(for: playerA, against: playerB)
        #expect(finalResult.roundsPlayedTogether == 1)
        #expect(finalResult.winsA == 1)
    }

    @Test("round where player B has no ScoreEvents is skipped entirely")
    func test_computeRecord_skipsRoundsWithMissingResolvedScoreForB() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // Round where B is in playerIDs but has zero ScoreEvents; A has events
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerA, playerB],
            guestNames: [],
            holeCount: 2
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = Date(timeIntervalSinceReferenceDate: 1000)
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 2, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB)

        #expect(record.roundsPlayedTogether == 0)
    }

    // MARK: - computeRecord: fresh engine regression guard (AC #6)

    @Test("source-level guard: StandingsEngine is constructed inside the for-round loop, not above it")
    func test_computeRecord_freshEngineNoStaleStateLeak() throws {
        // The stale-state leak guarded here would corrupt BOTH winner counts AND the
        // differential — a shared engine whose recompute fails on round N would bleed
        // round N-1's standings into round N's aggregation (Story 13.1 patch P2 /
        // Story 13.2 Task 1.2 / Story 13.3 AC #6).
        //
        // The failure mode requires an internal SwiftData exception inside
        // StandingsEngine.recompute which cannot be reliably staged in CI tests.
        // Per spec Task 6.3 fallback, this is a source-level guard.
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Domain/
            .deletingLastPathComponent()  // HyzerKitTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // HyzerKit/
            .appendingPathComponent("Sources/HyzerKit/Domain/HeadToHeadService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let lines = source.components(separatedBy: "\n")
        guard let loopIndex = lines.firstIndex(where: { $0.contains("for round in rounds") }) else {
            Issue.record("expected `for round in rounds` loop in HeadToHeadService.swift")
            return
        }
        let loopBody = lines[loopIndex..<lines.endIndex]
        let constructorLine = loopBody.first(where: { $0.contains("let engine = StandingsEngine(") })
        #expect(constructorLine != nil,
                "StandingsEngine must be constructed fresh inside `for round in rounds` — see AC #6 and Story 13.1 patch P2")
    }

    // MARK: - computeRecord: guest pairs are opaque (service level)

    @Test("computeRecord with a guest opponent returns a valid record — guest filtering is a UI concern")
    func test_computeRecord_includesGuestPairOK_butGuestsAreRoundScoped() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let guestID = GuestIdentifier.makeID()
        let course = Course(name: "Test", holeCount: 2, isSeeded: false)
        context.insert(course)

        // Round with registered A and guest B — both have events
        let round = Round(
            courseID: course.id,
            organizerID: UUID(),
            playerIDs: [playerA],
            guestNames: ["Guest"],
            holeCount: 2,
            guestIDs: [guestID]
        )
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = Date(timeIntervalSinceReferenceDate: 1000)
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 2, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: guestID,
                                  strokeCount: 4, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: round.id, holeNumber: 2, playerID: guestID,
                                  strokeCount: 4, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        // Service treats playerID as opaque — computeRecord does not check GuestIdentifier.isGuest.
        let record = try service.computeRecord(for: playerA, against: guestID)

        #expect(record.roundsPlayedTogether == 1)
        #expect(record.winsA == 1)  // A: 6 strokes (E), guest: 8 strokes (+2) → A wins
    }

    // MARK: - computeRecord: fetchLimit bounds (AC #2)

    @Test("600 completed rounds for player A only — no throw, zero shared rounds returned")
    func test_computeRecord_respectsFetchLimit_eventsA() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // 600 rounds where only player A has events; B has none → intersection is empty
        for i in 0..<600 {
            let round = Round(
                courseID: course.id,
                organizerID: UUID(),
                playerIDs: [playerA],
                guestNames: [],
                holeCount: 1
            )
            context.insert(round)
            round.start()
            round.complete()
            round.completedAt = Date(timeIntervalSinceReferenceDate: Double(i) * 60)
            context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: playerA,
                                      strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        }
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB, maxRounds: 500)

        #expect(record.roundsPlayedTogether == 0)
    }

    @Test("fetchLimit truncation keeps most-recent 500 rounds; decisive oldest round is dropped")
    func test_computeRecord_respectsFetchLimit_truncatesToMostRecent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let playerB = UUID().uuidString
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // Insert 600 shared rounds, completedAt ascending (index 0 = oldest).
        // Index 0 (OLDEST): A wins decisively — must be DROPPED by fetchLimit=500.
        // Indices 1-599: all ties.
        // With fetchLimit=500 (most-recent 500), we keep indices 100-599 → 500 ties.
        // If fetchLimit is ignored, winsA would be 1 (the oldest round leaks in).
        for i in 0..<600 {
            let strokesA: Int = (i == 0) ? 2 : 3  // index 0: A wins; all others: tie
            let strokesB: Int = (i == 0) ? 4 : 3

            let round = Round(
                courseID: course.id,
                organizerID: UUID(),
                playerIDs: [playerA, playerB],
                guestNames: [],
                holeCount: 1
            )
            context.insert(round)
            round.start()
            round.complete()
            round.completedAt = Date(timeIntervalSinceReferenceDate: Double(i) * 60)
            context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: playerA,
                                      strokeCount: strokesA, reportedByPlayerID: UUID(), deviceID: "test"))
            context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: playerB,
                                      strokeCount: strokesB, reportedByPlayerID: UUID(), deviceID: "test"))
        }
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        let record = try service.computeRecord(for: playerA, against: playerB, maxRounds: 500)

        // The oldest A-win (index 0) must be outside the most-recent 500 window.
        #expect(record.winsA == 0)
        #expect(record.ties == 500)
        #expect(record.roundsPlayedTogether == 500)
    }

    // MARK: - findOpponentCandidates: empty / zero cases

    @Test("empty store returns empty candidate list")
    func test_findCandidates_emptyStore_returnsEmpty() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let service = HeadToHeadService(modelContext: context)

        let candidates = try service.findOpponentCandidates(for: UUID().uuidString)

        #expect(candidates.isEmpty)
    }

    @Test("all rounds are solo or guest-only → returns empty candidate list")
    func test_findCandidates_noPeersBecauseAllRoundsSoloOrGuestOnly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = UUID().uuidString
        let guestID = GuestIdentifier.makeID()
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // Solo round — only A
        let soloRound = Round(courseID: course.id, organizerID: UUID(),
                              playerIDs: [playerA], guestNames: [], holeCount: 1)
        context.insert(soloRound)
        soloRound.start()
        soloRound.complete()
        soloRound.completedAt = Date(timeIntervalSinceReferenceDate: 1000)
        context.insert(ScoreEvent(roundID: soloRound.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))

        // Guest-only round — A + guest (guest is in guestIDs, not playerIDs)
        let guestRound = Round(courseID: course.id, organizerID: UUID(),
                               playerIDs: [playerA], guestNames: ["Guest"], holeCount: 1,
                               guestIDs: [guestID])
        context.insert(guestRound)
        guestRound.start()
        guestRound.complete()
        guestRound.completedAt = Date(timeIntervalSinceReferenceDate: 2000)
        context.insert(ScoreEvent(roundID: guestRound.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: guestRound.id, holeNumber: 1, playerID: guestID,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        let candidates = try service.findOpponentCandidates(for: playerA)

        #expect(candidates.isEmpty)
    }

    @Test("candidate list never includes player A themselves")
    func test_findCandidates_excludesSelf() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        let playerB = try insertRegisteredPlayer(context: context, displayName: "Bob")
        let playerC = try insertRegisteredPlayer(context: context, displayName: "Charlie")
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3], strokesB: [3])
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerC,
                        strokesA: [3], strokesB: [3])

        let service = HeadToHeadService(modelContext: context)
        let candidates = try service.findOpponentCandidates(for: playerA)

        let ids = candidates.map(\.playerID)
        #expect(ids.contains(playerB))
        #expect(ids.contains(playerC))
        #expect(!ids.contains(playerA))
    }

    @Test("guests in guestIDs are excluded from candidate list (AC #5 + AC #4)")
    func test_findCandidates_excludesGuests() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        let playerB = try insertRegisteredPlayer(context: context, displayName: "Bob")
        let guestID = GuestIdentifier.makeID()
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // A played with registered B → B is a candidate
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                        strokesA: [3], strokesB: [3])

        // A played with guest (in guestIDs, not playerIDs) → guest must NOT appear
        let guestRound = Round(courseID: course.id, organizerID: UUID(),
                               playerIDs: [playerA], guestNames: ["Guest"], holeCount: 1,
                               guestIDs: [guestID])
        context.insert(guestRound)
        guestRound.start()
        guestRound.complete()
        guestRound.completedAt = Date(timeIntervalSinceReferenceDate: 2000)
        context.insert(ScoreEvent(roundID: guestRound.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: guestRound.id, holeNumber: 1, playerID: guestID,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        let candidates = try service.findOpponentCandidates(for: playerA)

        #expect(candidates.count == 1)
        #expect(candidates[0].playerID == playerB)
    }

    @Test("non-completed rounds excluded from candidate discovery")
    func test_findCandidates_excludesNonCompletedRounds() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        let playerB = try insertRegisteredPlayer(context: context, displayName: "Bob")
        let playerC = try insertRegisteredPlayer(context: context, displayName: "Charlie")
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // Active round with B — must be excluded
        let activeRound = Round(courseID: course.id, organizerID: UUID(),
                                playerIDs: [playerA, playerB], guestNames: [], holeCount: 1)
        context.insert(activeRound)
        activeRound.start()  // NOT completed
        context.insert(ScoreEvent(roundID: activeRound.id, holeNumber: 1, playerID: playerA,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        context.insert(ScoreEvent(roundID: activeRound.id, holeNumber: 1, playerID: playerB,
                                  strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        try context.save()

        // Completed round with C — must be included
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerC,
                        strokesA: [3], strokesB: [3])

        let service = HeadToHeadService(modelContext: context)
        let candidates = try service.findOpponentCandidates(for: playerA)

        #expect(candidates.count == 1)
        #expect(candidates[0].playerID == playerC)
    }

    @Test("roundsTogether count accumulates correctly across multiple rounds")
    func test_findCandidates_countsRoundsTogetherCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        let playerB = try insertRegisteredPlayer(context: context, displayName: "Bob")
        let playerC = try insertRegisteredPlayer(context: context, displayName: "Charlie")
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // A played 3 rounds with B
        for i in 0..<3 {
            try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerB,
                            strokesA: [3], strokesB: [3],
                            completedAt: Date(timeIntervalSinceReferenceDate: Double(i) * 1000))
        }
        // A played 1 round with C
        try insertRound(context: context, course: course, playerAID: playerA, playerBID: playerC,
                        strokesA: [3], strokesB: [3])

        let service = HeadToHeadService(modelContext: context)
        let candidates = try service.findOpponentCandidates(for: playerA)

        #expect(candidates.count == 2)
        let bCandidate = candidates.first(where: { $0.playerID == playerB })
        let cCandidate = candidates.first(where: { $0.playerID == playerC })
        #expect(bCandidate?.roundsTogether == 3)
        #expect(cCandidate?.roundsTogether == 1)
    }

    @Test("candidates sorted case-insensitively ascending by displayName (AC #5)")
    func test_findCandidates_sortedAlphabeticallyCaseInsensitive() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        // Lowercase "alice" is a DISTINCT player from "Alice" (player A) and tests case-insensitive
        // ordering at the mixed lower/upper boundary per spec Task 6.4.
        let aliceLower = try insertRegisteredPlayer(context: context, displayName: "alice")
        let bob = try insertRegisteredPlayer(context: context, displayName: "Bob")
        let charlie = try insertRegisteredPlayer(context: context, displayName: "charlie")
        let dave = try insertRegisteredPlayer(context: context, displayName: "DAVE")
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        for peer in [aliceLower, bob, charlie, dave] {
            try insertRound(context: context, course: course, playerAID: playerA, playerBID: peer,
                            strokesA: [3], strokesB: [3])
        }

        let service = HeadToHeadService(modelContext: context)
        let candidates = try service.findOpponentCandidates(for: playerA)

        #expect(candidates.count == 4)
        // Case-insensitive ascending: alice < Bob < charlie < DAVE
        #expect(candidates[0].playerID == aliceLower)
        #expect(candidates[1].playerID == bob)
        #expect(candidates[2].playerID == charlie)
        #expect(candidates[3].playerID == dave)
    }

    @Test("orphan peer ID (no matching Player row) is silently dropped — no throw")
    func test_findCandidates_dropsOrphanPeerIDs() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let playerA = try insertRegisteredPlayer(context: context, displayName: "Alice")
        let orphanID = UUID().uuidString  // no Player row inserted for this ID
        let playerB = try insertRegisteredPlayer(context: context, displayName: "Bob")
        let course = Course(name: "Test", holeCount: 1, isSeeded: false)
        context.insert(course)

        // Round including an orphan UUID in playerIDs — no Player row exists for it
        let round = Round(courseID: course.id, organizerID: UUID(),
                          playerIDs: [playerA, orphanID, playerB], guestNames: [], holeCount: 1)
        context.insert(round)
        round.start()
        round.complete()
        round.completedAt = Date(timeIntervalSinceReferenceDate: 1000)
        for pid in [playerA, orphanID, playerB] {
            context.insert(ScoreEvent(roundID: round.id, holeNumber: 1, playerID: pid,
                                      strokeCount: 3, reportedByPlayerID: UUID(), deviceID: "test"))
        }
        try context.save()

        let service = HeadToHeadService(modelContext: context)
        let candidates = try service.findOpponentCandidates(for: playerA)

        // Orphan peer dropped; only Bob with a real Player row should appear
        #expect(candidates.count == 1)
        #expect(candidates[0].playerID == playerB)
    }
}
