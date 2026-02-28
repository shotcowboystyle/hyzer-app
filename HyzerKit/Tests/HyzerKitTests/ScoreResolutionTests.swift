import Testing
import Foundation
@testable import HyzerKit

@Suite("resolveCurrentScore")
struct ScoreResolutionTests {

    // MARK: - Task 8.1: Deterministic leaf selection (AC6)

    @Test("multiple leaf nodes returns earliest createdAt deterministically")
    func test_resolveCurrentScore_multipleLeaves_returnsDeterministicResult() {
        // Given: two leaf nodes (no supersedesEventID) from different devices — silent merge scenario
        let roundID = UUID()
        let playerID = UUID().uuidString

        let earlier = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-A")
        earlier.createdAt = Date(timeIntervalSince1970: 1000)

        let later = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-B")
        later.createdAt = Date(timeIntervalSince1970: 2000)

        // When: both events exist — neither supersedes the other
        let result = resolveCurrentScore(for: playerID, hole: 1, in: [later, earlier])

        // Then: earliest createdAt wins (NFR20 deterministic resolution)
        #expect(result?.id == earlier.id)
    }

    // MARK: - Task 8.2: Deterministic with 20 leaf nodes

    @Test("20 leaf nodes from different devices returns consistent deterministic result")
    func test_resolveCurrentScore_twentyLeaves_returnsDeterministicResult() {
        // Given: 20 events from different devices for the same {player, hole}
        let roundID = UUID()
        let playerID = UUID().uuidString
        let baseTime = Date(timeIntervalSince1970: 1000)

        let events = (0..<20).map { i -> ScoreEvent in
            let event = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-\(i)")
            event.createdAt = baseTime.addingTimeInterval(Double(i) * 10)
            return event
        }

        // When: resolve 5 times — must always return the same event
        let results = (0..<5).map { _ in
            resolveCurrentScore(for: playerID, hole: 1, in: events.shuffled())
        }

        // Then: all results point to the same event (earliest createdAt)
        let expectedID = events[0].id // device-0 has the earliest timestamp
        #expect(results.allSatisfy { $0?.id == expectedID })
    }

    // MARK: - Existing behavior regression tests

    @Test("single event returns that event")
    func test_resolveCurrentScore_singleEvent_returnsIt() {
        let roundID = UUID()
        let playerID = UUID().uuidString
        let event = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4, deviceID: "device-A")

        let result = resolveCurrentScore(for: playerID, hole: 1, in: [event])

        #expect(result?.id == event.id)
    }

    @Test("correction chain returns the leaf correction")
    func test_resolveCurrentScore_correctionChain_returnsLeaf() {
        let roundID = UUID()
        let playerID = UUID().uuidString

        let original = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 3, deviceID: "device-A")
        let correction = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: playerID, strokeCount: 4, deviceID: "device-A")
        correction.supersedesEventID = original.id

        let result = resolveCurrentScore(for: playerID, hole: 1, in: [original, correction])

        #expect(result?.id == correction.id)
    }

    @Test("no events for player returns nil")
    func test_resolveCurrentScore_noEventsForPlayer_returnsNil() {
        let roundID = UUID()
        let playerID = UUID().uuidString
        let otherEvent = ScoreEvent.fixture(roundID: roundID, holeNumber: 1, playerID: UUID().uuidString, strokeCount: 3, deviceID: "device-A")

        let result = resolveCurrentScore(for: playerID, hole: 1, in: [otherEvent])

        #expect(result == nil)
    }
}
