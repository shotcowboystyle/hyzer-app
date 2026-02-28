import Foundation
import Speech
import HyzerKit

/// Wraps `SFSpeechRecognizer` to provide on-device speech recognition for voice score entry.
///
/// Lives exclusively in `HyzerApp/Services/` — never in HyzerKit — because the `Speech` framework
/// is not available on watchOS/macOS (NFR: platform isolation constraint).
///
/// `@MainActor` — interacts with UI permission prompts and AVAudioEngine.
@MainActor
public final class VoiceRecognitionService {

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public init() {
        let recognizer = SFSpeechRecognizer()
        recognizer?.defaultTaskHint = .dictation
        self.speechRecognizer = recognizer
    }

    /// Requests microphone and speech recognition permissions, then records and transcribes speech.
    ///
    /// - Returns: The transcribed string from on-device recognition.
    /// - Throws: `VoiceParseError.microphonePermissionDenied` if mic access denied.
    ///           `VoiceParseError.recognitionUnavailable` if speech recognition unavailable.
    ///           `VoiceParseError.noSpeechDetected` if no speech was captured.
    public func recognize() async throws -> String {
        try await requestPermissions()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceParseError.recognitionUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                continuation.resume(throwing: VoiceParseError.recognitionUnavailable)
                return
            }

            var hasResumed = false
            recognitionTask = recognizer.recognitionTask(with: request) { [self] result, error in
                guard !hasResumed else { return }

                if let error = error {
                    hasResumed = true
                    self.stopAudioEngine()
                    let nsError = error as NSError
                    if nsError.code == 1110 {
                        continuation.resume(throwing: VoiceParseError.noSpeechDetected)
                    } else {
                        continuation.resume(throwing: VoiceParseError.recognitionUnavailable)
                    }
                    return
                }

                guard let result, result.isFinal else { return }
                hasResumed = true
                self.stopAudioEngine()
                let transcript = result.bestTranscription.formattedString
                if transcript.isEmpty {
                    continuation.resume(throwing: VoiceParseError.noSpeechDetected)
                } else {
                    continuation.resume(returning: transcript)
                }
            }
        }
    }

    private func stopAudioEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Permissions

    private func requestPermissions() async throws {
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micStatus else { throw VoiceParseError.microphonePermissionDenied }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { throw VoiceParseError.recognitionUnavailable }
    }
}
