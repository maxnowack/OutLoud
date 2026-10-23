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
        cleanupModelID = defaults.string(forKey: Key.cleanupModel) ?? ModelCatalog.qwen08B.id
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
    }

    /// Whether the transcript is cleaned up; needs the cleanup model (`docs/SPEC.md` §"Models").
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

    public var cleanupModelID: String {
        didSet { defaults.set(cleanupModelID, forKey: Key.cleanupModel) }
    }

    /// Whether the user has confirmed the models at first launch.
    public var hasCompletedSetup: Bool {
        didSet { defaults.set(hasCompletedSetup, forKey: Key.hasCompletedSetup) }
    }

    public var transcriptionModel: ModelDescriptor {
        ModelCatalog.model(id: transcriptionModelID) ?? ModelCatalog.parakeetV3
    }

    public var cleanupModel: ModelDescriptor {
        ModelCatalog.model(id: cleanupModelID) ?? ModelCatalog.qwen08B
    }

    private enum Key {
        static let cleanupEnabled = "cleanupEnabled"
        static let retentionPeriod = "retentionPeriod"
        static let transcriptionModel = "transcriptionModel"
        static let cleanupModel = "cleanupModel"
        static let hasCompletedSetup = "hasCompletedSetup"
    }
}
