import Foundation

/// Removes hesitation sounds before the transcript reaches the cleanup model.
///
/// Only sounds that are never words — "äh", "uh", "hm" — are removed here, with the commas the
/// transcription set around them. Fillers that can carry meaning ("like", "also", "halt") are left
/// to the model, which sees the context.
public enum HesitationFilter {
    static let sounds: Set<String> = [
        "umm", "uh", "uhh", "erm", "hmm", "hm", "mm", "mhm", "äh", "ähm", "äähm", "öh", "öhm",
        "ehm",
    ]
    /// Sounds that are also German words ("um vier", "er kommt"): removed only where the
    /// transcription set them off with a comma, as it does for a hesitation.
    static let ambiguousSounds: Set<String> = ["um", "er"]

    public static func apply(to text: String) -> String {
        var kept: [String] = []
        var capitalizeNext = false
        for token in text.split(separator: " ", omittingEmptySubsequences: true) {
            let word = token.trimmingCharacters(in: .punctuationCharacters).lowercased()
            let isSound =
                sounds.contains(word) || (ambiguousSounds.contains(word) && token.hasSuffix(","))
            guard isSound else {
                if capitalizeNext, let first = token.first, first.isLowercase {
                    kept.append(first.uppercased() + token.dropFirst())
                } else {
                    kept.append(String(token))
                }
                capitalizeNext = false
                continue
            }
            // Keep a sentence end the sound carried, e.g. "… um." or "Um."
            if let last = token.last, ".!?".contains(last), let previous = kept.popLast() {
                kept.append(previous.trimmingCharacters(in: [","]) + String(last))
                capitalizeNext = true
            } else if kept.isEmpty || kept.last.map({ ".!?".contains($0.last ?? " ") }) == true {
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
}
