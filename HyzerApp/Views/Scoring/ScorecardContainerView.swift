import SwiftUI
import SwiftData
import HyzerKit

/// A horizontal card stack showing one hole card per hole in the round.
///
/// Receives a `Round` object; queries ScoreEvents, Holes, and Players via `@Query`.
/// Client-side filtering keeps relevant data per hole — the dataset is small
/// (max ~108 ScoreEvents, 18 Holes, ~6 Players per round).
///
/// `@Query` lives in the View per the architecture rule — the ViewModel only handles actions.
struct ScorecardContainerView: View {
    let round: Round

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allScoreEvents: [ScoreEvent]
    @Query(sort: \Hole.number) private var allHoles: [Hole]
    @Query(sort: \Player.displayName) private var allPlayers: [Player]
    @Query(sort: \Course.name) private var allCourses: [Course]

    @State private var currentHole: Int = 1
    @State private var viewModel: ScorecardViewModel?
    @State private var leaderboardViewModel: LeaderboardViewModel?
    @State private var autoAdvanceTask: Task<Void, Never>?

    // MARK: - Client-side filters

    private var roundScoreEvents: [ScoreEvent] {
        allScoreEvents.filter { $0.roundID == round.id }
    }

    private var courseHoles: [Hole] {
        allHoles.filter { $0.courseID == round.courseID }
    }

    /// Unified player row list: registered players + guests, ordered as they were added.
    private var scorecardPlayers: [ScorecardPlayer] {
        let registered = round.playerIDs.compactMap { playerID -> ScorecardPlayer? in
            guard let player = allPlayers.first(where: { $0.id.uuidString == playerID }) else { return nil }
            return ScorecardPlayer(id: playerID, displayName: player.displayName, isGuest: false)
        }
        let guests = round.guestNames.map { name in
            ScorecardPlayer(id: "guest:\(name)", displayName: name, isGuest: true)
        }
        return registered + guests
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentHole) {
                ForEach(1...max(1, round.holeCount), id: \.self) { holeNumber in
                    HoleCardView(
                        holeNumber: holeNumber,
                        par: par(forHole: holeNumber),
                        courseName: courseName,
                        players: scorecardPlayers,
                        scores: roundScoreEvents.filter { $0.holeNumber == holeNumber },
                        onScore: { playerID, strokeCount in
                            enterScore(playerID: playerID, holeNumber: holeNumber, strokeCount: strokeCount)
                        },
                        onCorrection: { playerID, previousEventID, strokeCount in
                            correctScore(
                                playerID: playerID,
                                previousEventID: previousEventID,
                                holeNumber: holeNumber,
                                strokeCount: strokeCount
                            )
                        }
                    )
                    .tag(holeNumber)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            if let lvm = leaderboardViewModel {
                LeaderboardPillView(viewModel: lvm)
                    .padding(.top, SpacingTokens.md)
                    .padding(.horizontal, SpacingTokens.md)
            }
        }
        .background(Color.backgroundPrimary)
        .sheet(isPresented: Binding(
            get: { leaderboardViewModel?.isExpanded ?? false },
            set: { leaderboardViewModel?.isExpanded = $0 }
        )) {
            if let lvm = leaderboardViewModel {
                LeaderboardExpandedView(viewModel: lvm, totalHoles: round.holeCount)
            }
        }
        .alert("Score Entry Error", isPresented: showingErrorBinding) {
            Button("OK") { }
        } message: {
            Text(viewModel?.saveError?.localizedDescription ?? "")
        }
        .onAppear { initializeViewModels() }
        .onChange(of: currentHole) {
            // Cancel any pending auto-advance when the user swipes manually
            autoAdvanceTask?.cancel()
        }
    }

    // MARK: - Private

    private func initializeViewModels() {
        guard viewModel == nil else { return }
        guard let organizer = allPlayers.first(where: { $0.id.uuidString == round.playerIDs.first }) else {
            // Fall back to organizerID if organizer player not in query results yet
            viewModel = ScorecardViewModel(
                scoringService: appServices.scoringService,
                roundID: round.id,
                reportedByPlayerID: round.organizerID
            )
            leaderboardViewModel = LeaderboardViewModel(
                standingsEngine: appServices.standingsEngine,
                roundID: round.id,
                currentPlayerID: round.organizerID.uuidString
            )
            return
        }
        viewModel = ScorecardViewModel(
            scoringService: appServices.scoringService,
            roundID: round.id,
            reportedByPlayerID: organizer.id
        )
        leaderboardViewModel = LeaderboardViewModel(
            standingsEngine: appServices.standingsEngine,
            roundID: round.id,
            currentPlayerID: organizer.id.uuidString
        )
    }

    private func enterScore(playerID: String, holeNumber: Int, strokeCount: Int) {
        guard let vm = viewModel else { return }
        do {
            try vm.enterScore(playerID: playerID, holeNumber: holeNumber, strokeCount: strokeCount)
            leaderboardViewModel?.handleScoreEntered()
            handleAutoAdvance()
        } catch {
            vm.saveError = error
        }
    }

    private func correctScore(playerID: String, previousEventID: UUID, holeNumber: Int, strokeCount: Int) {
        guard let vm = viewModel else { return }
        do {
            try vm.correctScore(
                previousEventID: previousEventID,
                playerID: playerID,
                holeNumber: holeNumber,
                strokeCount: strokeCount
            )
            leaderboardViewModel?.handleScoreEntered()
        } catch {
            vm.saveError = error
        }
    }

    /// Triggers auto-advance if all players are scored on the current hole after a new score entry.
    ///
    /// Auto-advance only fires for initial scores and only when not on the last hole.
    private func handleAutoAdvance() {
        guard allPlayersScored(for: currentHole) else { return }
        guard currentHole < round.holeCount else { return }

        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { @MainActor in
            // Safe to ignore: CancellationError is expected when user swipes manually; handled by isCancelled check below
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion)) {
                currentHole += 1
            }
        }
    }

    /// Returns true if every player in the round has a resolved (leaf node) score for the given hole.
    private func allPlayersScored(for holeNumber: Int) -> Bool {
        scorecardPlayers.allSatisfy { player in
            resolveCurrentScore(for: player.id, hole: holeNumber, in: roundScoreEvents) != nil
        }
    }

    private func par(forHole holeNumber: Int) -> Int {
        courseHoles.first { $0.number == holeNumber }?.par ?? 3
    }

    private var courseName: String {
        allCourses.first { $0.id == round.courseID }?.name ?? "Unknown Course"
    }

    private var showingErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.saveError != nil },
            set: { if !$0 { viewModel?.saveError = nil } }
        )
    }
}
