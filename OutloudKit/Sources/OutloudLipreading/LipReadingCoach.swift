import CoreGraphics
import Foundation
import IOKit.ps
import Observation
import OutloudKit

/// What the settings show of the lip reader's learning, and the training itself: by the user's
/// button, or on its own while the Mac is idle, until it reads well enough to be used
/// (`plans/LIP_READING.md` §"Phase 4", §"Phase 6").
@MainActor
@Observable
public final class LipReadingCoach {
    /// The app words these; the package holds no user-visible text.
    public enum Training: Equatable {
        case idle
        case running
        case finished(adopted: Bool, before: Double, after: Double)
        case tooFewSamples
        case failed
    }

    public private(set) var samples = 0
    public private(set) var silentSamples = 0
    public private(set) var bytes: Int64 = 0
    public private(set) var training: Training = .idle
    /// The language `training` is of: an idle Mac learns the language it has new samples in,
    /// which need not be the one shown.
    public private(set) var trainingLanguage: String?
    /// The share of words the reader in use misreads on the held-back samples, after the last
    /// training; `nil` before the first.
    public private(set) var error: Double?
    /// When the last training ended that measured the reader, and on how many samples.
    public private(set) var learnedOn: Date?
    public private(set) var learnedFrom = 0
    /// The samples kept since the last training.
    public private(set) var newSamples = 0
    /// The share of words read right: `error`'s other side, at least zero.
    public var accuracy: Double? { error.map { max(0, 1 - $0) } }

    @ObservationIgnored private let files: LipReadingFiles
    @ObservationIgnored private let settings: OutloudSettings
    /// Called after an adapter was learned, so that the reader loads it.
    @ObservationIgnored public var onAdapterChange: (() -> Void)?
    /// Called once per language, the first time the reader is good enough to be used.
    @ObservationIgnored public var onReady: ((String) -> Void)?
    /// Below this share of misread words, lip reading is good enough to be used: the user's
    /// decision of 2026-11-03 (`plans/LIP_READING.md` §"Phase 6").
    public static let goodEnough = 0.30
    /// How many new samples start a training on their own. A run goes over all samples, so a
    /// handful more is not worth the minutes; ten is the least a first run takes.
    public static let automaticAfter = 10
    /// How long nobody touched mouse or keyboard before a training starts on its own.
    nonisolated static let idleAfter: TimeInterval = 10 * 60
    @ObservationIgnored private let defaults = UserDefaults.standard
    /// The samples kept of each language, as of the last `refresh`.
    @ObservationIgnored private var counts: [String: Int] = [:]

    /// How many samples of `language` the last training had.
    private func trainedAt(_ language: String) -> Int {
        defaults.integer(forKey: "lipReadingTrainedAtSamples.\(language)")
    }

    private func newSamples(_ language: String) -> Int {
        max(0, (counts[language] ?? 0) - trainedAt(language))
    }

    public init(files: LipReadingFiles, settings: OutloudSettings) {
        self.files = files
        self.settings = settings
    }

    public func refresh() async {
        let files = files
        let (all, size) = await Task.detached { (files.trainingSamples(), files.samplesSize()) }
            .value
        let language = settings.lipReadingLanguage
        counts = Dictionary(grouping: all, by: \.language).mapValues(\.count)
        samples = all.filter { $0.language == language }.count
        silentSamples = all.filter { $0.language == language && $0.silent }.count
        bytes = size
        error = defaults.object(forKey: "lipReadingError.\(language)") as? Double
        learnedOn = defaults.object(forKey: "lipReadingLearnedOn.\(language)") as? Date
        learnedFrom = defaults.integer(forKey: "lipReadingLearnedFrom.\(language)")
        newSamples = newSamples(language)
    }

    public var hasModel: Bool { files.hasModel(language: settings.lipReadingLanguage) }

    public func sampleKept() async { await refresh() }

