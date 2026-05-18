import Testing
import Foundation
@testable import HyzerKit

@Suite("DiscoveredRoundPayload")
struct DiscoveredRoundPayloadTests {

    @Test("equal when roundID and playerIDs both match")
    func test_equality_sameRoundIDAndPlayerIDs_areEqual() {
        let id = UUID()
        let pids = ["player-1", "player-2"]
        let a = DiscoveredRoundPayload(roundID: id, playerIDs: pids)
        let b = DiscoveredRoundPayload(roundID: id, playerIDs: pids)
        #expect(a == b)
    }

    @Test("not equal when roundIDs differ")
    func test_equality_differentRoundID_areNotEqual() {
        let pids = ["player-1"]
        let a = DiscoveredRoundPayload(roundID: UUID(), playerIDs: pids)
        let b = DiscoveredRoundPayload(roundID: UUID(), playerIDs: pids)
        #expect(a != b)
    }

    @Test("not equal when playerID order differs — Equatable on Array is order-sensitive")
    func test_equality_differentPlayerIDOrder_areNotEqual() {
        // This test locks the contract: Array Equatable IS order-sensitive.
        // AppServices' participant filter uses set-membership (contains), not equality,
        // so a "Set-based" refactor of playerIDs would change the Equatable semantics
        // of this type and must be considered carefully.
        let id = UUID()
        let a = DiscoveredRoundPayload(roundID: id, playerIDs: ["p1", "p2"])
        let b = DiscoveredRoundPayload(roundID: id, playerIDs: ["p2", "p1"])
        #expect(a != b)
    }
}
