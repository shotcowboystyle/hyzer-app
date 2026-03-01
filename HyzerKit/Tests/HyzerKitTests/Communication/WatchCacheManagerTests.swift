import Testing
import Foundation
@testable import HyzerKit

@Suite("WatchCacheManager")
@MainActor
struct WatchCacheManagerTests {

    // MARK: - Helpers

    private func makeManager(url: URL?) -> WatchCacheManager {
        WatchCacheManager(cacheURL: url)
    }

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    private func makeSnapshot(hole: Int = 1, par: Int = 3) -> StandingsSnapshot {
        StandingsSnapshot(
            standings: [
                Standing(playerID: "p1", playerName: "Alice", position: 1, totalStrokes: 33, holesPlayed: 9, scoreRelativeToPar: -3)
            ],
            roundID: UUID(),
            currentHole: hole,
            currentHolePar: par,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - Save / load roundtrip

    @Test("save and loadLatest returns the same snapshot")
    func test_saveAndLoad_roundtrip() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let manager = makeManager(url: url)
        let snapshot = makeSnapshot(hole: 5)

        try manager.save(snapshot)
        let loaded = manager.loadLatest()

        #expect(loaded == snapshot)
    }

    @Test("currentHolePar is preserved through save/load roundtrip")
    func test_saveAndLoad_preservesCurrentHolePar() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let manager = makeManager(url: url)
        let snapshot = makeSnapshot(hole: 3, par: 5)

        try manager.save(snapshot)
        let loaded = manager.loadLatest()

        #expect(loaded?.currentHolePar == 5)
    }

    @Test("save overwrites previous snapshot with newest data")
    func test_save_overwritesPrevious() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let manager = makeManager(url: url)

        try manager.save(makeSnapshot(hole: 3))
        let newer = makeSnapshot(hole: 9)
        try manager.save(newer)

        let loaded = manager.loadLatest()
        #expect(loaded?.currentHole == 9)
    }

    // MARK: - Missing file returns nil

    @Test("loadLatest returns nil when no file exists")
    func test_load_noFile_returnsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")
        let manager = makeManager(url: url)
        #expect(manager.loadLatest() == nil)
    }

    // MARK: - Corrupted file returns nil

    @Test("loadLatest returns nil when file contains invalid JSON")
    func test_load_corruptedFile_returnsNil() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "not-valid-json".data(using: .utf8)!.write(to: url)
        let manager = makeManager(url: url)
        #expect(manager.loadLatest() == nil)
    }

    @Test("loadLatest returns nil when file contains unexpected JSON structure")
    func test_load_unexpectedStructure_returnsNil() throws {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try #"{"foo": "bar"}"#.data(using: .utf8)!.write(to: url)
        let manager = makeManager(url: url)
        #expect(manager.loadLatest() == nil)
    }

    // MARK: - Nil URL (unavailable container)

    @Test("save with nil URL is a no-op")
    func test_save_nilURL_isNoOp() throws {
        let manager = makeManager(url: nil)
        try manager.save(makeSnapshot()) // Should not throw
    }

    @Test("loadLatest with nil URL returns nil")
    func test_load_nilURL_returnsNil() {
        let manager = makeManager(url: nil)
        #expect(manager.loadLatest() == nil)
    }
}
