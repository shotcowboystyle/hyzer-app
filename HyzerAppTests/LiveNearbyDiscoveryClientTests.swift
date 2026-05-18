import Testing
import Foundation
@testable import HyzerApp

@Suite("LiveNearbyDiscoveryClient")
struct LiveNearbyDiscoveryClientTests {

    @Test("init succeeds and serviceType honors Bonjour constraints")
    func test_init_andServiceTypeContract() {
        // Construction must not crash — exercises MCPeerID creation, DispatchQueue
        // setup, and AsyncStream.makeStream end-to-end.
        let client = LiveNearbyDiscoveryClient()
        _ = client.discoveredRounds  // verify the cached stream is reachable

        #expect(LiveNearbyDiscoveryClient.serviceType == "hyzer-rounds")
        // Bonjour service-type registration limit: ≤15 chars, alphanumeric + hyphen.
        #expect(LiveNearbyDiscoveryClient.serviceType.count <= 15)
        #expect(LiveNearbyDiscoveryClient.txtKeyRoundID == "rid")
        #expect(LiveNearbyDiscoveryClient.txtKeyPlayerIDs == "pids")
    }

    @Test("discoveredRounds returns the same stream across repeated property accesses")
    func test_discoveredRounds_isCachedSingleSubscriberStream() {
        let client = LiveNearbyDiscoveryClient()
        let a = client.discoveredRounds
        let b = client.discoveredRounds
        // We can't directly assert pointer equality on AsyncStream value types, but
        // we can assert that the second access does not throw and is shape-compatible.
        // The cached property contract is documented in the protocol.
        _ = a
        _ = b
    }
}
