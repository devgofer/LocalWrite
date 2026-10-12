import SwiftUI
struct LocalWriteSettingsView: View {
    @ObservedObject var controller: LocalWriteController

    @State private var shortcut = LocalWriteSettings.shortcut
    @State private var recording = false
    @State private var shortcutError: String?
    @State private var monitor: Any?

    var body: some View {
        Form {
            Section("快捷鍵") {
                HStack {
                    Text("開始／完成聽寫")
                    Spacer()
                    Button(recording ? "請按下新的快捷鍵⋯" : shortcut.displayName) {
                        recording ? stopRecording() : startRecording()
                    }
                    .frame(minWidth: 140)
                }
                if let shortcutError {
                    Text(shortcutError).font(.caption).foregroundStyle(.red)
                } else {
                    Text("按一下按鈕，再按下想用的組合鍵（需包含 ⌘、⌥ 或 ⌃，或使用 F 鍵）。按 Esc 取消。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if shortcut != .default {
                    Button("恢復預設（⌥Space）") { apply(.default) }
                }
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Accessibility",
                    isReady: controller.accessibilityGranted
                )

                if !controller.accessibilityGranted {
                    HStack {
                        Button("Request Access") {
                            controller.requestAccessibility()
                        }
                        Button("Open Settings") {
                            controller.openAccessibilitySettings()
                        }
                    }
                }

                PermissionRow(
                    title: "Speech Recognition",
                    isReady: controller.speechAuthorized
                )

                if !controller.speechAuthorized || !controller.microphoneAuthorized {
                    Button("Request Speech & Microphone Access") {
                        controller.requestSpeechAuthorization()
                    }
                }

                PermissionRow(title: "Microphone", isReady: controller.microphoneAuthorized)
                Button("Refresh Status") { controller.refreshPermissions() }

                PermissionRow(
                    title: "Foundation Model",
                    isReady: controller.modelAvailable
                )
            }

            Section("About") {
                Text("LocalWrite refines speech on-device when Apple’s Foundation Model is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { controller.refreshPermissions() }
        .onDisappear { if recording { stopRecording() } }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 420)
    }

    private func startRecording() {
        shortcutError = nil
        recording = true
        // Let the current shortcut be recorded as itself instead of triggering dictation.
        controller.pauseShortcut()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                stopRecording(); return nil
            }
            guard let candidate = Shortcut(event: event) else {
                shortcutError = "請包含 ⌘、⌥ 或 ⌃，例如 ⌥Space。"
                return nil
            }
            stopRecording(apply: candidate)
            return nil
        }
    }

    private func stopRecording(apply candidate: Shortcut? = nil) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        if let candidate { apply(candidate) } else { controller.restartShortcut() }
    }

    private func apply(_ candidate: Shortcut) {
        if controller.applyShortcut(candidate) {
            shortcut = candidate; shortcutError = nil
        } else {
            shortcutError = "\(candidate.displayName) 已被其他 App 使用，請換一個。"
            shortcut = LocalWriteSettings.shortcut
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let isReady: Bool

    var body: some View {
        HStack {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
            Text(title)
            Spacer()
            Text(isReady ? "Ready" : "Required")
                .foregroundStyle(.secondary)
        }
    }
}
