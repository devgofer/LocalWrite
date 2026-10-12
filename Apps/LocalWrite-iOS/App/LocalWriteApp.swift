import SwiftUI
import AVFoundation

@main
struct LocalWriteApp: App {
    var body: some Scene { WindowGroup { KeyboardHelperView() } }
}

struct KeyboardHelperView: View {
    @StateObject private var helper = KeyboardVoiceHelper()
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: helper.recording ? "mic.fill" : "keyboard")
                .font(.system(size: 48)).foregroundStyle(helper.recording ? .red : .primary)
            Text("LocalWrite 語音鍵盤").font(.title2.bold())
            Text(helper.message).multilineTextAlignment(.center)
            if helper.enabled || helper.preparing {
                Button("取消錄音") { helper.stop() }.buttonStyle(.bordered)
            } else {
                Text("首次使用：設定 → 一般 → 鍵盤 → 鍵盤 → 加入 LocalWrite，並允許完整取用。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("在鍵盤點麥克風開始說話，再點一次潤稿並填入。")
                    .font(.footnote)
            }
        }
        .padding(28)
        .onOpenURL { helper.open($0) }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            helper.stop(message: "錄音被中斷，請回到鍵盤重新點麥克風。")
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)) { _ in
            helper.stop(message: "音訊服務已重啟，請回到鍵盤重新點麥克風。")
        }
    }
}
