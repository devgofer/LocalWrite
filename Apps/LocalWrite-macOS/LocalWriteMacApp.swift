import SwiftUI

@main
struct LocalWriteMacApp: App {
    @StateObject private var controller = LocalWriteController()

    var body: some Scene {
        MenuBarExtra("LocalWrite", systemImage: "waveform") {
            Text(controller.modelAvailable ? "Model Ready" : "Model Unavailable")
                .foregroundStyle(.secondary)

            Divider()

            Button(controller.state == .listening ? "Stop Listening" : "Start Listening") {
                controller.toggleListening()
            }

            Divider()

            Button("Quit LocalWrite") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
