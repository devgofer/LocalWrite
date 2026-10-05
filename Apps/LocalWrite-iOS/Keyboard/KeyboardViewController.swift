import UIKit
import LocalWriteCore
import FoundationModels

@MainActor
final class KeyboardViewController: UIInputViewController {
    private let recordButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let speech = SpeechRecognizer()
    private var transcript = ""
    private var isRecording = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        statusLabel.text = "LocalWrite"
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel

        recordButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        recordButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)

        let globe = UIButton(type: .system)
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.addTarget(self, action: #selector(nextKeyboard), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [globe, statusLabel, recordButton])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }

    @objc private func nextKeyboard() {
        advanceToNextInputMode()
    }

    @objc private func toggleRecording() {
        isRecording ? cancelRecording() : startRecording()
    }

    private func startRecording() {
        Task {
            let status = await SpeechRecognizer.requestAuthorization()
            guard status == .authorized else {
                statusLabel.text = "Speech permission needed"
                return
            }

            transcript = ""
            isRecording = true
            recordButton.tintColor = .systemRed
            statusLabel.text = "Listening"

            do {
                try speech.start(
                    onPartialResult: { [weak self] text in
                        Task { @MainActor in
                            self?.transcript = text
                            self?.statusLabel.text = "Listening"
                        }
                    },
                    onFinished: { [weak self] finalText in
                        Task { @MainActor in
                            self?.isRecording = false
                            self?.recordButton.tintColor = .tintColor
                            self?.refineAndInsert(finalText)
                        }
                    }
                )
            } catch {
                isRecording = false
                recordButton.tintColor = .tintColor
                statusLabel.text = "Unavailable"
            }
        }
    }

    private func cancelRecording() {
        speech.cancel()
        isRecording = false
        recordButton.tintColor = .tintColor
        transcript = ""
        statusLabel.text = "LocalWrite"
    }

    private func refineAndInsert(_ finalText: String) {
        let text = (finalText.isEmpty ? transcript : finalText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            statusLabel.text = "LocalWrite"
            return
        }

        statusLabel.text = "Refining"

        Task {
            do {
                guard #available(iOS 26.0, *), FoundationModelsEngine.isAvailable else {
                    throw KeyboardError.modelUnavailable
                }

                let engine = FoundationModelsEngine()
                let result = try await engine.refine(text)
                textDocumentProxy.insertText(result.refined)

                transcript = ""
                statusLabel.text = "LocalWrite"
            } catch {
                statusLabel.text = "Try again"
            }
        }
    }

    override var needsInputModeSwitchKey: Bool {
        true
    }
}

private enum KeyboardError: Error {
    case modelUnavailable
}
