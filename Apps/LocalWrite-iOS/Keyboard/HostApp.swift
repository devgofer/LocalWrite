import UIKit

/// iOS has no public API that names the app a keyboard is typing into. These are the
/// undocumented routes other dictation keyboards rely on; each is checked before use
/// so a missing key cannot raise an exception. Returns nil when none works.
enum HostApp {
    /// What the last lookup found, for the shared diagnostics log.
    @MainActor static var lastProbe = ""

    @MainActor
    static func bundleID(for controller: UIInputViewController) -> String? {
        lastProbe = ""
        var candidates: [NSObject] = [controller]
        if let parent = controller.parent { candidates.append(parent) }
        for object in candidates {
            for key in ["_hostBundleID", "_hostApplicationBundleIdentifier"]
            where object.responds(to: NSSelectorFromString(key)) {
                let value = object.value(forKey: key) as? String
                lastProbe += "\(type(of: object)).\(key)=\(value ?? "nil") "
                if let value, !value.isEmpty, value != "<null>" { return value }
            }
        }
        if let pid = hostPID(candidates), let id = bundleID(pid: pid) { return id }
        return nil
    }

    @MainActor private static func hostPID(_ candidates: [NSObject]) -> pid_t? {
        for object in candidates where object.responds(to: NSSelectorFromString("_hostPID")) {
            if let pid = (object.value(forKey: "_hostPID") as? NSNumber)?.int32Value, pid > 0 {
                lastProbe += "pid=\(pid) "
                return pid
            }
        }
        return nil
    }

    /// RunningBoard can map a process identifier to its bundle when the sandbox allows it.
    @MainActor private static func bundleID(pid: pid_t) -> String? {
        guard let identifierClass = NSClassFromString("RBSProcessIdentifier") as? NSObject.Type,
              let handleClass = NSClassFromString("RBSProcessHandle") as? NSObject.Type else {
            lastProbe += "rbs=unavailable "; return nil
        }
        let makeIdentifier = NSSelectorFromString("identifierWithPid:")
        let makeHandle = NSSelectorFromString("handleForIdentifier:error:")
        guard identifierClass.responds(to: makeIdentifier), handleClass.responds(to: makeHandle) else { return nil }
        typealias IdentifierFunction = @convention(c) (AnyClass, Selector, Int32) -> Unmanaged<NSObject>?
        typealias HandleFunction = @convention(c) (AnyClass, Selector, NSObject, UnsafeMutableRawPointer?) -> Unmanaged<NSObject>?
        let identifierIMP = unsafeBitCast(identifierClass.method(for: makeIdentifier), to: IdentifierFunction.self)
        let handleIMP = unsafeBitCast(handleClass.method(for: makeHandle), to: HandleFunction.self)
        guard let identifier = identifierIMP(identifierClass, makeIdentifier, pid)?.takeUnretainedValue(),
              let handle = handleIMP(handleClass, makeHandle, identifier, nil)?.takeUnretainedValue() else { return nil }
        for key in ["bundleIdentifier", "bundle.identifier"] {
            let value = key.contains(".") ? handle.value(forKeyPath: key) as? String
                : (handle.responds(to: NSSelectorFromString(key)) ? handle.value(forKey: key) as? String : nil)
            lastProbe += "rbs.\(key)=\(value ?? "nil") "
            if let value, !value.isEmpty { return value }
        }
        return nil
    }
}
