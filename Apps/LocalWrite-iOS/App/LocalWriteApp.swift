import SwiftUI
import AVFoundation
import LocalWriteKeyboardBridge

@main
struct LocalWriteApp: App {
    var body: some Scene { WindowGroup { HomeView() } }
}

struct HomeView: View {
    @StateObject private var host = VoiceSessionHost()
    @State private var language = SharedSettings.shared().targetLanguage

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: host.warm ? "mic.fill" : "mic")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(host.warm ? Color.accentColor : .secondary)
                            .frame(width: 84, height: 84)
                            .background(Circle().fill(Color(.secondarySystemFill)))
                        Text(host.message).multilineTextAlignment(.center)
                        if host.warm {
                            Button("停止待命", role: .destructive) { host.endSession() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("開始待命") { Task { await host.startSession() } }
                                .buttonStyle(.borderedProminent).disabled(host.starting)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                Section("設定") {
                    Picker("翻譯成", selection: $language) {
                        ForEach(TranslationLanguage.all) { Text($0.displayName).tag($0.code) }
                    }
                }
                Section("第一次使用") {
                    Text("設定 → 一般 → 鍵盤 → 鍵盤 → 新增鍵盤 → LocalWrite，然後開啟「允許完整取用」。")
                    Text("開啟後 LocalWrite 會在背景待命，麥克風只在你說話時開啟。")
                    Text("在鍵盤點一下開始說話，再點一下就會整理或翻譯後填入。")
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("LocalWrite")
        }
        .onChange(of: language) { _, value in SharedSettings.shared().targetLanguage = value }
        .onOpenURL { host.open($0) }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            host.endSession(message: "麥克風被其他 App 中斷。下次點鍵盤麥克風會再開啟一次。")
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)) { _ in
            host.endSession(message: "音訊服務已重啟。下次點鍵盤麥克風會再開啟一次。")
        }
    }
}
