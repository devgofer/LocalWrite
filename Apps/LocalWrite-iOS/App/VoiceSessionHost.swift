import AVFoundation
import SwiftUI
import LocalWriteCore
import LocalWriteKeyboardBridge

/// Keeps the microphone warm in the background so the keyboard can dictate in place.
/// iOS keyboards cannot record, so the keyboard opens this app once per session;
/// after that it sends start/finish commands and inserts the result itself.
@MainActor
final class VoiceSessionHost: ObservableObject {
    @Published private(set) var warm = false
    @Published private(set) var starting = false
    @Published private(set) var message = "在任何輸入框切換到 LocalWrite 鍵盤，點麥克風就能開始。"
    @Published private(set) var expiresAt: Date?

    private let audio = AVAudioEngine()
    private let feed = SpeechAudioFeed()
    private let speech = SpeechRecognizer()
    private let model = FoundationModelsEngine()
    private let settings = SharedSettings.shared()
    private var exchange: KeyboardExchange?
    private var state: VoiceState?
    private var commandSignal: DarwinSignal?
    private var heartbeat: Task<Void, Never>?
    private var processing: Task<Void, Never>?
    private var lastCommand: UUID?
    private var tapInstalled = false

    /// Opened by the keyboard's cold mic. A URL alone cannot turn the microphone on.
    func open(_ url: URL) {
        guard let exchange = KeyboardExchange.shared(),
              let ticket = exchange.launchRequest(), ticket.matches(url) else { return }
        try? exchange.clearLaunchRequest()
        self.exchange = exchange
        Task { await startSession() }
    }

    func startSession() async {
        if warm { extend(); return }
        guard !starting else { return }
        guard let exchange = exchange ?? KeyboardExchange.shared() else {
            message = "共享容器尚未設定，請確認 App 與鍵盤的 App Group 簽章。"; return
        }
        self.exchange = exchange
        starting = true; defer { starting = false }
        message = "正在開啟麥克風⋯"
        guard await SpeechRecognizer.requestAuthorization() == .authorized else {
            message = "請到設定允許 LocalWrite 使用語音辨識。"; return
        }
        guard await SpeechRecognizer.requestMicrophoneAuthorization() else {
            message = "請到設定允許 LocalWrite 使用麥克風。"; return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            // Mixing keeps the user's music or video playing while the mic stays warm.
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
            let node = audio.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechRecognizerError.audioInputUnavailable }
            // Buffers are discarded unless a dictation is in progress.
            node.installTap(onBus: 0, bufferSize: 1024, format: format, block: feed.makeTapHandler())
            tapInstalled = true
            audio.prepare()
            try audio.start()
        } catch {
            teardownAudio()
            message = "無法開啟麥克風：\(error.localizedDescription)"; return
        }
        let expires = Date.now.addingTimeInterval(TimeInterval(settings.sessionMinutes * 60))
        state = VoiceState(sessionID: UUID(), phase: .idle, expiresAt: expires)
        warm = true; expiresAt = expires
        message = "已啟用。滑回原本的 App，點鍵盤麥克風就能說話。"
        commandSignal = DarwinSignal(observing: DarwinSignal.command) { [weak self] in
            Task { @MainActor in self?.readCommand() }
        }
        heartbeat = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let expiresAt = self.expiresAt else { return }
                if Date.now >= expiresAt { self.endSession(message: "麥克風已自動關閉。下次點鍵盤麥克風會再開啟一次。"); return }
                self.publish()
                do { try await Task.sleep(for: .seconds(VoiceState.heartbeatInterval)) } catch { return }
            }
        }
        publish()
    }

    func endSession(message: String = "麥克風已關閉。") {
        heartbeat?.cancel(); heartbeat = nil
        processing?.cancel(); processing = nil
        commandSignal = nil
        speech.cancel()
        teardownAudio()
        if state != nil { state?.phase = .ended; state?.requestID = nil; publish() }
        state = nil; warm = false; expiresAt = nil
        self.message = message
    }

    private func extend() {
        let expires = Date.now.addingTimeInterval(TimeInterval(settings.sessionMinutes * 60))
        expiresAt = expires; state?.expiresAt = expires
        message = "已啟用。滑回原本的 App，點鍵盤麥克風就能說話。"
        publish()
    }

    private func readCommand() {
        guard warm, let command = exchange?.command(), command.id != lastCommand, command.isFresh() else { return }
        lastCommand = command.id
        switch command.kind {
        case .start:
            begin(command)
        case .finish:
            guard state?.requestID == command.requestID, state?.phase == .recording else { return }
            state?.phase = .processing; publish()
            speech.finish()
        case .cancel:
            guard state?.requestID == command.requestID else { return }
            processing?.cancel(); processing = nil
            speech.cancel()
            state?.phase = .idle; state?.requestID = nil; state?.text = ""; publish()
        }
    }

    private func begin(_ command: KeyboardCommand) {
        processing?.cancel(); processing = nil
        speech.cancel()
        let id = command.requestID
        state?.requestID = id; state?.phase = .recording
        state?.text = ""; state?.message = ""; state?.usedRawFallback = false
        publish()
        do {
            try speech.start(externalAudioFeed: feed,
                onPartialResult: { [weak self] text in
                    guard let self, self.state?.requestID == id, self.state?.phase == .recording else { return }
                    self.state?.text = text; self.publish()
                }, onFinished: { [weak self] text in
                    guard let self, self.state?.requestID == id else { return }
                    self.process(text, for: command)
                }, onError: { [weak self] message in
                    guard let self, self.state?.requestID == id else { return }
                    self.fail(message)
                })
        } catch { fail(error.localizedDescription) }
    }

    private func process(_ text: String, for command: KeyboardCommand) {
        state?.phase = .processing; state?.text = text; publish()
        let model = self.model
        processing = Task { @MainActor [weak self] in
            var output = text
            var fallback = false
            do {
                let result = switch command.mode {
                case .clean: try await model.refine(text)
                case .translate:
                    try await model.translate(text, into: TranslationLanguage.named(command.targetLanguage).englishName)
                }
                output = result.refined
            } catch {
                // Foundation Models can be unavailable or throttled in the background.
                fallback = true
            }
            guard let self, !Task.isCancelled, self.state?.requestID == command.requestID else { return }
            self.state?.phase = .done; self.state?.text = output; self.state?.usedRawFallback = fallback
            self.state?.message = fallback ? "AI 暫時無法使用，已填入原始文字。" : ""
            self.publish()
        }
    }

    private func fail(_ message: String) {
        state?.phase = .failed; state?.message = message; publish()
    }

    private func publish() {
        guard var state, let exchange else { return }
        state.updatedAt = .now; self.state = state
        do { try exchange.write(state) } catch { return }
        DarwinSignal.post(DarwinSignal.state)
    }

    private func teardownAudio() {
        audio.stop()
        if tapInstalled { audio.inputNode.removeTap(onBus: 0); tapInstalled = false }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
