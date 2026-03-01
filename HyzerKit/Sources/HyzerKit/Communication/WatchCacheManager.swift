import Foundation

/// Persists and retrieves the latest `StandingsSnapshot` in the shared app group container.
///
/// Phone writes after every standings push. Watch reads on launch as the offline fallback.
///
/// App group identifier: `group.com.shotcowboystyle.hyzerapp`
/// Cache file: `standings-cache.json` in the shared container root.
@MainActor
public final class WatchCacheManager {
    private static let appGroupID = "group.com.shotcowboystyle.hyzerapp"
    private static let fileName = "standings-cache.json"

    private let cacheURL: URL?

    /// Production initialiser — resolves the URL from the shared app group container.
    public init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WatchCacheManager.appGroupID
        )
        cacheURL = containerURL?.appendingPathComponent(WatchCacheManager.fileName)
    }

    /// Test initialiser — uses a caller-supplied URL (e.g. a temp file or `nil` to simulate unavailable container).
    init(cacheURL: URL?) {
        self.cacheURL = cacheURL
    }

    // MARK: - Public API

    /// Serialises `snapshot` to the shared app group JSON cache.
    /// - Throws: `EncodingError` or file-system errors on write failure.
    public func save(_ snapshot: StandingsSnapshot) throws {
        // Safe to continue: nil URL only occurs in unit tests using the test initialiser.
        // Production builds always resolve a valid app group container URL.
        guard let url = cacheURL else { return }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    /// Loads the most recently persisted standings snapshot.
    /// - Returns: The cached snapshot, or `nil` if the file doesn't exist or is corrupt.
    public func loadLatest() -> StandingsSnapshot? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StandingsSnapshot.self, from: data)
    }
}
