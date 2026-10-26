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

/// The usual duration of a cleanup after a recording: the median of the last `window` durations,
/// kept across launches. A median, as most cleanups take about the same time and a few take far
/// longer — the first after a pause, while the model loads —, and an average pulled up by those
/// ended the bar at half for the usual ones (2026-10-26: 1.2–1.3 s measured, 1.97 s averaged).
/// The durations belong to one prompt: a changed prompt or set of examples starts them anew, as
/// the duration depends on how much the model reads.
@MainActor
public final class CleanupTimings {
    /// The guess before anything was measured: a prewarmed cleanup in the Mac app on an M1 Pro.
    static let initialDuration: Duration = .milliseconds(1500)
    /// How many recent durations the median is taken over.
    static let window = 10

    private let defaults: UserDefaults
    private let prompt: String

    public convenience init(defaults: UserDefaults = .standard) {
        self.init(defaults: defaults, prompt: CleanupPrompt.fingerprint)
    }

    init(defaults: UserDefaults, prompt: String) {
        self.defaults = defaults
        self.prompt = prompt
    }

    /// The duration to expect for the next cleanup.
    public var expectedDuration: Duration {
        let sorted = durations.sorted()
        guard !sorted.isEmpty else { return Self.initialDuration }
        let middle = sorted.count / 2
        let median =
            sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        return .seconds(median)
    }

    /// Takes in the duration of one cleanup that produced a cleaned text.
    public func record(_ duration: Duration) {
        let measured =
            Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        guard measured > 0 else { return }
        defaults.set(Array((durations + [measured]).suffix(Self.window)), forKey: Key.durations)
        defaults.set(prompt, forKey: Key.prompt)
        // The moving average of 0.2.0, replaced by the durations.
        defaults.removeObject(forKey: "cleanupSeconds")
    }

    /// The stored durations, oldest first, if they were measured with this prompt.
    private var durations: [Double] {
        guard defaults.string(forKey: Key.prompt) == prompt,
            let stored = defaults.array(forKey: Key.durations) as? [Double]
        else { return [] }
        return stored.filter { $0 > 0 }
    }

    private enum Key {
        static let durations = "cleanupDurations"
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
