import SwiftUI
import SwiftData
import os.log
import HyzerKit

/// Thin `Identifiable` wrapper around `UUID` — required by `.fullScreenCover(item:)`.
private struct IdentifiableUUID: Identifiable {
    let id: UUID
}

/// Routing key for the discrepancy deep-link cover.
/// Uses a composed string ID so SwiftUI's `.fullScreenCover(item:)` gets an `Identifiable` value.
private struct DiscrepancyDeepLinkKey: Identifiable, Equatable {
    let roundID: UUID
    let playerID: String
    let holeNumber: Int
    var id: String { "\(roundID)-\(playerID)-\(holeNumber)" }
}

/// Root view after onboarding — 3-tab navigation shell (Story 1.3).
struct HomeView: View {
    let player: Player

    @Environment(AppServices.self) private var appServices
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var pendingSummaryRoundID: UUID?
    @State private var pendingDiscrepancyKey: DiscrepancyDeepLinkKey?

    @Query(
        filter: #Predicate<Round> { $0.status == "active" || $0.status == "awaitingFinalization" },
        sort: \Round.startedAt
    ) private var activeRounds: [Round]

    var body: some View {
        TabView(selection: $selectedTab) {
            ScoringTabView(player: player)
                .tabItem { Label("Scoring", systemImage: "sportscourt") }
                .tag(0)
            HistoryTabView(player: player)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)
            NavigationStack {
                CourseListView()
            }
            .tabItem { Label("Courses", systemImage: "map") }
            .tag(2)
        }
        .tint(Color.accentPrimary)
        .onAppear { consumePendingDeepLinkIfNeeded() }
        .onChange(of: appServices.pendingDeepLink) { _, _ in consumePendingDeepLinkIfNeeded() }
        // Discrepancy modifier is above the summary modifier — discrepancy preempts summary (correct priority).
        .fullScreenCover(item: $pendingDiscrepancyKey) { key in
            DiscrepancyResolutionDeepLinkHost(key: key) {
                pendingDiscrepancyKey = nil
            }
        }
        .fullScreenCover(
            item: Binding(
                get: { pendingSummaryRoundID.map { IdentifiableUUID(id: $0) } },
                set: { pendingSummaryRoundID = $0?.id }
            )
        ) { item in
            RoundCompletionSummaryHost(roundID: item.id) {
                pendingSummaryRoundID = nil
            }
        }
    }

    /// Routes to the Scoring tab or presents the round summary / discrepancy resolution and consumes `pendingDeepLink`.
    /// Called from both `.onAppear` (covers cold-launch seeding) and `.onChange`.
    private func consumePendingDeepLinkIfNeeded() {
        guard let deepLink = appServices.pendingDeepLink else { return }
        switch deepLink {
        case .activeRound:
            selectedTab = 0
            appServices.pendingDeepLink = nil
        case .roundSummary(let roundID):
            // Defer the summary cover when the user is mid-scoring a different round —
            // force-presenting a cover would yank them out of their active scoring session.
            // The completed round is available via History; consume the deep-link without
            // routing rather than queueing (queueing risks a stale cover later).
            if !activeRounds.isEmpty {
                appServices.pendingDeepLink = nil
                return
            }
            selectedTab = 0
            pendingSummaryRoundID = roundID
            appServices.pendingDeepLink = nil
        case .discrepancyResolution(let roundID, let playerID, let holeNumber):
            selectedTab = 0
            // AC #3 reinterpretation per spec Task 8.2: when the deep-linked round is currently
            // active, satisfy "the discrepancy resolution view appears directly" via the badge
            // surfaced reactively by `ScorecardContainerView` rather than by pushing a cover that
            // would yank the organizer out of mid-round scoring. For non-active rounds we present
            // `DiscrepancyResolutionView` directly via `pendingDiscrepancyKey`.
            if activeRounds.contains(where: { $0.id == roundID }) {
                appServices.pendingDeepLink = nil
                return
            }
            pendingDiscrepancyKey = DiscrepancyDeepLinkKey(roundID: roundID, playerID: playerID, holeNumber: holeNumber)
            appServices.pendingDeepLink = nil
        }
    }
}

// MARK: - RoundCompletionSummaryHost

