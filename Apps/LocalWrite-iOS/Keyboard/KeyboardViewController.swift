import UIKit
import SwiftUI
import LocalWriteKeyboardBridge

@MainActor
final class KeyboardViewController: UIInputViewController {
    private lazy var model = KeyboardModel(controller: self)
    private var stateSignal: DarwinSignal?
    private var refresh: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: KeyboardView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host); view.addSubview(host.view); host.didMove(toParent: self)
        let height = view.heightAnchor.constraint(equalToConstant: 236)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        model.showsGlobe = needsInputModeSwitchKey
        stateSignal = DarwinSignal(observing: DarwinSignal.state) { [weak self] in
            Task { @MainActor in self?.model.refresh() }
        }
        refresh?.cancel()
        refresh = Task { @MainActor [weak self] in
            // UIKit connects the document proxy after appearance; reading it from
            // viewWillAppear can raise an Objective-C exception.
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            self?.model.attach()
            // Darwin signals drive updates; this slow tick only notices expiry.
            while !Task.isCancelled {
                self?.model.refresh()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        refresh?.cancel(); refresh = nil
        stateSignal = nil
        model.detach()
        super.viewWillDisappear(animated)
    }
}

@MainActor
final class KeyboardModel: ObservableObject {
    enum Mic { case unavailable, cold, ready, recording, processing }

    @Published private(set) var mic: Mic = .cold
    static let barCount = 24
    /// Recent microphone levels, oldest first, for the waveform.
    @Published private(set) var levels = Array(repeating: CGFloat(0), count: barCount)
    @Published private(set) var notice = ""
    @Published var mode: DictationMode { didSet { settings.mode = mode } }
    @Published var showsGlobe = true

    private weak var controller: KeyboardViewController?
    private let settings = SharedSettings.shared()
    private var exchange: KeyboardExchange?
    private var delivery = KeyboardDelivery()
    private var sentAt: Date?
    private var attached = false

    init(controller: KeyboardViewController) {
        self.controller = controller
        mode = settings.mode
    }

    var languageName: String { TranslationLanguage.named(settings.targetLanguage).displayName }
    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }

    func attach() {
        attached = true
        exchange = controller?.hasFullAccess == true ? KeyboardExchange.shared() : nil
        mode = settings.mode
        refresh()
    }

    func detach() {
        if delivery.requestID != nil { send(.cancel) }
        delivery.cancel(); sentAt = nil
        attached = false
    }

    func refresh() {
        guard attached, let controller, let proxy else { return }
        guard controller.hasFullAccess, let exchange else {
            mic = .unavailable; notice = "請到 設定 → 一般 → 鍵盤 → LocalWrite 開啟「允許完整取用」。"; return
        }
        guard let state = exchange.state(), state.isWarm() else {
            if delivery.requestID != nil { delivery.cancel(); notice = "麥克風已關閉，請再點一次麥克風。" }
            mic = .cold; resetLevels(); return
        }
        guard let request = delivery.requestID else { mic = .ready; resetLevels(); return }
        guard delivery.belongsTo(documentID: proxy.documentIdentifier) else {
            send(.cancel); delivery.cancel(); notice = "輸入框已變更，已取消。"; mic = .ready; return
        }
        guard state.requestID == request else {
            // The app has not picked up the start command yet.
            if let sentAt, Date.now.timeIntervalSince(sentAt) > 4 {
                delivery.cancel(); notice = "LocalWrite 沒有回應，請再試一次。"; mic = .ready
            }
            return
        }
        switch state.phase {
        case .recording:
            mic = .recording
            levels.removeFirst(); levels.append(CGFloat(state.level))
        case .processing:
            mic = .processing
        case .done:
            if let text = delivery.consume(state, documentID: proxy.documentIdentifier) {
                proxy.insertText(text)
                notice = state.usedRawFallback ? state.message : ""
            }
            mic = .ready; resetLevels(); sentAt = nil
        case .failed:
            delivery.cancel(); notice = state.message; mic = .ready; resetLevels()
        case .idle, .ended:
            delivery.cancel(); mic = .ready; resetLevels()
        }
    }

    func tapMic() {
        switch mic {
        case .ready:
            guard let proxy else { return }
            notice = ""; resetLevels()
            _ = delivery.begin(documentID: proxy.documentIdentifier)
            sentAt = .now
            send(.start)
            mic = .recording
        case .recording:
            send(.finish)
            mic = .processing
        case .processing:
            send(.cancel); delivery.cancel(); mic = .ready; resetLevels()
        case .cold, .unavailable:
            break
        }
    }

    /// Called synchronously when the cold mic Link is tapped, before iOS opens the app.
    func prepareLaunch() -> URL? {
        guard controller?.hasFullAccess == true, let exchange = exchange ?? KeyboardExchange.shared() else {
            notice = "請到 設定 → 一般 → 鍵盤 → LocalWrite 開啟「允許完整取用」。"; return nil
        }
        self.exchange = exchange
        let ticket = KeyboardLaunchRequest(hostBundleID: controller.map(HostApp.bundleID(for:)) ?? nil)
        exchange.diagnose("keyboard host=\(ticket.hostBundleID ?? "unknown") \(HostApp.lastProbe)")
        do { try exchange.write(ticket) } catch { notice = "無法開啟 LocalWrite，請再試一次。"; return nil }
        notice = "開啟麥克風後，滑回這裡就能說話。"
        return ticket.url
    }

    private func resetLevels() { levels = Array(repeating: 0, count: Self.barCount) }

    /// iOS does not tell keyboards which app they are in, so the field's traits stand in:
    /// a Send return key or a social keyboard means chat.
    private var fieldStyle: String {
        guard let proxy else { return "general" }
        if proxy.returnKeyType == .send || proxy.keyboardType == .twitter { return "chat" }
        return "general"
    }

    func insertSpace() { proxy?.insertText(" ") }
    func insertReturn() { proxy?.insertText("\n") }
    func deleteBackward() { proxy?.deleteBackward() }
    func nextKeyboard() { controller?.advanceToNextInputMode() }

    private func send(_ kind: KeyboardCommand.Kind) {
        guard let exchange, let request = delivery.requestID else { return }
        let command = KeyboardCommand(requestID: request, kind: kind, mode: mode,
                                     targetLanguage: settings.targetLanguage, style: fieldStyle)
        do { try exchange.write(command) } catch {
            delivery.cancel(); notice = "無法與 LocalWrite 溝通，請再試一次。"; mic = .ready; return
        }
        DarwinSignal.post(DarwinSignal.command)
    }
}

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 10) {
            Picker("模式", selection: $model.mode) {
                Text("整理").tag(DictationMode.clean)
                Text("翻譯成\(model.languageName)").tag(DictationMode.translate)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .disabled(model.mic == .recording || model.mic == .processing)

            Group {
                if model.mic == .recording {
                    Waveform(levels: model.levels)
                } else {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34)

            MicButton(model: model)

            HStack(spacing: 6) {
                if model.showsGlobe {
                    KeyButton(systemImage: "globe", label: "下一個鍵盤", width: 44) { model.nextKeyboard() }
                }
                KeyButton(title: "空格", label: "空格") { model.insertSpace() }
                RepeatingDeleteKey { model.deleteBackward() }
                KeyButton(systemImage: "return", label: "換行", width: 64) { model.insertReturn() }
            }
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 6)
    }

    private var status: String {
        switch model.mic {
        case .unavailable: model.notice
        case .cold: model.notice.isEmpty ? "點麥克風開啟 LocalWrite，滑回這裡就能說話" : model.notice
        case .ready: model.notice.isEmpty ? "點麥克風開始說話" : model.notice
        case .recording: ""
        case .processing: model.mode == .clean ? "整理中⋯" : "翻譯中⋯"
        }
    }
}

