import SwiftUI
import SwiftData
import HyzerKit

/// Root view after onboarding — 3-tab navigation shell (Story 1.3).
struct HomeView: View {
    let player: Player

    @Environment(AppServices.self) private var appServices
    @State private var selectedTab = 0

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
    }

    /// Routes to the Scoring tab and consumes `pendingDeepLink`.
    /// Called from both `.onAppear` (covers cold-launch seeding where the value is set
    /// before the view mounts and `.onChange` would not fire) and `.onChange`.
    private func consumePendingDeepLinkIfNeeded() {
        guard let deepLink = appServices.pendingDeepLink, case .activeRound = deepLink else { return }
        selectedTab = 0
        appServices.pendingDeepLink = nil
    }
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
