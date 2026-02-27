import SwiftUI
import SwiftData
import HyzerKit

/// Round setup flow: course selection → player management → start round.
///
/// Presented as a sheet from the Scoring tab. Dismisses on successful round start.
struct RoundSetupView: View {
    let organizer: Player

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Player.displayName) private var players: [Player]

    @State private var viewModel = RoundSetupViewModel()
    @State private var searchText = ""
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            Form {
                courseSection
                playerSection
                guestSection

                if viewModel.selectedCourse != nil {
                    summarySection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimary)
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search players")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.accentPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { startRound() }
                        .disabled(!viewModel.canStartRound)
                        .foregroundStyle(viewModel.canStartRound ? Color.accentPrimary : Color.textSecondary)
                }
            }
            .alert("Unable to Start Round", isPresented: $isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.saveError?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Sections

    private var courseSection: some View {
        Section {
            if courses.isEmpty {
                Text("No courses available.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(courses) { course in
                    HStack {
                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text(course.name)
                                .font(TypographyTokens.body)
                                .foregroundStyle(Color.textPrimary)
                            Text("\(course.holeCount) holes")
                                .font(TypographyTokens.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        if viewModel.selectedCourse?.id == course.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedCourse = course
                    }
                    .listRowBackground(Color.backgroundElevated)
                }
            }
        } header: {
            Text("Select Course")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var filteredPlayers: [Player] {
        let nonOrganizers = players.filter { $0.id != organizer.id }
        guard !searchText.isEmpty else { return nonOrganizers }
        return nonOrganizers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var playerSection: some View {
        Section {
            ForEach(filteredPlayers) { player in
                let isAdded = viewModel.addedPlayers.contains(where: { $0.id == player.id })
                HStack {
                    Text(player.displayName)
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if isAdded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isAdded {
                        viewModel.removePlayer(player)
                    } else {
                        viewModel.addPlayer(player)
                    }
                }
                .listRowBackground(Color.backgroundElevated)
            }
        } header: {
            Text("Add Players")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var guestSection: some View {
        Section {
            ForEach(viewModel.guestNames, id: \.self) { name in
                HStack {
                    Text(name)
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Image(systemName: "person.fill.questionmark")
                        .foregroundStyle(Color.textSecondary)
                }
                .listRowBackground(Color.backgroundElevated)
            }
            .onDelete { offsets in
                viewModel.removeGuest(at: offsets)
            }

            HStack {
                TextField("Guest name", text: $viewModel.guestNameInput)
                    .font(TypographyTokens.body)
                    .onChange(of: viewModel.guestNameInput) { _, newValue in
                        if newValue.count > 50 {
                            viewModel.guestNameInput = String(newValue.prefix(50))
                        }
                    }
                Button("Add") {
                    viewModel.addGuest()
                }
                .foregroundStyle(Color.accentPrimary)
                .disabled(viewModel.guestNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .listRowBackground(Color.backgroundElevated)
        } header: {
            Text("Add Guests")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var summarySection: some View {
        Section {
            if let course = viewModel.selectedCourse {
                HStack {
                    Text("Course")
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(course.name)
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                }
                .listRowBackground(Color.backgroundElevated)

                let participantCount = 1 + viewModel.addedPlayers.count + viewModel.guestNames.count
                HStack {
                    Text("Players")
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("\(participantCount)")
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                }
                .listRowBackground(Color.backgroundElevated)
            }
        } header: {
            Text("Summary")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Actions

    private func startRound() {
        do {
            try viewModel.startRound(organizer: organizer, in: modelContext)
            dismiss()
        } catch {
            viewModel.saveError = error
            isShowingError = true
        }
    }
}
