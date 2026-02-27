import SwiftUI
import SwiftData
import HyzerKit

/// Displays all courses sorted alphabetically.
///
/// Uses `@Query` for reactive SwiftData updates — no ViewModel needed (Story 1.3 dev notes).
struct CourseListView: View {
    @Query(sort: \Course.name) private var courses: [Course]
    @State private var isShowingEditor = false

    var body: some View {
        Group {
            if courses.isEmpty {
                emptyState
            } else {
                courseList
            }
        }
        .navigationTitle("Courses")
        .background(Color.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.accentPrimary)
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            CourseEditorView()
        }
    }

    // MARK: - Private

    private var courseList: some View {
        List(courses) { course in
            NavigationLink(destination: CourseDetailView(course: course)) {
                CourseRowView(course: course)
            }
            .listRowBackground(Color.backgroundElevated)
        }
        .scrollContentBackground(.hidden)
        .background(Color.backgroundPrimary)
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.lg) {
            Text("Add a course to get started.")
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Add Course") {
                isShowingEditor = true
            }
            .font(TypographyTokens.body)
            .foregroundStyle(Color.accentPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

// MARK: - Course Row

private struct CourseRowView: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(course.name)
                .font(TypographyTokens.body)
                .foregroundStyle(Color.textPrimary)
            Text("\(course.holeCount) holes")
                .font(TypographyTokens.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, SpacingTokens.xs)
    }
}
