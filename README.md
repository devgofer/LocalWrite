# LocalWrite

**Your words. Written locally.**

LocalWrite is an on-device voice writing tool for Apple platforms.

Speak naturally. LocalWrite captures the transcript, lightly cleans it up with Apple's on-device Foundation Model, and inserts the result directly into the text field you're already using.

No extra "Insert" step.

## Product direction

### macOS

The primary interaction is intentionally tiny:

1. Focus any text field.
2. Trigger LocalWrite with the configured keyboard shortcut.
3. A small capsule appears near the active writing area.
4. Speak naturally.
5. Stop speaking; after a short silence, LocalWrite finishes listening automatically.
6. The transcript is lightly refined on-device.
7. The refined text is inserted automatically.
8. The capsule disappears.

The visual direction is inspired by the simplicity of Typeless: one compact capsule, minimal controls, almost no UI chrome. The product should feel like a native interaction rather than another editor window.

### iOS

LocalWrite includes a custom keyboard foundation, but the voice path is intentionally **not** implemented inside the keyboard extension.

Apple's current custom-keyboard sandbox does not provide microphone access to third-party keyboards, so a keyboard extension cannot directly record the user's voice. The keyboard therefore remains a lightweight extension shell with the required keyboard-switching control.

The containing LocalWrite app is the place for iOS voice-capture experiments. This keeps the product honest about Apple's platform constraints instead of pretending the keyboard can do something the system does not allow.

## Requirements

- Xcode with Foundation Models support
- macOS/iOS 26 or later
- A compatible Apple Intelligence device for the on-device model

The Foundation Models framework exposes Apple's on-device language model through `SystemLanguageModel`. Model availability must be checked at runtime.

Speech recognition availability and supported on-device languages can vary by device and locale. LocalWrite requests on-device speech recognition where supported.

## Privacy

LocalWrite is designed around an on-device-first architecture. The refinement layer uses Apple's on-device Foundation Model when it is available. LocalWrite does not require a cloud LLM for its core refinement flow.

On iOS, the keyboard extension is intentionally non-networked. Voice capture is kept out of the keyboard extension because Apple does not grant third-party custom keyboards microphone access.

Speech recognition is requested only when the voice feature is used. The app declares the required microphone and speech-recognition usage descriptions.

## Status

The core architecture is implemented, but this repository still requires final Xcode target assembly and real-device validation. In particular, macOS Accessibility permissions, microphone/speech authorization, Foundation Model availability, global shortcut behavior, pasteboard insertion, and the iOS keyboard extension should be validated on physical Apple devices.
