import UIKit

/// Switches back to the app the keyboard was typing in. iOS has no public API for this.
/// The first route asks the system "back to <app>" breadcrumb, which iOS attaches when
/// another app opens LocalWrite by URL, to navigate back; the second opens a known bundle
/// ID. Both are undocumented, checked before use, and fail silently.
enum HostReturn {
    /// Retries for a few seconds because iOS can attach the breadcrumb after activation.
    @MainActor
    static func goBack(hostBundleID: String?) async -> String {
        var notes: [String] = []
        for attempt in 0..<15 {
            if let result = sendBreadcrumb(notes: &notes) { return "attempt \(attempt): \(result)" }
            try? await Task.sleep(for: .milliseconds(200))
        }
        if let hostBundleID, hostBundleID != Bundle.main.bundleIdentifier, open(bundleID: hostBundleID) {
            return "opened \(hostBundleID)"
        }
        return "no route: " + Array(Set(notes)).sorted().joined(separator: "; ")
    }

    @MainActor
    private static func sendBreadcrumb(notes: inout [String]) -> String? {
        let actionSelector = NSSelectorFromString("_systemNavigationAction")
        var owners: [NSObject] = [UIApplication.shared]
        owners += UIApplication.shared.connectedScenes.map { $0 as NSObject }
        for owner in owners {
            let name = String(describing: type(of: owner))
            guard owner.responds(to: actionSelector) else { notes.append("\(name) lacks action"); continue }
            guard let action = owner.perform(actionSelector)?.takeUnretainedValue() as? NSObject else {
                notes.append("\(name) action nil"); continue
            }
            let sendSelector = NSSelectorFromString("sendResponseForDestination:")
            guard action.responds(to: sendSelector) else { notes.append("\(type(of: action)) lacks send"); continue }
            let destinations = action.responds(to: NSSelectorFromString("destinations"))
                ? (action.value(forKey: "destinations") as? [NSNumber]) ?? [] : []
            let destination = destinations.first?.uintValue ?? 0
            typealias Send = @convention(c) (NSObject, Selector, UInt) -> Void
            unsafeBitCast(action.method(for: sendSelector), to: Send.self)(action, sendSelector, destination)
            return "\(name) breadcrumb destination=\(destination) of \(destinations)"
        }
        return nil
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
