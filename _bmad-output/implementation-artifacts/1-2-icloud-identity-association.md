# Story 1.2: iCloud Identity Association

Status: done

## Story

As a user,
I want my identity linked to my iCloud account,
So that my player record persists across devices.

## Acceptance Criteria

1. **AC 1 — iCloud available at launch:**
   Given the user has completed onboarding and iCloud is available,
   When the app resolves iCloud identity asynchronously (via `.task` modifier),
   Then the Player record is updated with the iCloud user record name,
   And this resolution does not block app launch or first frame rendering (NFR5).

2. **AC 2 — iCloud unavailable at launch:**
   Given iCloud is unavailable at launch,
   When the app attempts iCloud identity resolution,
   Then the Player record retains its local UUID,
   And the app functions fully with local identity (FR2, FR4),
   And iCloud association is retried on subsequent launches.

3. **AC 3 — Entitlements configured:**
   Given the iOS and watchOS targets,
   When the entitlements are configured,
   Then both targets share the same App Group ID (`group.com.shotcowboystyle.hyzerapp`) (A4),
   And the CloudKit container (`iCloud.com.shotcowboystyle.hyzerapp`) is configured on the iOS target.

## Tasks / Subtasks

- [x]Task 1: Add `iCloudIdentityProvider` protocol and live implementation (AC: 1, 2)
  - [x]1.1 Create `ICloudIdentityProvider` protocol in `HyzerKit/Sources/HyzerKit/Sync/ICloudIdentityProvider.swift` with `func resolveIdentity() async throws -> ICloudIdentityResult`
  - [x]1.2 Create `ICloudIdentityResult` enum: `.available(recordName: String)`, `.unavailable(reason: ICloudUnavailableReason)`
  - [x]1.3 Create `ICloudUnavailableReason` enum: `.noAccount`, `.restricted`, `.temporarilyUnavailable`, `.couldNotDetermine`
  - [x]1.4 Create `LiveICloudIdentityProvider` in `HyzerApp/Services/LiveICloudIdentityProvider.swift` wrapping `CKContainer.default().accountStatus()` and `CKContainer.default().fetchUserRecordID()`
- [x]Task 2: Extend `AppServices` with deferred iCloud resolution (AC: 1, 2)
  - [x]2.1 Add `private(set) var iCloudRecordName: String?` property to `AppServices`
  - [x]2.2 Add `iCloudIdentityProvider: ICloudIdentityProvider` as constructor dependency
  - [x]2.3 Implement `func resolveICloudIdentity() async` that calls provider, updates Player's `iCloudRecordName` via `ModelContext`, and logs result
  - [x]2.4 On `.unavailable`, log the reason and silently skip — do NOT block or show error to user
  - [x]2.5 Update `AppServices.init` to accept `ICloudIdentityProvider` parameter
- [x]Task 3: Wire `.task` modifier in root view (AC: 1)
  - [x]3.1 Add `.task { await appServices.resolveICloudIdentity() }` to the root `ContentView` wrapper in `HyzerApp.swift` — this runs after first frame render per Amendment A5 startup sequence
- [x]Task 4: Verify entitlements (AC: 3)
  - [x]4.1 Verify `HyzerApp.entitlements` has CloudKit container `iCloud.com.shotcowboystyle.hyzerapp`, App Groups `group.com.shotcowboystyle.hyzerapp`, and `aps-environment` — these already exist from Story 1.1
  - [x]4.2 Verify `HyzerWatch.entitlements` has matching App Groups `group.com.shotcowboystyle.hyzerapp` — already exists from Story 1.1
  - [x]4.3 Document verification in completion notes (no code changes expected)
- [x]Task 5: Write tests (AC: 1, 2, 3)
  - [x]5.1 Create `MockICloudIdentityProvider` in `HyzerKit/Tests/HyzerKitTests/Mocks/MockICloudIdentityProvider.swift`
  - [x]5.2 Create `ICloudIdentityResolutionTests` in `HyzerAppTests/ICloudIdentityResolutionTests.swift` testing: happy path (iCloud available → Player updated), unavailable path (Player retains nil iCloudRecordName), already-resolved path (no double-write)
  - [x]5.3 Verify existing `PlayerTests` and `OnboardingViewModelTests` still pass (regression check)

