import Foundation

/// How far a step of the processing is, from 0 to 1: the time it has run over the usual duration
/// of that step on this device (`DurationEstimate`; `plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md`
/// §"Approach"). The bar fills evenly up to `onTime` at the usual duration; a longer step creeps
/// on towards `ceiling` and never claims completion before the end.
enum PhaseProgress {
    /// Where the bar stands when the usual duration has passed.
    static let onTime = 0.9
    /// The bar stays below this until the step is done.
    static let ceiling = 0.95

    static func value(elapsed: Duration, expected: Duration) -> Double {
        let share = max(0, elapsed / max(expected, .milliseconds(1)))
        guard share > 1 else { return onTime * share }
        return onTime + (ceiling - onTime) * (1 - exp(-2 * (share - 1)))
    }

    /// The whole seconds left until the usual duration, rounded up; `nil` once it passed, when
    /// there is nothing honest left to count down.
    static func secondsLeft(elapsed: Duration, expected: Duration) -> Int? {
        let left = expected - elapsed
        guard left > .zero else { return nil }
        return Int((left / .seconds(1)).rounded(.up))
    }

    /// The countdown after `shown`, with `secondsLeft` now: like the bar, it never goes back —
    /// it holds when the expectation grows once the units are counted, and does not return once
    /// it ran out.
    static func countdown(after shown: Int?, secondsLeft: Int?) -> Int? {
        guard let shown, let secondsLeft else { return nil }
        return min(shown, secondsLeft)
    }
}

/// The usual duration of a step of the processing, learned on this device from the last `window`
/// runs: a fixed start plus a time per unit of work — a token of the text for the cleanup, as the
/// model reads the text and writes about as much back; a second of audio for the transcription,
/// as the model reads the whole recording (`plans/TRANSCRIPTION_PROGRESS.md`). The line is
/// fitted robustly — Theil–Sen: the median of the slopes between all pairs, then the median
/// start —, because most runs take about the expected time and a few far longer, the first after
/// a pause while the model loads; an average pulled up by those ended the bar at half
/// (`plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md` §"Status"). The runs belong to one fingerprint —
/// the cleanup's prompt, the transcription's model —; another one starts them anew.
@MainActor
public final class DurationEstimate {
    /// What is estimated: where its runs are kept, and the guess before any was measured.
    struct Step {
        let samplesKey: String
        let fingerprintKey: String
        let initialStart: Double
        let initialPerUnit: Double
        /// Where the units are unknown and nothing was measured.
        let initialDuration: Duration
        /// What earlier releases kept, removed with the first run recorded.
        var formerKeys: [String] = []

        /// By tokens; the guess from cleanups in the Mac app on an M1 Pro.
        static let cleanup = Step(
            samplesKey: "cleanupSamples", fingerprintKey: "cleanupPrompt", initialStart: 0.6,
            initialPerUnit: 0.012, initialDuration: .milliseconds(1500),
            formerKeys: ["cleanupSeconds", "cleanupDurations"])
        /// By seconds of audio; the Mac transcribes 10 s in 0.2 s, the guess leaves room for an
        /// iPhone.
        static let transcription = Step(
            samplesKey: "transcriptionSamples", fingerprintKey: "transcriptionModel",
            initialStart: 0.3, initialPerUnit: 0.05, initialDuration: .milliseconds(800))
    }

    /// How many recent runs the line is fitted to.
    static let window = 20

    private let defaults: UserDefaults
    private let step: Step
    private let fingerprint: String

    init(_ step: Step, fingerprint: String, defaults: UserDefaults) {
        self.step = step
        self.fingerprint = fingerprint
        self.defaults = defaults
    }

    /// The cleanup with the current prompt and examples: the duration depends on how much the
    /// model reads.
    public static func cleanup(defaults: UserDefaults = .standard) -> DurationEstimate {
        DurationEstimate(.cleanup, fingerprint: CleanupPrompt.fingerprint, defaults: defaults)
    }

    /// The transcription with the model of `modelID`.
    public static func transcription(
        modelID: String, defaults: UserDefaults = .standard
    ) -> DurationEstimate {
        DurationEstimate(.transcription, fingerprint: modelID, defaults: defaults)
    }

    /// The duration to expect for `units` of work, or for a usual run when they are not known
    /// (yet).
    public func expectedDuration(units: Double?) -> Duration {
        let samples = self.samples
        guard let units, units > 0 else {
            guard !samples.isEmpty else { return step.initialDuration }
            return .seconds(Self.median(samples.map(\.seconds)))
        }
        let (start, perUnit) = fit(samples)
        return .seconds(max(start + perUnit * units, 0.1))
    }

    /// Takes in one run that produced a result.
    public func record(_ duration: Duration, units: Double) {
        let seconds =
            Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        guard seconds > 0, units > 0 else { return }
        let updated = (samples + [(units, seconds)]).suffix(Self.window)
        defaults.set(updated.map { [$0.units, $0.seconds] }, forKey: step.samplesKey)
        defaults.set(fingerprint, forKey: step.fingerprintKey)
        for key in step.formerKeys { defaults.removeObject(forKey: key) }
    }

    /// Start and seconds per unit. With fewer than two different amounts there is no slope to
    /// see; the median time per unit stands in, from no start.
    func fit(_ samples: [(units: Double, seconds: Double)]) -> (Double, Double) {
        guard !samples.isEmpty else { return (step.initialStart, step.initialPerUnit) }
        var slopes: [Double] = []
        for (i, a) in samples.enumerated() {
            for b in samples[(i + 1)...] where b.units != a.units {
                slopes.append((b.seconds - a.seconds) / (b.units - a.units))
            }
        }
        guard !slopes.isEmpty else {
            return (0, Self.median(samples.map { $0.seconds / $0.units }))
        }
        let perUnit = max(Self.median(slopes), 0)
        let start = max(Self.median(samples.map { $0.seconds - perUnit * $0.units }), 0)
        return (start, perUnit)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// The stored runs, oldest first, if they were measured with this fingerprint.
    private var samples: [(units: Double, seconds: Double)] {
        guard defaults.string(forKey: step.fingerprintKey) == fingerprint,
            let stored = defaults.array(forKey: step.samplesKey) as? [[Double]]
        else { return [] }
        return stored.compactMap { pair in
            pair.count == 2 && pair[0] > 0 && pair[1] > 0 ? (pair[0], pair[1]) : nil
        }
    }
}
