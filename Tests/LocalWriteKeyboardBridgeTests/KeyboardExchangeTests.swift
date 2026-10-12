import XCTest
@testable import LocalWriteKeyboardBridge

final class KeyboardExchangeTests: XCTestCase {
    func testResultInsertedOnlyOnceIntoOriginalDocument() {
        var delivery = KeyboardDelivery()
        let document = UUID()
        let request = delivery.begin(documentID: document)
        let result = VoiceState(sessionID: UUID(), phase: .done, requestID: request, text: "Hello.",
                                expiresAt: .now.addingTimeInterval(60))
        XCTAssertNil(delivery.consume(result, documentID: UUID()))
        XCTAssertEqual(delivery.consume(result, documentID: document), "Hello.")
        XCTAssertNil(delivery.consume(result, documentID: document))
    }

    func testUnrelatedOrUnfinishedOrCanceledResultsAreIgnored() {
        var delivery = KeyboardDelivery()
        let document = UUID()
        let request = delivery.begin(documentID: document)
        var state = VoiceState(sessionID: UUID(), phase: .done, requestID: UUID(), text: "old",
                               expiresAt: .now.addingTimeInterval(60))
        XCTAssertNil(delivery.consume(state, documentID: document))
        state.requestID = request; state.phase = .processing
        XCTAssertNil(delivery.consume(state, documentID: document))
        state.phase = .done; delivery.cancel()
        XCTAssertNil(delivery.consume(state, documentID: document))
    }

    func testWarmSessionNeedsHeartbeatAndExpiry() {
        let now = Date()
        var state = VoiceState(sessionID: UUID(), phase: .idle, expiresAt: now.addingTimeInterval(600), updatedAt: now)
        XCTAssertTrue(state.isWarm(at: now.addingTimeInterval(3)))
        XCTAssertFalse(state.isWarm(at: now.addingTimeInterval(VoiceState.heartbeatTimeout + 1)))
        state.expiresAt = now.addingTimeInterval(1)
        XCTAssertFalse(state.isWarm(at: now.addingTimeInterval(2)))
        state.expiresAt = now.addingTimeInterval(600); state.phase = .ended
        XCTAssertFalse(state.isWarm(at: now))
    }

    func testCommandsExpire() {
        let command = KeyboardCommand(requestID: UUID(), kind: .start, mode: .translate, targetLanguage: "ja")
        XCTAssertTrue(command.isFresh())
        XCTAssertFalse(command.isFresh(at: .now.addingTimeInterval(11)))
    }

    func testLaunchRequiresMatchingFreshTicket() throws {
        let ticket = KeyboardLaunchRequest()
        XCTAssertTrue(ticket.matches(ticket.url))
        XCTAssertFalse(ticket.matches(URL(string: "localwrite://session/" + UUID().uuidString)!))
        XCTAssertFalse(ticket.matches(ticket.url, at: ticket.createdAt.addingTimeInterval(31)))
        XCTAssertFalse(ticket.matches(URL(string: ticket.url.absoluteString + "?other=1")!))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exchange = KeyboardExchange(directory: directory)
        XCTAssertNil(exchange.launchRequest())
        try exchange.write(ticket)
        XCTAssertEqual(exchange.launchRequest(), ticket)
        try exchange.clearLaunchRequest()
        XCTAssertNil(exchange.launchRequest())
    }

    func testExchangeRoundTripsStateAndCommand() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exchange = KeyboardExchange(directory: directory)
        let state = VoiceState(sessionID: UUID(), phase: .recording, text: "嗨", expiresAt: .now.addingTimeInterval(60))
        let command = KeyboardCommand(requestID: UUID(), kind: .finish)
        try exchange.write(state); try exchange.write(command)
        XCTAssertEqual(exchange.state()?.text, "嗨")
        XCTAssertEqual(exchange.command(), command)
    }

    func testSharedSettingsDefaults() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let settings = SharedSettings(defaults: defaults)
        XCTAssertEqual(settings.mode, .clean)
        settings.mode = .translate; settings.targetLanguage = "ja"
        XCTAssertEqual(settings.mode, .translate)
        XCTAssertEqual(TranslationLanguage.named(settings.targetLanguage).englishName, "Japanese")
    }

    func testDarwinSignalDelivers() {
        let name = "com.devgofer.LocalWrite.test.\(UUID().uuidString)"
        let received = expectation(description: "signal")
        let observer = DarwinSignal(observing: name) { received.fulfill() }
        DarwinSignal.post(name)
        wait(for: [received], timeout: 2)
        _ = observer
    }
}
