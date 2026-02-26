import CoreFoundation

/// Spacing design tokens based on an 8pt grid.
///
/// Touch targets: minimum 44×44pt (Apple HIG). Scoring controls: 48–56pt.
public enum SpacingTokens {
    public static let xs:  CGFloat = 4
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 16
    public static let lg:  CGFloat = 24
    public static let xl:  CGFloat = 32
    public static let xxl: CGFloat = 48

    /// Minimum touch target per Apple HIG.
    public static let minimumTouchTarget: CGFloat = 44
    /// Recommended touch target for scoring controls.
    public static let scoringTouchTarget: CGFloat = 52
}
