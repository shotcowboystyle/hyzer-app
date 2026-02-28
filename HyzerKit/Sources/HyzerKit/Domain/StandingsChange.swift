/// The result of a standings recomputation, including animation context.
///
/// Produced by `StandingsEngine.recompute(for:trigger:)`.
/// `positionChanges` maps playerID → (previous position, new position) for players
/// whose rank changed. Used to drive position-change arrow animations in the leaderboard.
public struct StandingsChange: Sendable {
    public let previousStandings: [Standing]
    public let newStandings: [Standing]
    public let trigger: StandingsChangeTrigger
    /// Maps playerID to (from: previousPosition, to: newPosition) for players whose rank changed.
    public let positionChanges: [String: PositionChange]

    public struct PositionChange: Sendable, Equatable {
        public let from: Int
        public let to: Int

        public init(from: Int, to: Int) {
            self.from = from
            self.to = to
        }
    }

    public init(
        previousStandings: [Standing],
        newStandings: [Standing],
        trigger: StandingsChangeTrigger,
        positionChanges: [String: PositionChange]
    ) {
        self.previousStandings = previousStandings
        self.newStandings = newStandings
        self.trigger = trigger
        self.positionChanges = positionChanges
    }
}
