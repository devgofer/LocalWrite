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

    func testAcceptsTypelessStyleCleanup() {
        let cases = [
            ("我覺得那個那個就是我們應該先做這個", "我覺得我們應該先做這個。"),
            ("我們約明天不對後天早上見好了", "我們約後天早上見好了。"),
            ("我要買三樣東西第一個是牛奶然後第二個是雞蛋第三個是麵包", "我要買三樣東西：\n1. 牛奶\n2. 雞蛋\n3. 麵包"),
            ("um so I think we should uh ship it on Friday I mean Thursday", "So I think we should ship it on Thursday.")
        ]
        for (raw, cleaned) in cases {
            XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: cleaned), cleaned)
        }
    }
    func testRejectsSummaryAndDroppedUncertainty() {
        let raw = "我覺得我們這週可能要先把登入頁面做完然後下週再處理付款流程"
        XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: "先做登入。"), raw)
        XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: "我覺得我們這週要先把登入頁面做完，下週再處理付款流程。"), raw)
    }
}
