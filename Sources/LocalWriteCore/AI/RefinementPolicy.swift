import Foundation

/// Guards the model's edit. Deleting fillers, repeats and self-corrections, reformatting
/// and better word choice are allowed. Changed numbers, translation, a summary, an
/// answer instead of an edit, or dropped uncertainty fall back to the original transcript.
enum RefinementPolicy {
    static func preserveWording(original: String, candidate: String) -> String {
        let output = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = tokens(fallback)
        let result = tokens(stripListMarkers(output))
        if result == source { return output }
        // Very short utterances such as 嗯是 or 對 keep every word.
        guard source.count > 3, !result.isEmpty else { return fallback }
        // Word choice may change some words, but most must come from the speaker.
        let known = Set(source)
        let novel = result.filter { !known.contains($0) }.count
        guard novel * 10 <= result.count * 4 else { return fallback }
        // Deletions are expected, but not a summary or an added answer.
        guard result.count * 10 >= source.count * 3, result.count * 2 <= source.count * 3 + 4 else { return fallback }
        // 三點 may become 3點, but no number may change or appear.
        guard numbers(in: stripListMarkers(output)).isSubset(of: numbers(in: fallback)) else { return fallback }
        guard !changedScript(source, result) else { return fallback }
        for word in hedges where fallback.lowercased().contains(word) && !output.lowercased().contains(word) {
            return fallback
        }
        return output
    }

    /// Uncertainty the speaker expressed must survive cleanup.
    private static let hedges = ["可能", "應該", "也許", "大概", "或許", "好像", "maybe", "probably", "might"]
    private static let chineseDigits: [Character: Int] = [
        "零": 0, "一": 1, "二": 2, "兩": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]
    private static let chineseUnits: [Character: Int] = ["十": 10, "百": 100, "千": 1000, "萬": 10000]

    /// Values of digit runs and Chinese numerals, so 三 and 3 compare equal.
    /// A lone 一 is skipped: it is mostly part of words like 一下 or 一起.
    static func numbers(in text: String) -> Set<Int> {
        var result = Set<Int>()
        var digits = "", chinese = ""
        func flush() {
            if let value = Int(digits) { result.insert(value) }
            if !chinese.isEmpty, chinese != "一" { result.insert(chineseValue(chinese)) }
            digits = ""; chinese = ""
        }
        for character in text {
            if character.isASCII, character.isNumber {
                if !chinese.isEmpty { flush() }
                digits.append(character)
            } else if chineseDigits[character] != nil || chineseUnits[character] != nil {
                if !digits.isEmpty { flush() }
                chinese.append(character)
            } else {
                flush()
            }
        }
        flush()
        return result
    }

    private static func chineseValue(_ text: String) -> Int {
        var total = 0, section = 0, number = 0
        for character in text {
            if let digit = chineseDigits[character] { number = digit; continue }
            guard let unit = chineseUnits[character] else { continue }
            if unit == 10000 {
                total += (section + number) * unit; section = 0
            } else {
                section += (number == 0 ? 1 : number) * unit
            }
            number = 0
        }
        return total + section + number
    }

    /// Chinese turned into English (or the reverse) means the model translated.
    private static func changedScript(_ source: [String], _ result: [String]) -> Bool {
        func cjkShare(_ tokens: [String]) -> Double {
            Double(tokens.filter { !$0.unicodeScalars.allSatisfy(\.isASCII) }.count) / Double(max(tokens.count, 1))
        }
        return abs(cjkShare(source) - cjkShare(result)) > 0.4
    }

    /// CJK and other non-ASCII characters are one token each; ASCII words (with
    /// decimal points inside numbers) are one lowercased token. Punctuation is ignored.
    static func tokens(_ text: String) -> [String] {
        let punctuation = CharacterSet(charactersIn: "，。！？、；：,.!?;:\"「」『』“”‘’（）()…—-·•*")
        var result: [String] = []
        var word = ""
        let scalars = Array(text.unicodeScalars)
        func flush() { if !word.isEmpty { result.append(word.lowercased()); word = "" } }
        for (index, scalar) in scalars.enumerated() {
            let insideNumber = scalar == "." && index > 0 && index + 1 < scalars.count
                && CharacterSet.decimalDigits.contains(scalars[index - 1])
                && CharacterSet.decimalDigits.contains(scalars[index + 1])
            if scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "'" || insideNumber) {
                word.unicodeScalars.append(scalar)
            } else if CharacterSet.whitespacesAndNewlines.contains(scalar) || punctuation.contains(scalar) {
                flush()
            } else {
                flush()
                result.append(String(scalar))
            }
        }
        flush()
        return result
    }

    /// Numbered or bulleted list markers the model adds when formatting a spoken list.
    private static func stripListMarkers(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.replacingOccurrences(of: #"^\s*(\d{1,2}[.、)）]|[-•*])\s*"#, with: "", options: .regularExpression)
        }.joined(separator: "\n")
    }
}
