import SwiftUI

/// Animation design tokens.
///
/// Every view using these tokens MUST check `@Environment(\.accessibilityReduceMotion)`
/// and provide a reduced-motion alternative (instant transition or opacity-only).
/// No magic animation values in views — reference this enum.
public enum AnimationTokens {
    public static let springStiff  = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    /// Overshoot spring used by the History course-stack fan-out entrance
    /// (per-index staggered card entrance). Response 0.32 gives ~320ms feel;
    /// damping 0.62 approximates the design spec's `cubic-bezier(0.22, 1.45, 0.36, 1)`.
    public static let springFanOut = Animation.spring(response: 0.32, dampingFraction: 0.62)

    public static let scoreEntryDuration:         TimeInterval = 0.2
    public static let leaderboardReshuffleDuration: TimeInterval = 0.4
    public static let pillPulseDelay:             TimeInterval = 0.2

    /// Standard ease-in-out duration for UI transitions (pill scale, scroll-to-player).
    public static let easeStandardDuration:       TimeInterval = 0.3
    /// Mic icon pulse cycle duration (watchOS voice overlay).
    public static let micPulseDuration:            TimeInterval = 0.8
    /// Auto-commit countdown duration (voice overlay progress bar + timer).
    public static let autoCommitDuration:          TimeInterval = 1.5
    /// CyberOrb breathing cycle duration (ease-in-out, repeats).
    public static let orbBreathingDuration:        TimeInterval = 3.5
}
