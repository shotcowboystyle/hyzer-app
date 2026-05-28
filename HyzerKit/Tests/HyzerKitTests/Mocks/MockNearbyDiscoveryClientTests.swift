import Testing
import Foundation
@testable import HyzerKit
import TestSupport

@Suite("MockNearbyDiscoveryClient")
struct MockNearbyDiscoveryClientTests {

    @Test("simulateFoundPeer yields payload on stream")
    func test_simulateFoundPeer_yieldsPayloadOnStream() async throws {
        let mock = MockNearbyDiscoveryClient()
        let roundID = UUID()
        let playerIDs = ["player-1", "player-2"]
        let collector = ValueCollector<DiscoveredRoundPayload>()

        // MockNearbyDiscoveryClient uses the default unbounded AsyncStream buffering
        // (see MockNearbyDiscoveryClient.swift:32 — `AsyncStream.makeStream` default),
        // so the order of subscription and injection is irrelevant: events injected
        // before subscription are buffered until the consumer subscribes.
        let task = Task {
            for await payload in mock.discoveredRounds {
                await collector.append(payload)
                return
            }
        }

        mock.simulateFoundPeer(roundID: roundID, playerIDs: playerIDs)
        try await waitUntil({ await collector.count >= 1 }, conditionDescription: "stream yields payload")
        task.cancel()

        let received = await collector.values.first
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
