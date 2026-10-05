import SwiftUI
import FoundationModels

@main
struct LocalWriteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    private var modelAvailable: Bool {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "waveform")
                    .font(.system(size: 44, weight: .medium))

                Text("LocalWrite")
                    .font(.largeTitle.bold())

                Text("Your words. Written locally.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(modelAvailable ? .green : .orange)
                        .frame(width: 8, height: 8)

                    Text(modelAvailable ? "On-device model ready" : "On-device model unavailable")
                        .font(.subheadline)
                }

                Text("Enable the LocalWrite keyboard in Settings → General → Keyboard → Keyboards.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("LocalWrite")
        }
    }
}
