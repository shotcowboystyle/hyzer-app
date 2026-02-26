import SwiftUI

/// Applies an animation from `AnimationTokens`, automatically switching to
/// an instant transition when `accessibilityReduceMotion` is enabled.
///
/// Usage:
/// ```swift
/// @Environment(\.accessibilityReduceMotion) private var reduceMotion
///
/// withAnimation(AnimationCoordinator.animation(.springStiff, reduceMotion: reduceMotion)) {
///     // state change
/// }
/// ```
public enum AnimationCoordinator {
    public static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : animation
    }
}
