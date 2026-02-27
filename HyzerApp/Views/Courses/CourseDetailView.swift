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
                List(holes) { hole in
                    HStack {
                        Text("Hole \(hole.number)")
                            .font(TypographyTokens.body)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text("Par \(hole.par)")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .listRowBackground(Color.backgroundElevated)
                }
                .scrollContentBackground(.hidden)
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
}
