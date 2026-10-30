import Foundation
import NaturalLanguage

/// Removes hesitation sounds before the transcript reaches the cleanup model.
///
/// Only sounds that are never words — "äh", "uh", "hm" — are removed here, with the commas the
/// transcription set around them, and "also" at the start of a German sentence. Fillers that can
/// carry meaning ("like", "halt", "also" inside a sentence) are left to the model, which sees the
/// context.
public enum HesitationFilter {
    static let sounds: Set<String> = [
        "umm", "uh", "uhh", "erm", "hmm", "hm", "mm", "mhm", "äh", "ähm", "äähm", "öh", "öhm",
        "ehm",
    ]
    /// Sounds that are also German words ("um vier", "er kommt"): removed only where the
    /// transcription set them off with a comma, as it does for a hesitation.
    static let ambiguousSounds: Set<String> = ["um", "er"]
    /// Carries no meaning at the start of a German sentence, as the cleanup prompt says; in
    /// English it does ("Also, …"). Removed here because the model, asked to drop it at the start
    /// of two sentences in a row, loses its place and writes the first of them again.
    static let germanSentenceStartFiller = "also"

    public static func apply(to text: String) -> String {
        let isGerman = NLLanguageRecognizer.dominantLanguage(for: text) == .german
        var kept: [String] = []
        var capitalizeNext = false
        for token in text.split(separator: " ", omittingEmptySubsequences: true) {
            let word = token.trimmingCharacters(in: .punctuationCharacters).lowercased()
            let startsSentence = kept.last.map(endsSentence) ?? true
            let isFiller =
                sounds.contains(word) || (ambiguousSounds.contains(word) && token.hasSuffix(","))
                || (isGerman && startsSentence && word == germanSentenceStartFiller)
            guard isFiller else {
                if capitalizeNext, let first = token.first, first.isLowercase {
                    kept.append(first.uppercased() + token.dropFirst())
                } else {
                    kept.append(String(token))
                }
                capitalizeNext = false
                continue
            }
            if startsSentence {
                // Drop the comma that set the filler off: "… so eine., also da" → "… so eine. Da"
                if let previous = kept.popLast() {
                    kept.append(previous.trimmingCharacters(in: [","]))
                }
                capitalizeNext = true
            } else if let last = token.last, ".!?".contains(last), let previous = kept.popLast() {
                // Keep a sentence end the sound carried, e.g. "… um."
                kept.append(previous.trimmingCharacters(in: [","]) + String(last))
                capitalizeNext = true
            }
        }
        var result = kept.joined(separator: " ")
        while result.contains(", ,") { result = result.replacingOccurrences(of: ", ,", with: ",") }
        result = result.replacingOccurrences(of: ",,", with: ",")
        for mark in [".", "?", "!"] {
            result = result.replacingOccurrences(of: ",\(mark)", with: mark)
        }
        if result.hasPrefix(",") { result.removeFirst() }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Whether a word ends a sentence, also where the transcription set a comma after the mark.
    private static func endsSentence(_ word: String) -> Bool {
        word.trimmingCharacters(in: [","]).last.map { ".!?".contains($0) } ?? false
    }
}
