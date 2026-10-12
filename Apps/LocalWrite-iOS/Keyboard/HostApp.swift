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
        if let context = controller.extensionContext { candidates.append(context) }
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
        // The extension's XPC connection usually leads to the process hosting the keyboard.
        for object in candidates {
            for key in ["_auxiliaryConnection", "_connection", "connection"] where object.responds(to: NSSelectorFromString(key)) {
                if let connection = object.value(forKey: key) as? NSXPCConnection {
                    lastProbe += "\(type(of: object)).\(key).pid=\(connection.processIdentifier) "
                    if connection.processIdentifier > 0 { return connection.processIdentifier }
                }
            }
        }
        for object in candidates {
            for key in ["_hostPID", "_hostProcessIdentifier", "hostPID"] where object.responds(to: NSSelectorFromString(key)) {
            if let pid = (object.value(forKey: key) as? NSNumber)?.int32Value, pid > 0 {
                lastProbe += "\(key)=\(pid) "
                return pid
            }
            }
        }
        return nil
    }

    /// Lists host-related methods and ivars on the objects around the keyboard, so the
    /// on-device log shows which undocumented accessors this iOS version offers.
    @MainActor
    static func survey(_ controller: UIInputViewController) -> String {
        var objects: [(String, AnyObject)] = [("controller", controller)]
        if let parent = controller.parent { objects.append(("parent", parent)) }
        if let context = controller.extensionContext { objects.append(("context", context)) }
        objects.append(("proxy", controller.textDocumentProxy as AnyObject))
        if let window = controller.view.window { objects.append(("window", window)) }
        if let scene = controller.view.window?.windowScene { objects.append(("scene", scene)) }
        let pattern = #/(?i)host|pid|bundle|audit|client|connection|process|remote|source/#
        var lines: [String] = []
        for (label, object) in objects {
            var names = Set<String>()
            var cls: AnyClass? = object_getClass(object)
            var classes: [String] = []
            while let current = cls, classes.count < 4, NSStringFromClass(current) != "NSObject" {
                classes.append(NSStringFromClass(current))
                var count: UInt32 = 0
                if let methods = class_copyMethodList(current, &count) {
                    for index in 0..<Int(count) {
                        let name = NSStringFromSelector(method_getName(methods[index]))
                        if name.contains(pattern) { names.insert(name) }
                    }
                    free(methods)
                }
                if let ivars = class_copyIvarList(current, &count) {
                    for index in 0..<Int(count) {
                        if let raw = ivar_getName(ivars[index]) {
                            let name = String(cString: raw)
                            if name.contains(pattern) { names.insert("ivar:" + name) }
                        }
                    }
                    free(ivars)
                }
                cls = class_getSuperclass(current)
            }
            lines.append("\(label)[\(classes.joined(separator: ">"))]: \(names.sorted().prefix(40).joined(separator: ","))")
        }
        return lines.joined(separator: " | ")
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
