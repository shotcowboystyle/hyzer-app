import Testing
import SwiftData
@testable import HyzerKit
@testable import HyzerApp

// MARK: - Test Mock

/// Local mock for HyzerAppTests — ICloudIdentityProvider protocol from HyzerKit.
private final class MockICloudIdentityProvider: ICloudIdentityProvider, @unchecked Sendable {
    var resultToReturn: ICloudIdentityResult = .available(recordName: "mock-record-name")
    var shouldThrow: Error?
    var resolveCallCount = 0

    func resolveIdentity() async throws -> ICloudIdentityResult {
        resolveCallCount += 1
        if let error = shouldThrow { throw error }
        return resultToReturn
    }
}

private struct TestError: Error {}

// MARK: - Tests

@Suite("ICloudIdentityResolution")
@MainActor
struct ICloudIdentityResolutionTests {

    private func makeServices(
        provider: MockICloudIdentityProvider = MockICloudIdentityProvider()
    ) throws -> (AppServices, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, configurations: config)
        let services = AppServices(
            modelContainer: container,
            iCloudIdentityProvider: provider
        )
        let context = ModelContext(container)
        return (services, context)
    }

    @Test("test_resolveICloudIdentity_whenAvailable_updatesPlayerRecordName")
    func test_resolveICloudIdentity_whenAvailable_updatesPlayerRecordName() async throws {
        let mock = MockICloudIdentityProvider()
        mock.resultToReturn = .available(recordName: "_abc123")
        let (services, context) = try makeServices(provider: mock)

        let player = Player(displayName: "Ace")
        context.insert(player)
        try context.save()

        await services.resolveICloudIdentity()

        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(players.count == 1)
        #expect(players[0].iCloudRecordName == "_abc123")
        #expect(mock.resolveCallCount == 1)
    }

    @Test("test_resolveICloudIdentity_whenUnavailable_playerRetainsNilRecordName")
    func test_resolveICloudIdentity_whenUnavailable_playerRetainsNilRecordName() async throws {
        let mock = MockICloudIdentityProvider()
        mock.resultToReturn = .unavailable(reason: .noAccount)
        let (services, context) = try makeServices(provider: mock)

        let player = Player(displayName: "Ace")
        context.insert(player)
        try context.save()

        await services.resolveICloudIdentity()

        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(players.count == 1)
        #expect(players[0].iCloudRecordName == nil)
        #expect(mock.resolveCallCount == 1)
    }

    @Test("test_resolveICloudIdentity_whenAlreadyResolved_skipsResolution")
    func test_resolveICloudIdentity_whenAlreadyResolved_skipsResolution() async throws {
        let mock = MockICloudIdentityProvider()
        let (services, context) = try makeServices(provider: mock)

        let player = Player(displayName: "Ace")
        player.iCloudRecordName = "_existing123"
        context.insert(player)
        try context.save()

        await services.resolveICloudIdentity()

        #expect(mock.resolveCallCount == 0)
        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(players[0].iCloudRecordName == "_existing123")
    }

    @Test("test_resolveICloudIdentity_whenProviderThrows_playerRetainsNilRecordName")
    func test_resolveICloudIdentity_whenProviderThrows_playerRetainsNilRecordName() async throws {
        let mock = MockICloudIdentityProvider()
        mock.shouldThrow = TestError()
        let (services, context) = try makeServices(provider: mock)

        let player = Player(displayName: "Ace")
        context.insert(player)
        try context.save()

        await services.resolveICloudIdentity()

        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(players[0].iCloudRecordName == nil)
        #expect(mock.resolveCallCount == 1)
    }
}
