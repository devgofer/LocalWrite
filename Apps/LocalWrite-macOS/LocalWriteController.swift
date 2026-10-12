import AppKit
import SwiftUI
import Speech
import AVFoundation
import LocalWriteCore
import OSLog

@MainActor
protocol SpeechCapturing {
    func start(onPartialResult: @escaping @MainActor (String) -> Void,
               onFinished: @escaping @MainActor (String) -> Void,
               onError: @escaping @MainActor (String) -> Void) throws
    func finish()
    func cancel()
    var onLevel: (@MainActor (Float) -> Void)? { get set }
}

extension SpeechRecognizer: SpeechCapturing {}

@MainActor
final class LocalWriteController: ObservableObject {
    @Published private(set) var state: WriteState = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var savedText = ""
    @Published private(set) var speechAuthorized = false
    @Published private(set) var microphoneAuthorized = false
    @Published private(set) var modelAvailable = false
    @Published private(set) var accessibilityGranted = false

    private let engine: any LocalWriteEngine
    private var speech: any SpeechCapturing
    private let authorizeSpeech: @MainActor () async -> SFSpeechRecognizerAuthorizationStatus
    private let authorizeMicrophone: @MainActor () async -> Bool
    private let captureTarget: @MainActor () throws -> TextInsertionTarget?
    private let modelAvailability: @MainActor () -> Bool
    private let accessibilityStatus: @MainActor () -> Bool
    private let promptAccessibility: @MainActor () -> Void
    private let showAccessibilitySettings: @MainActor () -> Void
    private let capsule = CapsulePanel()
    private let shortcut = GlobalShortcutMonitor()
    private var operation: Task<Void, Never>?
    private var operationID: UUID?
    private var target: TextInsertionTarget?
    private var permissionMonitor: Task<Void, Never>?
    private var speechStarted = false

