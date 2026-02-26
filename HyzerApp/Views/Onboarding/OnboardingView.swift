import SwiftUI
import SwiftData
import HyzerKit

/// Single-screen onboarding. Asks for display name and creates a Player record.
///
/// - No network calls. No iCloud identity (Story 1.2). No permission prompts.
/// - Works identically with or without network (AC #3).
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = OnboardingViewModel()
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.xl) {
                Spacer()

                Text("What should we call you?")
                    .font(TypographyTokens.h1)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.lg)

                TextField("Your name", text: $viewModel.displayName)
                    .font(TypographyTokens.h2)
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.accentPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, SpacingTokens.md)
                    .padding(.horizontal, SpacingTokens.lg)
                    .background(Color.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, SpacingTokens.lg)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if viewModel.canContinue {
                            saveAndContinue()
                        }
                    }
                    .accessibilityLabel("Display name. Enter the name your friends will see.")

                if viewModel.isOverMaxLength {
                    Text("\(OnboardingViewModel.maxDisplayNameLength) character limit")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.destructive)
                }

                Button(action: saveAndContinue) {
                    Text("Continue")
                        .font(TypographyTokens.h3)
                        .foregroundStyle(Color.backgroundPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: SpacingTokens.minimumTouchTarget)
                        .background(
                            viewModel.canContinue ? Color.accentPrimary : Color.textSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.canContinue)
                .padding(.horizontal, SpacingTokens.lg)
                .accessibilityLabel("Continue. Creates your player profile.")

                Spacer()
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .alert("Unable to Save", isPresented: .init(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("Try Again") { saveAndContinue() }
        } message: {
            Text("Your profile couldn't be saved. Please try again.")
        }
    }

    private func saveAndContinue() {
        withAnimation(AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion: reduceMotion)) {
            viewModel.savePlayer(in: modelContext)
        }
    }
}
