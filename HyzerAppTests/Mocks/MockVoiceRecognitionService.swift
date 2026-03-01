import Foundation
@testable import HyzerApp
@testable import HyzerKit

/// Test double for `VoiceRecognitionServiceProtocol`.
///
/// Configure `transcriptToReturn` for happy-path tests.
/// Configure `errorToThrow` to exercise error handling in `VoiceOverlayViewModel`.
@MainActor
final class MockVoiceRecognitionService: VoiceRecognitionServiceProtocol {
    var transcriptToReturn: String = ""
    var errorToThrow: VoiceParseError?
    var recognizeCallCount = 0
    var stopListeningCallCount = 0

    func recognize() async throws -> String {
        recognizeCallCount += 1
        if let error = errorToThrow { throw error }
        return transcriptToReturn
    }

    func stopListening() {
        stopListeningCallCount += 1
    }
}
