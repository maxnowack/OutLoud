import CryptoKit
import Foundation

/// How far a cleanup is, from 0 to 1: the time it has run over the usual duration of a cleanup
/// on this device (`CleanupTimings`; `plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md` §"Approach").
/// The bar fills evenly up to `onTime` at the usual duration; a longer cleanup creeps on towards
/// `ceiling` and never claims completion before the end.
enum CleanupProgress {
    /// Where the bar stands when the usual duration has passed.
    static let onTime = 0.9
    /// The bar stays below this until the cleanup is done.
    static let ceiling = 0.95

    static func value(elapsed: Duration, expected: Duration) -> Double {
        let share = max(0, elapsed / max(expected, .milliseconds(1)))
        guard share > 1 else { return onTime * share }
        return onTime + (ceiling - onTime) * (1 - exp(-2 * (share - 1)))
    }
}

/// The usual duration of a cleanup after a recording, learned on this device from the last
/// `window` cleanups: a fixed start plus a time per token of the text, as the model reads the text
/// and writes about as much back. The line is fitted robustly — Theil–Sen: the median of the
/// slopes between all pairs, then the median start —, because most cleanups take about the
/// expected time and a few far longer, the first after a pause while the model loads; an average
/// pulled up by those ended the bar at half (`plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md`
/// §"Status"). The cleanups belong to one prompt: a changed prompt or set of examples starts them
/// anew, as the duration depends on how much the model reads.
@MainActor
public final class CleanupTimings {
    /// The guess before anything was measured, from cleanups in the Mac app on an M1 Pro.
    static let initialStart = 0.6
    static let initialSecondsPerToken = 0.012
    /// Where the token count is unknown and nothing was measured.
    static let initialDuration: Duration = .milliseconds(1500)
    /// How many recent cleanups the line is fitted to.
    static let window = 20

    private let defaults: UserDefaults
    private let prompt: String

    public convenience init(defaults: UserDefaults = .standard) {
        self.init(defaults: defaults, prompt: CleanupPrompt.fingerprint)
    }

    init(defaults: UserDefaults, prompt: String) {
        self.defaults = defaults
        self.prompt = prompt
    }

    /// The duration to expect for a cleanup of `tokens`, or for a usual one when the count is
    /// not known (yet).
    public func expectedDuration(tokens: Int?) -> Duration {
        let samples = self.samples
        guard let tokens, tokens > 0 else {
            guard !samples.isEmpty else { return Self.initialDuration }
            return .seconds(Self.median(samples.map(\.seconds)))
        }
        let (start, perToken) = Self.fit(samples)
        return .seconds(max(start + perToken * Double(tokens), 0.1))
    }

    /// Takes in one cleanup that produced a cleaned text.
    public func record(_ duration: Duration, tokens: Int) {
        let seconds =
            Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        guard seconds > 0, tokens > 0 else { return }
        let updated = (samples + [(Double(tokens), seconds)]).suffix(Self.window)
        defaults.set(updated.map { [$0.tokens, $0.seconds] }, forKey: Key.samples)
        defaults.set(prompt, forKey: Key.prompt)
        // What 0.2.0 and 0.2.1 kept, replaced by the samples.
        defaults.removeObject(forKey: "cleanupSeconds")
        defaults.removeObject(forKey: "cleanupDurations")
    }

    /// Start and seconds per token. With fewer than two different lengths there is no slope to
    /// see; the median time per token stands in, from no start.
    static func fit(_ samples: [(tokens: Double, seconds: Double)]) -> (Double, Double) {
        guard !samples.isEmpty else { return (initialStart, initialSecondsPerToken) }
        var slopes: [Double] = []
        for (i, a) in samples.enumerated() {
            for b in samples[(i + 1)...] where b.tokens != a.tokens {
                slopes.append((b.seconds - a.seconds) / (b.tokens - a.tokens))
            }
        }
        guard !slopes.isEmpty else {
            return (0, median(samples.map { $0.seconds / $0.tokens }))
        }
        let perToken = max(median(slopes), 0)
        let start = max(median(samples.map { $0.seconds - perToken * $0.tokens }), 0)
        return (start, perToken)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// The stored cleanups, oldest first, if they were measured with this prompt.
    private var samples: [(tokens: Double, seconds: Double)] {
        guard defaults.string(forKey: Key.prompt) == prompt,
            let stored = defaults.array(forKey: Key.samples) as? [[Double]]
        else { return [] }
        return stored.compactMap { pair in
            pair.count == 2 && pair[0] > 0 && pair[1] > 0 ? (pair[0], pair[1]) : nil
        }
    }

    private enum Key {
        static let samples = "cleanupSamples"
        static let prompt = "cleanupPrompt"
    }
}

extension CleanupPrompt {
    /// Identifies the instructions and examples the model reads before a transcript.
    static let fingerprint: String = {
        let text = ([system] + examples.flatMap { [$0.transcript, $0.cleaned] })
            .joined(separator: "\u{1F}")
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }()
}
