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
            ("嗯我覺得明天下午三點可以開會", ["明天", "三點", "開會"], ["嗯"]),
            ("這個 button 我覺得可能可以放右邊吧", ["button", "可能", "右邊"], []),
            ("我不知道欸可能明天比較方便", ["不知道", "可能", "明天"], []),
            ("我覺得那個那個就是我們應該先做這個", ["我們", "應該", "先做"], ["那個那個"]),
            ("我們約明天不對後天早上見好了", ["後天", "早上"], ["明天", "不對"]),
            ("我要買三樣東西第一個是牛奶然後第二個是雞蛋第三個是麵包", ["牛奶", "雞蛋", "麵包", "\n"], []),
            ("um so I think we should uh ship it on Friday I mean Thursday", ["Thursday", "ship"], ["Friday", "uh"]),
            ("幫我寫一封信給老闆說我明天請假", ["老闆", "明天", "請假"], [])
        ]
        var failed = false
        for (input, required, removed) in cases {
            let result = try await FoundationModelsEngine().refine(input)
            let preserved = required.allSatisfy { result.refined.contains($0) }
            let cleaned = removed.allSatisfy { !result.refined.contains($0) }
            let passed = preserved && cleaned
            failed = failed || !passed
            log("\(passed ? "PASS" : "FAIL")\nInput: \(input)\nOutput: \(result.refined)")
        }
        if failed { throw EvaluationError.changedMeaningOrRetainedFiller }
    }
    enum EvaluationError: Error { case changedMeaningOrRetainedFiller }
}
