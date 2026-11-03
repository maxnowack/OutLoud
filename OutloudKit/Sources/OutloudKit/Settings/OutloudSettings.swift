import Foundation
import Observation

/// The settings both apps share, kept in `UserDefaults`.
@MainActor
@Observable
public final class OutloudSettings {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cleanupEnabled =
            defaults.object(forKey: Key.cleanupEnabled) == nil
            ? true : defaults.bool(forKey: Key.cleanupEnabled)
        retentionPeriod =
            defaults.string(forKey: Key.retentionPeriod).flatMap(RetentionPeriod.init(rawValue:))
            ?? .default
        transcriptionModelID =
            defaults.string(forKey: Key.transcriptionModel) ?? ModelCatalog.parakeetV3.id
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
        pausesPlayback =
            defaults.object(forKey: Key.pausesPlayback) == nil
            ? true : defaults.bool(forKey: Key.pausesPlayback)
        lipReading =
            defaults.string(forKey: Key.lipReading).flatMap(LipReadingMode.init(rawValue:)) ?? .off
        // Off until the user turns it on: it runs the camera (`plans/LIP_READING.md` §"Phase 6").
        learnsFromDictations = defaults.bool(forKey: Key.learnsFromDictations)
        lipReadingLanguage =
            defaults.string(forKey: Key.lipReadingLanguage)
            ?? (Locale.preferredLanguages.first?.hasPrefix("de") == true ? "de" : "en")
    }

    /// Whether the transcript is cleaned up; needs Apple's on-device model (ADR 0019).
    public var cleanupEnabled: Bool {
        didSet { defaults.set(cleanupEnabled, forKey: Key.cleanupEnabled) }
    }

    /// How long results are kept (`docs/SPEC.md` §"History").
    public var retentionPeriod: RetentionPeriod {
        didSet { defaults.set(retentionPeriod.rawValue, forKey: Key.retentionPeriod) }
    }

    public var transcriptionModelID: String {
        didSet { defaults.set(transcriptionModelID, forKey: Key.transcriptionModel) }
    }

    /// Whether other audio pauses while a dictation records (ADR 0024).
    public var pausesPlayback: Bool {
        didSet { defaults.set(pausesPlayback, forKey: Key.pausesPlayback) }
    }

    /// When the lips are read instead of the voice (`plans/LIP_READING.md`); macOS only.
    public var lipReading: LipReadingMode {
        didSet { defaults.set(lipReading.rawValue, forKey: Key.lipReading) }
    }

    /// Whether the mouth frames of a dictation with sound are kept, with its transcript, to
    /// train the lip reader on the user.
    public var learnsFromDictations: Bool {
        didSet { defaults.set(learnsFromDictations, forKey: Key.learnsFromDictations) }
    }

    /// The language the lips are read in, "de" or "en": a silent dictation has no sound to
    /// tell it.
    public var lipReadingLanguage: String {
        didSet { defaults.set(lipReadingLanguage, forKey: Key.lipReadingLanguage) }
    }

    /// Whether the user has confirmed the models at first launch.
    public var hasCompletedSetup: Bool {
        didSet { defaults.set(hasCompletedSetup, forKey: Key.hasCompletedSetup) }
    }

    public var transcriptionModel: ModelDescriptor {
        ModelCatalog.all.first { $0.id == transcriptionModelID } ?? ModelCatalog.parakeetV3
    }

    private enum Key {
        static let cleanupEnabled = "cleanupEnabled"
        static let retentionPeriod = "retentionPeriod"
        static let transcriptionModel = "transcriptionModel"
        static let hasCompletedSetup = "hasCompletedSetup"
        static let pausesPlayback = "pausesPlayback"
        static let lipReading = "lipReading"
        static let learnsFromDictations = "learnsFromDictations"
        static let lipReadingLanguage = "lipReadingLanguage"
    }
}
