import Foundation

/// Abstracts `UserDefaults` reads/writes used by `SyncScheduler`
/// so the scheduler can be tested without persistent storage.
public protocol UserDefaultsStorage: Sendable {
    func string(forKey defaultName: String) -> String?
    func setString(_ value: String, forKey defaultName: String)
}

// `@unchecked Sendable` is required because the `UserDefaultsStorage`
// protocol declares `Sendable` conformance, but `UserDefaults` is defined
// in Foundation (a different module) than this extension. Swift 6 strict
// concurrency requires retroactive `Sendable` conformance on cross-module
// classes to be opt-in via `@unchecked Sendable`. `UserDefaults` is
// documented as thread-safe by Apple, so the unchecked opt-in is sound.
//
// `@retroactive` (Swift 5.10+ / SE-0364) explicitly acknowledges the
// cross-module retroactive conformance and silences the future-proofing
// warning: "Extension declares a conformance of imported type 'UserDefaults'
// to imported protocol 'Sendable'; this will not behave correctly if the
// owners of 'Foundation' introduce this conformance in the future."
extension UserDefaults: @retroactive @unchecked Sendable {}

extension UserDefaults: UserDefaultsStorage {
    public func setString(_ value: String, forKey defaultName: String) {
        set(value, forKey: defaultName)
    }
}
