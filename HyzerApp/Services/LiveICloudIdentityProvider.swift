import CloudKit
import HyzerKit

/// Live implementation of `ICloudIdentityProvider` that calls CloudKit.
///
/// `CloudKit` is imported here (not in HyzerKit) so the protocol remains
/// platform-agnostic. watchOS never uses this implementation.
struct LiveICloudIdentityProvider: ICloudIdentityProvider, Sendable {
    func resolveIdentity() async throws -> ICloudIdentityResult {
        let status = try await CKContainer.default().accountStatus()
        switch status {
        case .available:
            let recordID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord.ID, Error>) in
                CKContainer.default().fetchUserRecordID { recordID, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let recordID {
                        continuation.resume(returning: recordID)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ICloudIdentity", code: -1))
                    }
                }
            }
            return .available(recordName: recordID.recordName)
        case .noAccount:
            return .unavailable(reason: .noAccount)
        case .restricted:
            return .unavailable(reason: .restricted)
        case .temporarilyUnavailable:
            return .unavailable(reason: .temporarilyUnavailable)
        case .couldNotDetermine:
            return .unavailable(reason: .couldNotDetermine)
        @unknown default:
            return .unavailable(reason: .couldNotDetermine)
        }
    }
}
