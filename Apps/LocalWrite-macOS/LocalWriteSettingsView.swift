import SwiftUI
struct LocalWriteSettingsView: View {
    @ObservedObject var controller: LocalWriteController

    @AppStorage(LocalWriteSettings.shortcutModifierKey)
    private var shortcutModifier = LocalWriteSettings.defaultShortcutModifier

    var body: some View {
        Form {
            Section("Shortcut") {
                Picker("Modifier", selection: $shortcutModifier) {
                    Text("Option").tag("option")
                    Text("Control").tag("control")
                    Text("Command").tag("command")
                }
                .onChange(of: shortcutModifier) { _, _ in
                    controller.restartShortcut()
                }

                HStack {
                    Text("Key")
                    Spacer()
                    Text("Space")
                        .foregroundStyle(.secondary)
                }

                Text("Current shortcut: (modifierLabel) + Space")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Accessibility",
                    isReady: controller.accessibilityGranted
                )

                if !controller.accessibilityGranted {
                    HStack {
                        Button("Request Access") {
                            controller.requestAccessibility()
                        }
                        Button("Open Settings") {
                            controller.openAccessibilitySettings()
                        }
                    }
                }

                PermissionRow(
                    title: "Speech Recognition",
                    isReady: controller.speechAuthorized
                )

                if !controller.speechAuthorized {
                    Button("Request Speech Access") {
                        controller.requestSpeechAuthorization()
                    }
                }

                PermissionRow(
                    title: "Foundation Model",
                    isReady: controller.modelAvailable
                )
            }

            Section("About") {
                Text("LocalWrite refines speech on-device when Apple’s Foundation Model is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 420)
    }

    private var modifierLabel: String {
        switch shortcutModifier {
        case "control": return "Control"
        case "command": return "Command"
        default: return "Option"
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let isReady: Bool

    var body: some View {
        HStack {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
            Text(title)
            Spacer()
            Text(isReady ? "Ready" : "Required")
                .foregroundStyle(.secondary)
        }
    }
}
