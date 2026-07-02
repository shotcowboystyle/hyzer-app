import SwiftUI
import HyzerKit

// MARK: - ScorecardHoleCardStack

/// Paged `TabView` of `HoleCardView`s — one card per hole in the round.
///
/// Extracted from `ScorecardContainerView` to keep that file under the 600-line
/// SwiftLint budget. Consumed only by `ScorecardContainerView.scoringContent`.
struct ScorecardHoleCardStack: View {
    let round: Round
    let holeCount: Int
    let courseHoles: [Hole]
    let courseName: String
    let scorecardPlayers: [ScorecardPlayer]
    let roundScoreEvents: [ScoreEvent]
    let playerNamesByID: [String: String]
    @Binding var currentHole: Int
    let onScore: (String, Int, Int) -> Void
    let onCorrection: (String, UUID, Int, Int) -> Void

    var body: some View {
        TabView(selection: $currentHole) {
            ForEach(1...max(1, holeCount), id: \.self) { holeNumber in
                let holeParValue = courseHoles.first { $0.number == holeNumber }?.par ?? 3
                HoleCardView(
                    holeNumber: holeNumber,
                    par: holeParValue,
                    courseName: courseName,
                    players: scorecardPlayers,
                    scores: roundScoreEvents.filter { $0.holeNumber == holeNumber },
                    scorerNamesByID: playerNamesByID,
                    isRoundFinished: round.isFinished,
                    onScore: { playerID, strokeCount in
                        onScore(playerID, holeNumber, strokeCount)
                    },
                    onCorrection: { playerID, previousEventID, strokeCount in
                        onCorrection(playerID, previousEventID, holeNumber, strokeCount)
                    }
                )
                .tag(holeNumber)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// MARK: - ScorecardVoiceOverlay

/// Positions and animates `VoiceOverlayView` at the bottom of the scorecard.
struct ScorecardVoiceOverlay: View {
    let voiceVM: VoiceOverlayViewModel
    let par: Int
    let reduceMotion: Bool

    var body: some View {
        let transition: AnyTransition = reduceMotion
            ? .opacity
            : .move(edge: .bottom).combined(with: .opacity)
        VStack {
            Spacer()
            VoiceOverlayView(viewModel: voiceVM, par: par)
                .transition(transition)
                .padding(.bottom, SpacingTokens.lg)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
