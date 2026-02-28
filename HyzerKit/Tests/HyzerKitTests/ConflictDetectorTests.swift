import Testing
import Foundation
@testable import HyzerKit

@Suite("ConflictDetector")
struct ConflictDetectorTests {

    // ConflictDetector is a pure value type — no setup needed.
    let detector = ConflictDetector()

    // MARK: - Case 1: No conflict

    @Test("single event for player+hole returns noConflict")
    func test_check_singleEvent_returnsNoConflict() {
        // Given: only one event for this {player, hole}
        let roundID = UUID()
        let playerID = UUID().uuidString
        let event = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-A")

        // When
        let result = detector.check(newEvent: event, existingEvents: [event])

        // Then
        if case .noConflict = result { } else {
            Issue.record("Expected .noConflict, got \(result)")
        }
    }

    // MARK: - Case 2: Same-device correction

    @Test("supersedesEventID set and same deviceID returns correction")
    func test_check_sameDeviceCorrection_returnsCorrection() {
        // Given: original event, then a correction from the same device
        let roundID = UUID()
        let playerID = UUID().uuidString
        let original = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-A")

        let correction = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4, deviceID: "device-A")
        correction.supersedesEventID = original.id

        let events = [original, correction]

        // When
        let result = detector.check(newEvent: correction, existingEvents: events)

        // Then
        if case .correction = result { } else {
            Issue.record("Expected .correction, got \(result)")
        }
    }

    // MARK: - Case 3: Silent merge

    @Test("different devices same strokeCount with no supersedesEventID returns silentMerge")
    func test_check_differentDeviceSameScore_returnsSilentMerge() {
        // Given: two initial events from different devices with same strokeCount
        let roundID = UUID()
        let playerID = UUID().uuidString
        let eventA = ScoreEvent.fixture(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 4, deviceID: "device-A")
        let eventB = ScoreEvent.fixture(roundID: roundID, holeNumber: 2, playerID: playerID, strokeCount: 4, deviceID: "device-B")

        let events = [eventA, eventB]

        // When: device-B's event arrives
        let result = detector.check(newEvent: eventB, existingEvents: events)

        // Then
        if case .silentMerge = result { } else {
            Issue.record("Expected .silentMerge, got \(result)")
        }
    }

    // MARK: - Case 4a: Discrepancy (different scores)

    @Test("different devices different strokeCount with no supersedesEventID returns discrepancy")
    func test_check_differentDeviceDifferentScore_returnsDiscrepancy() {
        // Given: device-A says 3, device-B says 4 — conflict
        let roundID = UUID()
        let playerID = UUID().uuidString
        let eventA = ScoreEvent.fixture(roundID: roundID, holeNumber: 3, playerID: playerID, strokeCount: 3, deviceID: "device-A")
        let eventB = ScoreEvent.fixture(roundID: roundID, holeNumber: 3, playerID: playerID, strokeCount: 4, deviceID: "device-B")

        let events = [eventA, eventB]

        // When: device-B's event arrives
        let result = detector.check(newEvent: eventB, existingEvents: events)

        // Then
        if case .discrepancy(let existingID, let incomingID) = result {
            #expect(existingID == eventA.id)
            #expect(incomingID == eventB.id)
        } else {
            Issue.record("Expected .discrepancy, got \(result)")
        }
    }

    // MARK: - Case 4b: Cross-device supersession

    @Test("supersedesEventID pointing to event from different deviceID returns discrepancy")
    func test_check_crossDeviceSupersession_returnsDiscrepancy() {
        // Given: device-B "corrects" an event originally recorded by device-A — cross-device supersession
        let roundID = UUID()
        let playerID = UUID().uuidString
        let originalByA = ScoreEvent.fixture(roundID: roundID, holeNumber: 4, playerID: playerID, strokeCount: 3, deviceID: "device-A")

        let crossCorrection = ScoreEvent.fixture(roundID: roundID, holeNumber: 4, playerID: playerID, strokeCount: 5, deviceID: "device-B")
        crossCorrection.supersedesEventID = originalByA.id

        let events = [originalByA, crossCorrection]

        // When: device-B's cross-device supersession arrives
        let result = detector.check(newEvent: crossCorrection, existingEvents: events)

        // Then: treated as discrepancy, not correction
        if case .discrepancy = result { } else {
            Issue.record("Expected .discrepancy for cross-device supersession, got \(result)")
        }
    }

    // MARK: - NFR20: Deterministic with 20+ concurrent identical events

    @Test("20+ concurrent identical events from different devices produce zero discrepancies")
    func test_check_twentyConcurrentIdenticalEvents_zeroDiscrepancies() {
        // Given: 20 devices all record the same score for the same {player, hole}
        let roundID = UUID()
        let playerID = UUID().uuidString
        let events = (0..<20).map { i in
            ScoreEvent.fixture(roundID: roundID, holeNumber: 5, playerID: playerID, strokeCount: 3, deviceID: "device-\(i)")
        }

        // When: check each event against the full set
        var discrepancyCount = 0
        for event in events {
            let result = detector.check(newEvent: event, existingEvents: events)
            if case .discrepancy = result { discrepancyCount += 1 }
        }

        // Then: zero discrepancies (NFR20)
        #expect(discrepancyCount == 0)
    }

    // MARK: - Mixed scenario

    @Test("mixed scores from multiple devices detects correct discrepancies")
    func test_check_mixedScoresMultipleDevices_detectsCorrectDiscrepancies() {
        // Given: 3 devices for player on hole 6
        // device-A and device-B agree on score 3 (silent merge between them)
        // device-C says score 5 (discrepancy with A and B)
        let roundID = UUID()
        let playerID = UUID().uuidString
        let eventA = ScoreEvent.fixture(roundID: roundID, holeNumber: 6, playerID: playerID, strokeCount: 3, deviceID: "device-A")
        let eventB = ScoreEvent.fixture(roundID: roundID, holeNumber: 6, playerID: playerID, strokeCount: 3, deviceID: "device-B")
        let eventC = ScoreEvent.fixture(roundID: roundID, holeNumber: 6, playerID: playerID, strokeCount: 5, deviceID: "device-C")

        let allEvents = [eventA, eventB, eventC]

        // When: check device-B (same score as A) → silent merge
        let resultB = detector.check(newEvent: eventB, existingEvents: allEvents)
        // When: check device-C (different score) → discrepancy
        let resultC = detector.check(newEvent: eventC, existingEvents: allEvents)

        // Then
        if case .silentMerge = resultB { } else {
            Issue.record("Expected .silentMerge for device-B, got \(resultB)")
        }
        if case .discrepancy = resultC { } else {
            Issue.record("Expected .discrepancy for device-C, got \(resultC)")
        }
    }
}
