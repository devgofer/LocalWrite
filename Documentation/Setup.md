# Setup

## macOS

Open the repository in Xcode and create/run a macOS App target using the files in `Apps/LocalWrite-macOS` plus `Sources/LocalWriteCore`.

Required capabilities:

- Microphone
- Speech Recognition usage description
- Accessibility permission at runtime for automatic insertion

The first launch should request microphone/speech permissions. To enable automatic insertion, add LocalWrite to:

**System Settings → Privacy & Security → Accessibility**

Then focus a text field in another app and press **Option-Space**.

### Expected flow

```
Option-Space
→ capsule
→ Listening
→ speak
→ Option-Space
→ Refining
→ Writing
→ text appears at cursor
→ capsule disappears
```

There is deliberately no Insert button.

## iOS

Create an iOS application target and a Custom Keyboard Extension target from the files under `Apps/LocalWrite-iOS`.

Apple requires the keyboard extension to expose a way to switch keyboards. LocalWrite uses the globe button and `advanceToNextInputMode()`.

Enable the keyboard from:

**Settings → General → Keyboard → Keyboards → LocalWrite**

Apple custom keyboards run in a separate process with memory limits, so the extension intentionally keeps its UI and state small. citeturn2search1

## Model availability

The app checks `SystemLanguageModel.default.isAvailable` before using the Foundation Model. Availability depends on Apple Intelligence support, device/region settings, and model readiness. citeturn0search0turn1search4

## Speech privacy

The speech layer requests on-device recognition with `requiresOnDeviceRecognition = true`. Apple's Speech framework notes that availability of on-device recognition varies by language and service. citeturn1search14
