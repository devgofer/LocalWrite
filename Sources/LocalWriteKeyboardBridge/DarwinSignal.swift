import Foundation

/// Cross-process "something changed" pings between the app and the keyboard.
/// They carry no data; the receiver reads the App Group files.
public final class DarwinSignal: @unchecked Sendable {
    public static let command = "com.devgofer.LocalWrite.command"
    public static let state = "com.devgofer.LocalWrite.state"

    public static func post(_ name: String) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(name as CFString), nil, nil, true)
    }

    private let name: String
    private let handler: @Sendable () -> Void

    /// Keep the returned object alive for as long as you want callbacks.
    public init(observing name: String, handler: @escaping @Sendable () -> Void) {
        self.name = name
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<DarwinSignal>.fromOpaque(observer).takeUnretainedValue().handler()
            },
            name as CFString, nil, .deliverImmediately)
    }

    deinit {
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                           Unmanaged.passUnretained(self).toOpaque(),
                                           CFNotificationName(name as CFString), nil)
    }
}
