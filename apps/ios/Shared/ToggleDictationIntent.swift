import ActivityKit
import AppIntents
import Foundation

/// Starts a recording, or ends the running one and returns its cleaned text, while the user stays
/// in their app (ADR 0022): a shortcut runs it and copies what it returns, since Outloud may not
/// write the clipboard from the background. The system runs it in the app, which installs
/// `toggle` at launch.
struct ToggleDictationIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Start or Stop Dictation with Outloud"
    static let description = IntentDescription(
        "Starts recording without opening Outloud, or ends the recording and returns the cleaned text, e.g. for Copy to Clipboard."
    )
    static let supportedModes: IntentModes = .background

    /// Returns the text when it ended a recording, `nil` when it started one.
    @MainActor static var toggle: (() async throws -> String?)?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        .result(value: try await Self.toggle?() ?? nil)
    }
}

/// The Live Activity iOS requires while an `AudioRecordingIntent` records; it goes on to show the
/// processing and how the dictation ended (`docs/DESIGN.md` §"DictationLiveActivity").
struct DictationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case recording, transcribing, cleaning
            /// The text went to the shortcut, which copies it.
            case copied
            /// Ended from the Live Activity: kept in the history, not copied.
            case saved
            case nothingRecognised, failed
        }

        var phase: Phase
        /// When the recording started, for its timer.
        var since: Date
        /// How far the transcription or the cleanup is, 0 to 1, while it runs.
        var progress: Double?
        /// Roughly how many seconds it still takes, until its usual duration passed.
        var secondsLeft: Int?
    }
}

/// The Live Activity's Stop button: ends the recording; the text goes to the history, and to the
/// clipboard only when Outloud is in front.
struct StopDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Dictation"
    static let isDiscoverable = false

    @MainActor static var stop: (() async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        await Self.stop?()
        return .result()
    }
}
