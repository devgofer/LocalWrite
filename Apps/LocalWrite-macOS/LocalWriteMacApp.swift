import SwiftUI
import AppKit

@main
struct LocalWriteMacApp: App {
    @StateObject private var controller = LocalWriteController()

    var body: some Scene {
        MenuBarExtra("LocalWrite", systemImage: "waveform") {
            Text(controller.modelAvailable ? "● 模型就緒" : "○ 模型不可用")

            Text(controller.accessibilityGranted ? "✓ 輔助使用已授權" : "⚠️ 需要輔助使用權限")

            Text(controller.speechAuthorized ? "✓ 語音辨識已授權" : "⚠️ 需要語音辨識權限")

            Text(controller.microphoneAuthorized ? "✓ 麥克風已授權" : "⚠️ 需要麥克風權限")

            Divider()

            if !controller.accessibilityGranted {
                Button("授權輔助使用⋯") {
                    controller.requestAccessibility()
                }

                Button("開啟輔助使用設定⋯") {
                    controller.openAccessibilitySettings()
                }
            }

            if !controller.speechAuthorized || !controller.microphoneAuthorized {
                Button("授權語音與麥克風⋯") {
                    controller.requestSpeechAuthorization()
                }
            }

            Button("重新整理權限狀態") { controller.refreshPermissions() }

            Divider()

            Button(controller.state == .listening ? "完成並填入" : "開始聆聽") {
                controller.toggleListening()
            }
            if controller.state == .listening {
                Button("取消") { controller.cancelListening() }
            }

            Button("複製上次文字") { controller.copySavedText() }
                .disabled(controller.savedText.isEmpty)
            if case .error(let message) = controller.state { Text(message) }

            Divider()

            Button("設定⋯") { SettingsWindow.show(controller: controller) }
                .keyboardShortcut(",")

            Divider()

            Button("結束 LocalWrite") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
