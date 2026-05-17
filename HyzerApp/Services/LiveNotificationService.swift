import Foundation
import UserNotifications
import os.log
import HyzerKit

private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "NotificationService")

/// Live implementation of `NotificationService` that wraps `UNUserNotificationCenter`.
///
/// Imported only in HyzerApp so HyzerKit remains platform-agnostic.
/// Mirrors the `LiveCloudKitClient` / `CloudKitClient` split.
struct LiveNotificationService: NotificationService, Sendable {

    // MARK: - NotificationService

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationAuthorizationStatus(from: settings.authorizationStatus)
    }

    @discardableResult
    func requestAuthorization() async -> NotificationAuthorizationStatus {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            // Log at info level — no PII in the message
            logger.info("Notification authorization result: \(granted ? "granted" : "denied")")
            return granted ? .authorized : .denied
        } catch {
            // Return `.notDetermined` rather than `.denied` so callers can distinguish a
            // definitive user decision from a transient system error. HomeView's
            // `hasPromptedForNotifications` flag is only persisted on definitive outcomes
            // (i.e., not `.notDetermined`) so the next "New Round" tap can retry.
            logger.error("requestAuthorization failed: \(error)")
            return .notDetermined
        }
    }

    func shouldSuppressPresentation(for payload: RoundStartedPayload, localPlayerID: UUID?) -> Bool {
        guard let localPlayerID else { return false }
        return payload.organizerID == localPlayerID
    }

    func parseRoundStartedPayload(_ userInfo: [AnyHashable: Any]) -> RoundStartedPayload? {
        guard let qry = CKNotificationEnvelope.querySubscriptionInfo(from: userInfo),
              let sid = qry["sid"] as? String,
              sid == NotificationSubscriptionID.roundActiveCreation,
              let rid = qry["rid"] as? String,
              let roundID = UUID(uuidString: rid),
              let af = CKNotificationEnvelope.dict(qry["af"]) else {
            return nil
        }

        guard let organizerIDString = af["organizerID"] as? String,
              let organizerID = UUID(uuidString: organizerIDString),
              let organizerFirstName = af["organizerFirstName"] as? String,
              let courseName = af["courseName"] as? String else {
            return nil
        }

        return RoundStartedPayload(
            roundID: roundID,
            organizerID: organizerID,
            organizerFirstName: organizerFirstName,
            courseName: courseName
        )
    }

    func parseRoundCompletePayload(_ userInfo: [AnyHashable: Any]) -> RoundCompletePayload? {
        guard let qry = CKNotificationEnvelope.querySubscriptionInfo(from: userInfo),
              let sid = qry["sid"] as? String,
              sid == NotificationSubscriptionID.roundCompleteUpdate,
              let rid = qry["rid"] as? String,
              let roundID = UUID(uuidString: rid),
              let af = CKNotificationEnvelope.dict(qry["af"]) else {
            return nil
        }

        guard let courseName = af["courseName"] as? String,
              let winnerFirstName = af["winnerFirstName"] as? String,
              let winnerScoreDisplay = af["winnerScoreDisplay"] as? String else {
            return nil
        }

        return RoundCompletePayload(
            roundID: roundID,
            courseName: courseName,
            winnerFirstName: winnerFirstName,
            winnerScoreDisplay: winnerScoreDisplay
        )
    }

    func parseDiscrepancyDetectedPayload(_ userInfo: [AnyHashable: Any]) -> DiscrepancyDetectedPayload? {
        guard let qry = CKNotificationEnvelope.querySubscriptionInfo(from: userInfo),
              let sid = qry["sid"] as? String,
              sid == NotificationSubscriptionID.discrepancyCreation,
              let rid = qry["rid"] as? String,
              let discrepancyID = UUID(uuidString: rid),
              let af = CKNotificationEnvelope.dict(qry["af"]) else {
            return nil
        }

        guard let roundIDString = af["roundID"] as? String,
              let roundID = UUID(uuidString: roundIDString),
              let playerID = af["playerID"] as? String,
              let holeNumber = af["holeNumber"] as? Int else {
            return nil
        }

        return DiscrepancyDetectedPayload(
            discrepancyID: discrepancyID,
            roundID: roundID,
            playerID: playerID,
            holeNumber: holeNumber
        )
    }
}

/// Canonical subscription IDs used for both CK registration and payload-parse routing.
/// Must stay in lock-step with `SyncScheduler.setupRoundActiveSubscription` /
/// `setupRoundCompleteSubscription` / `setupDiscrepancyCreationSubscription` and the AppDelegate dispatch switch.
enum NotificationSubscriptionID {
    static let roundActiveCreation = "Round-active-creation"
    static let roundCompleteUpdate = "Round-complete-update"
    static let discrepancyCreation = "Discrepancy-creation"
}

// MARK: - CKNotificationEnvelope

/// Centralised parsing for CloudKit subscription remote-notification `userInfo` payloads.
///
/// Handles both `[String: Any]` and bridged `NSDictionary` variants delivered by APNs —
/// the actual cast shape is not contractually guaranteed by Apple and can drift between iOS releases.
/// Used by both `AppDelegate` (for subscription-ID dispatch) and `LiveNotificationService`
/// (for payload extraction) so the two paths never diverge.
enum CKNotificationEnvelope {
    /// Extracts the `ck.qry` dictionary from a remote-notification userInfo.
    static func querySubscriptionInfo(from userInfo: [AnyHashable: Any]) -> [String: Any]? {
        guard let ck = dict(userInfo["ck"]) else { return nil }
        return dict(ck["qry"])
    }

    /// Returns the subscription ID (`ck.qry.sid`) if present.
    static func subscriptionID(from userInfo: [AnyHashable: Any]) -> String? {
        querySubscriptionInfo(from: userInfo)?["sid"] as? String
    }

    /// Defensive cast for nested dictionary access — APNs may deliver `NSDictionary`
    /// instead of `[String: Any]` depending on the deserialization path.
    static func dict(_ value: Any?) -> [String: Any]? {
        if let d = value as? [String: Any] { return d }
        if let nsDict = value as? NSDictionary, let bridged = nsDict as? [String: Any] { return bridged }
        return nil
    }
}

// MARK: - UNAuthorizationStatus bridge

extension NotificationAuthorizationStatus {
    init(from status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .provisional: self = .provisional
        case .ephemeral: self = .ephemeral
        @unknown default: self = .notDetermined
        }
    }
}
