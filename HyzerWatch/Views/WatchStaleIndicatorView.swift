import SwiftUI
import HyzerKit

/// Displays a staleness indicator when Watch standings have not been updated recently.
///
/// Shown when `lastUpdatedAt` exceeds 30 seconds and the phone is unreachable.
/// Uses `ColorTokens.warning` and `TypographyTokens.caption` per design spec.
struct WatchStaleIndicatorView: View {
    let durationText: String

    var body: some View {
        Label(durationText, systemImage: "wifi.slash")
            .font(TypographyTokens.caption)
            .foregroundStyle(Color.warning)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)
    }
}
