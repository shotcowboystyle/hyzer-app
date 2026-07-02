import SwiftUI
import HyzerKit

/// Full-width primary CTA capsule with the "Tropic Tide" gradient fill,
/// teal glow shadow, and a subtle glass-sheen highlight.
///
/// Used on Onboarding, Scoring empty-state, Round Setup footer, Round Summary,
/// and any other primary confirm surface.
struct GradientPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.h3)
                .foregroundStyle(isEnabled ? Color.accentInk : Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SpacingTokens.voiceTouchTarget)
                .background(background)
                .overlay(sheen)
                .clipShape(Capsule())
                .shadow(
                    color: isEnabled ? Color.accentPrimary.opacity(0.55) : .clear,
                    radius: 24, x: 0, y: 10
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(
            AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion: reduceMotion),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }

    @ViewBuilder
    private var background: some View {
        if isEnabled {
            LinearGradient.hyzerPrimary
        } else {
            Color.backgroundTertiary
        }
    }

    private var sheen: some View {
        // Top-edge and bottom-edge highlights give the fill a slight glass/sheen depth.
        Capsule()
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isEnabled ? 0.35 : 0),
                        Color.white.opacity(0),
                        Color.white.opacity(isEnabled ? 0.12 : 0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }
}

#Preview("Enabled / Disabled") {
    VStack(spacing: SpacingTokens.md) {
        GradientPrimaryButton("Continue") { }
        GradientPrimaryButton("Continue", isEnabled: false) { }
    }
    .padding(SpacingTokens.lg)
    .background(Color.backgroundPrimary)
}
