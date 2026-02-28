import Foundation

/// Testability abstraction over `VoiceRecognitionService`.
///
/// Allows `VoiceOverlayViewModel` to be tested with a mock in place of the real
/// `SFSpeechRecognizer`-backed implementation. Lives in `HyzerApp/Protocols/` because
/// it references behavior specific to the iOS Speech framework — it does NOT go in HyzerKit.
@MainActor
protocol VoiceRecognitionServiceProtocol: AnyObject {
    /// Records and transcribes speech.
    ///
    /// - Returns: The transcribed string from on-device recognition.
    /// - Throws: `VoiceParseError` on permission denial, unavailability, or silence.
    func recognize() async throws -> String

    /// Stops the audio engine and cancels any active recognition task.
    func stopListening()
}
