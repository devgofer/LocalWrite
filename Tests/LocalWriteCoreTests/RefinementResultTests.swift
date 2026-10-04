import XCTest
@testable import LocalWriteCore

final class RefinementResultTests: XCTestCase {
    func testChangedWhenRefinedTextDiffers() {
        let result = RefinementResult(
            original: "嗯我覺得可以",
            refined: "我覺得可以"
        )

        XCTAssertTrue(result.changed)
    }

    func testUnchangedWhenTextIsIdentical() {
        let result = RefinementResult(
            original: "我覺得可以。",
            refined: "我覺得可以。"
        )

        XCTAssertFalse(result.changed)
    }
}
