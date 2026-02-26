import Foundation
@testable import HyzerKit

final class MockICloudIdentityProvider: ICloudIdentityProvider, @unchecked Sendable {
    var resultToReturn: ICloudIdentityResult = .available(recordName: "mock-record-name")
    var shouldThrow: Error?
    var resolveCallCount = 0

    func resolveIdentity() async throws -> ICloudIdentityResult {
        resolveCallCount += 1
        if let error = shouldThrow { throw error }
        return resultToReturn
    }
}
