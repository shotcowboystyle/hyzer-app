import SwiftUI
import HyzerKit

/// Root view after onboarding. Placeholder — populated by Stories 1.3+.
struct HomeView: View {
    let player: Player

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                Text("Hey, \(player.displayName.isEmpty ? "Player" : player.displayName)!")
                    .font(TypographyTokens.h1)
                    .foregroundStyle(Color.textPrimary)

                Text("Courses and rounds coming soon.")
                    .font(TypographyTokens.body)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}
