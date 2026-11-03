import Foundation

/// Attention-only beam search, as ESPnet's with a CTC weight of 0 and no length bonus: on the
/// Phase 0 clip it read as well as with CTC prefix scoring (`plans/LIP_READING.md` §"Phase 0").
/// `step` returns, for each prefix, the log-probabilities of the next token.
struct BeamSearch {
    let beamSize: Int
    let endOfSentence: Int
    let maximumLength: Int

    func run(step: ([[Int]]) -> [[Float]]) -> [Int] {
        var running: [(tokens: [Int], score: Float)] = [([endOfSentence], 0)]
        var ended: [(tokens: [Int], score: Float)] = []
        for _ in 0..<maximumLength {
            let scores = step(running.map(\.tokens))
            var candidates: [(tokens: [Int], score: Float)] = []
            for (hypothesis, next) in zip(running, scores) {
                for (token, logp) in Self.top(next, beamSize) {
                    candidates.append((hypothesis.tokens + [token], hypothesis.score + logp))
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
