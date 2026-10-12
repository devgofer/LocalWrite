import XCTest
@testable import LocalWriteCore

final class RefinementPolicyTests: XCTestCase {
    func testKeepsDecimalsSymbolsAndWordBoundaries() {
        for (raw, output) in [("3.5", "35"), ("👍", "👎"), ("now here", "nowhere")] {
            XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: output), raw)
        }
    }

    func testRejectsTranslationAndLostUncertainty() {
        let raw = "這個 button 我覺得可能可以放右邊吧"
        XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: "這個按鈕，我覺得可以放在右邊。"), raw)
    }
    func testAcceptsPunctuationAndLeadingHesitationRemoval() {
        XCTAssertEqual(RefinementPolicy.preserveWording(original: "嗯我覺得明天可以", candidate: "我覺得明天可以。"), "我覺得明天可以。")
    }
    func testKeepsStandaloneAffirmation() {
        XCTAssertEqual(RefinementPolicy.preserveWording(original: "嗯是", candidate: "是。"), "嗯是")
    }
    func testRejectsAddedInformationAndChangedNumbers() {
        XCTAssertEqual(RefinementPolicy.preserveWording(original: "三點開會", candidate: "四點開會。"), "三點開會")
        XCTAssertEqual(RefinementPolicy.preserveWording(original: "明天開會", candidate: "明天下午三點開會。"), "明天開會")
    }
    func testAcceptsEnglishFillerButKeepsOrdinaryWords() {
        XCTAssertEqual(RefinementPolicy.preserveWording(original: "um I think so", candidate: "I think so."), "I think so.")
        XCTAssertEqual(RefinementPolicy.preserveWording(original: "umbrella", candidate: "brella"), "umbrella")
    }
}
