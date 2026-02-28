import Foundation
import SwiftData

/// String status values for `Round.status`. Stored as strings for CloudKit compatibility.
public enum RoundStatus {
    public static let setup = "setup"
    public static let active = "active"
    public static let awaitingFinalization = "awaitingFinalization"
    public static let completed = "completed"
}

/// A disc golf round. Stored in the domain SwiftData store.
///
/// CloudKit compatibility constraints:
/// - No `@Attribute(.unique)` — CloudKit does not support unique constraints
/// - All properties have defaults so CloudKit can instantiate without all values
/// - No `@Relationship` — players referenced via flat `playerIDs` foreign keys (Amendment A8)
///
/// Player list immutability (FR13): After `start()` is called the round is active.
/// There are no public mutating methods for `playerIDs` or `guestNames` — these are set
/// at init time and frozen when `start()` transitions status to "active".
///
/// **Known limitation:** `playerIDs` and `guestNames` are `public var` because SwiftData's
/// `@Model` macro requires full read/write access for persistence and fetch operations.
/// `private(set)` is incompatible with `@Model` property synthesis. Type-level enforcement
/// of post-start immutability is deferred to Story 3.5 (`RoundLifecycleManager`).
/// Until then, immutability is enforced by convention: only `RoundSetupViewModel` modifies
/// these properties, and only during the "setup" phase before `start()` is called.
@Model
public final class Round {
    public var id: UUID = UUID()
    /// Flat FK to the Course. Denormalized for CloudKit sync (Amendment A8).
    public var courseID: UUID = UUID()
    /// Player.id of the round creator / organizer (FR16).
    public var organizerID: UUID = UUID()
    /// Player.id UUIDs stored as strings for future CloudKit discovery (FR16b, Epic 4).
    public var playerIDs: [String] = []
    /// Round-scoped guest labels — no persistent Player identity (FR12b).
    public var guestNames: [String] = []
    /// Lifecycle: "setup" | "active" | "awaitingFinalization" | "completed".
    /// Stored as String for CloudKit compatibility (CloudKit doesn't support Swift enums).
    /// Use `RoundStatus` constants for comparisons.
    public var status: String = "setup"
    /// Denormalized from Course at creation time for efficient scoring access.
    public var holeCount: Int = 18
    public var createdAt: Date = Date()
    /// Non-nil once `start()` has been called.
    public var startedAt: Date?
    /// Non-nil once `complete()` has been called.
    public var completedAt: Date?

    public init(
        courseID: UUID,
        organizerID: UUID,
        playerIDs: [String],
        guestNames: [String],
        holeCount: Int
    ) {
        self.courseID = courseID
        self.organizerID = organizerID
        self.playerIDs = playerIDs
        self.guestNames = guestNames
        self.holeCount = holeCount
    }

    // MARK: - Status helpers

    public var isSetup: Bool { status == RoundStatus.setup }
    public var isActive: Bool { status == RoundStatus.active }
    public var isAwaitingFinalization: Bool { status == RoundStatus.awaitingFinalization }
    public var isCompleted: Bool { status == RoundStatus.completed }
    /// True when the round is in either `awaitingFinalization` or `completed` — no more scoring.
    public var isFinished: Bool { isAwaitingFinalization || isCompleted }

    // MARK: - Lifecycle

    /// Transitions the round from "setup" to "active" and records the start time.
    ///
    /// - Precondition: `status` must be "setup". Calling `start()` on an already-active
    ///   round is a programming error.
    public func start() {
        precondition(status == RoundStatus.setup, "Round.start() called on a non-setup round (status: \(status))")
        status = RoundStatus.active
        startedAt = Date()
    }

    /// Transitions the round from "active" to "awaitingFinalization".
    ///
    /// Called by `RoundLifecycleManager` when all (player, hole) pairs have resolved scores.
    /// - Precondition: `status` must be "active".
    public func awaitFinalization() {
        precondition(
            status == RoundStatus.active,
            "Round.awaitFinalization() called on a non-active round (status: \(status))"
        )
        status = RoundStatus.awaitingFinalization
    }

    /// Transitions the round to "completed" and records the completion time.
    ///
    /// Accepts from either "active" (early finish with `force`) or "awaitingFinalization"
    /// (user confirmed all scores). Sets `completedAt` to the current time.
    /// - Precondition: `status` must be "active" or "awaitingFinalization".
    public func complete() {
        precondition(
            status == RoundStatus.active || status == RoundStatus.awaitingFinalization,
            "Round.complete() called on round in unexpected status: \(status)"
        )
        status = RoundStatus.completed
        completedAt = Date()
    }
}
