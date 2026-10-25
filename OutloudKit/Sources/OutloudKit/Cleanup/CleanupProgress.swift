import CryptoKit
import Foundation

/// How far a cleanup is, from 0 to 1: the time it has run over the usual duration of a cleanup
/// on this device (`plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md` §"Approach"). The bar fills evenly up
/// to `onTime` at the usual duration; a longer cleanup creeps on towards `ceiling` and never
/// claims completion before the end.
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

/// The usual duration of a cleanup after a recording, as a moving average kept across launches.
/// It belongs to one prompt: a changed prompt or set of examples starts it anew, as the
/// duration depends on how much the model reads.
@MainActor
public final class CleanupTimings {
    /// The guess before anything was measured: a prewarmed cleanup on an M1 Pro Mac.
    static let initialDuration: Duration = .milliseconds(2500)
    /// How much a new measurement moves the average.
    static let weight = 0.3

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
        guard let seconds = average else { return Self.initialDuration }
        return .seconds(seconds)
    }

    /// Takes in the duration of one cleanup that produced a cleaned text.
    public func record(_ duration: Duration) {
        let measured =
            Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        guard measured > 0 else { return }
        let updated = average.map { $0 + Self.weight * (measured - $0) } ?? measured
        defaults.set(updated, forKey: Key.seconds)
        defaults.set(prompt, forKey: Key.prompt)
    }

    /// The stored average, if it was measured with this prompt.
    private var average: Double? {
        guard defaults.string(forKey: Key.prompt) == prompt,
            let seconds = defaults.object(forKey: Key.seconds) as? Double, seconds > 0
        else { return nil }
        return seconds
    }

    private enum Key {
        static let seconds = "cleanupSeconds"
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
