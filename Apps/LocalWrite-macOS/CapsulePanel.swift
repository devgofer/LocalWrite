import AppKit
import SwiftUI
import LocalWriteCore

final class CapsulePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 58),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        ignoresMouseEvents = true
    }

    func update(state: WriteState, transcript: String) {
        contentView = NSHostingView(
            rootView: CapsuleView(state: state, transcript: transcript)
        )
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.midX - frame.width / 2
        let y = screen.visibleFrame.minY + 76
        setFrameOrigin(NSPoint(x: x, y: y))
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}

struct CapsuleView: View {
    let state: WriteState
    let transcript: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state == .listening ? .red : .primary)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            if state == .listening {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, isActive: true)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12)))
    }

    private var label: String {
        switch state {
        case .listening:
            return transcript.isEmpty ? "Listening" : transcript
        case .refining:
            return "Refining"
        case .inserting:
            return "Writing"
        case .error(let message):
            return message
        case .idle:
            return ""
        }
    }
}
