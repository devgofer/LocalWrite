import Foundation

/// Guards the model's cleanup. Deleting words (fillers, repeats, self-corrections)
/// and reformatting are allowed; adding words, changing numbers, translating,
/// summarizing or dropping uncertainty falls back to the original transcript.
enum RefinementPolicy {
    static func preserveWording(original: String, candidate: String) -> String {
        let output = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = tokens(fallback)
        let result = tokens(stripListMarkers(output))
        if result == source { return output }
        // Very short utterances such as 嗯是 or 對 keep every word.
        guard source.count > 3, !result.isEmpty else { return fallback }
        let known = Set(source)
        let novel = result.filter { !known.contains($0) }.count
        guard novel <= result.count / 10 else { return fallback }
        // Deletions are expected, but not a summary.
        guard result.count * 10 >= source.count * 3, result.count <= source.count + source.count / 10 + 1 else {
            return fallback
        }
        for word in hedges where fallback.lowercased().contains(word) && !output.lowercased().contains(word) {
            return fallback
        }
        return output
    }

    /// Uncertainty the speaker expressed must survive cleanup.
    private static let hedges = ["可能", "應該", "也許", "大概", "或許", "好像", "maybe", "probably", "might"]

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
