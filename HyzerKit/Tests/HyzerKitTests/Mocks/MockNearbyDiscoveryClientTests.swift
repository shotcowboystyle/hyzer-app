import Testing
import Foundation
@testable import HyzerKit
import TestSupport

@Suite("MockNearbyDiscoveryClient")
struct MockNearbyDiscoveryClientTests {

    @Test("simulateFoundPeer yields payload on stream")
    func test_simulateFoundPeer_yieldsPayloadOnStream() async {
        let mock = MockNearbyDiscoveryClient()
        let roundID = UUID()
        let playerIDs = ["player-1", "player-2"]
        var received: DiscoveredRoundPayload?

        // Start consuming the stream before simulating. The Task captures the
        // continuation assignment which happens synchronously in the AsyncStream block.
        let task = Task {
            for await payload in mock.discoveredRounds {
                received = payload
                return
            }
        }

        // Brief yield to allow the Task to subscribe before we inject.
        // Deferred work: replace with deterministic wait once the project-wide
        // flaky-timing pattern (CLAUDE.md "Task.sleep pattern") is resolved.
        try? await Task.sleep(for: .milliseconds(20))
        mock.simulateFoundPeer(roundID: roundID, playerIDs: playerIDs)
        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()

        #expect(received?.roundID == roundID)
        #expect(received?.playerIDs == playerIDs)
    }

    @Test("startAdvertising records call count and last advertised roundID")
    func test_startAdvertising_recordsCallCountAndLastRoundID() async {
        let mock = MockNearbyDiscoveryClient()
        let roundID = UUID()

        #expect(mock.startAdvertisingCallCount == 0)
        await mock.startAdvertising(roundID: roundID, playerIDs: ["p1"])
        #expect(mock.startAdvertisingCallCount == 1)
        #expect(mock.lastAdvertisedRoundID == roundID)
        #expect(mock.lastAdvertisedPlayerIDs == ["p1"])
    }

    @Test("stopAdvertising clears lastAdvertisedRoundID")
    func test_stopAdvertising_clearsLastAdvertisedRoundID() async {
        let mock = MockNearbyDiscoveryClient()
        let roundID = UUID()

        await mock.startAdvertising(roundID: roundID, playerIDs: [])
        #expect(mock.lastAdvertisedRoundID == roundID)

        await mock.stopAdvertising()
        #expect(mock.stopAdvertisingCallCount == 1)
        #expect(mock.lastAdvertisedRoundID == nil)
    }
}
