import Foundation

/// Authorization state mirroring `UNAuthorizationStatus` without importing `UserNotifications`.
/// The live implementation bridges this to the real `UNAuthorizationStatus` values.
public enum NotificationAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

/// Typed payload for a "Round Started" push notification received from a CKQuerySubscription.
public struct RoundStartedPayload: Sendable, Equatable {
    public let roundID: UUID
    public let organizerID: UUID
    public let organizerFirstName: String
    public let courseName: String

    public init(roundID: UUID, organizerID: UUID, organizerFirstName: String, courseName: String) {
        self.roundID = roundID
        self.organizerID = organizerID
        self.organizerFirstName = organizerFirstName
        self.courseName = courseName
    }
}

/// Typed payload for a "Round Complete" push notification received from a CKQuerySubscription.
///
/// No self-exclusion: the winner receives this notification (AC #3 — celebrating your own win is valid).
public struct RoundCompletePayload: Sendable, Equatable {
    public let roundID: UUID
    public let courseName: String
    public let winnerFirstName: String
    public let winnerScoreDisplay: String

    public init(roundID: UUID, courseName: String, winnerFirstName: String, winnerScoreDisplay: String) {
        self.roundID = roundID
        self.courseName = courseName
        self.winnerFirstName = winnerFirstName
        self.winnerScoreDisplay = winnerScoreDisplay
    }
}

/// Protocol for managing push notification permissions and payload parsing.
///
/// Lives in HyzerKit so `AppServices` and tests can depend on it without importing
/// `UserNotifications` in every context. The live implementation (`LiveNotificationService`)
/// is in the HyzerApp target and wraps `UNUserNotificationCenter`.
///
/// All methods are async to accommodate the live implementation's async UNUserNotificationCenter calls.
/// This protocol must compile on macOS for HyzerKitTests — no UIKit or UserNotifications imports.
public protocol NotificationService: Sendable {
    /// Returns the current notification authorization status without prompting.
    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus

    /// Requests notification authorization. Returns the resulting status.
    /// System-idempotent: if the user has already been prompted, returns the stored answer immediately.
    @discardableResult
    func requestAuthorization() async -> NotificationAuthorizationStatus

    /// Returns `true` if the local device should suppress the foreground presentation
    /// of an incoming round-started notification (self-exclusion gate, AC #5).
    ///
    /// CKSubscription delivers to every subscriber including the writer's device.
    /// Suppression is enforced client-side: if `localPlayerID` equals the organizer, skip display.
    func shouldSuppressPresentation(for payload: RoundStartedPayload, localPlayerID: UUID?) -> Bool

    /// Parses a CKQuerySubscription user-info dictionary into a typed `RoundStartedPayload`.
    /// Returns `nil` if the dictionary is not a Round-active-creation subscription payload,
    /// or if required fields (`roundID`, `organizerID`, `organizerFirstName`, `courseName`) are absent or malformed.
    func parseRoundStartedPayload(_ userInfo: [AnyHashable: Any]) -> RoundStartedPayload?

    /// Parses a CKQuerySubscription user-info dictionary into a typed `RoundCompletePayload`.
    /// Returns `nil` if the dictionary is not a Round-complete-update subscription payload,
    /// or if required fields (`rid`, `courseName`, `winnerFirstName`, `winnerScoreDisplay`) are absent or malformed.
    ///
    /// No `shouldSuppressPresentation` overload exists for this payload — completion notifications
    /// are delivered unconditionally (AC #3: no self-exclusion for the winner).
    func parseRoundCompletePayload(_ userInfo: [AnyHashable: Any]) -> RoundCompletePayload?
}
