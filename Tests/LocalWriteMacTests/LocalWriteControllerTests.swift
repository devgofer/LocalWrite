import XCTest
import Speech
import LocalWriteCore
@testable import LocalWriteMac

@MainActor
private final class FakeSpeech: SpeechCapturing {
    var starts = 0
    var finishes = 0
    var onLevel: (@MainActor (Float) -> Void)?
    var partial: (@MainActor (String) -> Void)?
    var finished: (@MainActor (String) -> Void)?
    var error: (@MainActor (String) -> Void)?
    func start(onPartialResult: @escaping @MainActor (String) -> Void,
               onFinished: @escaping @MainActor (String) -> Void,
               onError: @escaping @MainActor (String) -> Void) throws {
        starts += 1
        partial = onPartialResult
        finished = onFinished
        error = onError
    }
    func finish() { finishes += 1 }
    func cancel() {} // Intentionally retains callbacks to simulate late delivery.
}

private struct FakeEngine: LocalWriteEngine {
    func refine(_ text: String) async throws -> RefinementResult {
        RefinementResult(original: text, refined: "Refined result.")
    }
}

@MainActor
private final class PermissionValue { var granted = false }

final class LocalWriteControllerTests: XCTestCase {
    @MainActor
    func testMissingAccessibilityDoesNotOpenSettingsOrRepromptOnStart() {
        var prompts = 0
        var settings = 0
        let controller = LocalWriteController(
            speech: FakeSpeech(), engine: FakeEngine(),
            captureTarget: { nil }, modelAvailability: { true }, accessibilityStatus: { false },
            promptAccessibility: { prompts += 1 }, showAccessibilitySettings: { settings += 1 },
            registerShortcut: false)
        controller.toggleListening()
        controller.toggleListening()
        XCTAssertEqual(prompts, 0)
        XCTAssertEqual(settings, 0)
    }

    @MainActor
    func testAlreadyGrantedPermissionDoesNotPromptAgain() {
        let permission = PermissionValue()
        var prompts = 0
        let controller = LocalWriteController(
            speech: FakeSpeech(), captureTarget: { nil }, modelAvailability: { true },
            accessibilityStatus: { permission.granted }, promptAccessibility: { prompts += 1 },
            showAccessibilitySettings: {}, registerShortcut: false)
        permission.granted = true
        controller.requestAccessibility()
        XCTAssertTrue(controller.accessibilityGranted)
        XCTAssertEqual(prompts, 0)
    }

    @MainActor
    func testStopWhilePermissionPendingDoesNotStartMicrophone() async {
        let speech = FakeSpeech()
        var permission: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>?
        let requested = expectation(description: "permission requested")
        let controller = LocalWriteController(
            speech: speech, engine: FakeEngine(),
            authorizeSpeech: { await withCheckedContinuation { permission = $0; requested.fulfill() } },
            authorizeMicrophone: { XCTFail("cancelled operation requested microphone"); return true },
            captureTarget: { nil }, modelAvailability: { true }, accessibilityStatus: { true }, registerShortcut: false)
        controller.toggleListening()
        await fulfillment(of: [requested], timeout: 2)
        controller.toggleListening()
        permission?.resume(returning: .authorized)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(speech.starts, 0)
        XCTAssertEqual(controller.state, .idle)
    }

    @MainActor
    func testSecondPressFinishesInsteadOfDiscarding() async {
        let speech = FakeSpeech()
        let controller = makeController(speech)
        controller.toggleListening()
        for _ in 0..<20 where speech.starts == 0 { await Task.yield() }
        speech.partial?("Keep talking")
        controller.toggleListening()
        XCTAssertEqual(speech.finishes, 1)
        XCTAssertEqual(controller.state, .refining)
        speech.finished?("Keep talking")
        for _ in 0..<50 where controller.state == .refining { await Task.yield() }
        XCTAssertEqual(controller.savedText, "Refined result.")
    }

    @MainActor
    func testLateResultAfterCancelDoesNotRefineOrOverwriteText() async {
        let speech = FakeSpeech()
        let controller = makeController(speech)
        controller.toggleListening()
        for _ in 0..<20 where speech.starts == 0 { await Task.yield() }
        XCTAssertEqual(speech.starts, 1)
        speech.partial?("Keep this")
        controller.cancelListening()
        speech.finished?("stale result")
        speech.error?("late error")
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.savedText, "Keep this")
    }

    @MainActor
    func testFailedInsertionRetainsRefinedResult() async {
        let speech = FakeSpeech()
        let controller = makeController(speech)
        controller.toggleListening()
        for _ in 0..<20 where speech.starts == 0 { await Task.yield() }
        speech.finished?("raw result")
        for _ in 0..<50 where controller.state == .refining { await Task.yield() }
        XCTAssertEqual(controller.savedText, "Refined result.")
        guard case .error = controller.state else { return XCTFail("missing target should report insertion error") }
    }

    @MainActor
    private func makeController(_ speech: FakeSpeech) -> LocalWriteController {
        LocalWriteController(speech: speech, engine: FakeEngine(), authorizeSpeech: { .authorized },
            authorizeMicrophone: { true }, captureTarget: { nil }, modelAvailability: { true }, accessibilityStatus: { true }, registerShortcut: false)
    }
}
