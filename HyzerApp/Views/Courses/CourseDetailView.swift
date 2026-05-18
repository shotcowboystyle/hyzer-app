import SwiftUI
import SwiftData
import HyzerKit

/// Read-only view showing a course's holes and pars.
///
/// An Edit toolbar button opens `CourseEditorView` in edit mode as a sheet.
struct CourseDetailView: View {
    let course: Course

    @Query private var holes: [Hole]
    @State private var isShowingEditor = false
    @Environment(\.modelContext) private var modelContext

    init(course: Course) {
        self.course = course
        let courseID = course.id
        _holes = Query(
            filter: #Predicate<Hole> { $0.courseID == courseID },
            sort: \Hole.number
        )
    }

    var body: some View {
        Group {
            if holes.isEmpty {
                VStack {
                    Text("No holes found for this course.")
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if let playerID = resolveLocalPlayerIDString() {
                            PersonalBestCardView(
                                playerID: playerID,
                                courseID: course.id,
                                displayTitle: "Your personal best"
                            )
                            .padding(.top, SpacingTokens.lg)
                            .padding(.bottom, SpacingTokens.lg)
                        }
                        holeList
                    }
                }
                .background(Color.backgroundPrimary)
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Course")
                .tint(Color.accentPrimary)
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            CourseEditorView(course: course, holes: holes)
        }
    }

    // MARK: - Hole list
    //
    // Implemented as ForEach inside the outer ScrollView rather than an embedded List
    // to avoid nested scroll conflicts on iOS 18. Visual parity with the original List
    // is preserved: same HStack layout, same backgroundElevated row treatment.
    @ViewBuilder private var holeList: some View {
        ForEach(holes) { hole in
            VStack(spacing: 0) {
                HStack {
                    Text("Hole \(hole.number)")
                        .font(TypographyTokens.body)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("Par \(hole.par)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.md)
                .background(Color.backgroundElevated)

                Divider()
                    .overlay(Color.backgroundPrimary)
            }
        }
    }

    // MARK: - Local player resolution

    /// Resolves the local player's ID string for Personal Best lookup.
    /// Returns nil pre-onboarding (unreachable on this surface in practice).
    private func resolveLocalPlayerIDString() -> String? {
        AppServices.resolveLocalPlayerID(from: modelContext)?.uuidString
    }
}
