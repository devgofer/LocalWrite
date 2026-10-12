import UIKit

/// Switches back to the app the keyboard was typing in. iOS has no public API for this.
/// The first route asks the system "back to <app>" breadcrumb, shown because the keyboard
/// opened LocalWrite by URL, to navigate back; the second opens a known bundle ID.
/// Both are undocumented, checked before use, and fail silently.
enum HostReturn {
    @MainActor
    static func goBack(hostBundleID: String?) -> String {
        let app = UIApplication.shared as NSObject
        let actionSelector = NSSelectorFromString("_systemNavigationAction")
        let sendSelector = NSSelectorFromString("sendResponseForDestination:")
        if app.responds(to: actionSelector),
           let action = app.perform(actionSelector)?.takeUnretainedValue() as? NSObject,
           action.responds(to: sendSelector) {
            let destinations = action.responds(to: NSSelectorFromString("destinations"))
                ? (action.value(forKey: "destinations") as? [NSNumber]) ?? [] : []
            let destination = destinations.first?.uintValue ?? 0
            typealias Send = @convention(c) (NSObject, Selector, UInt) -> Void
            unsafeBitCast(action.method(for: sendSelector), to: Send.self)(action, sendSelector, destination)
            return "breadcrumb destination=\(destination) of \(destinations)"
        }
        if let hostBundleID, hostBundleID != Bundle.main.bundleIdentifier, open(bundleID: hostBundleID) {
            return "opened \(hostBundleID)"
        }
        return "no route (breadcrumb \(app.responds(to: actionSelector) ? "present" : "missing"))"
    }

    private static func open(bundleID: String) -> Bool {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else { return false }
        let defaultSelector = NSSelectorFromString("defaultWorkspace")
        let openSelector = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspaceClass.responds(to: defaultSelector),
              let workspace = workspaceClass.perform(defaultSelector)?.takeUnretainedValue() as? NSObject,
              workspace.responds(to: openSelector) else { return false }
        return workspace.perform(openSelector, with: bundleID) != nil
    }
}
