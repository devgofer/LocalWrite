import SwiftUI
import AppKit

@main
struct LocalWriteMacApp: App {
    @StateObject private var controller = LocalWriteController()

    var body: some Scene {
        MenuBarExtra("LocalWrite", systemImage: "waveform") {
            Text(controller.modelAvailable ? "Model Ready" : "Model Unavailable")
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: controller.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                Text(controller.accessibilityGranted ? "Accessibility Ready" : "Accessibility Required")
            }

            HStack {
                Image(systemName: controller.speechAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle")
                Text(controller.speechAuthorized ? "Speech Ready" : "Speech Permission Required")
            }

            if !controller.accessibilityGranted {
                Button("Enable Accessibility") {
                    controller.requestAccessibility()
                }

                Button("Open Accessibility Settings") {
                    controller.openAccessibilitySettings()
                }
            }

            Divider()

            Button(controller.state == .listening ? "Stop Listening" : "Start Listening") {
                controller.toggleListening()
            }

            Divider()

            SettingsLink {
                Text("Settings…")
            }

            Divider()

            Button("Quit LocalWrite") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            LocalWriteSettingsView(controller: controller)
        }
    }
}
