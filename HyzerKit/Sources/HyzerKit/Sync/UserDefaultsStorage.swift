import Foundation

/// Abstracts `UserDefaults` reads/writes used by `SyncScheduler`
/// so the scheduler can be tested without persistent storage.
public protocol UserDefaultsStorage: Sendable {
    func string(forKey defaultName: String) -> String?
    func setString(_ value: String, forKey defaultName: String)
}

extension UserDefaults: UserDefaultsStorage {
    public func setString(_ value: String, forKey defaultName: String) {
        set(value, forKey: defaultName)
    }
}
