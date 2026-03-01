import Testing
import Foundation
import Observation
@testable import HyzerKit

// MARK: - Mock provider

@MainActor
@Observable
final class MockWatchStandingsProvider: WatchStandingsObservable {
    var currentSnapshot: StandingsSnapshot?
    var isPhoneReachable: Bool = false
}

// MARK: - WatchLeaderboardViewModel tests

@Suite("WatchLeaderboardViewModel")
@MainActor
struct WatchLeaderboardViewModelTests {

    private func makeStandings(count: Int = 2) -> [Standing] {
        (0..<count).map { i in
            Standing(
                playerID: "player-\(i)",
                playerName: "Player \(i)",
                position: i + 1,
                totalStrokes: 30 + i,
                holesPlayed: 9,
                scoreRelativeToPar: i - 3
            )
        }
    }

    private func makeSnapshot(
        standings: [Standing] = [],
        hole: Int = 1,
        date: Date = Date()
    ) -> StandingsSnapshot {
        StandingsSnapshot(standings: standings, roundID: UUID(), currentHole: hole, lastUpdatedAt: date)
    }

    // MARK: - Task 8.4: standings mapping

    @Test("standings returns empty array when no snapshot")
    func test_standings_emptyWhenNoSnapshot() {
        let provider = MockWatchStandingsProvider()
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.standings.isEmpty)
    }

    @Test("standings reflects snapshot standings")
    func test_standings_reflectsSnapshot() {
        let provider = MockWatchStandingsProvider()
        let expected = makeStandings(count: 3)
        provider.currentSnapshot = makeSnapshot(standings: expected)
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.standings.count == 3)
        #expect(vm.standings[0].playerID == "player-0")
        #expect(vm.standings[2].position == 3)
    }

    // MARK: - Task 8.4: stale detection

    @Test("isStale is false when snapshot is fresh and phone unreachable")
    func test_isStale_false_whenFresh() {
        let provider = MockWatchStandingsProvider()
        provider.isPhoneReachable = false
        provider.currentSnapshot = makeSnapshot(date: Date()) // just now
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.isStale == false)
    }

    @Test("isStale is true when phone unreachable and snapshot is over 30s old")
    func test_isStale_true_whenStale() {
        let provider = MockWatchStandingsProvider()
        provider.isPhoneReachable = false
        let staleDate = Date().addingTimeInterval(-31)
        provider.currentSnapshot = makeSnapshot(date: staleDate)
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.isStale == true)
    }

    @Test("isStale is false when phone is reachable even if snapshot is old")
    func test_isStale_false_whenPhoneReachable() {
        let provider = MockWatchStandingsProvider()
        provider.isPhoneReachable = true
        let staleDate = Date().addingTimeInterval(-60)
        provider.currentSnapshot = makeSnapshot(date: staleDate)
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.isStale == false)
    }

    @Test("isStale is false when no snapshot")
    func test_isStale_false_whenNoSnapshot() {
        let provider = MockWatchStandingsProvider()
        provider.isPhoneReachable = false
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.isStale == false)
    }

    // MARK: - Task 8.4: stale text formatting

    @Test("staleDurationText formats seconds correctly")
    func test_staleDurationText_seconds() {
        let provider = MockWatchStandingsProvider()
        let date = Date().addingTimeInterval(-45)
        provider.currentSnapshot = makeSnapshot(date: date)
        let vm = WatchLeaderboardViewModel(provider: provider)
        // Elapsed ≈ 45 seconds
        #expect(vm.staleDurationText.hasSuffix("s ago"))
    }

    @Test("staleDurationText formats minutes correctly")
    func test_staleDurationText_minutes() {
        let provider = MockWatchStandingsProvider()
        let date = Date().addingTimeInterval(-125) // ~2 minutes
        provider.currentSnapshot = makeSnapshot(date: date)
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.staleDurationText == "2m ago")
    }

    @Test("staleDurationText is empty when no snapshot")
    func test_staleDurationText_emptyWhenNoSnapshot() {
        let provider = MockWatchStandingsProvider()
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.staleDurationText.isEmpty)
    }

    // MARK: - Task 8.5: snapshot update triggers view state change

    @Test("updating snapshot changes standings")
    func test_snapshotUpdate_changesStandings() {
        let provider = MockWatchStandingsProvider()
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.standings.isEmpty)

        provider.currentSnapshot = makeSnapshot(standings: makeStandings(count: 2))
        #expect(vm.standings.count == 2)
    }

    @Test("updating snapshot from stale to fresh clears staleness")
    func test_snapshotUpdate_staleToFresh() {
        let provider = MockWatchStandingsProvider()
        provider.isPhoneReachable = false
        provider.currentSnapshot = makeSnapshot(date: Date().addingTimeInterval(-60))
        let vm = WatchLeaderboardViewModel(provider: provider)
        #expect(vm.isStale == true)

        provider.currentSnapshot = makeSnapshot(date: Date())
        #expect(vm.isStale == false)
    }

    @Test("isConnected reflects phone reachability")
    func test_isConnected_reflectsPhoneReachable() {
        let provider = MockWatchStandingsProvider()
        let vm = WatchLeaderboardViewModel(provider: provider)

        provider.isPhoneReachable = false
        #expect(vm.isConnected == false)

        provider.isPhoneReachable = true
        #expect(vm.isConnected == true)
    }
}

// MARK: - StandingsSnapshot staleness logic tests

@Suite("StandingsSnapshot staleness")
struct StandingsSnapshotStalenessTests {

    @Test("isStale returns false when elapsed < 30s")
    func test_isStale_false_whenFresh() {
        let snapshot = StandingsSnapshot(standings: [], roundID: UUID(), currentHole: 1, lastUpdatedAt: Date())
        #expect(snapshot.isStale(from: Date().addingTimeInterval(29)) == false)
    }

    @Test("isStale returns true when elapsed > 30s")
    func test_isStale_true_whenOld() {
        let snapshot = StandingsSnapshot(standings: [], roundID: UUID(), currentHole: 1, lastUpdatedAt: Date())
        #expect(snapshot.isStale(from: Date().addingTimeInterval(31)) == true)
    }

    @Test("staleDurationText shows seconds for elapsed < 60s")
    func test_staleDurationText_seconds() {
        let reference = Date().addingTimeInterval(1000)
        let snapshot = StandingsSnapshot(
            standings: [],
            roundID: UUID(),
            currentHole: 1,
            lastUpdatedAt: reference.addingTimeInterval(-45)
        )
        #expect(snapshot.staleDurationText(from: reference) == "45s ago")
    }

    @Test("staleDurationText shows minutes for elapsed >= 60s")
    func test_staleDurationText_minutes() {
        let reference = Date().addingTimeInterval(1000)
        let snapshot = StandingsSnapshot(
            standings: [],
            roundID: UUID(),
            currentHole: 1,
            lastUpdatedAt: reference.addingTimeInterval(-120)
        )
        #expect(snapshot.staleDurationText(from: reference) == "2m ago")
    }

    @Test("staleDurationText shows hours for elapsed >= 3600s")
    func test_staleDurationText_hours() {
        let reference = Date().addingTimeInterval(10000)
        let snapshot = StandingsSnapshot(
            standings: [],
            roundID: UUID(),
            currentHole: 1,
            lastUpdatedAt: reference.addingTimeInterval(-7200)
        )
        #expect(snapshot.staleDurationText(from: reference) == "2h ago")
    }
}
