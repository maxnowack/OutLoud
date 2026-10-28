import Foundation

/// Whether a pause command paused what played, judged from the loudness of the apps that put out
/// sound (ADR 0025): only a pause that silenced them may be undone with the play/pause key, which
/// would otherwise start the last player.
public struct PauseCheck: Sendable {
    public enum Verdict: Sendable, Equatable {
        /// The apps fell silent: play them on once the recording ends.
        case paused
        /// They still sound — a call, a video that does not take the command: leave them, and
        /// tell the user that the microphone may pick them up.
        case stillPlaying
    }

    /// A peak below -50 dB is silence: a player's quietest passage stays above it, and a
    /// browser that keeps its output open after pausing writes zeros.
    static let audiblePeak: Float = 0.003
    /// How long the apps must stay silent to count as paused; a gap between two notes is shorter.
    static let silentFor: Duration = .milliseconds(200)
    /// How long a player may take to fall silent after the command, its fade included.
    static let stopWithin: Duration = .seconds(1)

    /// The time since the pause command of the last audible peak and of the last peak heard.
    private var lastAudible: Duration = .zero
    private var lastHeard: Duration = .zero

    public init() {}

    /// Whether audio of this peak sounds.
    public static func isAudible(peak: Float) -> Bool { peak >= audiblePeak }

    /// Takes the peak of a stretch of the apps' output that ended `elapsed` after the command.
    public mutating func record(peak: Float, elapsed: Duration) {
        lastHeard = max(lastHeard, elapsed)
        if Self.isAudible(peak: peak) { lastAudible = max(lastAudible, elapsed) }
    }

    /// The verdict `elapsed` after the command, or `nil` while it is open. Silence counts only as
    /// far as output was heard, so that a tap that delivers nothing does not pass for a pause.
    public func verdict(elapsed: Duration) -> Verdict? {
        if lastHeard - lastAudible >= Self.silentFor { return .paused }
        return elapsed >= Self.stopWithin ? .stillPlaying : nil
    }
}
