import SwiftUI

/// Typography design tokens using SF Pro Rounded and SF Mono.
///
/// All fonts use system text styles where possible for automatic Dynamic Type scaling.
/// For the Hero size (48pt), views should use `@ScaledMetric(wrappedValue: TypographyTokens.heroBaseSize)`.
public enum TypographyTokens {
    /// Base size for hero text. Use with `@ScaledMetric` in views.
    public static let heroBaseSize: CGFloat = 48

    // SF Pro Rounded — scales with Dynamic Type via system text styles
    public static let hero:    Font = .system(.largeTitle, design: .rounded, weight: .bold)
    public static let h1:      Font = .system(.title,      design: .rounded, weight: .bold)
    public static let h2:      Font = .system(.title2,     design: .rounded, weight: .semibold)
    public static let h3:      Font = .system(.headline,   design: .rounded, weight: .semibold)
    public static let body:    Font = .system(.body,       design: .rounded, weight: .regular)
    public static let caption: Font = .system(.caption,    design: .rounded, weight: .regular)

    // SF Mono — for score display
    public static let score:      Font = .system(.title2,  design: .monospaced, weight: .bold)
    public static let scoreLarge: Font = .system(.title,   design: .monospaced, weight: .bold)
}
