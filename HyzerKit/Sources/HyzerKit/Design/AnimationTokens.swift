import SwiftUI

/// Animation design tokens.
///
/// Every view using these tokens MUST check `@Environment(\.accessibilityReduceMotion)`
/// and provide a reduced-motion alternative (instant transition or opacity-only).
/// No magic animation values in views — reference this enum.
public enum AnimationTokens {
    public static let springStiff  = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)

    public static let scoreEntryDuration:         TimeInterval = 0.2
    public static let leaderboardReshuffleDuration: TimeInterval = 0.4
    public static let pillPulseDelay:             TimeInterval = 0.2
}
