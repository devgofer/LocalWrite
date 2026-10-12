import AppKit
import SwiftUI
import LocalWriteCore

/// What the capsule shows; one hosting view observes it for the panel's lifetime.
@MainActor
final class CapsuleModel: ObservableObject {
    static let barCount = 16
    @Published var state: WriteState = .idle
    @Published private(set) var levels = Array(repeating: CGFloat(0), count: barCount)

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(CGFloat(level))
    }

    func reset() { levels = Array(repeating: 0, count: Self.barCount) }
}

final class CapsulePanel: NSPanel {
    private var capsuleVisible = false
    private let model = CapsuleModel()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 44),
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
        contentView = NSHostingView(rootView: CapsuleView(model: model))
    }

    func update(state: WriteState) {
        if state == .listening, model.state != .listening { model.reset() }
        model.state = state
    }

    func push(level: Float) {
        guard model.state == .listening else { return }
        model.push(level)
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        setFrameOrigin(NSPoint(
            x: screen.visibleFrame.midX - frame.width / 2,
            y: screen.visibleFrame.minY + 76
        ))
        if !capsuleVisible {
            capsuleVisible = true
            alphaValue = 0
            orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            animator().alphaValue = 1
        }
    }

    func hide() {
        // Avoid an old animation completion hiding a new recording session.
        capsuleVisible = false
        alphaValue = 0
        orderOut(nil)
    }
}

/// A Typeless-like pill: a live waveform while listening, a short status otherwise.
struct CapsuleView: View {
    @ObservedObject var model: CapsuleModel

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Group {
                switch model.state {
                case .listening:
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                            Capsule()
                                .fill(.white)
                                .frame(width: 3, height: 4 + level * 18)
                        }
                    }
                    .animation(.easeOut(duration: 0.08), value: model.levels)
                    .frame(height: 24)
                    .padding(.horizontal, 18)
                case .refining, .inserting:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(.white)
                        Text("整理中").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                case .error(let message):
                    Text(message)
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                        .lineLimit(1).truncationMode(.tail)
                        .padding(.horizontal, 16)
                case .idle:
                    EmptyView()
                }
            }
            .frame(height: 36)
            .background(Capsule().fill(.black.opacity(0.82)))
            .overlay(Capsule().stroke(.white.opacity(0.14)))
            Spacer(minLength: 0)
        }
        .frame(width: 240, height: 44)
    }
}
