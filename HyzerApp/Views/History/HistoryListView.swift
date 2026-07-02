import SwiftUI
import SwiftData
import HyzerKit

/// History tab root view: reverse-chronological list of completed rounds (Epic 8, Story 8.1).
///
/// `@Query` lives here per the established project pattern (see `ScoringTabView`).
/// `HistoryListViewModel` handles data transformation. Card data is computed lazily
/// per card via `onAppear` for smooth scroll performance with large history lists.
struct HistoryListView: View {
    let currentPlayerID: String

    @Query private var completedRounds: [Round]

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryListViewModel?

    init(currentPlayerID: String) {
        self.currentPlayerID = currentPlayerID
        // Local-capture workaround: `#Predicate` cannot reference a static member
        // (`RoundStatus.completed`) directly. Mirrors the pattern in
        // `PlayerTrendService`, `PersonalBestService`, `HeadToHeadService`.
        let completedStatus = RoundStatus.completed
        _completedRounds = Query(
            filter: #Predicate<Round> { $0.status == completedStatus },
            sort: \Round.completedAt,
            order: .reverse
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if completedRounds.isEmpty {
                    emptyState
                } else if let vm = viewModel {
                    roundList(vm: vm)
                } else {
                    Color.backgroundPrimary
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundPrimary)
            .navigationTitle("History")
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = HistoryListViewModel(modelContext: modelContext, currentPlayerID: currentPlayerID)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.lg) {
            Text("Your round history will appear here after your first completed round.")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xl)
        }
    }

    private func roundList(vm: HistoryListViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.md) {
                ForEach(courseGroups, id: \.courseID) { group in
                    if group.rounds.count == 1, let onlyRound = group.rounds.first {
                        NavigationLink {
                            HistoryRoundDetailView(round: onlyRound, currentPlayerID: currentPlayerID)
                        } label: {
                            HistoryRoundCard(round: onlyRound, viewModel: vm)
                        }
                        .onAppear { vm.ensureCardData(for: onlyRound) }
                    } else {
                        CourseStackView(
                            rounds: group.rounds,
                            viewModel: vm,
                            currentPlayerID: currentPlayerID
                        )
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)
        }
    }

    /// Groups `completedRounds` by course id, preserving reverse-chronological order.
    /// Group order follows the first (most recent) round seen for each course.
    private var courseGroups: [CourseGroup] {
        var order: [UUID] = []
        var byCourse: [UUID: [Round]] = [:]
        for round in completedRounds {
            let key = round.courseID
            if byCourse[key] == nil {
                order.append(key)
                byCourse[key] = []
            }
            byCourse[key]?.append(round)
        }
        return order.map { CourseGroup(courseID: $0, rounds: byCourse[$0] ?? []) }
    }
}

private struct CourseGroup {
    let courseID: UUID
    let rounds: [Round]
}

// MARK: - HistoryRoundCard

private struct HistoryRoundCard: View {
    let round: Round
    let viewModel: HistoryListViewModel

    private var data: HistoryRoundCardData? {
        viewModel.cardDataCache[round.id]
    }

    var body: some View {
        if let data = data {
            cardContent(data: data)
        } else {
            RoundedRectangle(cornerRadius: SpacingTokens.md)
                .fill(Color.backgroundElevated)
                .frame(height: SpacingTokens.xxl * 2)
        }
    }

    private func cardContent(data: HistoryRoundCardData) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text(data.courseName)
                    .font(TypographyTokens.h3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            HStack(spacing: SpacingTokens.xs) {
                Text(data.formattedDate)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Text("·")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
                Text("\(data.playerCount) players")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if data.userIsWinner {
                if let winnerScore = data.winnerFormattedScore {
                    HStack(spacing: SpacingTokens.xs) {
                        Text("You won at")
                            .font(TypographyTokens.body)
                            .foregroundStyle(Color.textPrimary)
                        Text(winnerScore)
                            .font(TypographyTokens.body)
                            .foregroundStyle(data.winnerScoreColor ?? Color.textPrimary)
                    }
                }
            } else {
                if let winnerName = data.winnerName, let winnerScore = data.winnerFormattedScore {
                    HStack(spacing: SpacingTokens.xs) {
                        Text("\(winnerName) won at")
                            .font(TypographyTokens.body)
                            .foregroundStyle(Color.textPrimary)
                        Text(winnerScore)
                            .font(TypographyTokens.body)
                            .foregroundStyle(data.winnerScoreColor ?? Color.textPrimary)
                    }
                }
                if let userPosition = data.userPosition, let userScore = data.userFormattedScore {
                    HStack(spacing: SpacingTokens.xs) {
                        Text("You finished \(userPosition) at")
                            .font(TypographyTokens.body)
                            .foregroundStyle(Color.textPrimary)
                        Text(userScore)
                            .font(TypographyTokens.body)
                            .foregroundStyle(data.userScoreColor ?? Color.textPrimary)
                    }
                }
            }
        }
        .padding(SpacingTokens.lg)
        .background(Color.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(data: data))
    }

