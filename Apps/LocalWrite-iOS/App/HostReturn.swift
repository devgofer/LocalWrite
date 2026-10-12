import Foundation
import OSLog

/// Switches back to the app the keyboard was typing in. iOS has no public API for this;
/// LSApplicationWorkspace is undocumented, so every step is checked and failure is silent.
enum HostReturn {
    private static let log = Logger(subsystem: "com.devgofer.LocalWrite", category: "HostReturn")

    @discardableResult
    static func open(bundleID: String) -> Bool {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else { return false }
        let defaultSelector = NSSelectorFromString("defaultWorkspace")
        let openSelector = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspaceClass.responds(to: defaultSelector),
              let workspace = workspaceClass.perform(defaultSelector)?.takeUnretainedValue() as? NSObject,
              workspace.responds(to: openSelector) else { return false }
        let opened = workspace.perform(openSelector, with: bundleID) != nil
        log.notice("Return to \(bundleID, privacy: .public): \(opened)")
        return opened
    }
}
