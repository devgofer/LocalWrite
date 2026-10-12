import Foundation

/// Resolves spoken corrections of a day, time or quantity before the model sees the text,
/// because the small on-device model often keeps the first version:
/// 「你明天有空嗎？阿不對，是後天」→「你後天有空嗎？」
enum SelfCorrection {
    private static let markerPattern = #"[，,。？?！!\s]*(?:啊|阿|呃|欸|嗯)?[，,\s]*(?:不對|不是|我是說|應該說|說錯了)[，,\s]*(?:是)?"#

    private static let day = #"(?:大後天|後天|明天|今天|昨天|前天|今晚|明晚|(?:這|下)?(?:週|星期|禮拜)[一二三四五六日天])"#
    private static let time = #"(?:(?:早上|上午|中午|下午|晚上)?[0-9一二三四五六七八九十兩]+(?:[:：][0-9]{2}|點(?:半|[0-9一二三四五六七八九十]+分?)?))"#
    private static let count = #"(?:[0-9一二三四五六七八九十兩]+(?:張|個|杯|份|位|人|次|天|週|小時|分鐘|塊|元|件|本|台))"#

    static func apply(_ text: String) -> String {
        var text = text
        // Several corrections in one dictation are resolved left to right.
        for _ in 0..<5 {
            guard let marker = try? Regex(markerPattern), let found = text.firstMatch(of: marker) else { break }
            let before = String(text[..<found.range.lowerBound])
            let after = String(text[found.range.upperBound...])
            let ending = text[found.range].first { "？?。.！!".contains($0) }
            guard let fixed = correct(before: before, after: after, ending: ending) else { break }
            text = fixed
        }
        return text
    }

    private static func correct(before: String, after: String, ending: Character?) -> String? {
        for pattern in [time, day, count] {
            guard let regex = try? Regex("^" + pattern),
                  let replacement = after.firstMatch(of: regex),
                  let all = try? Regex(pattern) else { continue }
            let matches = before.matches(of: all)
            guard let old = matches.last else { continue }
            var result = before
            result.replaceSubrange(old.range, with: String(after[replacement.range]))
            let rest = String(after[replacement.range.upperBound...])
            // 「…嗎？不對，後天」 restates the sentence: keep its original ending.
            // 「約明天三點，不對，下午4:30 OK嗎」 continues it: keep what follows.
            if let ending { return result + String(ending) }
            return result + rest
        }
        return nil
    }
}
