import Foundation

/// Attention-only beam search, as ESPnet's with a CTC weight of 0 and no length bonus: on the
/// Phase 0 clip it read as well as with CTC prefix scoring (`plans/LIP_READING.md` §"Phase 0").
/// `step` returns, for each prefix, the log-probabilities of the next token; it is also told,
/// for each prefix, which of the previous step's prefixes it extends.
struct BeamSearch {
    let beamSize: Int
    let endOfSentence: Int
    let maximumLength: Int

    /// The most tokens a recording of `frames` frames is read into: one per two frames, 12.5 a
    /// second, more than anyone says. Without a bound below the frames, a reader that does not
    /// know the lips repeats itself until the frames run out, and a step costs more the longer
    /// the prefix.
    static func maximumLength(frames: Int) -> Int { max(1, frames / 2) }

    func run(step: (_ prefixes: [[Int]], _ parents: [Int]) throws -> [[Float]]) rethrows -> [Int] {
        var running: [(tokens: [Int], score: Float, parent: Int)] = [([endOfSentence], 0, 0)]
        var ended: [(tokens: [Int], score: Float, parent: Int)] = []
        for _ in 0..<maximumLength {
            let scores = try step(running.map(\.tokens), running.map(\.parent))
            var candidates: [(tokens: [Int], score: Float, parent: Int)] = []
            for (index, (hypothesis, next)) in zip(running, scores).enumerated() {
                for (token, logp) in Self.top(next, beamSize) {
                    candidates.append((hypothesis.tokens + [token], hypothesis.score + logp, index))
                }
            }
            candidates.sort { $0.score > $1.score }
            running = []
            for candidate in candidates.prefix(beamSize) {
                if candidate.tokens.last == endOfSentence {
                    ended.append(candidate)
                } else {
                    running.append(candidate)
                }
            }
            // Scores only fall as a hypothesis grows, so nothing running can still win.
            let bestEnded = ended.map(\.score).max() ?? -.infinity
            if running.isEmpty || running[0].score < bestEnded { break }
        }
        let best = (ended + running).max { $0.score < $1.score }?.tokens ?? []
        return best.dropFirst().filter { $0 != endOfSentence }
    }

    static func top(_ values: [Float], _ k: Int) -> [(Int, Float)] {
        Array(values.enumerated().sorted { $0.element > $1.element }.prefix(k))
            .map { ($0.offset, $0.element) }
    }
}
