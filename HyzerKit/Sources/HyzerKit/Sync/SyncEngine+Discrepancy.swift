import Foundation
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "SyncEngine")

extension SyncEngine {
    /// Pushes a `Discrepancy` record to CloudKit so the `Discrepancy-creation` subscription
    /// fires and delivers an organizer-only push notification (Story 12.3, AC #1).
    ///
    /// This is a CREATE-only write — Discrepancy records are immutable per event-sourcing.
    /// Resolution creates a new ScoreEvent (Story 6.1), not a Discrepancy mutation.
    ///
    /// Follows the same `.pending → .inFlight → .synced/.failed` state machine as `pushRoundCompletion`.
    /// `serverRecordChanged` is treated as success — a concurrent push from a peer device means
    /// the record is already on the server, which satisfies the subscription-fire requirement.
    ///
    /// - Parameters:
    ///   - discrepancyID: The local `Discrepancy.id`.
    ///   - roundID: The round containing the conflict.
    ///   - organizerID: The round's organizer (denormalized for the CK subscription predicate).
    ///   - playerID: The player whose score is in conflict (String — supports guest IDs).
    ///   - holeNumber: The 1-based hole number where the conflict occurred.
    ///   - createdAt: The discrepancy's creation timestamp.
    /// - Returns: `true` if the record was successfully pushed (or treated as success via
    ///   already-`.synced` skip / `serverRecordChanged`); `false` if the local-save or CK
    ///   push failed and `SyncMetadata` was marked `.failed`. The result is `@discardableResult`
    ///   because the fire-and-forget caller in `detectConflicts` does not currently act on it,
    ///   but tests and future retry logic can.
    @discardableResult
    public func pushDiscrepancy(
        discrepancyID: UUID,
        roundID: UUID,
        organizerID: UUID,
        playerID: String,
        holeNumber: Int,
        createdAt: Date
    ) async -> Bool {
        let idString = discrepancyID.uuidString

        let existingMeta = fetchAllMetadata().first {
            $0.recordID == idString && $0.recordType == DiscrepancyRecord.recordType
        }
        if let existing = existingMeta, existing.syncStatus == .synced {
            logger.info("SyncEngine.pushDiscrepancy: discrepancy \(idString) already .synced — skipping")
            return true
        }
        if let existing = existingMeta, existing.syncStatus == .inFlight {
            logger.info("SyncEngine.pushDiscrepancy: discrepancy \(idString) is .inFlight (stale?) — proceeding")
        }

        let meta: SyncMetadata
        if let existing = existingMeta {
            meta = existing
        } else {
            meta = SyncMetadata(recordID: idString, recordType: DiscrepancyRecord.recordType)
            modelContext.insert(meta)
        }
        meta.syncStatus = .inFlight
        meta.lastAttempt = Date()

        do {
            try modelContext.save()
        } catch {
            logger.error("SyncEngine.pushDiscrepancy: failed to persist .inFlight status: \(error)")
            meta.syncStatus = .failed
            do { try modelContext.save() } catch {
                logger.error("SyncEngine.pushDiscrepancy: failed to persist .failed after inFlight save failure: \(error)")
            }
            return false
        }

        let dto = DiscrepancyRecord(
            id: discrepancyID,
            roundID: roundID,
            organizerID: organizerID,
            playerID: playerID,
            holeNumber: holeNumber,
            createdAt: createdAt
        )
        let ckRecord = dto.toCKRecord()

        do {
            _ = try await cloudKitClient.save([ckRecord])
            meta.syncStatus = .synced
            do {
                try modelContext.save()
                logger.info("SyncEngine.pushDiscrepancy: pushed discrepancy \(idString)")
                return true
            } catch {
                meta.syncStatus = .failed
                do {
                    try modelContext.save()
                } catch {
                    logger.error("SyncEngine.pushDiscrepancy: failed to persist .failed after local-save failure: \(error)")
                }
                logger.error("SyncEngine.pushDiscrepancy: CK save succeeded but local save failed — marking .failed for retry: \(error)")
                return false
            }
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            meta.syncStatus = .synced
            do {
                try modelContext.save()
            } catch {
                logger.error("SyncEngine.pushDiscrepancy: failed to persist .synced after serverRecordChanged: \(error)")
            }
            logger.info("SyncEngine.pushDiscrepancy: serverRecordChanged for discrepancy \(idString) — concurrent peer push, marking .synced")
            return true
        } catch {
            meta.syncStatus = .failed
            do { try modelContext.save() } catch {
                logger.error("SyncEngine.pushDiscrepancy: failed to persist .failed status: \(error)")
            }
            logger.error("SyncEngine.pushDiscrepancy: push failed for discrepancy \(idString): \(error)")
            return false
        }
    }
}
