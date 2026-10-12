import XCTest
@testable import LocalWriteCore

final class RefinementResultTests: XCTestCase {
    func testEmptyModelOutputIsRejected() {
        XCTAssertThrowsError(try FoundationModelsEngine.validateOutput(" \n "))
    }

    func testModelOutputKeepsIntentionalMixedLanguage() throws {
        XCTAssertEqual(try FoundationModelsEngine.validateOutput(" 這個 button 可能可以吧。\n"), "這個 button 可能可以吧。")
    }

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

    func testTidyFixesDoubledPronounAndEnglishPunctuation() {
        XCTAssertEqual(FoundationModelsEngine.tidy("我我想問一下，謝謝。"), "我想問一下，謝謝。")
        XCTAssertEqual(FoundationModelsEngine.tidy("I was thinking we could grab lunch。"), "I was thinking we could grab lunch.")
    }
}
