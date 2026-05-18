import Foundation
import SwiftData
import HyzerKit
import os.log

/// Fetches and exposes a head-to-head record between two players for `HeadToHeadView`.
///
/// Single-shot: call `compute()` once from `.task`. Matches the shape of `PersonalBestViewModel`.
@MainActor
@Observable
final class HeadToHeadViewModel {
    let playerAID: String
    let playerAName: String
    let playerBID: String
    let playerBName: String

    private(set) var record: HeadToHeadRecord?
    private(set) var errorMessage: String?
    private(set) var hasComputed: Bool = false

    var isLoading: Bool { !hasComputed && errorMessage == nil }
    var hasNoData: Bool {
        hasComputed && (errorMessage != nil || (record?.roundsPlayedTogether ?? 0) == 0)
    }
    var hasData: Bool { hasComputed && errorMessage == nil && (record?.roundsPlayedTogether ?? 0) > 0 }

    var roundsPlayedFormatted: String? {
        guard let r = record, r.roundsPlayedTogether > 0 else { return nil }
        return r.roundsPlayedTogether == 1 ? "1 round" : "\(r.roundsPlayedTogether) rounds"
    }
    var winsAFormatted: String? { record.map { "\($0.winsA)" } }
    var winsBFormatted: String? { record.map { "\($0.winsB)" } }
    var winsAPercentFormatted: String? {
        percentString(numerator: record?.winsA, denominator: record?.roundsPlayedTogether)
    }
    var winsBPercentFormatted: String? {
        percentString(numerator: record?.winsB, denominator: record?.roundsPlayedTogether)
    }

    /// Average differential displayed via `Standing.formatScore(_:)` after rounding (AC #1).
    var averageDifferentialFormatted: String? {
        guard let avg = record?.averageDifferential else { return nil }
        return Standing.formatScore(Int(avg.rounded()))
    }

    /// VoiceOver summary (AC #9). Empty state reads as the AC #3 copy verbatim.
    var accessibilityLabel: String {
        if isLoading { return "Head-to-head loading." }
        if hasData,
           let record,
           let rounds = roundsPlayedFormatted,
           let winsA = winsAFormatted, let pctA = winsAPercentFormatted,
           let winsB = winsBFormatted, let pctB = winsBPercentFormatted,
           let diff = averageDifferentialFormatted
        {
            return "Head-to-head, \(playerAName) versus \(playerBName). \(rounds) played. \(playerAName) wins \(winsA), \(pctA). \(playerBName) wins \(winsB), \(pctB). Average differential \(diff)."
        }
        return "\(playerAName) and \(playerBName) haven't played a round together yet."
    }

    private let service: HeadToHeadServicing
    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "HeadToHeadViewModel")

    /// Reused `NumberFormatter` instance — allocation is non-trivial so we cache one per type.
    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    init(
        modelContext: ModelContext,
        playerAID: String, playerAName: String,
        playerBID: String, playerBName: String
    ) {
        self.playerAID = playerAID
        self.playerAName = playerAName
        self.playerBID = playerBID
        self.playerBName = playerBName
        self.service = HeadToHeadService(modelContext: modelContext)
    }

    /// Testing injection initializer. NOT used in production.
    init(
        service: HeadToHeadServicing,
        playerAID: String, playerAName: String,
        playerBID: String, playerBName: String
    ) {
        self.playerAID = playerAID
        self.playerAName = playerAName
        self.playerBID = playerBID
        self.playerBName = playerBName
        self.service = service
    }

    /// Fetches and computes the record. Called once from `.task` after the View has rendered
    /// with `isLoading == true`, so the user sees `ProgressView` while the SwiftData pass runs.
    func compute() async {
        errorMessage = nil
        hasComputed = false
        do {
            record = try service.computeRecord(for: playerAID, against: playerBID, maxRounds: 500)
            hasComputed = true
        } catch {
            logger.error("HeadToHeadViewModel.compute failed: \(error)")
            errorMessage = "Unable to load head-to-head record."
            hasComputed = true
        }
    }

    private func percentString(numerator: Int?, denominator: Int?) -> String? {
        guard let n = numerator, let d = denominator, d > 0 else { return nil }
        let fraction = Double(n) / Double(d)
        return Self.percentFormatter.string(from: NSNumber(value: fraction))
    }
}