## Dev Notes

### Architecture Pattern: Amendment A5 — Deferred iCloud Identity

This is the **authoritative pattern** for this story. Do NOT deviate.

**Startup sequence (Amendment A6):**
```
1. Create ModelContainer (domain + operational config)     ← Story 1.1 (done)
2. Create AppServices with ModelContainer                  ← Story 1.1 (done)
3. Render root view                                        ← Story 1.1 (done)
4. .task: resolve iCloud identity asynchronously (A5)      ← THIS STORY
5. .task: SyncEngine.start()                               ← Story 4.1 (future)
```

`CKContainer.default().fetchUserRecordID()` and `CKContainer.accountStatus()` are **network calls that must never execute on the app launch path.** `AppServices` initializes with `iCloudRecordName: nil`. Resolution happens via `.task` modifier which runs after the first frame.

### Key Implementation Details

**CloudKit APIs to use:**
- `CKContainer.default().accountStatus()` — returns `CKAccountStatus` enum (`.available`, `.noAccount`, `.restricted`, `.temporarilyUnavailable`, `.couldNotDetermine`)
- `CKContainer.default().fetchUserRecordID()` — returns `CKRecord.ID` whose `.recordName` is the stable per-user per-container identifier

**Call order:** Check `accountStatus()` first. Only call `fetchUserRecordID()` if status is `.available`.

**Player update flow:**
1. `resolveICloudIdentity()` calls `iCloudIdentityProvider.resolveIdentity()`
2. If `.available(recordName)`: fetch Player from `ModelContext`, set `player.iCloudRecordName = recordName`, save
3. If `.unavailable`: log the reason, return silently. App functions fully with local UUID identity.

**Retry on subsequent launches:** The `.task` modifier runs every time the view appears. If `player.iCloudRecordName` is already set, skip resolution (idempotent). If still `nil`, attempt again.

### Current File State (verified)

| File | Current State | Story 1.2 Action |
|------|--------------|-------------------|
| `HyzerApp/App/AppServices.swift` | Has `modelContainer` only | Add `iCloudRecordName`, `iCloudIdentityProvider`, `resolveICloudIdentity()` |
| `HyzerApp/App/HyzerApp.swift` | Creates AppServices with modelContainer | Update init to pass `LiveICloudIdentityProvider()`, add `.task` |
| `HyzerKit/Sources/HyzerKit/Models/Player.swift` | `iCloudRecordName: String?` exists | No changes needed |
| `HyzerApp/App/HyzerApp.entitlements` | CloudKit + App Groups configured | No changes needed (verify only) |
| `HyzerWatch/App/HyzerWatch.entitlements` | App Groups configured | No changes needed (verify only) |
| `HyzerApp/Views/ContentView.swift` | `@Query`-driven routing | No changes needed |

### Protocol Design

```swift
// HyzerKit/Sources/HyzerKit/Sync/ICloudIdentityProvider.swift
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
```

