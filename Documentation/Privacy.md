# Privacy

LocalWrite is designed around an on-device-first writing flow.

## AI refinement

LocalWrite uses Apple's on-device Foundation Model through the Foundation Models framework when the model is available.

The app checks model availability at runtime rather than assuming every device can run the model.

## Speech

The speech layer requests on-device recognition with `requiresOnDeviceRecognition = true`.

Apple notes that this setting prevents the speech request from sending audio over the network only when the selected speech recognizer supports on-device recognition. LocalWrite therefore checks `supportsOnDeviceRecognition` before starting.

## macOS

On macOS, voice capture runs in the main LocalWrite app. Final text is inserted into the focused application through a temporary pasteboard bridge and the previous pasteboard contents are restored only if no other app or user action has replaced them.

Accessibility permission is required for this insertion mechanism. The app retains the most recent transcript or refined result in memory so it can be copied after an insertion failure. It does not write this text to a history file. A host that cannot expose a verifiable text value is reported as unconfirmed, and the text remains available.

The macOS signing configuration now uses the existing Apple Development identity so future builds can retain a stable Accessibility identity. On this task's starting checkout, the macOS sandbox entitlement had already been removed; that existing state was preserved. See `Keyboard-and-Permissions-2026-10-08.md` for the current diagnosis and authorization status.

## iOS keyboard

The keyboard uses Full Access to exchange commands and results with the minimal containing app through `group.com.devgofer.LocalWrite`. LocalWrite performs no network requests. The keyboard itself does not open the microphone or read the clipboard.

A microphone tap in the keyboard creates a one-use local launch ticket and opens the containing app to start recording. Recording can continue while the user returns to the original text field. Capture stops when dictation finishes, is canceled, or fails. Speech recognition and refinement run on-device. The current device-test implementation still requires the system back control to return to the host app.

Shared result files contain the latest transcript/result. A pending request also temporarily stores the document identifier and surrounding text to validate the insertion destination after keyboard recreation. Completion acknowledgment or ending the session clears them. If the app crashes, a result can remain in the shared container until the next session overwrites it; stale snapshots are never automatically inserted. A result is delivered only once, to the requesting document while its context is unchanged.

## Data handling principle

LocalWrite does not require a cloud LLM for its core refinement design.

The product goal is simple: keep the user's words on-device whenever the selected Apple speech/model capabilities support that flow, and never add a server dependency merely to make the prototype work.
