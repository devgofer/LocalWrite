import SwiftUI
import AVFoundation
import Speech
import FoundationModels
import LocalWriteCore

@main
struct LocalWriteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

@MainActor
final class VoicePrototypeController: ObservableObject {
    enum State: Equatable {
        case idle
        case listening
        case refining
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var refinedText = ""
    @Published private(set) var speechAuthorized = false
    @Published private(set) var microphoneAuthorized = false

    let modelAvailable: Bool

    private let speech = SpeechRecognizer(locale: Locale.current)
    private let engine: FoundationModelsEngine?

    init() {
        if #available(iOS 26.0, *) {
            modelAvailable = FoundationModelsEngine.isAvailable
            engine = FoundationModelsEngine()
        } else {
            modelAvailable = false
            engine = nil
        }

        speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        microphoneAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func toggleListening() {
        if case .listening = state {
            speech.cancel()
            state = .idle
            return
        }

        startListening()
    }

    func requestPermissions() {
        Task {
            let speechStatus = await SpeechRecognizer.requestAuthorization()

            let microphoneGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }

            speechAuthorized = speechStatus == .authorized
            microphoneAuthorized = microphoneGranted

            if !speechAuthorized || !microphoneAuthorized {
                state = .error("Speech and microphone permissions are required.")
            }
        }
    }

    private func startListening() {
        guard modelAvailable else {
            state = .error("Foundation Model unavailable.")
            return
        }

        guard speechAuthorized, microphoneAuthorized else {
            requestPermissions()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)

            transcript = ""
            refinedText = ""
            state = .listening

            try speech.start(
                onPartialResult: { [weak self] text in
                    Task { @MainActor in
                        self?.transcript = text
                    }
                },
                onFinished: { [weak self] finalText in
                    Task { @MainActor in
                        self?.beginRefinement(with: finalText)
                    }
                }
            )
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func beginRefinement(with finalText: String) {
        let rawText = finalText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawText.isEmpty else {
            state = .idle
            return
        }

        transcript = rawText
        state = .refining

        Task {
            guard let engine else {
                state = .error("Foundation Model unavailable.")
                return
            }

            do {
                let result = try await engine.refine(rawText)
                refinedText = result.refined
                state = .idle
            } catch {
                state = .error(error.localizedDescription)
            }

            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

struct ContentView: View {
    @StateObject private var controller = VoicePrototypeController()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "waveform")
                        .font(.system(size: 44, weight: .medium))

                    Text("LocalWrite")
                        .font(.largeTitle.bold())

                    Text("Your words. Written locally.")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(controller.modelAvailable ? .green : .orange)
                            .frame(width: 8, height: 8)

                        Text(controller.modelAvailable ? "On-device model ready" : "On-device model unavailable")
                            .font(.subheadline)
                    }

                    Button {
                        controller.toggleListening()
                    } label: {
                        Label(
                            controller.state == .listening ? "Stop Listening" : "Speak",
                            systemImage: controller.state == .listening ? "stop.fill" : "mic.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.state == .refining)

                    permissionSection

                    if !controller.transcript.isEmpty {
                        textSection(title: "Transcript", text: controller.transcript)
                    }

                    if !controller.refinedText.isEmpty {
                        textSection(title: "LocalWrite", text: controller.refinedText)
                    }

                    if case let .error(message) = controller.state {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("The iOS keyboard is a lightweight shell. Voice capture happens in this app because third-party custom keyboards cannot access the microphone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("LocalWrite")
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            permissionRow(
                title: "Microphone",
                granted: controller.microphoneAuthorized
            )

            permissionRow(
                title: "Speech Recognition",
                granted: controller.speechAuthorized
            )

            if !controller.speechAuthorized || !controller.microphoneAuthorized {
                Button("Allow Permissions") {
                    controller.requestPermissions()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func permissionRow(title: String, granted: Bool) -> some View {
        Label(
            title,
            systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle"
        )
        .foregroundStyle(granted ? .primary : .secondary)
    }

    private func textSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
