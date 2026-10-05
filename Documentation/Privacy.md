# Privacy

LocalWrite is designed around an on-device-first writing flow.

## AI refinement

LocalWrite uses Apple's on-device Foundation Model through the Foundation Models framework when the model is available. Apple requires apps to check model availability because availability depends on device, region, Apple Intelligence settings, and model readiness.

## Speech

The macOS prototype requests speech recognition permission and asks Apple's Speech framework for on-device recognition with `requiresOnDeviceRecognition = true`.

If the requested speech recognizer cannot perform the operation on-device, LocalWrite should fail clearly rather than silently changing the privacy expectation.

## Text insertion

The macOS prototype uses the pasteboard only as a bridge into the currently focused application. It restores the previous pasteboard contents after insertion.

Accessibility permission is required for simulated Command-V input.

## Product promise

LocalWrite should never imply that every Apple device can run the on-device model or every speech language can be recognized offline. Availability is capability-dependent.
