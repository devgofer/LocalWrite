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

    func testAcceptsBetterWordChoiceButNotTranslation() {
        let raw = "就是那個報告我還沒有弄好弄好之後我會再傳給你看看"
        let polished = "那份報告我還沒完成，完成後再傳給你看。"
        XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: polished), polished)
        XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: "I haven't finished the report yet."), raw)
    }
    func testAcceptsSpokenNumbersAsDigits() {
        let raw = "我們明天下午三點在會議室開會"
        XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: "我們明天下午3點在會議室開會。"), "我們明天下午3點在會議室開會。")
        XCTAssertEqual(RefinementPolicy.preserveWording(original: raw, candidate: "我們明天下午4點在會議室開會。"), raw)
    }

    func testSelfCorrectionOfDaysTimesAndCounts() {
        XCTAssertEqual(SelfCorrection.apply("你明天有空嗎？阿不對，後天。"), "你後天有空嗎？")
        XCTAssertEqual(SelfCorrection.apply("你明天有空嗎？啊不對，是後天有嗎？"), "你後天有空嗎？")
        XCTAssertEqual(SelfCorrection.apply("我們約明天三點阿不對，是下午4:30 OK嗎？"), "我們約明天下午4:30 OK嗎？")
        XCTAssertEqual(SelfCorrection.apply("幫我訂三張不是四張票"), "幫我訂四張票")
        XCTAssertEqual(SelfCorrection.apply("我不是故意的"), "我不是故意的")
    }
}
