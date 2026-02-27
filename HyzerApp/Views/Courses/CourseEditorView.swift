import SwiftUI
import SwiftData
import HyzerKit

/// Course creation form presented as a sheet.
///
/// Uses `CourseEditorViewModel` for validation, par management, and saving.
/// `ModelContext` is retrieved from the environment and passed to the VM at save time.
struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = CourseEditorViewModel()
    @State private var isShowingError = false
    @State private var saveError: Error?

    var body: some View {
        NavigationStack {
            Form {
                Section("Course Info") {
                    TextField("Course Name", text: $viewModel.courseName)
                        .font(TypographyTokens.body)
                        .onChange(of: viewModel.courseName) { _, newValue in
                            if newValue.count > 100 {
                                viewModel.courseName = String(newValue.prefix(100))
                            }
                        }
                    Picker("Holes", selection: holeCountBinding) {
                        Text("9").tag(9)
                        Text("18").tag(18)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.backgroundElevated)

                Section("Par Per Hole") {
                    ForEach(0..<viewModel.holeCount, id: \.self) { index in
                        HStack {
                            Text("Hole \(index + 1)")
                                .font(TypographyTokens.body)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Picker("Par", selection: $viewModel.holePars[index]) {
                                ForEach(2...6, id: \.self) { par in
                                    Text("\(par)").tag(par)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                .listRowBackground(Color.backgroundElevated)
            }
            .scrollContentBackground(.hidden)
            .background(Color.backgroundPrimary)
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.accentPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!viewModel.canSave)
                        .foregroundStyle(viewModel.canSave ? Color.accentPrimary : Color.textSecondary)
                }
            }
            .alert("Unable to Save", isPresented: $isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Private

    private var holeCountBinding: Binding<Int> {
        Binding(
            get: { viewModel.holeCount },
            set: { viewModel.setHoleCount($0) }
        )
    }

    private func save() {
        do {
            try viewModel.saveCourse(in: modelContext)
            dismiss()
        } catch {
            saveError = error
            isShowingError = true
        }
    }
}