    init(
        speech: any SpeechCapturing = SpeechRecognizer(),
        engine: any LocalWriteEngine = FoundationModelsEngine(),
        authorizeSpeech: @escaping @MainActor () async -> SFSpeechRecognizerAuthorizationStatus = { await SpeechRecognizer.requestAuthorization() },
        authorizeMicrophone: @escaping @MainActor () async -> Bool = { await SpeechRecognizer.requestMicrophoneAuthorization() },
        captureTarget: @escaping @MainActor () throws -> TextInsertionTarget? = { try TextInsertionTarget.capture() },
        modelAvailability: @escaping @MainActor () -> Bool = { FoundationModelsEngine.isAvailable },
        accessibilityStatus: @escaping @MainActor () -> Bool = { AccessibilityPermission.isGranted },
        promptAccessibility: @escaping @MainActor () -> Void = { AccessibilityPermission.requestPrompt() },
        showAccessibilitySettings: @escaping @MainActor () -> Void = { AccessibilityPermission.openSettings() },
        registerShortcut: Bool = true
    ) {
        self.speech = speech
        self.engine = engine
        self.authorizeSpeech = authorizeSpeech
        self.authorizeMicrophone = authorizeMicrophone
        self.captureTarget = captureTarget
        self.modelAvailability = modelAvailability
        self.accessibilityStatus = accessibilityStatus
        self.promptAccessibility = promptAccessibility
        self.showAccessibilitySettings = showAccessibilitySettings
        self.speech.onLevel = { [weak self] level in self?.capsule.push(level: level) }
        refreshPermissions()
        Logger(subsystem: "com.devgofer.LocalWrite", category: "Permissions")
            .notice("Accessibility granted: \(self.accessibilityGranted); app: \(Bundle.main.bundlePath, privacy: .public)")
        if registerShortcut {
            restartShortcut()
            permissionMonitor = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard let self else { return }
                    let granted = self.accessibilityStatus()
                    if self.accessibilityGranted != granted { self.accessibilityGranted = granted }
                }
            }
        }
    }

    isolated deinit { permissionMonitor?.cancel() }

    /// Press once to start, press again when you are done speaking.
    func toggleListening() {
        guard state == .listening else { startListening(); return }
        guard speechStarted else { cancelListening(); return }
        // Finishing waits for the final transcript, then refines and inserts it.
        state = .refining
        refreshCapsule()
        speech.finish()
    }

    /// Discards the current recording.
    func cancelListening() {
        guard state == .listening || state == .refining else { return }
        operationID = nil
        operation?.cancel()
        operation = nil
        speech.cancel()
        speechStarted = false
        if !transcript.isEmpty { savedText = transcript }
        state = .idle
        refreshCapsule()
    }

    func refreshPermissions() {
        accessibilityGranted = accessibilityStatus()
        speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        modelAvailable = modelAvailability()
    }

    func requestAccessibility() {
        refreshPermissions()
        guard !accessibilityGranted else { return }
        promptAccessibility()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        NSApp.activate(ignoringOtherApps: true)
        showAccessibilitySettings()
    }

    func requestSpeechAuthorization() {
        NSApp.activate(ignoringOtherApps: true)
        Task {
            _ = await SpeechRecognizer.requestAuthorization()
            _ = await SpeechRecognizer.requestMicrophoneAuthorization()
            refreshPermissions()
        }
    }

    func copySavedText() {
        guard !savedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(savedText, forType: .string)
    }

    func restartShortcut() {
        do { try shortcut.start { [weak self] in self?.toggleListening() } }
        catch { fail(error.localizedDescription) }
    }

    private func startListening() {
        guard state == .idle || state.isError else { return }
        refreshPermissions()
        guard modelAvailable else { fail("Foundation Model unavailable."); return }

        guard accessibilityGranted else {
            fail("LocalWrite 尚未取得這個版本的輔助使用授權。可在選單重新檢查，或由你選擇開啟設定；程式不會自動跳轉。")
            return
        }

        do { target = try captureTarget() }
        catch { fail(error.localizedDescription); return }

        let id = UUID()
        operationID = id
        speechStarted = false
        transcript = ""
        state = .listening
        refreshCapsule()
        let authorizeSpeech = self.authorizeSpeech
        operation = Task { [weak self] in
            let status = await authorizeSpeech()
            guard let self, self.operationID == id, !Task.isCancelled else { return }
            guard status == .authorized else {
                self.refreshPermissions()
                self.fail("Speech recognition permission is required.")
                return
            }
            let microphone = await self.authorizeMicrophone()
            guard self.operationID == id, !Task.isCancelled else { return }
            self.refreshPermissions()
            guard microphone else { self.fail("Microphone permission is required."); return }
            do {
                try self.speech.start(
                    onPartialResult: { [weak self] text in
                        guard let self, self.operationID == id else { return }
                        self.transcript = text
                        self.savedText = text
                    },
                    onFinished: { [weak self] text in
                        guard let self, self.operationID == id else { return }
                        self.beginRefinement(with: text, id: id)
                    },
                    onError: { [weak self] message in
                        guard let self, self.operationID == id else { return }
                        self.fail(message)
                    }
                )
                self.speechStarted = true
            } catch { self.fail(error.localizedDescription) }
        }
    }

    private func beginRefinement(with text: String, id: UUID) {
        speechStarted = false
        transcript = text
        savedText = text
        state = .refining
        refreshCapsule()
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.engine.refine(text)
                guard self.operationID == id, !Task.isCancelled else { return }
                self.savedText = result.refined
                self.state = .inserting
                self.refreshCapsule()
                guard let target = self.target else { throw TextInsertionError.noTextField }
                try await TextInserter.insert(result.refined, into: target)
                guard self.operationID == id else { return }
                self.operationID = nil
                self.transcript = ""
                self.state = .idle
                self.refreshCapsule()
            } catch {
                guard self.operationID == id else { return }
                self.fail(error.localizedDescription)
            }
        }
    }

    private func fail(_ message: String) {
        operationID = nil
        speechStarted = false
        speech.cancel()
        state = .error(message)
        refreshCapsule()
    }

    private func refreshCapsule() {
        capsule.update(state: state)
        if state == .idle { capsule.hide() } else { capsule.show() }
    }
}

private extension WriteState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
