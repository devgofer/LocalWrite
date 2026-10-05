import AppKit

final class GlobalShortcutMonitor {
    private var monitor: Any?

    func start(onTrigger: @escaping () -> Void) {
        stop()

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 49,
                  !event.isARepeat,
                  Self.matchesConfiguredModifier(event.modifierFlags) else {
                return
            }

            onTrigger()
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static func matchesConfiguredModifier(_ flags: NSEvent.ModifierFlags) -> Bool {
        switch LocalWriteSettings.shortcutModifier {
        case "control":
            return flags.contains(.control)
        case "command":
            return flags.contains(.command)
        case "option":
            return flags.contains(.option)
        default:
            return flags.contains(.option)
        }
    }

    deinit {
        stop()
    }
}