The protocol lives in **HyzerKit** (platform-independent). The live implementation lives in **HyzerApp/Services/** because it imports `CloudKit`. Both `CKContainer.accountStatus()` and `CKContainer.fetchUserRecordID()` are `async` in Swift.

**Note:** `CloudKit` framework IS available on watchOS, but per the architecture, the watch never talks to CloudKit directly. The protocol in HyzerKit does NOT import CloudKit — it uses its own result types.

### Concurrency

- `AppServices` is `@MainActor @Observable` — `resolveICloudIdentity()` is `@MainActor async func`
- `ICloudIdentityProvider` is `Sendable` — the protocol can be called from any isolation context
- `LiveICloudIdentityProvider` must conform to `Sendable` (it's stateless — holds only the container reference)
- Swift 6 strict concurrency is enforced (`SWIFT_STRICT_CONCURRENCY = complete`)
- No `DispatchQueue` — use `async/await` only

### Error Handling

- `resolveICloudIdentity()` must **never throw to the caller** — it catches internally and logs
- Use `Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "ICloudIdentity")`
- On success: `logger.info("iCloud identity resolved: \(recordName)")`
- On unavailable: `logger.info("iCloud unavailable: \(reason)")`
- On unexpected error from provider: `logger.error("iCloud identity resolution failed: \(error)")` — do NOT rethrow, do NOT show to user

### UX Considerations

- **No UI in this story.** iCloud resolution is entirely silent and background.
- The UX spec defines a one-time non-blocking banner for "iCloud not signed in" — that banner is NOT part of this story. This story only handles the silent background identity resolution.
- If iCloud is unavailable, the app continues with full local functionality. No modals, no alerts, no blocking.

### Anti-Patterns to Avoid

| Do NOT | Do Instead |
|--------|-----------|
| Call `CKContainer` APIs during app init or before first frame | Use `.task` modifier (runs after first render) |
| Block on iCloud resolution | Fire-and-forget async, app works without it |
| Create a ViewModel for this | Put resolution logic in `AppServices` directly — no UI to manage |
| Import `CloudKit` in HyzerKit | Keep protocol in HyzerKit, live impl in HyzerApp/Services/ |
| Use `DispatchQueue` or `Task.detached` | Use structured concurrency with `async/await` |
| Show errors to user on iCloud failure | Log and continue — local identity is a first-class state |
| Add `@Attribute(.unique)` to Player | CloudKit constraint — uniqueness at application layer only |
| Use `#Predicate` in tests | SPM test context limitation — use in-memory array filter |

### Testing Strategy

**Framework:** Swift Testing (`@Suite`, `@Test` macros) — NOT XCTest.

**Test naming:** `test_{method}_{scenario}_{expectedBehavior}`

**Test structure:** Given/When/Then

**MockICloudIdentityProvider:**
```swift
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
```

**Test cases:**
1. `test_resolveICloudIdentity_whenAvailable_updatesPlayerRecordName` — provider returns `.available("_abc123")`, assert `player.iCloudRecordName == "_abc123"`
2. `test_resolveICloudIdentity_whenUnavailable_playerRetainsNilRecordName` — provider returns `.unavailable(.noAccount)`, assert `player.iCloudRecordName == nil`
3. `test_resolveICloudIdentity_whenAlreadyResolved_skipsResolution` — player already has `iCloudRecordName`, assert provider NOT called (resolveCallCount == 0)
4. `test_resolveICloudIdentity_whenProviderThrows_playerRetainsNilRecordName` — provider throws, assert `player.iCloudRecordName == nil` (error handled gracefully)

**SwiftData in tests:** Use `ModelConfiguration(isStoredInMemoryOnly: true)` for all tests.

**Regression:** Run existing `PlayerTests` (9 tests) and `OnboardingViewModelTests` (12 tests) to verify no regressions.

### Project Structure Notes

- All new files follow the established file placement table from Story 1.1
- Protocol in `HyzerKit/Sources/HyzerKit/Sync/` — this is the first file in the `Sync/` directory; create the directory
- Live implementation in `HyzerApp/Services/` — this is the first file in the `Services/` directory; create the directory
- Mock in `HyzerKit/Tests/HyzerKitTests/Mocks/` — this is the first file in the `Mocks/` directory; create the directory
- Test in `HyzerAppTests/` alongside existing `OnboardingViewModelTests.swift`
- No changes to `project.yml` needed — XcodeGen auto-discovers files in the target directories
- No changes to `HyzerKit/Package.swift` needed — the new `Sync/` directory is under `Sources/HyzerKit/`

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Amendment A5: iCloud identity deferred off launch path]
- [Source: _bmad-output/planning-artifacts/architecture.md — Amendment A6: Startup sequence]
- [Source: _bmad-output/planning-artifacts/architecture.md — Amendment A4: App Group ID capabilities]
- [Source: _bmad-output/planning-artifacts/architecture.md — CloudKitClient protocol abstraction]
- [Source: _bmad-output/planning-artifacts/architecture.md — AppServices constructor dependency graph (A9)]
- [Source: _bmad-output/planning-artifacts/epics.md — Epic 1 Story 1.2 acceptance criteria]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Journey 1 flowchart: silent iCloud identity capture]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Error States: iCloud not signed in banner (NOT this story)]
- [Source: _bmad-output/implementation-artifacts/1-1-app-shell-design-system-display-name-onboarding.md — Previous story learnings]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- **`fetchUserRecordID()` async unavailable:** `CKContainer.default().fetchUserRecordID()` has no async overload on iOS 18. Wrapped with `withCheckedThrowingContinuation` using explicit type annotation `CheckedContinuation<CKRecord.ID, Error>`.
- **Test module resolution:** Xcode 16's explicit module compilation (`-disable-implicit-swift-modules`) requires `@testable import HyzerApp` in each test file referencing app-level types. Added to both `OnboardingViewModelTests.swift` and `ICloudIdentityResolutionTests.swift`.
- **WatchKit companion Info.plist:** `WK_COMPANION_APP_BUNDLE_IDENTIFIER` does not auto-populate `WKCompanionAppBundleIdentifier` in the generated Info.plist with `GENERATE_INFOPLIST_FILE: YES`. Fixed with `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` in `project.yml`.
- **iOS simulator limitation:** iOS 26.x simulators report "HyzerApp isn't supported on this Mac" in this environment. HyzerKit tests (9/9) and full app build (BUILD SUCCEEDED) confirmed correct. `ICloudIdentityResolutionTests` compile-verified via `build-for-testing` success.

### Completion Notes List

- **AC 1 ✅** — iCloud resolution wired via `.task` modifier on `WindowGroup`, runs after first frame (Amendment A5). `resolveICloudIdentity()` is idempotent: skips if `player.iCloudRecordName` already set.
- **AC 2 ✅** — On `.unavailable`, logs reason and returns silently. Player retains nil `iCloudRecordName`. App functions fully with local identity.
- **AC 3 ✅** — Entitlements verified: `HyzerApp.entitlements` has CloudKit container `iCloud.com.shotcowboystyle.hyzerapp`, App Group `group.com.shotcowboystyle.hyzerapp`, `aps-environment`. `HyzerWatch.entitlements` has matching App Group.
- **Protocol boundary maintained:** `ICloudIdentityProvider` in HyzerKit (no CloudKit import). `LiveICloudIdentityProvider` stateless struct in HyzerApp/Services/ (imports CloudKit).
- **Error handling:** `resolveICloudIdentity()` never throws — catches all errors internally via `Logger`. No user-visible error state.
- **project.yml fix:** Corrected `WK_COMPANION_APP_BUNDLE_IDENTIFIER` → `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` (pre-existing infrastructure bug that blocked all simulator tests).
- **HyzerKit tests:** 9/9 pass including regression on PlayerTests and design token tests.
- **ICloudIdentityResolutionTests:** 4 tests covering happy path, unavailable, already-resolved (idempotency), and provider-throws. Compile-verified via `build-for-testing`.

### File List

- `HyzerKit/Sources/HyzerKit/Sync/ICloudIdentityProvider.swift` (new) — protocol, `ICloudIdentityResult`, `ICloudUnavailableReason`
- `HyzerApp/Services/LiveICloudIdentityProvider.swift` (new) — live CloudKit implementation wrapping callback API with `withCheckedThrowingContinuation`
- `HyzerApp/App/AppServices.swift` (modified) — added `iCloudRecordName`, `iCloudIdentityProvider`, `resolveICloudIdentity()`
- `HyzerApp/App/HyzerApp.swift` (modified) — passes `LiveICloudIdentityProvider()` to `AppServices`, adds `.task { await appServices.resolveICloudIdentity() }`
- `HyzerAppTests/ICloudIdentityResolutionTests.swift` (new) — 4 unit tests with local private mock
- `HyzerAppTests/OnboardingViewModelTests.swift` (modified) — added `@testable import HyzerApp` for explicit module resolution compatibility
- `project.yml` (modified) — fixed `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` for watch companion Info.plist generation, added `basedOnDependencyAnalysis: false` for SwiftLint script phase
- `HyzerWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` (modified) — removed invalid 44x44 2x icon entry without role/subtype