    private func accessibilityLabel(data: HistoryRoundCardData) -> String {
        if data.userIsWinner {
            let scoreSuffix = data.winnerScoreRelativeToPar
                .map { " at \(verboseScore(relativeToPar: $0))" } ?? ""
            return "\(data.courseName), \(data.formattedDate). You won\(scoreSuffix)."
        }
        var parts: [String] = ["\(data.courseName), \(data.formattedDate)."]
        if let name = data.winnerName {
            if let rel = data.winnerScoreRelativeToPar {
                parts.append("\(name) won at \(verboseScore(relativeToPar: rel)).")
            } else {
                parts.append("\(name) won.")
            }
        }
        if let position = data.userPosition {
            if let rel = data.userScoreRelativeToPar {
                parts.append("You finished \(position) at \(verboseScore(relativeToPar: rel)).")
            } else {
                parts.append("You finished \(position).")
            }
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - CourseStackView

/// Renders a group of rounds played on the same course as a "fanned card stack".
///
/// Collapsed state: top round's card with 1–2 peeking layers behind it
/// (offset diagonally, rotated, dimmed per depth) + "N rounds" pill badge.
/// Tapping expands the stack into a vertical list with a per-index stagger; a
/// "Collapse" link above the list restacks instantly (no stagger on collapse).
private struct CourseStackView: View {
    let rounds: [Round]
    let viewModel: HistoryListViewModel
    let currentPlayerID: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    /// Per-round appearance flag driving the staggered fan-out animation.
    @State private var appeared: Set<UUID> = []

    private var topRound: Round? { rounds.first }

    private var courseDisplayName: String {
        // Prefer any cached card's course name; fall back to a neutral label.
        rounds
            .compactMap { viewModel.cardDataCache[$0.id]?.courseName }
            .first ?? "Course"
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedList
            } else {
                collapsedStack
            }
        }
        .onAppear {
            // Seed the top round's card data so the collapsed preview renders content.
            if let topRound { viewModel.ensureCardData(for: topRound) }
        }
    }

    // MARK: - Collapsed

    private var collapsedStack: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                ForEach(peekLayers.reversed()) { layer in
                    peekPlaceholder
                        .offset(x: layer.xOffset, y: layer.yOffset)
                        .rotationEffect(.degrees(layer.rotation))
                        .opacity(layer.opacity)
                }
                if let topRound {
                    HistoryRoundCard(round: topRound, viewModel: viewModel)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleExpanded() }

            countBadge
                .padding(.top, SpacingTokens.sm)
                .padding(.trailing, SpacingTokens.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(courseDisplayName), \(rounds.count) rounds. Tap to expand.")
        .accessibilityAddTraits(.isButton)
    }

    private var peekPlaceholder: some View {
        RoundedRectangle(cornerRadius: SpacingTokens.md)
            .fill(Color.backgroundElevated)
            .frame(height: SpacingTokens.xxl * 2)
            .overlay(
                RoundedRectangle(cornerRadius: SpacingTokens.md)
                    .stroke(Color.hairline, lineWidth: 1)
            )
    }

    private var peekLayers: [PeekLayer] {
        let depthCount = min(2, rounds.count - 1)
        guard depthCount > 0 else { return [] }
        return (1...depthCount).map { depth in
            PeekLayer(
                id: depth,
                xOffset: CGFloat(depth) * 5,
                yOffset: CGFloat(depth) * 6,
                rotation: Double(depth) * 1.4,
                opacity: 1.0 - Double(depth) * 0.18
            )
        }
    }

    private var countBadge: some View {
        Text("\(rounds.count) rounds")
            .font(TypographyTokens.caption)
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, 4)
            .background(Color.backgroundTertiary)
            .clipShape(Capsule())
            .accessibilityHidden(true)
    }

    // MARK: - Expanded

    private var expandedList: some View {
        VStack(spacing: SpacingTokens.sm) {
            collapseLink
            ForEach(Array(rounds.enumerated()), id: \.element.id) { index, round in
                NavigationLink {
                    HistoryRoundDetailView(round: round, currentPlayerID: currentPlayerID)
                } label: {
                    HistoryRoundCard(round: round, viewModel: viewModel)
                }
                .onAppear { viewModel.ensureCardData(for: round) }
                .opacity(appeared.contains(round.id) ? 1 : 0)
                .scaleEffect(appeared.contains(round.id) ? 1.0 : 0.97)
                .offset(y: appeared.contains(round.id) ? 0 : -10)
                .task(id: round.id) { await animateEntrance(for: round, index: index) }
            }
        }
    }

    private var collapseLink: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button {
                collapse()
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "chevron.left")
                    Text("Collapse \(courseDisplayName)")
                }
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .accessibilityLabel("Collapse \(courseDisplayName) stack")
    }

    // MARK: - Animation

    private func toggleExpanded() {
        if reduceMotion {
            isExpanded.toggle()
            appeared = Set(rounds.map(\.id))
            return
        }
        withAnimation(AnimationCoordinator.animation(AnimationTokens.springGentle, reduceMotion: reduceMotion)) {
            isExpanded = true
        }
    }

    private func collapse() {
        // Collapse is instant — no stagger, per spec.
        appeared.removeAll()
        withAnimation(AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion: reduceMotion)) {
            isExpanded = false
        }
    }

    private func animateEntrance(for round: Round, index: Int) async {
        guard isExpanded, !appeared.contains(round.id) else { return }
        if reduceMotion {
            appeared.insert(round.id)
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(40 * index))
        } catch {
            if Task.isCancelled { return }
            // Non-cancellation errors are unexpected; continue without delay.
        }
        guard isExpanded else { return }
        withAnimation(AnimationCoordinator.animation(AnimationTokens.springFanOut, reduceMotion: reduceMotion)) {
            _ = appeared.insert(round.id)
        }
    }
}

private struct PeekLayer: Identifiable {
    let id: Int
    let xOffset: CGFloat
    let yOffset: CGFloat
    let rotation: Double
    let opacity: Double
}
