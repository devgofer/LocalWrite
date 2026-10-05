import AppKit
import Foundation
import SwiftUI
import Speech
import LocalWriteCore

@MainActor
final class LocalWriteController: ObservableObject {
    @Published private(set) var state: WriteState = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var speechAuthorized = false

    let modelAvailable: Bool
    private(set) var accessibilityGranted: Bool
    private let engine: FoundationModelsEngine?
    private let speech = SpeechRecognizer()
    private let capsule = CapsulePanel()
    private let shortcut = GlobalShortcutMonitor()

    init() {
        if #available(macOS 26.0, *) {
            modelAvailable = FoundationModelsEngine.isAvailable
            engine = FoundationModelsEngine()
        } else {
            modelAvailable = false
            engine = nil
        }

        accessibilityGranted = AccessibilityPermission.isGranted
        speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized

        capsule.contentView = NSHostingView(
            rootView: CapsuleView(state: .idle, transcript: "")
        )

        restartShortcut()
    }

    func toggleListening() {
        if state == .listening {
            speech.cancel()
            state = .idle
            transcript = ""
            refreshCapsule()
        } else {
            startListening()
        }
    }

    func refreshPermissions() {
        accessibilityGranted = AccessibilityPermission.isGranted
        speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func requestAccessibility() {
        AccessibilityPermission.requestPrompt()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        AccessibilityPermission.openSettings()
    }

    func requestSpeechAuthorization() {
        Task {
            _ = await SpeechRecognizer.requestAuthorization()
            refreshPermissions()
        }
    }

    func restartShortcut() {
        shortcut.start { [weak self] in
            Task { @MainActor in
                self?.startListening()
            }
        }
    }

    private func startListening() {
        guard state == .idle || state.isError else { return }

        refreshPermissions()

        guard modelAvailable else {
            state = .error("Foundation Model unavailable")
            refreshCapsule()
            return
        }

        guard accessibilityGranted else {
            state = .error("Accessibility permission is required.")
            refreshCapsule()
            AccessibilityPermission.requestPrompt()
            return
        }

        transcript = ""
        state = .listening
        refreshCapsule()

        Task {
            let status = await SpeechRecognizer.requestAuthorization()
            refreshPermissions()

            guard status == .authorized else {
                state = .error("Speech recognition permission is required.")
                refreshCapsule()
                return
            }

            do {
                try speech.start(
                    onPartialResult: { [weak self] text in
                        Task { @MainActor in
                            self?.transcript = text
                            self?.refreshCapsule()
                        }
                    },
                    onFinished: { [weak self] finalText in
                        Task { @MainActor in
                            self?.beginRefinement(with: finalText)
                        }
                    }
                )
            } catch {
                state = .error(error.localizedDescription)
                refreshCapsule()
            }
        }
    }

    private func beginRefinement(with finalText: String) {
        let rawText = (finalText.isEmpty ? transcript : finalText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawText.isEmpty else {
            state = .idle
            transcript = ""
            refreshCapsule()
            return
        }

        transcript = rawText
        state = .refining
        refreshCapsule()

        Task {
            guard let engine else {
                state = .error("Foundation Model unavailable.")
                refreshCapsule()
                return
            }

            do {
                let result = try await engine.refine(rawText)
                state = .inserting
                refreshCapsule()

                try TextInserter.insert(result.refined)

                transcript = ""
                state = .idle
                refreshCapsule()
            } catch {
                state = .error(error.localizedDescription)
                refreshCapsule()
            }
        }
    }

    private func refreshCapsule() {
        capsule.update(state: state, transcript: transcript)

        if state == .idle {
            capsule.hide()
        } else {
            capsule.show()
        }
    }
}

private extension WriteState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
