import AVFoundation
import SwiftUI
import Speech
import LocalWriteCore
import LocalWriteKeyboardBridge

@MainActor
final class KeyboardVoiceHelper: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var preparing = false
    @Published private(set) var recording = false
    @Published private(set) var message = "在文字欄位切換至 LocalWrite 鍵盤，點麥克風開始。"
    @Published private(set) var expiresAt: Date?
    private let audio = AVAudioEngine()
    private let feed = SpeechAudioFeed()
    private let speech = SpeechRecognizer()
    private let model = FoundationModelsEngine()
    private var exchange: KeyboardExchange?
    private var snapshot: KeyboardSnapshot?
    private var loop: Task<Void, Never>?
    private var refinement: Task<Void, Never>?
    private var preparation: Task<Void, Never>?
    private var preparationID: UUID?
    private var lastCommand: UUID?
    private var tapInstalled = false
    private var sessionActive = false
    private var heartbeat = Date.distantPast

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func open(_ url: URL) {
        guard let exchange = KeyboardExchange.shared(),
              let ticket = exchange.launchRequest(), ticket.matches(url) else { return }
        // Consume once, before asking for permissions. Replaying the URL cannot record.
        do { try exchange.clearLaunchRequest() } catch { return }
        stop()
        self.exchange = exchange
        snapshot = KeyboardSnapshot(sessionID: ticket.sessionID, requestID: ticket.requestID, phase: .starting)
        message = "正在準備麥克風⋯"
        publish()
        enable(ticket)
    }

    private func enable(_ ticket: KeyboardLaunchRequest) {
        guard !enabled, !preparing else { return }
        let id = UUID(); preparationID = id; preparing = true
        preparation = Task { [weak self] in
            let authorized = await SpeechRecognizer.requestAuthorization()
            guard let self, self.preparationID == id, !Task.isCancelled else { return }
            guard authorized == .authorized else { self.fail("請允許 LocalWrite 使用語音辨識。"); return }
            let microphone = await SpeechRecognizer.requestMicrophoneAuthorization()
            guard self.preparationID == id, !Task.isCancelled else { return }
            guard microphone else { self.fail("請允許 LocalWrite 使用麥克風。"); return }
            for _ in 0..<40 where UIApplication.shared.applicationState != .active {
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                guard self.preparationID == id else { return }
            }
            guard UIApplication.shared.applicationState == .active else {
                self.fail("請留在 LocalWrite 等待麥克風啟動後，再返回原本 App。"); return
            }
            guard FoundationModelsEngine.isAvailable else { self.fail("Apple 本機模型目前尚未就緒。"); return }
            if let command = self.exchange?.command(), command.kind == .cancel,
               command.sessionID == ticket.sessionID, command.requestID == ticket.requestID {
                self.stop(); return
            }
            guard let exchange = KeyboardExchange.shared() else {
                self.stop(message: "共享容器尚未設定。請確認 App 與鍵盤的 App Group 簽章。"); return
            }
            self.exchange = exchange
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement)
                try session.setActive(true)
                self.sessionActive = true
                let node = self.audio.inputNode
                let format = node.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechRecognizerError.audioInputUnavailable }
                node.installTap(onBus: 0, bufferSize: 1024, format: format, block: self.feed.makeTapHandler())
                self.tapInstalled = true
                self.audio.prepare()
                try self.audio.start()
                self.enabled = true; self.preparing = false; self.recording = true
                self.expiresAt = .now.addingTimeInterval(90)
                self.snapshot = KeyboardSnapshot(sessionID: ticket.sessionID, phase: .ready)
                self.message = "聆聽中。點左上角返回原本 App，再點鍵盤麥克風完成。"
                self.startDictation(ticket.requestID)
                self.loop = Task { @MainActor [weak self] in
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                        guard let self, self.enabled else { return }
                        self.tick()
                    }
                }
            } catch { self.fail(error.localizedDescription) }
        }
    }

    func stop(message: String = "語音工作階段已結束。", publishState: Bool = true) {
        preparationID = nil; preparation?.cancel(); preparation = nil
        loop?.cancel(); loop = nil; refinement?.cancel(); refinement = nil
        speech.cancel(); stopCapture(); endBackgroundTask()
        enabled = false; preparing = false; expiresAt = nil
        self.message = message
        if publishState, let session = snapshot?.sessionID {
            snapshot = KeyboardSnapshot(sessionID: session, phase: .stopped)
            publish()
        }
    }

    private func tick() {
        guard let expiresAt, Date.now < expiresAt else { stop(); return }
        if let command = exchange?.command(), command.id != lastCommand,
           let session = snapshot?.sessionID, command.isValid(for: session) {
            lastCommand = command.id
            switch command.kind {
            case .start:
                // Each recording is started by a foreground keyboard launch ticket.
                break
            case .finish:
                if snapshot?.requestID == command.requestID, snapshot?.phase == .recording { finish() }
            case .cancel:
                if snapshot?.requestID == command.requestID {
                    stop()
                    return
                }
            }
        }
        if Date.now.timeIntervalSince(heartbeat) >= 0.5 { publish() }
    }

    private func startDictation(_ id: UUID) {
        guard let session = snapshot?.sessionID else { return }
        snapshot = KeyboardSnapshot(sessionID: session, requestID: id, phase: .recording)
        publish()
        do {
            try speech.start(externalAudioFeed: feed,
                onPartialResult: { [weak self] text in
                    guard self?.snapshot?.requestID == id else { return }
                    self?.snapshot?.text = text
                }, onFinished: { [weak self] text in
                    guard let self, self.snapshot?.requestID == id else { return }
                    self.refine(text, request: id, session: session)
                }, onError: { [weak self] message in
                    guard self?.snapshot?.requestID == id else { return }
                    self?.fail(message)
                })
        } catch { fail(error.localizedDescription) }
    }

    private func refine(_ text: String, request: UUID, session: UUID) {
        beginBackgroundTask()
        stopCapture()
        snapshot?.phase = .refining; snapshot?.text = text; message = "潤稿中⋯"; publish()
        refinement = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.model.refine(text)
                guard !Task.isCancelled, self.enabled, self.snapshot?.requestID == request else { return }
                self.snapshot = KeyboardSnapshot(sessionID: session, requestID: request, phase: .completed, text: result.refined)
                self.message = "已完成。回到原本的文字欄位即可填入。"
                self.publish()
            } catch {
                guard !Task.isCancelled, self.snapshot?.requestID == request else { return }
                self.fail(error.localizedDescription)
            }
        }
    }

    func finish() {
        guard snapshot?.phase == .recording else { return }
        beginBackgroundTask()
        speech.finish()
        stopCapture()
    }

    private func stopCapture() {
        recording = false
        audio.stop()
        if tapInstalled { audio.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if sessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            sessionActive = false
        }
    }

    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish dictation") { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.snapshot?.phase == .completed || self.snapshot?.phase == .failed {
                    self.loop?.cancel(); self.loop = nil
                    self.endBackgroundTask()
                } else {
                    self.fail("處理時間已到，請重新點麥克風。")
                    self.loop?.cancel(); self.loop = nil
                    self.endBackgroundTask()
                }
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask); backgroundTask = .invalid
    }

    private func fail(_ message: String) {
        preparing = false
        beginBackgroundTask(); speech.cancel(); stopCapture()
        snapshot?.phase = .failed; snapshot?.message = message
        self.message = message; publish()
    }

    private func publish() {
        guard var snapshot, let exchange else { return }
        snapshot.updatedAt = .now; self.snapshot = snapshot; heartbeat = .now
        do { try exchange.write(snapshot) }
        catch { stop(message: "無法與鍵盤交換資料：\(error.localizedDescription)", publishState: false) }
    }
}