    /// Looks once a minute whether to train on its own, in every language, for as long as the
    /// app runs.
    public func trainsWhenIdle() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await refresh()
            let languages = Self.languagesToTrain(
                newSamples: Dictionary(
                    uniqueKeysWithValues: LipReadingLanguage.all.map { ($0, newSamples($0)) }),
                idle: Self.idleSeconds, onMains: Self.onMainsPower,
                running: training == .running, hasModel: { [files] in files.hasModel(language: $0) }
            )
            // A run stopped by input leaves the next language for the next idle stretch.
            for language in languages where Self.idleSeconds >= Self.idleAfter {
                await train(language: language, stopsOnInput: true)
            }
        }
    }

    /// The languages a training starts in on their own, one after the other.
    static func languagesToTrain(
        newSamples: [String: Int], idle: TimeInterval, onMains: Bool, running: Bool,
        hasModel: (String) -> Bool
    ) -> [String] {
        LipReadingLanguage.all.filter {
            trainsNow(
                newSamples: newSamples[$0] ?? 0, idle: idle, onMains: onMains, running: running,
                hasModel: hasModel($0))
        }
    }

    /// Whether a training starts on its own: enough new samples, nobody at the Mac for
    /// `idleAfter`, on mains power, and none running.
    static func trainsNow(
        newSamples: Int, idle: TimeInterval, onMains: Bool, running: Bool, hasModel: Bool
    ) -> Bool {
        newSamples >= automaticAfter && idle >= idleAfter && onMains && !running && hasModel
    }

    /// Whether to tell the user that lip reading is good enough: once, the first time it is.
    static func announces(error: Double, announced: Bool) -> Bool {
        error < goodEnough && !announced
    }

    /// Trains on the samples of `language`, by default the one shown; one started on its own
    /// stops at the first input, and keeps what it shows.
    public func train(language: String? = nil, stopsOnInput: Bool = false) async {
        guard training != .running else { return }
        let language = language ?? settings.lipReadingLanguage
        let files = files
        let shown = (training, trainingLanguage)
        (training, trainingLanguage) = (.running, language)
        let result = await Task.detached(priority: .background) {
            Result {
                try LipTraining.train(
                    files: files, language: language,
                    stops: { stopsOnInput && Self.idleSeconds < Self.idleAfter })
            }
        }.value
        switch result {
        case .success(let report):
            markTrained(language, samples: report.samples + report.heldOut)
            training = .finished(
                adopted: report.adopted, before: report.errorBefore, after: report.errorAfter)
            if report.adopted { onAdapterChange?() }
            let now = report.adopted ? report.errorAfter : report.errorBefore
            defaults.set(now, forKey: "lipReadingError.\(language)")
            defaults.set(Date(), forKey: "lipReadingLearnedOn.\(language)")
            defaults.set(
                report.samples + report.heldOut, forKey: "lipReadingLearnedFrom.\(language)")
            if Self.announces(
                error: now, announced: defaults.bool(forKey: "lipReadingAnnounced.\(language)"))
            {
                defaults.set(true, forKey: "lipReadingAnnounced.\(language)")
                onReady?(language)
            }
        case .failure(LipTraining.TrainingError.stopped):
            (training, trainingLanguage) = shown
        case .failure(LipTraining.TrainingError.tooFewSamples):
            training = .tooFewSamples
        case .failure:
            // Not again before more samples came in: a run that failed fails the same way.
            markTrained(language, samples: counts[language] ?? 0)
            training = .failed
        }
        await refresh()
    }

    private func markTrained(_ language: String, samples: Int) {
        defaults.set(samples, forKey: "lipReadingTrainedAtSamples.\(language)")
    }

    public func deleteSamples() async {
        let files = files
        try? await Task.detached { try files.deleteSamples() }.value
        // The samples of every language are gone, and with them what was learned from them.
        for language in LipReadingLanguage.all {
            for key in [
                "lipReadingTrainedAtSamples", "lipReadingAnnounced", "lipReadingError",
                "lipReadingLearnedOn", "lipReadingLearnedFrom",
            ] {
                defaults.removeObject(forKey: "\(key).\(language)")
            }
        }
        (training, trainingLanguage) = (.idle, nil)
        onAdapterChange?()
        await refresh()
    }

    /// Seconds since the last input of mouse, keyboard or trackpad, of any user process.
    nonisolated static var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .hidSystemState, eventType: CGEventType(rawValue: ~0)!)
    }

    static var onMainsPower: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return true }  // a desktop Mac reports no source
        return (type as String) == kIOPSACPowerValue
    }
}