/// Fetches the completed Round by ID and presents `RoundSummaryView` as a full-screen modal.
///
/// Presented from `HomeView` (not `ScoringTabView`) because `ScoringTabView.activeRounds`
/// only queries `status == "active"` or `"awaitingFinalization"` — a completed round won't appear there.
private struct RoundCompletionSummaryHost: View {
    let roundID: UUID
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    @State private var summaryViewModel: RoundSummaryViewModel?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let vm = summaryViewModel {
                RoundSummaryView(viewModel: vm, onDismiss: onDismiss)
            } else if isLoading {
                ProgressView("Loading summary…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
            } else {
                // Round not found after retry — dismiss silently (no error toast per AC #2 spirit).
                Color.clear.onAppear { onDismiss() }
            }
        }
        .task { await loadSummary() }
    }

    private func loadSummary() async {
        // Recompute standings (idempotent — ensures latest synced events are reflected).
        appServices.standingsEngine.recompute(for: roundID, trigger: .remoteSync)

        if let vm = buildViewModel() {
            summaryViewModel = vm
            isLoading = false
            return
        }

        // Round / course not locally materialised yet. Pull-and-retry with bounded
        // exponential backoff (no Task.yield busy-loop — that completed in microseconds
        // and silently dismissed any non-instant sync per CLAUDE.md tech-debt note).
        let backoffsMillis: [UInt64] = [200, 500, 1000]
        for delay in backoffsMillis {
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            await appServices.syncEngine.pullRecords()
            appServices.standingsEngine.recompute(for: roundID, trigger: .remoteSync)
            if let vm = buildViewModel() {
                summaryViewModel = vm
                isLoading = false
                return
            }
        }
        isLoading = false
    }

    private func buildViewModel() -> RoundSummaryViewModel? {
        var roundDescriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == roundID })
        roundDescriptor.fetchLimit = 1
        guard let round = (try? modelContext.fetch(roundDescriptor))?.first else { return nil }

        let fetchedCourseID = round.courseID
        var courseDescriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == fetchedCourseID })
        courseDescriptor.fetchLimit = 1
        // Require the Course locally — without it, coursePar is 0 and the summary card
        // renders a degenerate "Round complete at Unknown Course" placeholder. Fall through
        // to the silent-dismiss branch and let the user re-open via History.
        guard let course = (try? modelContext.fetch(courseDescriptor))?.first else { return nil }
        let courseName = course.name

        let courseID = fetchedCourseID
        var holeDescriptor = FetchDescriptor<Hole>(predicate: #Predicate { $0.courseID == courseID })
        holeDescriptor.fetchLimit = round.holeCount
        let holes = (try? modelContext.fetch(holeDescriptor)) ?? []
        // No holes locally means coursePar is 0; abandon rather than render gibberish.
        guard !holes.isEmpty else { return nil }
        let coursePar = holes.reduce(0) { $0 + $1.par }

        let standings = appServices.standingsEngine.currentStandings
        // For a completed-round summary, the round's hole count is authoritative; the
        // leader's `holesPlayed` could lag for DNF players in the standings array.
        let played = round.holeCount
        let localPlayerID = AppServices.resolveLocalPlayerID(from: modelContext)
        let currentPlayerID = localPlayerID?.uuidString ?? round.organizerID.uuidString

        return RoundSummaryViewModel(
            round: round,
            standings: standings,
            courseName: courseName,
            holesPlayed: played,
            coursePar: coursePar,
            currentPlayerID: currentPlayerID
        )
    }
}

// MARK: - DiscrepancyResolutionDeepLinkHost

/// Fetches the target Discrepancy by `{roundID, playerID, holeNumber}` and presents
/// `DiscrepancyResolutionView` as a full-screen modal for notification deep-links.
///
/// Handles both the `.unresolved` flow (organizer picks the correct score) and the AC #4
/// "already resolved" path (read-only view with a banner — no duplicate resolution event).
private struct DiscrepancyResolutionDeepLinkHost: View {
    let key: DiscrepancyDeepLinkKey
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    @State private var discrepancy: Discrepancy?
    @State private var discrepancyViewModel: DiscrepancyViewModel?
    @State private var playerName: String = ""
    @State private var playerNamesByID: [String: String] = [:]
    @State private var isPresented: Bool = true
    @State private var isLoading = true

