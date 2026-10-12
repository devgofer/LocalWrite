import AppKit
import SwiftUI

/// LocalWrite is a menu-bar-only app, so SwiftUI's SettingsLink opens nothing (or a
/// window behind other apps). This owns the window and brings it to the front.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(controller: LocalWriteController) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: LocalWriteSettingsView(controller: controller)))
            window.title = "LocalWrite 設定"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