/// Bars that move with the speaker's voice, newest on the right.
private struct Waveform: View {
    let levels: [CGFloat]
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule().fill(Color.accentColor).frame(width: 3, height: 4 + level * 26)
            }
        }
        .animation(.easeOut(duration: 0.1), value: levels)
        .accessibilityLabel("聆聽中")
    }
}

private struct MicButton: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        switch model.mic {
        case .cold:
            // SwiftUI Link is the URL-opening path still available to keyboards.
            Link(destination: URL(string: "localwrite://session")!) { circle("mic", tint: .accentColor, filled: false) }
                .environment(\.openURL, OpenURLAction { _ in
                    guard let url = model.prepareLaunch() else { return .handled }
                    return .systemAction(url)
                })
                .accessibilityLabel("開啟 LocalWrite 麥克風")
        case .unavailable:
            circle("mic.slash", tint: .secondary, filled: false).accessibilityLabel("需要完整取用")
        case .ready:
            Button(action: model.tapMic) { circle("mic.fill", tint: .accentColor, filled: true) }
                .accessibilityLabel("開始說話")
        case .recording:
            Button(action: model.tapMic) { circle("stop.fill", tint: .red, filled: true) }
                .accessibilityLabel("完成並填入")
        case .processing:
            Button(action: model.tapMic) {
                ZStack { Circle().fill(Color(.tertiarySystemFill)); ProgressView() }.frame(width: 64, height: 64)
            }
            .accessibilityLabel("取消")
        }
    }

    private func circle(_ image: String, tint: Color, filled: Bool) -> some View {
        Image(systemName: image)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(filled ? Color.white : tint)
            .frame(width: 64, height: 64)
            .background(Circle().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(Color(.tertiarySystemFill))))
            .overlay(Circle().stroke(filled ? .clear : tint, lineWidth: 1.5))
    }
}

private struct KeyButton: View {
    var title: String? = nil
    var systemImage: String? = nil
    let label: String
    var width: CGFloat? = nil
    let action: () -> Void

    init(title: String, label: String, action: @escaping () -> Void) {
        self.title = title; self.label = label; self.action = action
    }
    init(systemImage: String, label: String, width: CGFloat, action: @escaping () -> Void) {
        self.systemImage = systemImage; self.label = label; self.width = width; self.action = action
    }

    var body: some View {
        Button(action: action) { KeyFace(title: title, systemImage: systemImage) }
            .buttonStyle(.plain)
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .accessibilityLabel(label)
    }
}

private struct KeyFace: View {
    var title: String?
    var systemImage: String?
    var body: some View {
        Group {
            if let systemImage { Image(systemName: systemImage) } else { Text(title ?? "") }
        }
        .font(.system(size: 17))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground).opacity(0.9)))
        .contentShape(Rectangle())
    }
}

/// Deletes once on touch, then repeats while held.
private struct RepeatingDeleteKey: View {
    let action: () -> Void
    @State private var repeating: Task<Void, Never>?

    var body: some View {
        KeyFace(systemImage: "delete.left")
            .frame(width: 64)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard repeating == nil else { return }
                    action()
                    repeating = Task { @MainActor in
                        do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                        while !Task.isCancelled {
                            action()
                            do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
                        }
                    }
                }
                .onEnded { _ in repeating?.cancel(); repeating = nil })
            .accessibilityLabel("刪除")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}
