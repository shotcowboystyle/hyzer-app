import SwiftUI
import HyzerKit

/// Horizontally scrollable hole navigator. Each cell shows the hole's par above
/// its number; the active cell fills with accent + glows and the strip auto-scrolls
/// to keep it horizontally centered.
///
/// Sits above `HoleCardView` inside `ScorecardContainerView`. Replaces the previous
/// `TabView(.page)` dot indicator — the page swipe remains, the dots are gone.
struct HoleStripView: View {
    let holes: [HoleCell]
    @Binding var activeHole: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(holes) { hole in
                        cell(for: hole)
                            .id(hole.number)
                            .onTapGesture {
                                withAnimation(
                                    AnimationCoordinator.animation(
                                        AnimationTokens.springGentle,
                                        reduceMotion: reduceMotion
                                    )
                                ) {
                                    activeHole = hole.number
                                }
                            }
                    }
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.sm)
            }
            .background(Color.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusCard))
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            .padding(.horizontal, SpacingTokens.sm)
            .onAppear { center(proxy: proxy, animated: false) }
            .onChange(of: activeHole) { _, _ in center(proxy: proxy, animated: true) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Hole navigator")
        }
    }

    private func center(proxy: ScrollViewProxy, animated: Bool) {
        let target = activeHole
        if animated && !reduceMotion {
            withAnimation(AnimationCoordinator.animation(
                AnimationTokens.springGentle,
                reduceMotion: reduceMotion
            )) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func cell(for hole: HoleCell) -> some View {
        let isActive = hole.number == activeHole
        return VStack(spacing: 2) {
            Text("PAR \(hole.par)")
                .font(.system(size: TypographyTokens.holeCellParBaseSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(isActive ? Color.accentInk.opacity(0.75) : Color.textSecondary)
            Text("\(hole.number)")
                .font(.system(size: TypographyTokens.holeCellNumberBaseSize, weight: .heavy, design: .rounded))
                .foregroundStyle(isActive ? Color.accentInk : Color.textPrimary)
        }
        .frame(width: 50, height: 50)
        .background(
            RoundedRectangle(cornerRadius: SpacingTokens.cornerRadiusInline)
                .fill(isActive ? Color.accentPrimary : Color.backgroundPrimary.opacity(0.5))
        )
        .scaleEffect(isActive ? 1.06 : 1.0)
        .shadow(
            color: isActive ? Color.accentPrimary.opacity(0.55) : .clear,
            radius: 14, x: 0, y: 4
        )
        .animation(
            AnimationCoordinator.animation(AnimationTokens.springStiff, reduceMotion: reduceMotion),
            value: isActive
        )
        .accessibilityLabel("Hole \(hole.number), par \(hole.par)\(isActive ? ", current" : "")")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

/// Minimal data envelope for the strip — decoupled from SwiftData's `Hole`.
struct HoleCell: Identifiable, Equatable {
    var id: Int { number }
    let number: Int
    let par: Int
}
