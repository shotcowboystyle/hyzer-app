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

    /// Shown when finishRound returns .hasMissingScores — confirms early termination.
    @State private var missingScoreCount: Int = 0
    @State private var isShowingEarlyFinishWarning = false
    /// Controls the finalization prompt separately from `isAwaitingFinalization` so
    /// that SwiftUI can dismiss the alert without an infinite re-presentation loop (H1 fix).
    @State private var isShowingFinalizationPrompt = false
    /// Shown when a lifecycle operation raises an error.
    @State private var lifecycleError: Error?
    /// Bridges `ScorecardViewModel.isRoundCompleted` → fullScreenCover presentation.
    /// Decoupled from the VM flag to avoid infinite re-presentation loop (same H1 pattern).
    @State private var isShowingSummary = false
    @State private var summaryViewModel: RoundSummaryViewModel?

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
                        isRoundFinished: round.isFinished,
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

            if let lvm = leaderboardViewModel,
               lvm.currentStandings.contains(where: { $0.holesPlayed > 0 }) {
                LeaderboardPillView(viewModel: lvm)
                    .padding(.top, SpacingTokens.md)
                    .padding(.horizontal, SpacingTokens.md)
            }
        }
        .background(Color.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !round.isFinished {
                    Menu {
                        Button(role: .destructive) {
                            finishRoundTapped()
                        } label: {
                            Label("Finish Round", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
        // Finalization prompt: all scores recorded, user confirms
        .alert(
            "Finalize Round?",
            isPresented: $isShowingFinalizationPrompt
        ) {
            Button("Finalize") { finalizeRoundConfirmed() }
            Button("Keep Scoring", role: .cancel) {
                viewModel?.dismissFinalizationPrompt()
            }
        } message: {
            Text("All scores recorded. Finalize the round?")
        }
        .onChange(of: viewModel?.isAwaitingFinalization) { _, newValue in
            if newValue == true {
                isShowingFinalizationPrompt = true
            }
        }
        .onChange(of: viewModel?.isRoundCompleted) { _, newValue in
            if newValue == true {
                let standings = leaderboardViewModel?.currentStandings ?? []
                let played = standings.first?.holesPlayed ?? round.holeCount
                let par = courseHoles.reduce(0) { $0 + $1.par }
                summaryViewModel = RoundSummaryViewModel(
                    round: round,
                    standings: standings,
                    courseName: courseName,
                    holesPlayed: played,
                    coursePar: par
                )
                withAnimation(AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion)) {
                    isShowingSummary = true
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingSummary) {
            if let vm = summaryViewModel {
                RoundSummaryView(viewModel: vm, onDismiss: { isShowingSummary = false })
            }
        }
        // Early finish warning: unscored holes remain
        .alert(
            "Missing Scores",
            isPresented: $isShowingEarlyFinishWarning
        ) {
            Button("Finish Anyway", role: .destructive) { finishRoundForced() }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("\(missingScoreCount) score\(missingScoreCount == 1 ? "" : "s") missing. Finish anyway?")
        }
        // General lifecycle error alert
        .alert("Error", isPresented: showingLifecycleErrorBinding) {
            Button("OK") { lifecycleError = nil }
        } message: {
            Text(lifecycleError?.localizedDescription ?? "")
        }
        .alert("Score Entry Error", isPresented: showingScoreErrorBinding) {
            Button("OK") { }
        } message: {
            Text(viewModel?.saveError?.localizedDescription ?? "")
        }
        .onAppear { initializeViewModels() }
        .onChange(of: currentHole) {
            autoAdvanceTask?.cancel()
        }
    }

    // MARK: - Private

    private func initializeViewModels() {
        guard viewModel == nil else { return }
        guard let organizer = allPlayers.first(where: { $0.id.uuidString == round.playerIDs.first }) else {
            viewModel = ScorecardViewModel(
                scoringService: appServices.scoringService,
                lifecycleManager: appServices.roundLifecycleManager,
                roundID: round.id,
                reportedByPlayerID: round.organizerID
            )
            leaderboardViewModel = LeaderboardViewModel(
                standingsEngine: appServices.standingsEngine,
                roundID: round.id,
                currentPlayerID: round.organizerID.uuidString
            )
            appServices.standingsEngine.recompute(for: round.id, trigger: .localScore)
            return
        }
        viewModel = ScorecardViewModel(
            scoringService: appServices.scoringService,
            lifecycleManager: appServices.roundLifecycleManager,
            roundID: round.id,
            reportedByPlayerID: organizer.id
        )
        leaderboardViewModel = LeaderboardViewModel(
            standingsEngine: appServices.standingsEngine,
            roundID: round.id,
            currentPlayerID: organizer.id.uuidString
        )
        appServices.standingsEngine.recompute(for: round.id, trigger: .localScore)
    }

    private func enterScore(playerID: String, holeNumber: Int, strokeCount: Int) {
        guard let vm = viewModel else { return }
        do {
            try vm.enterScore(playerID: playerID, holeNumber: holeNumber, strokeCount: strokeCount, isRoundFinished: round.isFinished)
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
                strokeCount: strokeCount,
                isRoundFinished: round.isFinished
            )
            leaderboardViewModel?.handleScoreEntered()
        } catch {
            vm.saveError = error
        }
    }

    // MARK: - Finish Round (manual early finish, Task 7)

    private func finishRoundTapped() {
        guard let vm = viewModel else { return }
        do {
            let result = try vm.finishRound(force: false)
            switch result {
            case .hasMissingScores(let count):
                missingScoreCount = count
                isShowingEarlyFinishWarning = true
            case .completed:
                // No missing scores — round completed directly (post-completion nav is automatic)
                break
            }
        } catch {
            lifecycleError = error
        }
    }

    private func finishRoundForced() {
        guard let vm = viewModel else { return }
        do {
            try vm.finishRound(force: true)
            // Post-completion navigation: HomeView's @Query no longer includes this round,
            // so ScoringTabView automatically switches back to the "Start Round" state.
        } catch {
            lifecycleError = error
        }
    }

    // MARK: - Finalization (after auto-completion prompt, Task 6)

    private func finalizeRoundConfirmed() {
        guard let vm = viewModel else { return }
        do {
            try vm.finalizeRound()
            // Post-completion navigation happens automatically (HomeView @Query update)
        } catch {
            lifecycleError = error
        }
    }

    // MARK: - Auto advance

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

    private var showingScoreErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.saveError != nil },
            set: { if !$0 { viewModel?.saveError = nil } }
        )
    }

    private var showingLifecycleErrorBinding: Binding<Bool> {
        Binding(
            get: { lifecycleError != nil },
            set: { if !$0 { lifecycleError = nil } }
        )
    }
}
