import Foundation
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "SyncEngine")

extension SyncEngine {
    /// Pushes a completed `Round` record update to CloudKit so the CKQuerySubscription
    /// (`Round-complete-update`, `firesOnRecordUpdate`, predicate `status == "completed"`)
    /// fires and delivers a "Round Complete" push to all participants.
    ///
    /// This issues a CloudKit **update** to the existing Round record. The CKQuerySubscription
    /// on `status == 'completed'` with `firesOnRecordUpdate` fires server-side.
    ///
    /// Follows the same `.pending → .inFlight → .synced/.failed` state machine as `pushRound`.
    /// If the existing SyncMetadata entry is `.inFlight` (stale from a crashed prior process),
    /// we proceed anyway — a stale `.inFlight` must not block completion forever.
    ///
    /// - Parameters:
    ///   - roundID: The `Round.id` UUID.
    ///   - organizerID: The organizer's `Player.id`.
    ///   - organizerFirstName: Precomputed first-name token (PII gate).
    ///   - courseName: The `Course.name`.
    ///   - playerIDs: The round's `playerIDs` array.
    ///   - createdAt: The round's `createdAt` timestamp.
    ///   - winnerFirstName: Precomputed first-name of the alphabetically-first position-1 player.
    ///   - winnerScoreDisplay: The winner's "+/- par" score string (e.g., "+2", "-3", "E").
    public func pushRoundCompletion(
        roundID: UUID,
        organizerID: UUID,
        organizerFirstName: String,
        courseName: String,
        playerIDs: [String],
        createdAt: Date,
        winnerFirstName: String,
        winnerScoreDisplay: String
    ) async {
        let idString = roundID.uuidString

        // Check for existing synced metadata — synced means we already pushed successfully.
        let existingMeta = fetchAllMetadata().first {
            $0.recordID == idString && $0.recordType == RoundRecord.recordType
        }
        if let existing = existingMeta, existing.syncStatus == .synced {
            logger.info("SyncEngine.pushRoundCompletion: round \(idString) already .synced — skipping")
            return
        }
        // If .inFlight: a stale .inFlight from a crashed prior process must not block
        // completion forever. Log and proceed (completion push overrides).
        if let existing = existingMeta, existing.syncStatus == .inFlight {
            logger.info("SyncEngine.pushRoundCompletion: round \(idString) is .inFlight (stale?) — proceeding with completion push")
        }

        // Insert or reuse SyncMetadata entry
        let meta: SyncMetadata
        if let existing = existingMeta {
            meta = existing
        } else {
            meta = SyncMetadata(recordID: idString, recordType: RoundRecord.recordType)
            modelContext.insert(meta)
        }
        meta.syncStatus = .inFlight
        meta.lastAttempt = Date()

        do {
            try modelContext.save()
        } catch {
            logger.error("SyncEngine.pushRoundCompletion: failed to persist .inFlight status: \(error)")
            return
        }

        let dto = RoundRecord(
            id: roundID,
            organizerID: organizerID,
            organizerFirstName: organizerFirstName,
            courseName: courseName,
            status: "completed",
            playerIDs: playerIDs,
            createdAt: createdAt,
            winnerFirstName: winnerFirstName,
            winnerScoreDisplay: winnerScoreDisplay
        )
        let ckRecord = dto.toCKRecord()

        do {
            // This is an UPDATE to an existing CK record (the Round was created with
            // status="active" by pushRound in Story 12.1). The local DTO has no
            // recordChangeTag, so `.ifServerRecordUnchanged` would reject every update
            // as `serverRecordChanged` and the subscription would never fire. Use
            // `.changedKeys` to merge the completion fields without a tag check.
            _ = try await cloudKitClient.save([ckRecord], savePolicy: .changedKeys)
            meta.syncStatus = .synced
            do {
                try modelContext.save()
                logger.info("SyncEngine.pushRoundCompletion: pushed round \(idString)")
            } catch {
                // CK save succeeded but local metadata save failed — demote to .failed so the
                // retry pipeline picks it up; the CK upsert is idempotent (recordID is UUID).
                meta.syncStatus = .failed
                do {
                    try modelContext.save()
                } catch {
                    logger.error("SyncEngine.pushRoundCompletion: failed to persist .failed after local-save failure: \(error)")
                }
                logger.error("SyncEngine.pushRoundCompletion: CK save succeeded but local save failed — marking .failed for retry: \(error)")
            }
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            // The record already exists on the server in the target state (e.g., a concurrent
            // completion push from another device). For this use case (stable UUID key, we are
            // the authoritative writer), treat serverRecordChanged as success.
            meta.syncStatus = .synced
            do {
                try modelContext.save()
            } catch {
                logger.error("SyncEngine.pushRoundCompletion: failed to persist .synced after serverRecordChanged: \(error)")
            }
            logger.info("SyncEngine.pushRoundCompletion: serverRecordChanged for round \(idString) — record already on server, marking .synced")
        } catch {
            meta.syncStatus = .failed
            do { try modelContext.save() } catch {
                logger.error("SyncEngine.pushRoundCompletion: failed to persist .failed status: \(error)")
            }
            logger.error("SyncEngine.pushRoundCompletion: push failed for round \(idString): \(error)")
        }
    }

    /// Returns true if this device pushed a completion update for `roundID` within the
    /// recent window (default 5 minutes). Used by `AppServices.handleRoundCompleteNotification`
    /// to suppress the deep-link cover on the writer's own device — the user is already viewing
    /// the in-round summary cover from `ScorecardContainerView`, so re-presenting from HomeView
    /// would race two `.fullScreenCover` presentations for the same round.
    ///
    /// Distinguishes "we wrote it" from "we pulled it" via `lastAttempt`: push paths set
    /// `lastAttempt = Date()`, pull paths leave it `nil`.
    public func didRecentlyPushCompletion(for roundID: UUID, within window: TimeInterval = 300) -> Bool {
        let idString = roundID.uuidString
        guard let meta = fetchAllMetadata().first(where: {
            $0.recordID == idString && $0.recordType == RoundRecord.recordType
        }) else {
            return false
        }
        guard meta.syncStatus == .synced, let lastAttempt = meta.lastAttempt else { return false }
        return Date().timeIntervalSince(lastAttempt) < window
    }
}
