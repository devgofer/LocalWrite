import UIKit
import SwiftUI
import LocalWriteKeyboardBridge

@MainActor
final class KeyboardViewController: UIInputViewController {
    private let microphone = UIButton(type: .system)
    private let status = UILabel()
    private let micSlot = UIView()
    private var launchLink: UIHostingController<KeyboardLaunchKey>?
    private var launching = false
    private var documentReady = false
    private var launchTime: Date?
    private var exchange: KeyboardExchange?
    private var delivery = KeyboardDelivery()
    private var poll: Task<Void, Never>?
    private var waiting = false
    private var finishing = false
    private var before: String?
    private var after: String?
    private var commandTime: Date?
    private var notice: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        let delete = key("delete.left", label: "刪除", action: #selector(deleteBackward))
        let enter = key("return", label: "換行", action: #selector(insertNewline))
        microphone.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        microphone.accessibilityLabel = "開始語音輸入"
        microphone.accessibilityIdentifier = "keyboard.microphone"
        microphone.addTarget(self, action: #selector(toggleMicrophone), for: .touchUpInside)
        microphone.tintColor = .systemBlue
        microphone.backgroundColor = .tertiarySystemBackground
        microphone.layer.cornerRadius = 24
        // A long press provides keyboard switching without an extra globe key.
        enter.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(switchKeyboard(_:))))
        enter.accessibilityHint = "長按切換鍵盤"
        let link = UIHostingController(rootView: KeyboardLaunchKey { [weak self] in self?.prepareLaunch() })
        launchLink = link
        addChild(link); micSlot.addSubview(link.view); link.didMove(toParent: self)
        micSlot.addSubview(microphone)
        for child in [link.view!, microphone] {
            child.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: micSlot.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: micSlot.trailingAnchor),
                child.topAnchor.constraint(equalTo: micSlot.topAnchor),
                child.bottomAnchor.constraint(equalTo: micSlot.bottomAnchor)
            ])
        }
        link.view.backgroundColor = .clear
        let row = UIStackView(arrangedSubviews: [delete, micSlot, enter])
        row.axis = .horizontal; row.spacing = 20; row.distribution = .fillEqually
        status.font = .preferredFont(forTextStyle: .caption2)
        status.textAlignment = .center; status.numberOfLines = 2; status.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [row, status])
        stack.axis = .vertical; stack.spacing = 8; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            row.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        exchange = hasFullAccess ? KeyboardExchange.shared() : nil
        launching = false
        documentReady = true
        poll?.cancel()
        poll = Task { @MainActor [weak self] in
            // UIKit connects the host's document proxy after its appearance callback.
            // Reading documentIdentifier from viewWillAppear can raise an ObjC exception.
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard let self, self.documentReady else { return }
            if self.delivery.requestID == nil, let pending = self.exchange?.pendingRequest(),
               self.delivery.resume(pending, documentID: self.textDocumentProxy.documentIdentifier) {
                self.before = pending.before; self.after = pending.after
                self.launchTime = pending.ticket.createdAt; self.waiting = true
            }
            while !Task.isCancelled && self.documentReady {
                self.update()
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        documentReady = false
        // Keep the request while our own launch opens LocalWrite. On returning,
        // the document ID and surrounding text must still match before insertion.
        if !launching { cancelPending() }
        poll?.cancel(); poll = nil
        super.viewWillDisappear(animated)
    }

    private func key(_ icon: String, label: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.accessibilityLabel = label
        button.backgroundColor = .tertiarySystemBackground
        button.tintColor = .label; button.layer.cornerRadius = 14
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func deleteBackward() { cancelPending(); textDocumentProxy.deleteBackward() }
    @objc private func insertNewline() { cancelPending(); textDocumentProxy.insertText("\n") }
    @objc private func switchKeyboard(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { cancelPending(); advanceToNextInputMode() }
    }

    private func prepareLaunch() -> URL? {
        guard documentReady, hasFullAccess, delivery.requestID == nil,
              let exchange = KeyboardExchange.shared() else {
            notice = "請在鍵盤設定允許 LocalWrite 完整取用。"; status.text = notice
            return nil
        }
        self.exchange = exchange
        let session = UUID()
        let request = delivery.begin(sessionID: session, documentID: textDocumentProxy.documentIdentifier)
        let ticket = KeyboardLaunchRequest(sessionID: session, requestID: request)
        before = textDocumentProxy.documentContextBeforeInput
        after = textDocumentProxy.documentContextAfterInput
        do {
            try exchange.write(KeyboardPendingRequest(ticket: ticket,
                documentID: textDocumentProxy.documentIdentifier, before: before, after: after))
            try exchange.write(ticket)
            launching = true; launchTime = .now; waiting = true; notice = nil
            update()
            return ticket.url
        } catch {
            cancelPending(); status.text = "無法啟動錄音，請再試一次。"
            return nil
        }
    }

    @objc private func toggleMicrophone() {
        guard !waiting, !finishing,
              let exchange, let snapshot = exchange.snapshot(), snapshot.isLive(),
              let request = delivery.requestID,
              snapshot.requestID == request, snapshot.phase == .recording else { return }
        do {
            finishing = true
            try exchange.write(KeyboardCommand(sessionID: snapshot.sessionID, requestID: request, kind: .finish))
            update()
        } catch { cancelPending(); status.text = "無法結束錄音，請重試。" }
    }

    private func update() {
        guard documentReady else { return }
        let pending = delivery.requestID != nil
        microphone.isHidden = !pending
        launchLink?.view.isHidden = pending
        microphone.isEnabled = !waiting && !finishing
        guard hasFullAccess else { status.text = "請在設定允許鍵盤完整取用。"; return }
        guard pending else { status.text = notice ?? ""; return }
        guard delivery.belongsTo(documentID: textDocumentProxy.documentIdentifier) else {
            cancelPending(); notice = "輸入欄位已變更，請重新點麥克風。"; update(); return
        }
        guard let snapshot = exchange?.snapshot(), snapshot.sessionID == delivery.sessionID,
              snapshot.isLive() else {
            if waiting, let launchTime, Date.now.timeIntervalSince(launchTime) < 90 {
                status.text = "正在啟動錄音⋯"; return
            }
            cancelPending(); notice = "錄音已結束或未能啟動，請重新點麥克風。"; update(); return
        }
        if snapshot.requestID == delivery.requestID, delivery.requestID != nil {
            waiting = snapshot.phase == .starting
            switch snapshot.phase {
            case .starting:
                status.text = "正在準備麥克風⋯"
            case .recording:
                status.text = finishing ? "正在結束收音⋯" : "聆聽中，再點一次完成"
                microphone.setImage(UIImage(systemName: "stop.fill"), for: .normal)
                microphone.tintColor = .systemRed
                microphone.accessibilityLabel = "結束語音並填入"
            case .refining: finishing = true; status.text = "潤稿中⋯"
            case .completed:
                guard before == textDocumentProxy.documentContextBeforeInput,
                      after == textDocumentProxy.documentContextAfterInput else {
                    cancelPending(); notice = "輸入位置已變更，已取消填入。"; status.text = notice; return
                }
                if let text = delivery.consume(snapshot, documentID: textDocumentProxy.documentIdentifier) {
                    // Claim before insertion to prevent replay after controller recreation.
                    do { try exchange?.clearPendingRequest() }
                    catch { notice = "無法確認結果已取用，請重試。"; cancelPending(); return }
                    textDocumentProxy.insertText(text)
                    if let request = snapshot.requestID {
                        try? exchange?.write(KeyboardCommand(sessionID: snapshot.sessionID, requestID: request, kind: .cancel))
                    }
                    finishing = false; commandTime = nil; launchTime = nil
                    microphone.isHidden = true; launchLink?.view.isHidden = false
                }
            case .failed:
                cancelPending(); notice = snapshot.message; status.text = notice; return
            default: break
            }
        }
        if delivery.requestID == nil {
            status.text = notice ?? ""
            microphone.setImage(UIImage(systemName: "mic.fill"), for: .normal)
            microphone.tintColor = .systemBlue
            microphone.accessibilityLabel = "開始語音輸入"
        }
        microphone.isEnabled = !waiting && !finishing
    }

    private func cancelPending() {
        if let request = delivery.requestID, let session = delivery.sessionID {
            try? exchange?.write(KeyboardCommand(sessionID: session, requestID: request, kind: .cancel))
        }
        if exchange?.pendingRequest()?.ticket.requestID == delivery.requestID {
            try? exchange?.clearPendingRequest()
            try? exchange?.clearLaunchRequest()
        }
        delivery.cancel(); waiting = false; finishing = false; commandTime = nil
        launching = false; launchTime = nil
        microphone.isHidden = true; launchLink?.view.isHidden = false
        microphone.isEnabled = true
    }
}

/// SwiftUI Link supplies the public URL-opening path available to the keyboard.
/// The ticket is written synchronously when tapped, before the system opens the app.
private struct KeyboardLaunchKey: View {
    let prepare: @MainActor () -> URL?
    var body: some View {
        Link(destination: URL(string: "localwrite://dictate/start")!) {
            Image(systemName: "mic")
                .font(.title2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
        }
        .accessibilityLabel("開始語音輸入")
        .accessibilityIdentifier("keyboard.microphone")
        .environment(\.openURL, OpenURLAction { _ in
            guard let url = prepare() else { return .handled }
            return .systemAction(url)
        })
    }
}
