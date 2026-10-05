import AppKit
import SwiftUI
import LocalWriteCore

final class CapsulePanel: NSPanel {
    private var isVisible = false

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
        alphaValue = 0
    }

    func update(state: WriteState, transcript: String) {
        contentView = NSHostingView(rootView: CapsuleView(state: state, transcript: transcript))
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        setFrameOrigin(NSPoint(
            x: screen.visibleFrame.midX - frame.width / 2,
            y: screen.visibleFrame.minY + 76
        ))
        if !isVisible {
            isVisible = true
            alphaValue = 0
            orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else { orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.isVisible = false
            self?.orderOut(nil)
        })
    }
}

struct CapsuleView: View {
    let state: WriteState
    let transcript: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
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

    private var indicatorColor: Color {
        switch state {
        case .listening: return .red
        case .error: return .orange
        default: return .primary
        }
    }

    private var label: String {
        switch state {
        case .listening: return transcript.isEmpty ? "Listening" : transcript
        case .refining: return "Refining"
        case .inserting: return "Writing"
        case .error(let message): return message
        case .idle: return ""
        }
    }
}
