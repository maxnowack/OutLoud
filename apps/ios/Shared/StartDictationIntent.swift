import AppIntents

/// Opens Outloud and starts a recording; the Action Button, the Control Center, the Lock Screen
/// and Siri run it (ADR 0003, ADR 0017).
///
/// It is compiled into the app and the widget extension, which needs it for the control. The
/// system runs it in the app, which installs `start` at launch.
struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Dictate with Outloud"
    static let description = IntentDescription(
        "Opens Outloud and starts recording. Tap Stop when you are done; the text is copied to the clipboard."
    )
    static let supportedModes: IntentModes = .foreground(.immediate)

    /// What the app does when the intent runs; set by the app at launch.
    @MainActor static var start: (() async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        await Self.start?()
        return .result()
    }
}
