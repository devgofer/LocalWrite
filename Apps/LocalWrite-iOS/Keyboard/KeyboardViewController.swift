import UIKit
import LocalWriteCore

final class KeyboardViewController: UIInputViewController {
    private let recordButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        recordButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        recordButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)

        view.addSubview(recordButton)
        recordButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 52),
            recordButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func toggleRecording() {
        // Recording/refinement coordinator is shared with LocalWriteCore.
        // The keyboard UI stays intentionally tiny.
    }
}
