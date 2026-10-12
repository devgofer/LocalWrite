import XCTest
import AppKit
@testable import LocalWriteMac

final class PasteboardTransactionTests: XCTestCase {
    @MainActor
    func testRestoresOriginalClipboard() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("original", forType: .string)
        let transaction = try PasteboardTransaction(text: "dictation", pasteboard: board)
        XCTAssertEqual(board.string(forType: .string), "dictation")
        transaction.restoreIfUnchanged()
        XCTAssertEqual(board.string(forType: .string), "original")
    }

    @MainActor
    func testDoesNotOverwriteNewCopy() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("original", forType: .string)
        let transaction = try PasteboardTransaction(text: "dictation", pasteboard: board)
        board.clearContents()
        board.setString("new copy", forType: .string)
        transaction.restoreIfUnchanged()
        XCTAssertEqual(board.string(forType: .string), "new copy")
    }
}
