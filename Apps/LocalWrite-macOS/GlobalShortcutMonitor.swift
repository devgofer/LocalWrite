import AppKit

final class GlobalShortcutMonitor {
    private var monitor: Any?

    func start(onTrigger: @escaping () -> Void) {
        stop()

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.option),
                  event.keyCode == 49 else {
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

    deinit {
        stop()
    }
}
