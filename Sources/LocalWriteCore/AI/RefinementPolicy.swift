import Foundation

/// Accept punctuation/spacing edits and removal of a leading hesitation only.
/// If a model translates, adds, drops or rewrites words, keep the original text.
/// This deliberately favors preserving intent over aggressive grammar correction.
enum RefinementPolicy {
    static func preserveWording(original: String, candidate: String) -> String {
        let output = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let expected = characters(original)
        let actual = characters(output)
        if expected == actual { return output }
        if let withoutHesitation = removingLeadingHesitation(original),
           characters(withoutHesitation) == actual { return output }
        return original.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func characters(_ text: String) -> String {
        let punctuation = CharacterSet(charactersIn: "，。！？、；：,.!?;:\"「」『』“”‘’")
        let scalars = Array(text.unicodeScalars)
        let cleaned = scalars.enumerated().compactMap { index, scalar -> Unicode.Scalar? in
            let insideNumber = index > 0 && index + 1 < scalars.count
                && CharacterSet.decimalDigits.contains(scalars[index - 1])
                && CharacterSet.decimalDigits.contains(scalars[index + 1])
            return punctuation.contains(scalar) && !insideNumber ? nil : scalar
        }
        let pieces = String(String.UnicodeScalarView(cleaned)).split(whereSeparator: { $0.isWhitespace })
        var result = ""
        for piece in pieces {
            if let last = result.unicodeScalars.last, let first = piece.unicodeScalars.first,
               last.isASCII, first.isASCII,
               CharacterSet.alphanumerics.contains(last), CharacterSet.alphanumerics.contains(first) {
                result += " "
            }
            result += piece
        }
        return result
    }

    private static func removingLeadingHesitation(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A standalone affirmation such as 嗯 or 嗯，是 stays intact.
        let affirmations = ["嗯是", "嗯對", "嗯好", "呃是", "呃對", "呃好", "嗯是的", "嗯對的"]
        if affirmations.contains(where: { text.hasPrefix($0) }) {
            return nil
        }
        for prefix in ["嗯我", "呃我", "嗯這", "呃這", "嗯", "呃", "啊"] where text.hasPrefix(prefix) {
            if prefix.count == 1 {
                if text.count > 2 {
                    return String(text.dropFirst())
                }
            } else {
                return String(text.dropFirst())
            }
        }
        for prefix in ["um ", "uh ", "Um ", "Uh ", "um, ", "uh, ", "Um, ", "Uh, "] where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return nil
    }
}
