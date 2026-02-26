import Testing
import SwiftUI
import SwiftData
@testable import HyzerKit

@Suite("Player model")
struct PlayerTests {

    // MARK: - 10.1 Model creation

    @Test("test_init_withDisplayName_setsProperties")
    func test_init_withDisplayName_setsProperties() {
        let player = Player(displayName: "Ace")
        #expect(player.displayName == "Ace")
        #expect(player.aliases.isEmpty)
        #expect(player.iCloudRecordName == nil)
        #expect(!player.id.uuidString.isEmpty)
    }

    @Test("test_init_defaults_satisfyCloudKitConstraints")
    func test_init_defaults_satisfyCloudKitConstraints() {
        // CloudKit requires all properties to have defaults so records can be
        // initialised without values. Verify the defaults are in place.
        let player = Player(displayName: "")
        #expect(player.aliases == [])
        #expect(player.iCloudRecordName == nil)
    }

    // MARK: - 10.1 Persistence

    @Test("test_persist_inMemoryStore_roundTrips")
    func test_persist_inMemoryStore_roundTrips() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, configurations: config)
        let context = ModelContext(container)

        let player = Player(displayName: "Birdie Bob")
        context.insert(player)
        try context.save()

        let all = try context.fetch(FetchDescriptor<Player>())
        let fetched = all.filter { $0.displayName == "Birdie Bob" }
        #expect(fetched.count == 1)
        #expect(fetched[0].displayName == "Birdie Bob")
    }

    @Test("test_fixture_factory_createsPlayerWithDefaults")
    func test_fixture_factory_createsPlayerWithDefaults() {
        let player = Player.fixture()
        #expect(player.displayName == "Test Player")
        #expect(player.aliases.isEmpty)
        #expect(player.iCloudRecordName == nil)
    }

    @Test("test_fixture_factory_acceptsCustomValues")
    func test_fixture_factory_acceptsCustomValues() {
        let player = Player.fixture(displayName: "Eagle Ed", aliases: ["Ed"])
        #expect(player.displayName == "Eagle Ed")
        #expect(player.aliases == ["Ed"])
    }

    // MARK: - 10.3 Design token accessibility

    @Test("test_designTokens_colorsAreAccessible")
    @MainActor
    func test_designTokens_colorsAreAccessible() {
        _ = Color.backgroundPrimary
        _ = Color.accentPrimary
        _ = Color.textPrimary
        _ = Color.textSecondary
        _ = Color.scoreUnderPar
        _ = Color.scoreOverPar
        _ = Color.scoreAtPar
        _ = Color.scoreWayOver
        _ = Color.destructive
    }

    @Test("test_designTokens_typographyIsAccessible")
    @MainActor
    func test_designTokens_typographyIsAccessible() {
        _ = TypographyTokens.hero
        _ = TypographyTokens.h1
        _ = TypographyTokens.h2
        _ = TypographyTokens.h3
        _ = TypographyTokens.body
        _ = TypographyTokens.caption
        _ = TypographyTokens.score
        _ = TypographyTokens.scoreLarge
        #expect(TypographyTokens.heroBaseSize == 48)
    }

    @Test("test_designTokens_spacingValues")
    func test_designTokens_spacingValues() {
        #expect(SpacingTokens.xs  == 4)
        #expect(SpacingTokens.sm  == 8)
        #expect(SpacingTokens.md  == 16)
        #expect(SpacingTokens.lg  == 24)
        #expect(SpacingTokens.xl  == 32)
        #expect(SpacingTokens.xxl == 48)
        #expect(SpacingTokens.minimumTouchTarget == 44)
    }

    @Test("test_designTokens_animationTokensAreDefined")
    @MainActor
    func test_designTokens_animationTokensAreDefined() {
        _ = AnimationTokens.springStiff
        _ = AnimationTokens.springGentle
        #expect(AnimationTokens.scoreEntryDuration == 0.2)
        #expect(AnimationTokens.leaderboardReshuffleDuration == 0.4)
        #expect(AnimationTokens.pillPulseDelay == 0.2)
    }
}
