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

    /// Reflects the current sync phase. Observed via `syncStateStream` by AppServices.
    public private(set) var syncState: SyncState = .idle {
        didSet { stateContinuation.yield(syncState) }
    }

    /// Continuation that feeds `syncStateStream`.
    private let stateContinuation: AsyncStream<SyncState>.Continuation

    /// Async stream that emits whenever `syncState` changes.
    ///
    /// Consumed by a `@MainActor` task in `AppServices` to bridge actor-isolated state
    /// to the `@Observable` `syncState` property visible to SwiftUI views.
    ///
    /// Single-subscriber: only one task should consume this stream at a time.
    public let syncStateStream: AsyncStream<SyncState>

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

        // Create the state stream and continuation together so they're always in sync.
        let (stream, continuation) = AsyncStream<SyncState>.makeStream()
        self.syncStateStream = stream
        self.stateContinuation = continuation
    }

    // MARK: - Public API

    /// Entry point called at app startup. Flushes any pending pushes and pulls remote changes.
    public func start() async {
        await pushPending()
        await pullRecords()
    }

    /// Resets all `.failed` entries to `.pending` and flushes them via `pushPending()`.
    ///
    /// Called by `SyncScheduler` when connectivity is restored after an offline period.
    /// The explicit `.pending` reset creates a clean state-machine transition that allows
    /// subsequent `pushPending()` calls to pick them up even if the caller doesn't call
    /// `retryFailed()` first.
    public func retryFailed() async {
        let failedEntries = fetchAllMetadata().filter { $0.syncStatus == .failed }
        guard !failedEntries.isEmpty else { return }

        for entry in failedEntries {
            entry.syncStatus = .pending
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("SyncEngine.retryFailed: failed to reset .failed entries to .pending: \(error)")
            return
        }
        logger.info("SyncEngine.retryFailed: reset \(failedEntries.count) .failed entries to .pending")
        await pushPending()
    }

    /// Pushes all `.pending` and `.failed` `SyncMetadata` entries to CloudKit.
    ///
    /// Picks up both `.pending` and `.failed` entries for belt-and-suspenders coverage.
    /// `.retryFailed()` resets entries explicitly; this method handles any that slipped through.
    ///
    /// `.inFlight` status is set **before** the `await CloudKitClient.save()` call.
    /// This is the reentrancy guard described in Amendment A1: a second concurrent call
    /// to `pushPending()` will skip entries already marked `.inFlight`.
    public func pushPending() async {
        let pendingEntries = fetchAllMetadata().filter {
            $0.syncStatus == .pending || $0.syncStatus == .failed
        }
        guard !pendingEntries.isEmpty else { return }

        // Scope event fetch to only ScoreEvent IDs referenced by pending entries
        let pendingEventIDs = Set(
            pendingEntries
                .filter { $0.recordType == ScoreEventRecord.recordType }
                .compactMap { UUID(uuidString: $0.recordID) }
        )
        let allEvents = fetchScoreEvents(withIDs: pendingEventIDs)
        let eventsByID = Dictionary(uniqueKeysWithValues: allEvents.map { ($0.id, $0) })

        // Build batch FIRST to identify which entries can actually be pushed.
        // Only matched entries get marked .inFlight; unmatched are marked .failed
        // so they don't stay .pending forever (spike: ScoreEvent records only).
        var batch: [(metadata: SyncMetadata, record: CKRecord)] = []
        var unmatchedEntries: [SyncMetadata] = []

        for entry in pendingEntries {
            guard entry.recordType == ScoreEventRecord.recordType,
                  let eventID = UUID(uuidString: entry.recordID),
                  let event = eventsByID[eventID] else {
                unmatchedEntries.append(entry)
                continue
            }
            batch.append((entry, ScoreEventRecord(from: event).toCKRecord()))
        }

        // Mark unmatched entries as .failed so they don't stay .pending forever
        if !unmatchedEntries.isEmpty {
            for entry in unmatchedEntries {
                entry.syncStatus = .failed
            }
            do {
                try modelContext.save()
            } catch {
                logger.error("SyncEngine.pushPending: failed to save unmatched entry statuses: \(error)")
            }
        }

        guard !batch.isEmpty else { return }

        // CRITICAL: Mark .inFlight BEFORE the async CloudKit call (AC4 / Amendment A1).
        // Only batch entries are marked — a concurrent pushPending() call that arrives
        // during the `await` below will see these as .inFlight and skip them.
        let now = Date()
        for (entry, _) in batch {
            entry.syncStatus = .inFlight
            entry.lastAttempt = now
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("SyncEngine.pushPending: failed to persist .inFlight status: \(error)")
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
            do {
                try modelContext.save()
            } catch {
                logger.error("SyncEngine.pushPending: failed to persist .failed status: \(error)")
            }
            syncState = isNetworkError(ckError) ? .offline : .error(SyncError.cloudKitFailure(ckError))
            logger.error("SyncEngine.pushPending: CloudKit error: \(ckError)")
        } catch {
            for (entry, _) in batch { entry.syncStatus = .failed }
            do {
                try modelContext.save()
            } catch {
                logger.error("SyncEngine.pushPending: failed to persist .failed status after unexpected error: \(error)")
            }
            syncState = .error(SyncError.cloudKitFailure(CKError(.internalError)))
            logger.error("SyncEngine.pushPending: unexpected error: \(error)")
        }
    }

    /// Pulls new `ScoreEvent` records from CloudKit and inserts them locally.
    ///
    /// Deduplicates by `ScoreEvent.id` — existing local events are never overwritten
    /// (event-sourcing append-only invariant, NFR19).
    /// After insertion, runs `ConflictDetector.check()` for each affected {roundID, playerID, holeNumber}
    /// group. Silent merges are logged; discrepancies produce a `Discrepancy` record.
    /// Calls `StandingsEngine.recompute()` for every affected round.
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

        // Parse all CKRecords up front to scope the local event fetch to affected rounds
        let dtos = fetched.compactMap { ScoreEventRecord(from: $0) }
        guard !dtos.isEmpty else {
            syncState = .idle
            return
        }

        let incomingRoundIDs = Set(dtos.map(\.roundID))
        let existingEvents = fetchScoreEvents(forRoundIDs: incomingRoundIDs)
        let existingIDs = Set(existingEvents.map(\.id))
        var affectedRoundIDs: Set<UUID> = []
        var newlyInsertedEvents: [ScoreEvent] = []

        for dto in dtos {
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
            newlyInsertedEvents.append(event)
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

        detectConflicts(newEvents: newlyInsertedEvents, allExisting: existingEvents)

        // Hop to MainActor to recompute standings for each affected round (AC2)
        for roundID in affectedRoundIDs {
            await standingsEngine.recompute(for: roundID, trigger: .remoteSync)
        }
        syncState = .idle
        logger.info("SyncEngine.pullRecords: inserted events for \(affectedRoundIDs.count) round(s)")
    }

    // MARK: - Conflict detection

    /// Runs conflict detection on newly inserted events and creates Discrepancy records.
    ///
    /// Pre-fetches existing Discrepancy records to deduplicate (Story 6.1: resolution event guard).
    private func detectConflicts(newEvents: [ScoreEvent], allExisting: [ScoreEvent]) {
        let affectedRoundIDArray = Array(Set(newEvents.map(\.roundID)))
        let existingDiscrepancies: [Discrepancy]
        do {
            let descriptor = FetchDescriptor<Discrepancy>(
                predicate: #Predicate { affectedRoundIDArray.contains($0.roundID) }
            )
            existingDiscrepancies = try modelContext.fetch(descriptor)
        } catch {
            logger.error("SyncEngine: failed to fetch discrepancies — dedup guard bypassed: \(error)")
            return
        }

        let allEvents = allExisting + newEvents
        let conflictDetector = ConflictDetector()
        for newEvent in newEvents {
            let groupEvents = allEvents.filter {
                $0.roundID == newEvent.roundID &&
                $0.playerID == newEvent.playerID &&
                $0.holeNumber == newEvent.holeNumber
            }
            let result = conflictDetector.check(newEvent: newEvent, existingEvents: groupEvents)
            switch result {
            case .noConflict, .correction:
                break
            case .silentMerge:
                logger.debug("SyncEngine: silent merge for player \(newEvent.playerID, privacy: .private) hole \(newEvent.holeNumber)")
            case .discrepancy(let existingID, let incomingID):
                let alreadyExists = existingDiscrepancies.contains {
                    $0.roundID == newEvent.roundID &&
                    $0.playerID == newEvent.playerID &&
                    $0.holeNumber == newEvent.holeNumber
                }
                guard !alreadyExists else {
                    let pid = newEvent.playerID
                    let hole = newEvent.holeNumber
                    logger.debug("SyncEngine: discrepancy exists for player \(pid, privacy: .private) hole \(hole) — skip")
                    break
                }
                let discrepancy = Discrepancy(
                    roundID: newEvent.roundID,
                    playerID: newEvent.playerID,
                    holeNumber: newEvent.holeNumber,
                    eventID1: existingID,
                    eventID2: incomingID
                )
                modelContext.insert(discrepancy)
                logger.info("SyncEngine: discrepancy for player \(newEvent.playerID, privacy: .private) hole \(newEvent.holeNumber)")
            }
        }

        if !newEvents.isEmpty {
            do {
                try modelContext.save()
            } catch {
                logger.error("SyncEngine: save discrepancies failed: \(error)")
            }
        }
    }

    // MARK: - Private helpers

    /// Fetches all SyncMetadata entries. Uses fetch-all-and-filter-in-Swift because
    /// `#Predicate` with custom enum types (SyncStatus) has unpredictable behavior
    /// on macOS test hosts. Bounded in practice: one entry per sync attempt.
    private func fetchAllMetadata() -> [SyncMetadata] {
        do {
            var descriptor = FetchDescriptor<SyncMetadata>()
            descriptor.fetchLimit = 1000
            let entries = try modelContext.fetch(descriptor)
            if entries.count == 1000 {
                logger.error("SyncEngine.fetchAllMetadata hit fetchLimit — SyncMetadata table may be growing unboundedly")
            }
            return entries
        } catch {
            logger.error("SyncEngine.fetchAllMetadata failed: \(error)")
            return []
        }
    }

    /// Fetches ScoreEvents whose IDs are in `ids`. Used by the push pipeline to look up
    /// only the events referenced by pending SyncMetadata entries.
    private func fetchScoreEvents(withIDs ids: Set<UUID>) -> [ScoreEvent] {
        guard !ids.isEmpty else { return [] }
        let idArray = Array(ids)
        var descriptor = FetchDescriptor<ScoreEvent>(predicate: #Predicate { idArray.contains($0.id) })
        descriptor.fetchLimit = idArray.count
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("SyncEngine.fetchScoreEvents(withIDs:) failed: \(error)")
            return []
        }
    }

    /// Fetches ScoreEvents scoped to the given round IDs. Used by the pull pipeline and
    /// conflict detection to avoid full-table scans on the event-sourced table.
    private func fetchScoreEvents(forRoundIDs roundIDs: Set<UUID>) -> [ScoreEvent] {
        guard !roundIDs.isEmpty else { return [] }
        let roundIDArray = Array(roundIDs)
        let descriptor = FetchDescriptor<ScoreEvent>(predicate: #Predicate { roundIDArray.contains($0.roundID) })
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("SyncEngine.fetchScoreEvents(forRoundIDs:) failed: \(error)")
            return []
        }
    }

    private func isNetworkError(_ error: CKError) -> Bool {
        error.code == .networkUnavailable || error.code == .networkFailure
    }
}
