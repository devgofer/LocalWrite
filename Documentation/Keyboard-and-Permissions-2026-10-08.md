# Mac permissions and iOS keyboard — 2026-10-08

## Mac: reproduced and repaired on this machine

System Settings showed LocalWrite enabled. Its Show in Finder action pointed to the Xcode DerivedData build. Launching either that build or the repository build produced `Accessibility granted: false`.

The macOS TCC service reported `Failed to match existing code requirement` for `com.devgofer.LocalWrite` / `kTCCServiceAccessibility`: the stored grant referenced an old ad-hoc cdhash. Updating the app signature alone and toggling the stale record off/on did not resolve it.

The Mac target now uses the existing Apple Development identity and Team AP6ML9U34X. The old DerivedData copy was updated to the same signed version. After the user completed Touch ID, the stale entry was removed and the signed repository app was added to the same permission category. The actual app then reported `Accessibility granted: true` at 12:22:34. A second quit/relaunch at 23:30:17 again returned true. The app does not change TCC records itself. Permissions are checked using AXIsProcessTrusted, with no false-positive override.

Run `build/Build/Products/Debug/LocalWrite.app`. Retain development signing in future builds; ad-hoc signing creates a new code identity on rebuild. The earlier changes also remove repeated automatic Settings redirection and refresh permission status while running.

The macOS entitlements already lacked App Sandbox at the start of this work; this turn did not edit that file.

## iOS: keyboard-triggered recording, device verification in progress

The manually enabled five-minute helper flow has been removed in response to the user's revised requirement. Three keys remain: Delete, Microphone, Return. Long-press Return switches keyboard; the system may provide its own keyboard controls.

Current implemented flow:

1. Tap the keyboard microphone. A SwiftUI Link opens LocalWrite with a one-use, 30-second App Group launch ticket.
2. The app validates/consumes that ticket, obtains speech/microphone permission if needed, and starts recording automatically.
3. Use the system back control to return to the host text field. **Automatic return remains unimplemented.**
4. Tap the microphone again to stop capture, await the final transcript, refine with Foundation Models, and insert through textDocumentProxy.

Microphone capture stops on finish/cancel/error. Background processing gets a finite iOS background task after capture ends. Active recording needs a heartbeat; finished results remain valid for up to 120 seconds so suspension does not immediately invalidate them. Pending delivery retains request/session/document IDs and surrounding text across controller recreation, refuses another document or changed context, and clears its one-use claim before insertion.

Shared data uses App Group `group.com.devgofer.LocalWrite`. No transcript is passed via the clipboard or a URL. Temporary launch/pending/status/command files can remain after a crash; expired requests/results are rejected. The pending file includes surrounding text solely to prevent inserting into a changed field.

## Evidence and limits

- 35 XCTest tests passed: Mac 7, core 21, keyboard bridge 7.
- iOS Simulator build and signed iPhone 17 build passed.
- Signed app/keyboard installed on the connected iPhone 17 with App Group provisioning.
- iPhone Settings confirms LocalWrite is an installed keyboard with Full Access enabled.
- Created a `LocalWrite test` note for device testing.
- iPhone Mirroring setup explicitly says the microphone is unavailable while mirroring. Mirroring was closed for the physical speech test.
- The full speech → Foundation Models → host-field insertion result remains pending device verification. Compilation and bridge tests do not establish that result.

## Reference findings

[Typeless's own app-switching explanation](https://www.typeless.com/help/release-notes/ios/when-does-app-switching-happen) describes opening the containing app when microphone access is needed, and starting directly when a switch is unnecessary. It does not establish how LocalWrite can automatically return to any host.

[KeyboardKit's implementation note](https://keyboardkit.com/blog/2024/09/11/ios18-breaks-selector-based-url-opening) uses SwiftUI Link for keyboard URL actions after iOS 18; this is the basis of the launch implementation. [Apple's keyboard guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) describes extension restrictions.

## Reproduction commands

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --scratch-path /private/tmp/LocalWrite-xcode-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LocalWrite.xcodeproj -scheme LocalWriteMac -derivedDataPath build build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LocalWrite.xcodeproj -scheme LocalWriteiOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build-ios CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES build
```

For a physical iPhone, use the registered device destination and the same development team for both iOS targets. Do not apply the simulator ad-hoc signing override to the Mac app.

## Device crash investigation (23:30–23:38)

The user reproduced an immediate crash after a keyboard microphone tap. The retrieved iPhone report `LocalWrite-2026-10-08-233214.ips` identifies `_dispatch_assert_queue_fail` → Swift executor check → the audio-tap closure nested in `KeyboardVoiceHelper.enable`. The callback inherited main-actor isolation but AVAudioEngine invokes it on an audio queue. It now comes from a nonisolated, explicitly Sendable `SpeechAudioFeed.makeTapHandler`; the core's direct capture and recognition callbacks also explicitly use Sendable closures. A synthetic-buffer test invokes the production callback on a detached executor. That extracted callback test passed even before the final annotation, so it does not independently reproduce the original nested iOS closure crash; the captured device stack is the failure evidence, and acoustic device retesting is still required.

The keyboard report `LocalWriteKeyboard-2026-10-08-233028.ips` raises an Objective-C exception in UIKit's documentIdentifier accessor during viewWillAppear. Proxy restoration/polling now starts after viewDidAppear and a deferred turn; disappearance cancels polling before the proxy is disconnected. This also awaits device regression verification.

Exchange files now live under `Library/Caches/LocalWrite` in the App Group so they are transient cache data and accessible to ordinary development diagnostics. The signed crash-fix build was installed successfully. No newer crash report had appeared at the subsequent check, but no new recording status file existed yet either; this is not counted as an end-to-end pass.

## Follow-up verification — 2026-10-11

The latest signed Mac build was launched again at 13:52:59; its own permission log still reports `Accessibility granted: true`. This verifies the stable developer signature across the shared-audio-code rebuild as well as relaunch.

The connected iPhone still contains only the six crash reports from 2026-10-08 23:30–23:32, preceding the crash-fix installation. Its cache contains a stopped status and an unconsumed pending request from 23:57 on that date, with no finish command. This does not establish successful insertion. A fresh physical speech test has been requested; microphone capture cannot be verified through iPhone Mirroring.
