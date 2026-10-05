import Foundation
import Speech
import AVFoundation

@available(macOS 13.0, iOS 16.0, *)
public final class SpeechRecognizer: NSObject, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceWorkItem: DispatchWorkItem?

    public init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        super.init()
    }

    public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    public func start(
        onPartialResult: @escaping @Sendable (String) -> Void,
        onFinished: @escaping @Sendable (String) -> Void
    ) throws {
        cancel()

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw SpeechRecognizerError.requestUnavailable }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        guard recognizer.isAvailable else {
            stopAudioCapture()
            throw SpeechRecognizerError.serviceUnavailable
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                onPartialResult(text)

                if result?.isFinal == true {
                    self.complete(with: text, onFinished: onFinished)
                } else {
                    self.scheduleSilenceCompletion(text: text, onFinished: onFinished)
                }
            } else if error != nil {
                self.complete(with: "", onFinished: onFinished)
            }
        }
    }

    public func cancel() {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        stopAudioCapture()
    }

    private func scheduleSilenceCompletion(
        text: String,
        onFinished: @escaping @Sendable (String) -> Void
    ) {
        silenceWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.request?.endAudio()
            self.complete(with: text, onFinished: onFinished)
        }

        silenceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: item)
    }

    private func complete(
        with text: String,
        onFinished: @escaping @Sendable (String) -> Void
    ) {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        stopAudioCapture()
        task?.cancel()
        task = nil
        request = nil
        onFinished(text)
    }

    private func stopAudioCapture() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

public enum SpeechRecognizerError: Error {
    case requestUnavailable
    case serviceUnavailable
}
