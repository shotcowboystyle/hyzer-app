import SwiftUI
import HyzerKit

/// Toolbar sync state indicator for the scoring view.
///
/// Reads `syncState` from the `AppServices` environment object and renders
/// a minimal indicator only when the user needs to know about sync status.
///
/// **State mapping:**
/// - `.idle` / `.synced` — no indicator (silence = success)
/// - `.syncing` — subtle `ProgressView` with VoiceOver label
/// - `.offline` — `cloud.slash` SF Symbol in `textSecondary` tint
/// - `.error` — `exclamationmark.icloud` SF Symbol in `warning` tint
///
/// Uses `AnimationTokens` and respects `accessibilityReduceMotion`.
struct SyncIndicatorView: View {
    @Environment(AppServices.self) private var appServices
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        indicator
            .animation(
                reduceMotion ? .none : AnimationTokens.springGentle,
                value: stateID
            )
    }

    // MARK: - Private

    @ViewBuilder
    private var indicator: some View {
        switch appServices.syncState {
        case .idle:
            EmptyView()

        case .syncing:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.7)
                .tint(Color.textSecondary)
                .accessibilityLabel(Text("Syncing scores"))

        case .offline:
            Image(systemName: "cloud.slash")
                .foregroundStyle(Color.textSecondary)
                .accessibilityLabel(Text("Offline — scores saving locally"))

        case .error:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(Color.warning)
                .accessibilityLabel(Text("Sync error — will retry automatically"))
        }
    }

    /// Stable ID used to drive `.animation(value:)` — must change when state changes.
    private var stateID: Int {
        switch appServices.syncState {
        case .idle: return 0
        case .syncing: return 1
        case .offline: return 2
        case .error: return 3
        }
    }
}
