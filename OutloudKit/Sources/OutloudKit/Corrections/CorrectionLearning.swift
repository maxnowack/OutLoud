import Foundation

/// Finds the correction the user made by hand in a pasted result (ADR 0040): the field's text
/// right after the paste against its text once the user stopped typing.
public enum CorrectionLearning {
    /// The most words a learned side may hold, as in ghost-pepper
    /// (`plans/CORRECTIONS.md` §"Problem"): a longer change is the user rewriting, not correcting.
    static let maximumWords = 2
    /// A field longer than this is not compared; it bounds the work of each look at the field.
    public static let maximumFieldLength = 20_000

    /// The pair the edit teaches, or `nil` when it teaches none: the change is not one run of one
    /// or two words replaced by one or two others, it changes only case or punctuation, it adds
    /// or removes words without replacing any, or it lies outside the pasted result — the user
    /// writing on, or editing what was there before.
    public static func pair(pasted: String, before: String, after: String) -> (
        heard: String, meant: String
    )? {
        let pasted = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pasted.isEmpty, before != after, before.count <= maximumFieldLength,
            after.count <= maximumFieldLength
        else { return nil }
        let old = words(in: before)
        let new = words(in: after)
        var prefix = 0
        while prefix < old.count, prefix < new.count, old[prefix].text == new[prefix].text {
            prefix += 1
        }
        var suffix = 0
        while suffix < old.count - prefix, suffix < new.count - prefix,
            old[old.count - 1 - suffix].text == new[new.count - 1 - suffix].text
        {
            suffix += 1
        }
        let removed = old[prefix..<(old.count - suffix)]
        let added = new[prefix..<(new.count - suffix)]
        guard (1...maximumWords).contains(removed.count), (1...maximumWords).contains(added.count),
            let first = removed.first, let last = removed.last
        else { return nil }
        let heard = trimmed(removed.map(\.text).joined(separator: " "))
        let meant = trimmed(added.map(\.text).joined(separator: " "))
        guard !heard.isEmpty, !meant.isEmpty, comparable(heard) != comparable(meant) else {
            return nil
        }
        let changed = first.range.lowerBound..<last.range.upperBound
        guard occurrences(of: pasted, in: before).contains(where: { $0.contains(changed) })
        else { return nil }
        return (heard, meant)
    }

    private struct Word {
        let text: Substring
        let range: Range<String.Index>
    }

    private static func words(in text: String) -> [Word] {
        var words: [Word] = []
        var start: String.Index?
        for index in text.indices {
            if text[index].isWhitespace {
                if let begun = start {
                    words.append(Word(text: text[begun..<index], range: begun..<index))
                }
                start = nil
            } else if start == nil {
                start = index
            }
        }
        if let begun = start {
            words.append(Word(text: text[begun...], range: begun..<text.endIndex))
        }
        return words
    }

    /// Without the punctuation around it, as the word is written.
    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }

    /// The words without case and punctuation, to tell a change of words from a change of form.
    private static func comparable(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: \.isWhitespace).map {
            String($0.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        }.filter { !$0.isEmpty }
    }

    private static func occurrences(of part: String, in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var searched = text.startIndex..<text.endIndex
        while let range = text.range(of: part, range: searched) {
            found.append(range)
            searched = range.upperBound..<text.endIndex
        }
        return found
    }
}
