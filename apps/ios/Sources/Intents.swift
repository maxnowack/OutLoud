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

enum OutloudIntentError: Error, CustomLocalizedStringResourceConvertible {
    case modelsMissing
    case nothingToCleanUp
    case cleanupUnavailable
    case cleanupOff
    case cleanupFailed
    case busy

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .modelsMissing: "Open Outloud once to download its models."
        case .nothingToCleanUp: "There was no text to clean up."
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
    }
}
