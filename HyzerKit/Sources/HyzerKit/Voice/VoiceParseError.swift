import Foundation

/// Errors thrown by `VoiceRecognitionService` during the speech recognition lifecycle.
public enum VoiceParseError: Error, Sendable {
    /// The user denied microphone access.
    case microphonePermissionDenied
    /// On-device speech recognition is unavailable (unsupported locale or model not downloaded).
    case recognitionUnavailable
    /// The speech recognizer produced no usable speech within the recognition window.
    case noSpeechDetected
}
