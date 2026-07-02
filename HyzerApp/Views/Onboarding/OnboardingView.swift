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
            HyzerBackground()

            VStack(spacing: 28) {
                Spacer()

                HyzerLogo()

                Text("What should we call you?")
                    .font(TypographyTokens.h1)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.lg)

                nameField

                if viewModel.isOverMaxLength {
                    Text("\(OnboardingViewModel.maxDisplayNameLength) character limit")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(Color.destructive)
                }

                GradientPrimaryButton(
                    "Continue",
                    isEnabled: viewModel.canContinue,
                    action: saveAndContinue
                )
                .padding(.horizontal, SpacingTokens.lg)
                .accessibilityLabel("Continue. Creates your player profile.")

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.lg)
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

    private var nameField: some View {
        TextField("Your name", text: $viewModel.displayName)
            .font(TypographyTokens.h2)
            .foregroundStyle(Color.textPrimary)
            .tint(Color.accentPrimary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isTextFieldFocused ? Color.accentPrimary : Color.hairline,
                        lineWidth: isTextFieldFocused ? 2 : 1
                    )
            )
            .shadow(
                color: isTextFieldFocused
                    ? Color.accentPrimary.opacity(0.18)
                    : Color.black.opacity(0.25),
                radius: isTextFieldFocused ? 12 : 6,
                x: 0,
                y: isTextFieldFocused ? 0 : 4
            )
            .animation(
                AnimationCoordinator.animation(.easeOut(duration: 0.2), reduceMotion: reduceMotion),
                value: isTextFieldFocused
            )
            .focused($isTextFieldFocused)
            .submitLabel(.done)
            .onSubmit {
                if viewModel.canContinue {
                    saveAndContinue()
                }
            }
            .accessibilityLabel("Display name. Enter the name your friends will see.")
    }

    private func saveAndContinue() {
        withAnimation(AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion: reduceMotion)) {
            viewModel.savePlayer(in: modelContext)
        }
    }
}
