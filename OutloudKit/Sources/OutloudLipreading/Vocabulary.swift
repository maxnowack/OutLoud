import Foundation

/// The SentencePiece unigram vocabulary of one language's decoder: id 0 is the CTC blank, the
/// last id both starts and ends a sentence. Pieces mark a word's start with "▁".
public struct Vocabulary: Sendable {
    public let pieces: [String]
    let scores: [Float]
    private let index: [String: Int]
    private let longestPiece: Int

    public var count: Int { pieces.count }
    public var endOfSentence: Int { pieces.count - 1 }
    var unknown: Int { index["<unk>"] ?? 1 }

    public init(pieces: [String], scores: [Float]) {
        self.pieces = pieces
        self.scores = scores
        index = Dictionary(pieces.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        longestPiece = pieces.map(\.count).max() ?? 1
    }

    /// Reads `[[piece, score], ...]`, the file the conversion writes.
    public init(contentsOf url: URL) throws {
        let entries =
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[Any]] ?? []
        self.init(
            pieces: entries.map { $0[0] as? String ?? "" },
            scores: entries.map { Float(($0[1] as? NSNumber)?.doubleValue ?? 0) })
    }

    /// The text the labels are written in: upper case, letters, digits and apostrophes, words
    /// separated by single spaces — as LRS3's transcripts, which the model was trained on.
    public static func normalise(_ text: String) -> String {
        let kept = text.uppercased().map { $0.isLetter || $0.isNumber || $0 == "'" ? $0 : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    public func decode(_ ids: [Int]) -> String {
        ids.filter { $0 > 0 && $0 < endOfSentence }.map { pieces[$0] }.joined()
            .replacingOccurrences(of: "▁", with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// The most probable segmentation of the normalised text (Viterbi over the unigram scores),
    /// as SentencePiece encodes it.
    public func encode(_ text: String) -> [Int] {
        let characters = Array(
            Self.normalise(text).split(separator: " ").map { "▁" + $0 }.joined())
        guard !characters.isEmpty else { return [] }
        var best = [Float](repeating: -.infinity, count: characters.count + 1)
        var back = [(start: Int, id: Int)](repeating: (0, 0), count: characters.count + 1)
        best[0] = 0
        for end in 1...characters.count {
            for start in max(0, end - longestPiece)..<end where best[start] > -.infinity {
                let piece = String(characters[start..<end])
                if let id = index[piece], best[start] + scores[id] > best[end] {
                    best[end] = best[start] + scores[id]
                    back[end] = (start, id)
                }
            }
            if best[end] == -.infinity {  // a character no piece covers
                best[end] = best[end - 1] - 100
                back[end] = (end - 1, unknown)
            }
        }
        var ids: [Int] = []
        var end = characters.count
        while end > 0 {
            ids.append(back[end].id)
            end = back[end].start
        }
        return ids.reversed()
    }
}
