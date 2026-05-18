import Testing
import Foundation
@testable import HyzerApp

@Suite("LiveNearbyDiscoveryClient encoding")
struct LiveNearbyDiscoveryClientEncodingTests {

    @Test("encodeDiscoveryInfo includes rid and pids for a single player")
    func test_encodeDiscoveryInfo_singlePlayer_includesRidAndPids() {
        let roundID = UUID()
        let playerID = UUID().uuidString
        let info = LiveNearbyDiscoveryClient.encodeDiscoveryInfo(roundID: roundID, playerIDs: [playerID])

        #expect(info["rid"] == roundID.uuidString)
        #expect(info["pids"] == playerID)
    }

    @Test("encodeDiscoveryInfo emits guest IDs as-is alongside UUID strings")
    func test_encodeDiscoveryInfo_guestIDsAreEmittedAsIs() {
        let roundID = UUID()
        let guestID = "guest:\(UUID().uuidString)"
        let regularID = UUID().uuidString
        let info = LiveNearbyDiscoveryClient.encodeDiscoveryInfo(
            roundID: roundID,
            playerIDs: [guestID, regularID]
        )

        #expect(info["pids"] == "\(guestID),\(regularID)")
    }

    @Test("encodeDiscoveryInfo caps the pids value at the RFC 6763 byte budget and preserves prefix order")
    func test_encodeDiscoveryInfo_caps_pids_at_byte_budget() {
        let roundID = UUID()
        // 12 full UUIDs (36 chars each + commas) would be ~443 bytes — well over the
        // 240-byte cap for the value, so truncation must occur.
        let playerIDs = (0..<12).map { _ in UUID().uuidString }
        let info = LiveNearbyDiscoveryClient.encodeDiscoveryInfo(roundID: roundID, playerIDs: playerIDs)

        let pidsValue = info["pids"] ?? ""
        let pids = pidsValue.components(separatedBy: ",")

        // The encoded value must fit the byte budget so the Bonjour TXT key=value pair
        // stays under RFC 6763's 255-byte per-pair limit.
        #expect(pidsValue.utf8.count <= LiveNearbyDiscoveryClient.txtValueMaxBytes)
        // Truncation must have occurred (input intentionally exceeds the budget).
        #expect(pids.count < playerIDs.count)
        // Order is preserved: the encoded set is a prefix of the input.
        #expect(pids == Array(playerIDs.prefix(pids.count)))
    }

    @Test("encodeDiscoveryInfo accepts up to ~6 full UUIDs without truncation")
    func test_encodeDiscoveryInfo_smallGroup_isNotTruncated() {
        // 6 full UUIDs = 6 × 36 + 5 commas = 221 bytes — within the 240-byte budget.
        let roundID = UUID()
        let playerIDs = (0..<6).map { _ in UUID().uuidString }
        let info = LiveNearbyDiscoveryClient.encodeDiscoveryInfo(roundID: roundID, playerIDs: playerIDs)

        let pids = info["pids"]?.components(separatedBy: ",") ?? []
        #expect(pids == playerIDs, "small groups within the budget must not be truncated")
    }

    @Test("serviceType is hyzer-rounds")
    func test_serviceType_isHyzerRounds() {
        #expect(LiveNearbyDiscoveryClient.serviceType == "hyzer-rounds")
    }
}
