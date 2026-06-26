import Foundation
@testable import HyzerKit

/// Shared `ICloudIdentityProvider` stub. Defaults to `.unavailable` (matches the
/// pre-Story-15.11 `StubICloudIdentityProvider` / `UnavailableIdentityProvider`
/// behavior). Use the static factories for the available / throwing variants.
final class StubICloudIdentityProvider: ICloudIdentityProvider, @unchecked Sendable {
    var resultToReturn: ICloudIdentityResult
    var shouldThrow: Error?
    private(set) var resolveCallCount = 0

    init(result: ICloudIdentityResult = .unavailable(reason: .couldNotDetermine)) {
        self.resultToReturn = result
    }

    func resolveIdentity() async throws -> ICloudIdentityResult {
        resolveCallCount += 1
        if let error = shouldThrow { throw error }
        return resultToReturn
    }

    /// Returns a provider that yields `.available(recordName:)`.
    static func available(recordName: String = "_test-record-name") -> StubICloudIdentityProvider {
        StubICloudIdentityProvider(result: .available(recordName: recordName))
    }

    /// Returns a provider that yields `.unavailable(reason:)`.
    static func unavailable(reason: ICloudUnavailableReason = .couldNotDetermine) -> StubICloudIdentityProvider {
        StubICloudIdentityProvider(result: .unavailable(reason: reason))
    }
}
