# Setup

## macOS

Open the repository in Xcode and create/run a macOS App target using the files in `Apps/LocalWrite-macOS` plus `Sources/LocalWriteCore`.

Required capabilities:

- Microphone
- Speech Recognition usage description
- Accessibility permission at runtime for automatic insertion
- Foundation Models availability on a compatible Apple Intelligence device

The first voice interaction requests speech recognition authorization when needed. To enable automatic insertion and the global keyboard shortcut, add LocalWrite to:

**System Settings → Privacy & Security → Accessibility**

Then focus a text field in another app and press the configured shortcut. The default is **Option-Space**.

### Expected flow

```
Option-Space
→ capsule
→ Listening
→ speak
→ short silence
→ Refining
→ Writing
→ text appears at cursor
→ capsule disappears
```

There is deliberately no Insert button.

### Settings

Open **LocalWrite → Settings…** from the menu bar menu.

The current settings window lets you:

- change the shortcut modifier between Option, Control, and Command
- inspect Accessibility, Speech Recognition, and Foundation Model readiness
- request the required permissions

## iOS

Create an iOS application target and a Custom Keyboard Extension target from the files under `Apps/LocalWrite-iOS`.

The keyboard includes the required globe/input-mode control. Apple currently restricts third-party custom keyboards from microphone access, so the keyboard extension does **not** attempt direct voice capture.

The LocalWrite iOS app is the place to prototype voice capture and Foundation Model refinement. A future architecture may need a user-driven handoff between the containing app and keyboard rather than recording inside the keyboard extension.

Enable the keyboard from:

**Settings → General → Keyboard → Keyboards → LocalWrite**

Apple custom keyboards run in a separate process with memory limits, so the extension intentionally keeps its UI and state small.

## Model availability

The app checks `SystemLanguageModel.default.isAvailable` before using the Foundation Model. Availability depends on Apple Intelligence support, device/region settings, and model readiness.

## Speech privacy

The speech layer requests on-device recognition with `requiresOnDeviceRecognition = true`. Apple's Speech framework notes that on-device recognition support varies by language and service.
