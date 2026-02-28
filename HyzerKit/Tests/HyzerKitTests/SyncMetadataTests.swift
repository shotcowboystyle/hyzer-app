import Testing
import Foundation
import SwiftData
@testable import HyzerKit

@Suite("SyncMetadata model")
struct SyncMetadataTests {

    // MARK: - Default values

    @Test("init sets recordID, recordType and defaults remaining fields")
    func test_init_setsRequiredFields_andDefaults() {
        let meta = SyncMetadata(recordID: "abc-123", recordType: "ScoreEvent")

        #expect(meta.recordID == "abc-123")
        #expect(meta.recordType == "ScoreEvent")
        #expect(meta.syncStatus == .pending)
        #expect(meta.lastAttempt == nil)
        #expect(meta.createdAt <= Date())
        #expect(meta.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    // MARK: - State transitions

    @Test("syncStatus transitions from pending to inFlight")
    func test_syncStatus_pending_to_inFlight() {
        let meta = SyncMetadata(recordID: "r1", recordType: "ScoreEvent")
        #expect(meta.syncStatus == .pending)

        meta.syncStatus = .inFlight
        meta.lastAttempt = Date()
        #expect(meta.syncStatus == .inFlight)
        #expect(meta.lastAttempt != nil)
    }

    @Test("syncStatus transitions from inFlight to synced")
    func test_syncStatus_inFlight_to_synced() {
        let meta = SyncMetadata(recordID: "r1", recordType: "ScoreEvent")
        meta.syncStatus = .inFlight
        meta.syncStatus = .synced
        #expect(meta.syncStatus == .synced)
    }

    @Test("syncStatus transitions from inFlight to failed on error")
    func test_syncStatus_inFlight_to_failed() {
        let meta = SyncMetadata(recordID: "r1", recordType: "ScoreEvent")
        meta.syncStatus = .inFlight
        meta.syncStatus = .failed
        #expect(meta.syncStatus == .failed)
    }

    @Test("SyncStatus raw values match expected strings")
    func test_syncStatus_rawValues() {
        #expect(SyncStatus.pending.rawValue == "pending")
        #expect(SyncStatus.inFlight.rawValue == "inFlight")
        #expect(SyncStatus.synced.rawValue == "synced")
        #expect(SyncStatus.failed.rawValue == "failed")
    }

    @Test("SyncStatus is Codable")
    func test_syncStatus_codable() throws {
        let encoded = try JSONEncoder().encode(SyncStatus.inFlight)
        let decoded = try JSONDecoder().decode(SyncStatus.self, from: encoded)
        #expect(decoded == .inFlight)
    }

    // MARK: - SwiftData persistence

    @Test("SyncMetadata persists and fetches in SwiftData (in-memory)")
    @MainActor
    func test_syncMetadata_persistsAndFetches() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SyncMetadata.self, configurations: config)
        let context = ModelContext(container)

        let meta = SyncMetadata(recordID: "event-uuid-string", recordType: "ScoreEvent")
        meta.syncStatus = .synced
        context.insert(meta)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SyncMetadata>())
        #expect(fetched.count == 1)
        #expect(fetched[0].recordID == "event-uuid-string")
        #expect(fetched[0].recordType == "ScoreEvent")
        #expect(fetched[0].syncStatus == .synced)
    }

    @Test("multiple SyncMetadata entries for different records coexist")
    @MainActor
    func test_syncMetadata_multipleEntriesCoexist() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SyncMetadata.self, configurations: config)
        let context = ModelContext(container)

        for i in 0..<5 {
            let meta = SyncMetadata(recordID: "id-\(i)", recordType: "ScoreEvent")
            meta.syncStatus = i % 2 == 0 ? .pending : .synced
            context.insert(meta)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SyncMetadata>())
        #expect(fetched.count == 5)
        let pending = fetched.filter { $0.syncStatus == .pending }
        let synced = fetched.filter { $0.syncStatus == .synced }
        #expect(pending.count == 3)
        #expect(synced.count == 2)
    }
}
