import Foundation

/// A word Outloud writes the way the user means it (`docs/SPEC.md` §"Corrections"): a pair — what
/// the transcription heard and what was meant — or a single term, a spelling the user keeps.
public struct Correction: Codable, Equatable, Hashable, Identifiable, Sendable {
    public enum Origin: String, Codable, Sendable {
        /// The user entered it in the settings.
        case added
        /// The Mac learned it from the user's edit after a paste (ADR 0040).
        case learned
    }

    public let id: UUID
    /// What the transcription writes; `nil` for a term, which matches its own spelling.
    public let heard: String?
    /// How the user writes it.
    public let meant: String
    public let origin: Origin
    public let createdAt: Date
    /// How many results it has corrected.
    public internal(set) var uses: Int

    /// What a result is searched for.
    var pattern: String { heard ?? meant }

    /// The longest text a side may hold, so that an entry stays a word or a name.
    public static let maximumLength = 50
    /// The most words a side may hold.
    public static let maximumWords = 4

    /// A checked correction, or `nil` when a side is not a short run of words: empty, without a
    /// letter or digit, too long, with control characters, or with `<` or `>`, which the cleanup
    /// prompt uses to frame its input (`OutloudKit/AGENTS.md` §"Security"). Each side is written on
    /// one line with single spaces. An empty `heard`, or one that differs from `meant` only in case
    /// and spacing, makes a term.
    init?(
        id: UUID = UUID(), heard: String?, meant: String, origin: Origin, createdAt: Date,
        uses: Int = 0
    ) {
        guard let meant = Self.checked(meant), uses >= 0 else { return nil }
        let heard = heard.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let heard, !heard.isEmpty {
            guard let checkedHeard = Self.checked(heard) else { return nil }
            self.heard = Self.words(checkedHeard) == Self.words(meant) ? nil : checkedHeard
        } else {
            self.heard = nil
        }
        self.id = id
        self.meant = meant
        self.origin = origin
        self.createdAt = createdAt
        self.uses = uses
    }

    /// The side trimmed and with single spaces, or `nil` when it is not allowed.
    static func checked(_ side: String) -> String? {
        let words = side.split(whereSeparator: \.isWhitespace)
        let text = words.joined(separator: " ")
        guard !text.isEmpty, text.count <= maximumLength, words.count <= maximumWords,
            text.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains),
            !text.unicodeScalars.contains(where: forbidden.contains)
        else { return nil }
        return text
    }

    private static let forbidden = CharacterSet.controlCharacters
        .union(.newlines).union(.illegalCharacters).union(CharacterSet(charactersIn: "<>"))

    /// The words of a side, compared without case.
    static func words(_ side: String) -> [String] {
        side.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard
            let checked = Correction(
                id: try container.decode(UUID.self, forKey: .id),
                heard: try container.decodeIfPresent(String.self, forKey: .heard),
                meant: try container.decode(String.self, forKey: .meant),
                origin: try container.decode(Origin.self, forKey: .origin),
                createdAt: try container.decode(Date.self, forKey: .createdAt),
                uses: try container.decode(Int.self, forKey: .uses))
        else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "invalid correction"))
        }
        self = checked
    }
}

extension Correction {
    /// `text` with every correction applied, in one pass from left to right: a longer pattern
    /// wins over a shorter one at the same place, and a replacement is never searched again.
    /// Matches whole words only, without regard to case, and across any spacing. A match that
    /// already lies inside the meant text — "Max" in "Max Nowack" for "Max" → "Max Nowack" — is
    /// left, so that applying the list twice changes nothing more than applying it once.
    ///
    /// - Returns: The text and the corrections that changed it.
    static func apply(_ corrections: [Correction], to text: String) -> (
        text: String, used: Set<Correction.ID>
    ) {
        guard !corrections.isEmpty, !text.isEmpty else { return (text, []) }
        let ordered = corrections.sorted { $0.pattern.count > $1.pattern.count }
        let alternatives = ordered.map { correction in
            "("
                + correction.pattern.split(separator: " ")
                .map { NSRegularExpression.escapedPattern(for: String($0)) }
                .joined(separator: "\\s+") + ")"
        }
        // A pattern is built from escaped words only, so the expression always compiles.
        guard
            let expression = try? NSRegularExpression(
                pattern: "(?<![\\p{L}\\p{N}])(?:" + alternatives.joined(separator: "|")
                    + ")(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive])
        else { return (text, []) }
        let source = text as NSString
        var result = ""
        var used: Set<Correction.ID> = []
        var position = 0
        for match in expression.matches(
            in: text, range: NSRange(location: 0, length: source.length))
        {
            guard
                let index = ordered.indices.first(where: {
                    match.range(at: $0 + 1).location != NSNotFound
                })
            else { continue }
            let correction = ordered[index]
            let found = source.substring(with: match.range)
            guard found != correction.meant,
                !Self.lies(match.range, insideAnOccurrenceOf: correction.meant, in: source)
            else { continue }
            result += source.substring(
                with: NSRange(location: position, length: match.range.location - position))
            result += correction.meant
            position = match.range.location + match.range.length
            used.insert(correction.id)
        }
        result += source.substring(from: position)
        return (result, used)
    }

    /// Whether `range` lies inside a longer occurrence of `meant`, compared without case.
    private static func lies(
        _ range: NSRange, insideAnOccurrenceOf meant: String, in source: NSString
    ) -> Bool {
        let length = (meant as NSString).length
        guard length > range.length else { return false }
        let start = max(0, range.location + range.length - length)
        let end = min(source.length, range.location + length)
        var searched = NSRange(location: start, length: end - start)
        while searched.length >= length {
            let found = source.range(of: meant, options: [.caseInsensitive], range: searched)
            guard found.location != NSNotFound else { return false }
            if found.location <= range.location,
                found.location + found.length >= range.location + range.length
            {
                return true
            }
            searched = NSRange(location: found.location + 1, length: end - found.location - 1)
        }
        return false
    }
}
