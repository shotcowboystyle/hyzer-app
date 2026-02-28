import Testing
import Foundation
@testable import HyzerKit

@Suite("MockNetworkMonitor")
struct NetworkMonitorTests {

    @Test("isConnected reflects initial state — connected")
    func test_isConnected_initiallyConnected() {
        let monitor = MockNetworkMonitor(initiallyConnected: true)
        #expect(monitor.isConnected == true)
    }

    @Test("isConnected reflects initial state — disconnected")
    func test_isConnected_initiallyDisconnected() {
        let monitor = MockNetworkMonitor(initiallyConnected: false)
        #expect(monitor.isConnected == false)
    }

    @Test("setConnected updates isConnected")
    func test_setConnected_updatesIsConnected() {
        let monitor = MockNetworkMonitor(initiallyConnected: true)
        monitor.setConnected(false)
        #expect(monitor.isConnected == false)
        monitor.setConnected(true)
        #expect(monitor.isConnected == true)
    }

    @Test("pathUpdates emits current state immediately on subscription")
    func test_pathUpdates_emitsCurrentState_immediately() async {
        let monitor = MockNetworkMonitor(initiallyConnected: true)
        // Use an actor-isolated collector to avoid data races
        let collector = ValueCollector<Bool>()

        let task = Task {
            for await value in monitor.pathUpdates {
                await collector.append(value)
                if await collector.count >= 1 { break }
            }
        }

        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()
        await task.value

        let values = await collector.values
        #expect(values.first == true)
    }

    @Test("pathUpdates emits changes via setConnected")
    func test_pathUpdates_emitsConnectivityChanges() async {
        let monitor = MockNetworkMonitor(initiallyConnected: true)
        let collector = ValueCollector<Bool>()

        let task = Task {
            for await value in monitor.pathUpdates {
                await collector.append(value)
                if await collector.count >= 3 { break }
            }
        }

        try? await Task.sleep(for: .milliseconds(10))
        monitor.setConnected(false)
        try? await Task.sleep(for: .milliseconds(10))
        monitor.setConnected(true)
        try? await Task.sleep(for: .milliseconds(10))

        task.cancel()
        await task.value

        let values = await collector.values
        #expect(values.contains(false))
        #expect(values.contains(true))
    }
}

// MARK: - Helper actor for thread-safe value collection

private actor ValueCollector<T> {
    private(set) var values: [T] = []

    var count: Int { values.count }

    func append(_ value: T) {
        values.append(value)
    }
}
