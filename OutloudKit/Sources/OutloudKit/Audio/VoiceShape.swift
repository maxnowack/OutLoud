import Foundation

/// The shape of the voice at the microphone, as the LevelWave draws it (`docs/DESIGN.md`
/// §"LevelWave"): the last `window` of the input, in `pointCount` averages from -1 to 1.
///
/// A voice repeats itself every few milliseconds, and a shape that starts anywhere in a period
/// jumps sideways from one frame to the next. So each shape starts where it best matches the one
/// shown before — or, with nothing shown, where the signal rises through zero, as an oscilloscope
/// triggers — and the line moves only part of the way to it each frame. Measured on the German
/// and English samples, this moves the line by a third as much from frame to frame as the bare
/// shapes, and keeps most of its height (`plans/TRANSCRIPTION_PROGRESS.md` §"Status").
enum VoiceShape {
    /// How much of the input is shown: a few periods of a voice, which lie between about 4 and
    /// 12 ms.
    static let window = 0.03
    /// How far back the start may move: more than a period of the deepest voice.
    static let search = 0.02
    static let pointCount = 64
    /// How far the line moves towards a new shape each frame.
    static let blend: Float = 0.35

    /// The shape of the end of `samples`, scaled so that its peak reaches 1; zeros where there is
    /// too little input or none.
    ///
    /// - Parameter previous: The line shown before, which the shape is matched to.
    static func points(
        of samples: [Float], sampleRate: Double, after previous: [Float] = [],
        count: Int = pointCount
    ) -> [Float] {
        let length = Int(window * sampleRate)
        let reach = Int(search * sampleRate)
        let smoothing = max(Int(sampleRate / 1000), 1)
        let silent = [Float](repeating: 0, count: count)
        guard length >= count, samples.count >= length + reach + smoothing else { return silent }
        let base = samples.count - length - reach
        // Sums from `base`, so that any point is one subtraction, whichever start is tried.
        var sums = [Float](repeating: 0, count: length + reach + 1)
        for index in 0..<(length + reach) { sums[index + 1] = sums[index] + samples[base + index] }
        let perPoint = Double(length) / Double(count)
        func shape(from start: Int) -> [Float] {
            let raw = (0..<count).map { point in
                let from = start + Int(Double(point) * perPoint)
                let to = start + Int(Double(point + 1) * perPoint)
                return (sums[to] - sums[from]) / Float(to - from)
            }
            let peak = raw.map(abs).max() ?? 0
            return peak > 1e-6 ? raw.map { $0 / peak } : silent
        }
        let shown = previous.count == count ? previous : []
        let shownPeak = shown.map(abs).max() ?? 0
        guard shownPeak > 0.05 else {
            return shape(
                from: trigger(
                    in: samples, latest: samples.count - length, reach: reach,
                    smoothing: smoothing) - base)
        }
        // Every fourth sample at 48 kHz: finer than a point, and a quarter of the work.
        let step = max(Int(sampleRate / 12_000), 1)
        var best = silent
        var bestMatch = -Float.infinity
        for start in stride(from: reach, through: 0, by: -step) {
            let candidate = shape(from: start)
            let match = zip(candidate, shown).reduce(0) { $0 + $1.0 * $1.1 }
            if match > bestMatch {
                bestMatch = match
                best = candidate
            }
        }
        return best
    }

    /// The line `blend` of the way from `shown` to `next`; `next` when there is nothing to move
    /// from.
    static func moving(_ shown: [Float], towards next: [Float]) -> [Float] {
        guard shown.count == next.count else { return next }
        return zip(shown, next).map { $0 + ($1 - $0) * blend }
    }

    /// The latest index at or before `latest`, by at most `reach`, where the smoothed signal
    /// rises through zero; `latest` itself when there is none, as in silence or a hiss. The
    /// smoothing — about a millisecond, centred — keeps the overtones of a voice and noise from
    /// crossing zero in between the periods; a trailing average would lag and start the shape
    /// half a millisecond after the crossing.
    private static func trigger(in samples: [Float], latest: Int, reach: Int, smoothing: Int)
        -> Int
    {
        func smoothed(_ index: Int) -> Float {
            samples[(index - smoothing / 2)..<(index + smoothing / 2)].reduce(0, +)
        }
        var after = smoothed(latest)
        for index in stride(from: latest - 1, through: latest - reach, by: -1) {
            let before = smoothed(index)
            if before < 0, after >= 0 { return index }
            after = before
        }
        return latest
    }
}
