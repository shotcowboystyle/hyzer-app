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
    /// Bolder variant of h2 (title2 · rounded · bold) — used on Round Summary player rows
    /// and any surface that needs h2 rhythm with heavier presence than the semibold default.
    public static let h2Bold:  Font = .system(.title2,     design: .rounded, weight: .bold)
    public static let h3:      Font = .system(.headline,   design: .rounded, weight: .semibold)
    public static let body:    Font = .system(.body,       design: .rounded, weight: .regular)
    public static let caption: Font = .system(.footnote,   design: .rounded, weight: .regular)

    /// Screen-level large title — 34pt bold rounded (e.g. Courses list header).
    /// Same visual size as `hero` but named for header-row usage semantics.
    public static let pageTitle: Font = .system(.largeTitle, design: .rounded, weight: .bold)

    // SF Mono — for score display
    public static let score:      Font = .system(.title2,     design: .monospaced, weight: .bold)
    /// 28pt-class score display — used on the Round Summary standings rows.
    public static let scoreMedium: Font = .system(.title,      design: .monospaced, weight: .bold)
    public static let scoreLarge:  Font = .system(.largeTitle, design: .monospaced, weight: .bold)

    // MARK: - Fixed-size base metrics (use with `@ScaledMetric` at call sites)
    //
    // These are for values that don't map cleanly onto a system text style. Callers
    // that need Dynamic Type should wrap with `@ScaledMetric(wrappedValue: …)`.

    /// Round Summary course-name hero title (38pt bold rounded).
    public static let pageTitleHeroBaseSize: CGFloat = 38

    /// "Hyzer" onboarding wordmark base size (32pt heavy rounded).
    public static let wordmarkBaseSize: CGFloat = 32
    /// Wordmark letter-spacing — -0.02em at 32pt.
    public static let wordmarkTracking: CGFloat = -0.64

    /// Hole-strip active cell number (20pt heavy rounded).
    public static let holeCellNumberBaseSize: CGFloat = 20
    /// Hole-strip "PAR N" label (9.5pt semibold monospace).
    public static let holeCellParBaseSize: CGFloat = 9.5

    /// Watch scoring hero digit (64pt bold monospace).
    public static let watchScoreBaseSize: CGFloat = 64
}
