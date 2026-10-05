import XCTest
@testable import LocalWriteCore

final class LocalWriteCoreTests: XCTestCase {
    func testRefinementResultChangedFlag() {
        XCTAssertFalse(RefinementResult(original: "hello", refined: "hello").changed)
        XCTAssertTrue(RefinementResult(original: "hello", refined: "Hello.").changed)
    }

    func testWriteStateEquality() {
        XCTAssertEqual(WriteState.idle, .idle)
        XCTAssertEqual(WriteState.error("failed"), .error("failed"))
        XCTAssertNotEqual(WriteState.error("a"), .error("b"))
    }
}
