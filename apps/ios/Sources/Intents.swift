import AppIntents
import OutloudKit

/// Opens Outloud and starts a recording; the Action Button can run it (ADR 0003).
struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Dictate with Outloud"
    static let description = IntentDescription(
        "Opens Outloud and starts recording. Tap Stop when you are done; the text is copied to the clipboard."
    )
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppModel.shared.startRecording()
        return .result()
    }
}

/// Cleans up text — what "Dictate Text" produced in a shortcut, say — and copies the result
/// (ADR 0003: system dictation supplies the transcript).
struct CleanUpTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Clean Up Text with Outloud"
    static let description = IntentDescription(
        "Removes filler words, fixes punctuation and sets paragraphs, then copies the text to the clipboard."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let app = AppModel.shared
        await app.start()
        guard app.dictation.hasRequiredModels else { throw OutloudIntentError.modelsMissing }
        guard let outcome = await app.cleanUp(text: text) else {
            throw OutloudIntentError.nothingToCleanUp
        }
        return .result(value: outcome.result, dialog: "Copied to the clipboard.")
    }
}

enum OutloudIntentError: Error, CustomLocalizedStringResourceConvertible {
    case modelsMissing
    case nothingToCleanUp

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .modelsMissing: "Open Outloud once to download its models."
        case .nothingToCleanUp: "There was no text to clean up."
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
