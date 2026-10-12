import AppKit
@preconcurrency import ApplicationServices
import LocalWriteCore

extension WritingContext {
    /// The app being dictated into, plus its window title for browsers (Gmail in Chrome).
    @MainActor
    static func frontmost() -> WritingContext {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .general }
        var title: String?
        if AccessibilityPermission.isGranted {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var window: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
               let window, CFGetTypeID(window) == AXUIElementGetTypeID() {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &value) == .success {
                    title = value as? String
                }
            }
        }
        return classify(bundleID: app.bundleIdentifier, appName: app.localizedName, windowTitle: title)
    }
}