    var body: some View {
        Group {
            if let vm = discrepancyViewModel, let d = discrepancy {
                NavigationStack {
                    DiscrepancyResolutionView(
                        viewModel: vm,
                        discrepancy: d,
                        playerName: playerName,
                        playerNamesByID: playerNamesByID,
                        isPresented: $isPresented,
                        isAlreadyResolved: d.status == .resolved
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { onDismiss() }
                        }
                    }
                }
            } else if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundPrimary)
            } else {
                Color.clear.onAppear { onDismiss() }
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue { onDismiss() }
        }
        .task { await loadDiscrepancy() }
    }

    private func loadDiscrepancy() async {
        let roundID = key.roundID
        let playerID = key.playerID
        let holeNumber = key.holeNumber

        var descriptor = FetchDescriptor<Discrepancy>(
            predicate: #Predicate { $0.roundID == roundID && $0.playerID == playerID && $0.holeNumber == holeNumber },
            sortBy: [SortDescriptor(\Discrepancy.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let d: Discrepancy
        do {
            guard let fetched = try modelContext.fetch(descriptor).first else {
                isLoading = false
                return
            }
            d = fetched
        } catch {
            Self.logger.error("loadDiscrepancy: Discrepancy fetch failed: \(error)")
            isLoading = false
            return
        }

        var roundDescriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == roundID })
        roundDescriptor.fetchLimit = 1
        let round: Round
        do {
            guard let fetched = try modelContext.fetch(roundDescriptor).first else {
                isLoading = false
                return
            }
            round = fetched
        } catch {
            Self.logger.error("loadDiscrepancy: Round fetch failed: \(error)")
            isLoading = false
            return
        }

        let localPlayerID = AppServices.resolveLocalPlayerID(from: modelContext) ?? round.organizerID

        var playerDescriptor = FetchDescriptor<Player>()
        playerDescriptor.fetchLimit = 200
        let players: [Player]
        do {
            players = try modelContext.fetch(playerDescriptor)
        } catch {
            Self.logger.error("loadDiscrepancy: Player fetch failed: \(error)")
            players = []
        }
        let nameLookup = Dictionary(uniqueKeysWithValues: players.map { ($0.id.uuidString, $0.displayName) })

        let resolvedPlayerName: String
        if let player = players.first(where: { $0.id.uuidString == playerID }) {
            resolvedPlayerName = player.displayName
        } else {
            let guestIndex = round.guestIDs.firstIndex(of: playerID)
            resolvedPlayerName = guestIndex.flatMap { round.guestNames.indices.contains($0) ? round.guestNames[$0] : nil } ?? playerID
        }

        let vm = DiscrepancyViewModel(
            scoringService: appServices.scoringService,
            standingsEngine: appServices.standingsEngine,
            modelContext: modelContext,
            roundID: round.id,
            organizerID: round.organizerID,
            currentPlayerID: localPlayerID
        )
        // AC #4: skip `loadUnresolved()` for already-resolved discrepancies — the view reads
        // `discrepancy` directly so the VM does not need its unresolved-flow state populated,
        // and per spec Open Question #3 the VM is "focused on the unresolved-flow".
        if d.status == .unresolved {
            vm.loadUnresolved()
        }

        discrepancy = d
        discrepancyViewModel = vm
        playerName = resolvedPlayerName
        playerNamesByID = nameLookup
        isLoading = false
    }

    private static let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "DiscrepancyResolutionDeepLinkHost")
}

// MARK: - Scoring Tab

private struct ScoringTabView: View {
    let player: Player

    @Environment(AppServices.self) private var appServices
    @Query(
        filter: #Predicate<Round> { $0.status == "active" || $0.status == "awaitingFinalization" },
        sort: \Round.startedAt
    ) private var activeRounds: [Round]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingRoundSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if let activeRound = activeRounds.first {
                    ScorecardContainerView(round: activeRound)
                        .transition(.opacity)
                } else {
                    noRoundView
                        .transition(.opacity)
                }
            }
            .animation(AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion), value: activeRounds.isEmpty)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("Scoring")
        }
        .sheet(isPresented: $isShowingRoundSetup) {
            RoundSetupView(organizer: player)
        }
    }

    private var noRoundView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Text("No round in progress.")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
            Button("Start Round") {
                requestNotificationPermissionIfNeeded()
                isShowingRoundSetup = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentPrimary)
        }
    }

    /// Requests notification authorization on first "New Round" tap (AC #3).
    ///
    /// Fire-and-forget: round creation succeeds regardless of the user's authorization decision.
    /// UserDefaults flag ensures we attempt the prompt exactly once (system is already idempotent,
    /// but the flag enables single-prompt semantics in tests without relying on UNUserNotificationCenter state).
    private func requestNotificationPermissionIfNeeded() {
        let defaults = UserDefaults.standard
        let hasPromptedKey = "HyzerApp.notifications.hasPrompted"
        guard !defaults.bool(forKey: hasPromptedKey) else { return }
        let service = appServices.notificationService
        Task {
            let status = await service.requestAuthorization()
            // Only persist the prompted flag on a definitive system outcome — a transient
            // error (status returned as .notDetermined from the live service's catch path)
            // should leave the flag unset so the next "New Round" tap can retry.
            if status != .notDetermined {
                UserDefaults.standard.set(true, forKey: hasPromptedKey)
            }
        }
    }
}

// MARK: - History Tab

private struct HistoryTabView: View {
    let player: Player

    var body: some View {
        HistoryListView(currentPlayerID: player.id.uuidString)
    }
}
