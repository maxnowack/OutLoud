import AppIntents
import OutloudKit

/// Cleans up text — what "Dictate Text" produced in a shortcut, say — and returns it, for the
/// shortcut to copy: Outloud may not write the clipboard in the background (ADR 0003, ADR 0018).
/// The cleanup runs on Apple's on-device model, also in the background (ADR 0019).
struct CleanUpTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Clean Up Text with Outloud"
    static let description = IntentDescription(
        "Removes filler words, fixes punctuation and sets paragraphs, and returns the text, e.g. for Copy to Clipboard."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let app = AppModel.shared
        await app.start()
        guard CleanupAvailability.current == .available else {
            throw OutloudIntentError.cleanupUnavailable
        }
        guard app.settings.cleanupEnabled else { throw OutloudIntentError.cleanupOff }
        guard !app.dictation.state.isBusy else { throw OutloudIntentError.busy }
        guard let outcome = await app.cleanUpForShortcut(text: text) else {
            throw OutloudIntentError.nothingToCleanUp
        }
        // The text was asked to be cleaned up; handing it back unchanged would hide that it was not.
        guard case .cleaned(let cleaned) = outcome.cleanup else {
            throw OutloudIntentError.cleanupFailed
        }
        return .result(value: cleaned)
    }
}

/// Transcribes a recording — what "Record Audio" produced in a shortcut — and returns the text,
/// so that the shortcut can copy it while the user stays in their app: iOS lets the Shortcuts app
/// record and write the clipboard in the background, but not Outloud
/// (`plans/BACKGROUND_DICTATION.md`).
struct TranscribeAudioIntent: AppIntent {
    static let title: LocalizedStringResource = "Transcribe Audio with Outloud"
    static let description = IntentDescription(
        "Turns a recording into text on this iPhone and returns it, e.g. for Copy to Clipboard."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Audio", supportedContentTypes: [.audio])
    var audio: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let app = AppModel.shared
        await app.start()
        guard app.dictation.hasRequiredModels else { throw OutloudIntentError.modelsMissing }
        guard !app.dictation.state.isBusy else { throw OutloudIntentError.busy }
        let samples = try AudioFile.samples(of: audio.data, named: audio.filename)
        guard let outcome = await app.transcribe(samples: samples) else {
            throw OutloudIntentError.nothingRecognised
        }
        return .result(value: outcome.result)
    }
}

enum OutloudIntentError: Error, CustomLocalizedStringResourceConvertible {
    case modelsMissing
    case nothingToCleanUp
    case nothingRecognised
    case cleanupUnavailable
    case cleanupOff
    case cleanupFailed
    case busy

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .modelsMissing: "Open Outloud once to download its models."
        case .nothingToCleanUp: "There was no text to clean up."
        case .nothingRecognised: "Nothing was recognised in the recording."
        case .cleanupUnavailable: "Cleaning up text needs Apple Intelligence, switched on."
        case .cleanupOff: "Cleanup is switched off in Outloud's settings."
        case .cleanupFailed: "Outloud could not clean up this text. Please try again."
        case .busy: "Outloud is busy with another dictation. Please try again."
        }
    }
}

struct OutloudShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDictationIntent(),
            phrases: ["Dictate with \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Dictate", systemImageName: "mic")
        AppShortcut(
            intent: CleanUpTextIntent(),
            phrases: ["Clean up text with \(.applicationName)"],
            shortTitle: "Clean Up Text", systemImageName: "text.badge.checkmark")
        AppShortcut(
            intent: TranscribeAudioIntent(),
            phrases: ["Transcribe audio with \(.applicationName)"],
            shortTitle: "Transcribe Audio", systemImageName: "waveform")
    }
}
