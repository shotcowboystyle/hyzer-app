import Foundation

public enum ICloudUnavailableReason: Sendable {
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}

public enum ICloudIdentityResult: Sendable {
    case available(recordName: String)
    case unavailable(reason: ICloudUnavailableReason)
}

public protocol ICloudIdentityProvider: Sendable {
    func resolveIdentity() async throws -> ICloudIdentityResult
}
