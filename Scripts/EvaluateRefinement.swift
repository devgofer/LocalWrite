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
        let cases: [(String, [String])] = [
            ("嗯我覺得明天下午三點可以開會", ["明天", "三點", "開會"]),
            ("這個 button 我覺得可能可以放右邊吧", ["button", "可能", "右邊"]),
            ("我不知道欸可能明天比較方便", ["不知道", "可能", "明天"])
        ]
        var failed = false
        for (input, required) in cases {
            let result = try await FoundationModelsEngine().refine(input)
            let preserved = required.allSatisfy { result.refined.contains($0) }
            let fillerRemoved = !input.hasPrefix("嗯我") || !result.refined.hasPrefix("嗯")
            let passed = preserved && fillerRemoved
            failed = failed || !passed
            log("\(passed ? "PASS" : "FAIL")\nInput: \(input)\nOutput: \(result.refined)")
        }
        if failed { throw EvaluationError.changedMeaningOrRetainedFiller }
    }
    enum EvaluationError: Error { case changedMeaningOrRetainedFiller }
}
