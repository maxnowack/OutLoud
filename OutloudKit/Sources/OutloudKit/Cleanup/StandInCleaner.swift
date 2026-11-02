#if DEBUG
    import Foundation

    /// Answers every transcript with the text given at launch, in place of Apple's model where a
    /// simulator does not offer it: `-OutloudCleanupStandIn <text>` (`-OutloudCleanupStandIn ""`
    /// only makes the cleanup available). Debug builds only; the store screenshots use it
    /// (`marketing/store-screenshots/README.md`).
    struct StandInCleaner: Cleaning {
        static let argument = "OutloudCleanupStandIn"

        /// The text given at launch, or `nil` when the stand-in is not asked for.
        static var text: String? { UserDefaults.standard.string(forKey: argument) }

        let text: String

        func clean(_ transcript: String) async throws -> String { text }
    }
#endif
