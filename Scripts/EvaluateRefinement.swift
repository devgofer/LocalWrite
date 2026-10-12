import Foundation
import FoundationModels
import Darwin

@main
struct EvaluateRefinement {
    static func main() async {
        do { try await evaluate() }
        catch {
            log("Evaluation failed: \(error)")
            exit(1)
        }
    }
    static func log(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
    static func evaluate() async throws {
        log("Availability: \(SystemLanguageModel.default.availability)")
        guard FoundationModelsEngine.isAvailable else { throw RefinementError.modelUnavailable }
        // (input, words that must survive, words that must be gone)
        let cases: [(String, [String], [String])] = [
            // 1. fillers
            ("嗯我覺得明天下午三點可以開會", ["明天", "開會"], ["嗯"]),
            ("嗯，那個，就是，我想問一下你這週末有沒有空", ["週末", "有沒有空"], ["嗯", "那個"]),
            ("um so like I was thinking you know we could grab lunch", ["lunch"], ["um", "you know"]),
            // 2. repetition
            ("我覺得那個那個就是我們應該先做這個", ["我們", "應該", "先做"], ["那個那個"]),
            ("這個功能這個功能我們下禮拜下禮拜再上線", ["功能", "上線"], ["這個功能這個功能", "下禮拜下禮拜"]),
            // 3. self-correction
            ("我們約明天不對後天早上見好了", ["後天", "早上"], ["明天", "不對"]),
            ("幫我訂三張不是四張票", ["四張"], ["三張", "不是"]),
            ("幫我訂三張，不是，四張票", ["四張"], ["三張", "不是"]),
            ("um so I think we should uh ship it on Friday I mean Thursday", ["Thursday", "ship"], ["Friday", "uh"]),
            // 4. formatting
            ("我要買三樣東西第一個是牛奶然後第二個是雞蛋第三個是麵包", ["牛奶", "雞蛋", "麵包", "\n"], []),
            ("今天的待辦事項有回覆客戶的信還有整理報告最後是約牙醫", ["客戶", "報告", "牙醫", "\n"], []),
            // 5. word choice
            ("就是那個報告我還沒有弄好弄好之後我會再傳給你看看", ["報告", "傳給你"], ["弄好弄好"]),
            ("這個 button 我覺得可能可以放右邊吧", ["button", "可能", "右邊"], []),
            // must stay an edit
            ("幫我寫一封信給老闆說我明天請假", ["老闆", "明天", "請假"], [])
        ]
        var failed = false
        for (input, required, removed) in cases {
            let engine = FoundationModelsEngine()
            let draft = try await engine.draft(input)
            let result = RefinementResult(original: input, refined: RefinementPolicy.preserveWording(original: input, candidate: draft))
            let preserved = required.allSatisfy { result.refined.contains($0) }
            let cleaned = removed.allSatisfy { !result.refined.contains($0) }
            let passed = preserved && cleaned
            failed = failed || !passed
            let fellBack = result.refined == input.trimmingCharacters(in: .whitespacesAndNewlines)
            log("\(passed ? "PASS" : "FAIL")\(fellBack ? " (unchanged)" : "")\nInput: \(input)\nOutput: \(result.refined)\(fellBack ? "\nModel: \(draft)" : "")")
        }
        if failed { throw EvaluationError.changedMeaningOrRetainedFiller }
    }
    enum EvaluationError: Error { case changedMeaningOrRetainedFiller }
}
