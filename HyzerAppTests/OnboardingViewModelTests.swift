import Testing
import SwiftData
@testable import HyzerKit

/// Tests for OnboardingViewModel (10.2: onboarding flow creates Player record).
///
/// Note: OnboardingViewModel lives in the HyzerApp target. These tests are
/// compiled into HyzerAppTests which depends on HyzerApp, so the ViewModel
/// is available via @testable import.
@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {

    @Test("test_canContinue_emptyName_returnsFalse")
    func test_canContinue_emptyName_returnsFalse() {
        let vm = OnboardingViewModel()
        vm.displayName = ""
        #expect(!vm.canContinue)
    }

    @Test("test_canContinue_whitespaceOnly_returnsFalse")
    func test_canContinue_whitespaceOnly_returnsFalse() {
        let vm = OnboardingViewModel()
        vm.displayName = "   "
        #expect(!vm.canContinue)
    }

    @Test("test_canContinue_nonEmptyName_returnsTrue")
    func test_canContinue_nonEmptyName_returnsTrue() {
        let vm = OnboardingViewModel()
        vm.displayName = "Ace"
        #expect(vm.canContinue)
    }

    @Test("test_savePlayer_createsPlayerInContext")
    func test_savePlayer_createsPlayerInContext() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, configurations: config)
        let context = ModelContext(container)

        let vm = OnboardingViewModel()
        vm.displayName = "  Birdie  "
        vm.savePlayer(in: context)

        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(players.count == 1)
        // Verifies trimming
        #expect(players[0].displayName == "Birdie")
    }

    @Test("test_savePlayer_emptyName_doesNotCreatePlayer")
    func test_savePlayer_emptyName_doesNotCreatePlayer() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, configurations: config)
        let context = ModelContext(container)

        let vm = OnboardingViewModel()
        vm.displayName = ""
        vm.savePlayer(in: context)

        let players = try context.fetch(FetchDescriptor<Player>())
        #expect(players.isEmpty)
    }
}
