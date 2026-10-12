import XCTest
@testable import LocalWriteKeyboardBridge

final class KeyboardExchangeTests: XCTestCase {
    func testResultInsertedOnlyOnceIntoOriginalDocument() {
        var delivery = KeyboardDelivery()
        let session = UUID(), document = UUID()
        let request = delivery.begin(sessionID: session, documentID: document)
        let result = KeyboardSnapshot(sessionID: session, requestID: request, phase: .completed, text: "Hello.")
        XCTAssertNil(delivery.consume(result, documentID: UUID()))
        XCTAssertEqual(delivery.consume(result, documentID: document), "Hello.")
        XCTAssertNil(delivery.consume(result, documentID: document))
    }
    func testCanceledOrExpiredOrUnrelatedResultsAreIgnored() {
        var delivery = KeyboardDelivery()
        let session = UUID(), document = UUID()
        let request = delivery.begin(sessionID: session, documentID: document)
        var result = KeyboardSnapshot(sessionID: session, requestID: request, phase: .completed, text: "old", updatedAt: .now.addingTimeInterval(-121))
        XCTAssertNil(delivery.consume(result, documentID: document))
        result.updatedAt = .now; result.requestID = UUID()
        XCTAssertNil(delivery.consume(result, documentID: document))
        result.requestID = request; delivery.cancel()
        XCTAssertNil(delivery.consume(result, documentID: document))
    }
    func testCommandsMustBelongToLiveSession() {
        let session = UUID()
        let command = KeyboardCommand(sessionID: session, requestID: UUID(), kind: .start)
        XCTAssertTrue(command.isValid(for: session))
        XCTAssertFalse(command.isValid(for: UUID()))
        XCTAssertFalse(command.isValid(for: session, at: .now.addingTimeInterval(10)))
    }
    func testCompletedResultSurvivesBackgroundSuspensionButRecordingNeedsHeartbeat() {
        let now = Date()
        var result = KeyboardSnapshot(sessionID: UUID(), phase: .completed, text: "Done", updatedAt: now)
        XCTAssertTrue(result.isLive(at: now.addingTimeInterval(30)))
        XCTAssertFalse(result.isLive(at: now.addingTimeInterval(121)))
        result.phase = .recording
        XCTAssertFalse(result.isLive(at: now.addingTimeInterval(5)))
    }
    func testKeyboardRecreationRecoversOnlyOriginalDocumentAndRequest() {
        let document = UUID()
        let ticket = KeyboardLaunchRequest(sessionID: UUID(), requestID: UUID())
        let pending = KeyboardPendingRequest(ticket: ticket, documentID: document, before: "A", after: "B")
        var replacement = KeyboardDelivery()
        XCTAssertFalse(replacement.resume(pending, documentID: UUID()))
        XCTAssertFalse(replacement.resume(pending, documentID: document, at: ticket.createdAt.addingTimeInterval(121)))
        XCTAssertTrue(replacement.resume(pending, documentID: document))
        let result = KeyboardSnapshot(sessionID: ticket.sessionID, requestID: ticket.requestID, phase: .completed, text: "hello")
        XCTAssertEqual(replacement.consume(result, documentID: document), "hello")
        XCTAssertNil(replacement.consume(result, documentID: document))
    }
    func testKeyboardLaunchRequiresMatchingFreshTicket() throws {
        let ticket = KeyboardLaunchRequest(sessionID: UUID(), requestID: UUID())
        XCTAssertTrue(ticket.matches(ticket.url))
        XCTAssertFalse(ticket.matches(URL(string: "localwrite://dictate/" + UUID().uuidString)!))
        XCTAssertFalse(ticket.matches(ticket.url, at: ticket.createdAt.addingTimeInterval(31)))
        XCTAssertFalse(ticket.matches(ticket.url, at: ticket.createdAt.addingTimeInterval(-3)))
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
    func testAtomicExchangeUsesSeparateMailboxes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exchange = KeyboardExchange(directory: directory)
        let session = UUID()
        let snapshot = KeyboardSnapshot(sessionID: session, phase: .ready)
        let command = KeyboardCommand(sessionID: session, requestID: UUID(), kind: .start)
        try exchange.write(snapshot); try exchange.write(command)
        XCTAssertEqual(exchange.snapshot(), snapshot)
        XCTAssertEqual(exchange.command()?.id, command.id)
    }
}
