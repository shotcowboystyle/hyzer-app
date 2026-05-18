import Foundation
import CryptoKit

/// Pure deterministic hash for `RoundSignatureInput`. Returns 32 stable bytes (`SHA256`).
///
/// **Why SHA256 instead of `Hasher`/`hashValue`:**
/// Swift's standard `Hasher` is randomized per process launch (documented at
/// https://developer.apple.com/documentation/swift/hasher) — calling
/// `hashValue` twice across two app launches yields different values, violating AC #1.
/// `SHA256` is process-independent and runs in <50µs per input on iPhone 12+.
///
/// **Wire format (do NOT change without bumping a version constant — historical
/// signatures must remain stable across app updates):**
/// `<courseID-uuid-string-utf8> 0x1E <playerIDs joined by 0x1F utf8> 0x1E <strokes joined by ',' utf8>`
/// where `0x1E` is the ASCII Record Separator and `0x1F` is the ASCII Unit Separator —
/// both are guaranteed not to appear in UUIDs, the `"guest:"` prefix, or stroke integers,
/// so the framing is unambiguous.
public enum RoundSignatureHasher {
    public static func hash(_ input: RoundSignatureInput) -> Data {
        var payload = Data()
        payload.append(contentsOf: input.courseID.uuidString.utf8)
        payload.append(0x1E)
        payload.append(contentsOf: input.playerIDs.joined(separator: "\u{001F}").utf8)
        payload.append(0x1E)
        payload.append(contentsOf: input.sortedTotalStrokes.map(String.init).joined(separator: ",").utf8)
        return Data(SHA256.hash(data: payload))
    }
}
