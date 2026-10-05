# Xcode Project

LocalWrite keeps the reusable logic in a Swift Package and defines the Apple app targets in `project.yml`.

The project definition uses XcodeGen to generate an Xcode project with:

- **LocalWriteMac** — macOS menu bar app
- **LocalWriteiOS** — iOS containing app
- **LocalWriteKeyboard** — iOS Custom Keyboard extension

## Generate

Install XcodeGen, then run from the repository root:

```bash
xcodegen generate
open LocalWrite.xcodeproj
```

XcodeGen's project specification supports local Swift Package dependencies, application targets, app-extension targets, Info.plists, entitlements, and target dependencies. citeturn1search0turn1search2

## Signing

The bundle identifiers in `project.yml` are placeholders:

- `com.devgofer.LocalWrite`
- `com.devgofer.LocalWrite.iOS`
- `com.devgofer.LocalWrite.iOS.Keyboard`

Choose your Apple Developer Team and adjust signing settings in Xcode before installing on a physical device.

## Important validation

The repository can define the target structure, but final signing and device validation still need to happen on a Mac with the appropriate Xcode version and Apple Developer configuration.

Validate separately:

1. macOS microphone permission
2. macOS Speech Recognition permission
3. macOS Accessibility permission
4. Foundation Model availability
5. global shortcut behavior
6. pasteboard insertion into multiple host apps
7. iOS keyboard installation and keyboard switching
8. iOS keyboard memory behavior
9. iOS app voice capture experiments

The iOS keyboard must not be treated as a microphone recorder: Apple's custom keyboard sandbox does not grant third-party keyboards microphone access. citeturn2search0turn2search1
