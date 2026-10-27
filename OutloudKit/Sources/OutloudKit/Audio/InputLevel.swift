import Foundation

/// The input level shown while recording, 0 to 1 (`docs/DESIGN.md` §"LevelWave").
enum InputLevel {
    /// Speech at the microphone lies between about -35 and -15 dB; -55 dB to -15 dB keeps
    /// silence at the bottom and lets normal speaking fill most of the display. The range of
    /// -50 dB to 0 dB before left most of it empty.
    static let floor: Float = -55
    static let top: Float = -15

    /// How often the controller reads the level while recording: about once a frame, so that
    /// the wave moves with the voice. The audio's IO buffers come about every 10 ms; the tap,
    /// whatever size it asks for, every 100 ms, which the eye sees as lagging.
    static let tick: Duration = .milliseconds(16)

    /// The level of a stretch of audio with this mean square.
    static func of(meanSquare: Float) -> Float {
        let decibels = 10 * log10(max(meanSquare, 1e-10))
        return max(0, min(1, (decibels - floor) / (top - floor)))
    }

    /// Rises at once with a louder reading and falls back within about a tenth of a second, by
    /// a quarter of the way each `tick`, so that the display does not drop to nothing within a
    /// syllable.
    static func following(_ previous: Float, _ next: Float) -> Float {
        next >= previous ? next : previous + (next - previous) * 0.25
    }
}
