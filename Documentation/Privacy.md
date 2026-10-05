# Privacy

LocalWrite is designed around an on-device-first writing flow.

## AI refinement

LocalWrite uses Apple's on-device Foundation Model through the Foundation Models framework when the model is available.

The app checks model availability at runtime rather than assuming every device can run the model.

## Speech

The speech layer requests on-device recognition with `requiresOnDeviceRecognition = true`.

Apple notes that this setting prevents the speech request from sending audio over the network only when the selected speech recognizer supports on-device recognition. LocalWrite therefore checks `supportsOnDeviceRecognition` before starting.

## macOS

On macOS, voice capture runs in the main LocalWrite app. Final text is inserted into the focused application through a temporary pasteboard bridge and the previous pasteboard contents are restored.

Accessibility permission is required for this insertion mechanism.

## iOS keyboard

The iOS custom keyboard is intentionally non-networked with `RequestsOpenAccess = false`.

Apple's current custom keyboard documentation states that keyboards without open access have no microphone access. This means LocalWrite cannot truthfully provide microphone recording directly inside the third-party keyboard extension.

The iOS keyboard target therefore does not attempt to capture audio. Its current role is the keyboard-extension shell and keyboard-switching integration. The containing LocalWrite app remains the place for future voice-capture experiments that comply with Apple's extension restrictions.

## Data handling principle

LocalWrite does not require a cloud LLM for its core refinement design.

The product goal is simple: keep the user's words on-device whenever the selected Apple speech/model capabilities support that flow, and never add a server dependency merely to make the prototype work.
