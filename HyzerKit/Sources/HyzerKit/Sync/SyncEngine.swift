import Foundation
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "SyncEngine")

/// Manages CloudKit sync for `ScoreEvent` records.
///
/// **Actor** — serialises access to `SyncMetadata` and in-flight CloudKit operations.
/// Conforms to `ModelActor` (equivalent to `@ModelActor`) with a custom init that
/// also accepts `CloudKitClient` and `StandingsEngine` dependencies.
/// Uses a background `ModelContext` via `DefaultSerialModelExecutor` — never the main context.
///
/// Push pipeline:
///   local ScoreEvent + SyncMetadata(.pending)
///   → `pushPending()` marks `.inFlight` BEFORE `await`
///   → `CloudKitClient.save()`
///   → marks `.synced` on success / `.failed` on error
///
/// Pull pipeline:
///   `pullRecords()` fetches remote CKRecords
///   → converts via `ScoreEventRecord`
///   → inserts new ScoreEvents into SwiftData
///   → calls `StandingsEngine.recompute(for:trigger:.remoteSync)`
public actor SyncEngine: ModelActor {
    // MARK: - ModelActor protocol requirements

    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer
    public var modelContext: ModelContext { modelExecutor.modelContext }

    // MARK: - Dependencies

    private let cloudKitClient: any CloudKitClient
    private let standingsEngine: StandingsEngine

    // MARK: - Observable state

    /// Reflects the current sync phase. Observed by future `SyncIndicatorView` (Story 4.2).
    public private(set) var syncState: SyncState = .idle

    // MARK: - Init

    public init(
        cloudKitClient: any CloudKitClient,
        standingsEngine: StandingsEngine,
        modelContainer: ModelContainer
    ) {
        self.cloudKitClient = cloudKitClient
        self.standingsEngine = standingsEngine
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = modelContainer
    }

    // MARK: - Public API

    /// Entry point called at app startup. Flushes any pending pushes and pulls remote changes.
    public func start() async {
        await pushPending()
        await pullRecords()
    }

    /// Pushes all `.pending` `SyncMetadata` entries to CloudKit.
    ///
    /// `.inFlight` status is set **before** the `await CloudKitClient.save()` call.
    /// This is the reentrancy guard described in Amendment A1: a second concurrent call
    /// to `pushPending()` will skip entries already marked `.inFlight`.
    public func pushPending() async {
        let pendingEntries = fetchAllMetadata().filter { $0.syncStatus == .pending }
        guard !pendingEntries.isEmpty else { return }

        // CRITICAL: Mark .inFlight BEFORE the async CloudKit call (AC4 / Amendment A1)
        let now = Date()
        for entry in pendingEntries {
            entry.syncStatus = .inFlight
            entry.lastAttempt = now
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("SyncEngine.pushPending: failed to persist .inFlight status: \(error)")
            return
        }

        // Build CKRecords for each in-flight entry (spike: ScoreEvent records only)
        var batch: [(metadata: SyncMetadata, record: CKRecord)] = []
        for entry in pendingEntries {
            guard entry.recordType == ScoreEventRecord.recordType else { continue }
            guard let eventID = UUID(uuidString: entry.recordID) else { continue }
            let all = fetchAllScoreEvents()
            guard let event = all.first(where: { $0.id == eventID }) else { continue }
            batch.append((entry, ScoreEventRecord(from: event).toCKRecord()))
        }

        guard !batch.isEmpty else {
            // No matching domain objects — mark as synced to unblock the pipeline
            for entry in pendingEntries { entry.syncStatus = .synced }
            try? modelContext.save()
            return
        }

        syncState = .syncing
        do {
            _ = try await cloudKitClient.save(batch.map(\.record))
            for (entry, _) in batch { entry.syncStatus = .synced }
            try modelContext.save()
            syncState = .idle
            logger.info("SyncEngine.pushPending: pushed \(batch.count) record(s)")
        } catch let ckError as CKError {
            for (entry, _) in batch { entry.syncStatus = .failed }
            try? modelContext.save()
            syncState = isNetworkError(ckError) ? .offline : .error(SyncError.cloudKitFailure(ckError))
            logger.error("SyncEngine.pushPending: CloudKit error: \(ckError)")
        } catch {
            for (entry, _) in batch { entry.syncStatus = .failed }
            try? modelContext.save()
            syncState = .idle
            logger.error("SyncEngine.pushPending: unexpected error: \(error)")
        }
    }

    /// Pulls new `ScoreEvent` records from CloudKit and inserts them locally.
    ///
    /// Deduplicates by `ScoreEvent.id` — existing local events are never overwritten
    /// (event-sourcing append-only invariant, NFR19).
    /// After insertion, calls `StandingsEngine.recompute()` for every affected round.
    public func pullRecords() async {
        syncState = .syncing
        let query = CKQuery(
            recordType: ScoreEventRecord.recordType,
            predicate: NSPredicate(value: true)
        )
        let fetched: [CKRecord]
        do {
            fetched = try await cloudKitClient.fetch(matching: query, in: nil)
        } catch let ckError as CKError {
            syncState = isNetworkError(ckError) ? .offline : .error(SyncError.cloudKitFailure(ckError))
            logger.error("SyncEngine.pullRecords: CloudKit fetch error: \(ckError)")
            return
        } catch {
            syncState = .idle
            logger.error("SyncEngine.pullRecords: unexpected error: \(error)")
            return
        }

        let existingIDs = Set(fetchAllScoreEvents().map(\.id))
        var affectedRoundIDs: Set<UUID> = []

        for ckRecord in fetched {
            guard let dto = ScoreEventRecord(from: ckRecord) else { continue }
            guard !existingIDs.contains(dto.id) else { continue }   // deduplicate

            let event = ScoreEvent(
                roundID: dto.roundID,
                holeNumber: dto.holeNumber,
                playerID: dto.playerID,
                strokeCount: dto.strokeCount,
                reportedByPlayerID: dto.reportedByPlayerID,
                deviceID: dto.deviceID
            )
            // Preserve original id and timestamp from the remote record
            event.id = dto.id
            event.createdAt = dto.createdAt
            if let supersedesID = dto.supersedesEventID {
                event.supersedesEventID = supersedesID
            }
            modelContext.insert(event)

            // Record inbound sync metadata as .synced (it's already in CloudKit)
            let meta = SyncMetadata(recordID: dto.id.uuidString, recordType: ScoreEventRecord.recordType)
            meta.syncStatus = .synced
            modelContext.insert(meta)

            affectedRoundIDs.insert(dto.roundID)
        }

        guard !affectedRoundIDs.isEmpty else {
            syncState = .idle
            return
        }

        do {
            try modelContext.save()
        } catch {
            logger.error("SyncEngine.pullRecords: save failed: \(error)")
            syncState = .idle
            return
        }

        // Hop to MainActor to recompute standings for each affected round (AC2)
        for roundID in affectedRoundIDs {
            await standingsEngine.recompute(for: roundID, trigger: .remoteSync)
        }
        syncState = .idle
        logger.info("SyncEngine.pullRecords: inserted events for \(affectedRoundIDs.count) round(s)")
    }

    // MARK: - Private helpers

    private func fetchAllMetadata() -> [SyncMetadata] {
        (try? modelContext.fetch(FetchDescriptor<SyncMetadata>())) ?? []
    }

    private func fetchAllScoreEvents() -> [ScoreEvent] {
        (try? modelContext.fetch(FetchDescriptor<ScoreEvent>())) ?? []
    }

    private func isNetworkError(_ error: CKError) -> Bool {
        error.code == .networkUnavailable || error.code == .networkFailure
    }
}
