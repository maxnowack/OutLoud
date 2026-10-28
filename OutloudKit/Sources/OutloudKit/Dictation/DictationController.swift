import Foundation
import Observation

/// Why a dictation produced no result.
public enum DictationFailure: Equatable, Sendable {
    case microphoneDenied
    case modelsMissing
    case nothingRecognised
    case recordingFailed(String)
    case transcriptionFailed(String)
}

/// Where a dictation stands (`docs/SPEC.md` §"Result view and states").
public enum DictationState: Equatable, Sendable {
    case idle
    case recording
    case transcribing
    case cleaning
    case finished(DictationOutcome)
    case failed(DictationFailure)

    public var isBusy: Bool {
        switch self {
        case .recording, .transcribing, .cleaning: true
        default: false
        }
    }
}

/// One dictation at a time, from the recording to the result and its entry in the history.
///
/// The apps decide when a recording starts and ends — the hotkey on macOS, the shortcut or the
/// record button on iOS — and what happens with the result.
///
/// `state`, `progress` and `voice` describe the dictation the user sees. A recording ended with
/// `stopRecordingInBackground()` is processed out of sight, and the next recording may start at
/// once (`plans/done/PASTE_ON_RETURN.md`); the transcriptions and cleanups of all dictations run one
/// after another, in the order their recordings ended.
@MainActor
@Observable
public final class DictationController {
    public private(set) var state: DictationState = .idle
    /// The shape of the voice while recording: `VoiceShape.pointCount` points from -1 to 1,
    /// scaled by the input level, so that they lie at 0 in silence; empty otherwise.
    public private(set) var voice: [Float] = []
    /// Roughly how far the transcription or the cleanup is, 0 to 1, while it runs after a
    /// recording; `nil` otherwise.
    public private(set) var progress: Double?
    /// Roughly how many whole seconds the transcription or the cleanup still takes, while it
    /// runs after a recording and until its usual duration passed; `nil` otherwise.
    public private(set) var secondsLeft: Int?

    @ObservationIgnored private let settings: OutloudSettings
    @ObservationIgnored private let library: ModelLibrary
    @ObservationIgnored private let engines: Engines
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let cleaner: @MainActor () -> (any Cleaning)?
    /// Where the durations of the transcription and the cleanup are learned.
    @ObservationIgnored private let estimates: UserDefaults
    /// The cleaner made when the recording started, so that it prepares while the user speaks.
    @ObservationIgnored private var preparedCleaner: (any Cleaning)?
    /// Reads the input level while recording.
    @ObservationIgnored private var levelReading: Task<Void, Never>?
    /// The input level while recording, 0 to 1.
    @ObservationIgnored private var level: Float = 0
    /// The processing of the dictations, one after another.
    @ObservationIgnored private let queue = SerialQueue()
    /// Called after a result was added to the history.
    @ObservationIgnored public var onHistoryChange: (() -> Void)?
    /// Called once a recording has ended, whether it is processed or dropped; the Mac resumes
    /// the playback it paused (ADR 0024).
    @ObservationIgnored public var onRecordingEnded: (() -> Void)?

    public init(
        settings: OutloudSettings, library: ModelLibrary, engines: Engines, history: HistoryStore,
        now: @escaping () -> Date = Date.init,
        cleaner: @escaping @MainActor () -> (any Cleaning)? = DictationController.appleCleaner,
        estimates: UserDefaults = .standard
    ) {
        self.settings = settings
        self.library = library
        self.engines = engines
        self.history = history
        self.now = now
        self.cleaner = cleaner
        self.estimates = estimates
    }

    /// Apple's on-device model where the system offers it; asked per dictation, since the user
    /// can switch Apple Intelligence on or off at any time (ADR 0019).
    public static func appleCleaner() -> (any Cleaning)? {
        CleanupAvailability.current == .available ? AppleCleaner() : nil
    }

    /// Whether the transcription model is installed; the cleanup needs no download (ADR 0019).
    public var hasRequiredModels: Bool {
        library.state(of: settings.transcriptionModel).isInstalled
    }

    /// Loads the transcription model ahead of the first dictation.
    public func preloadModels() async {
        guard hasRequiredModels else { return }
        await engines.preload(settings.transcriptionModel)
    }

    /// Starts a recording. Returns `false` and sets a failed state when it cannot start.
    ///
    /// - Parameter mixable: Opens a session that mixes with other audio, as iOS requires in the
    ///   background; with `pausesPlayback` it still turns others down (`AudioRecorder.OtherAudio`).
    @discardableResult
    public func startRecording(mixable: Bool = false) async -> Bool {
        guard !state.isBusy else { return false }
        guard hasRequiredModels else {
            state = .failed(.modelsMissing)
            return false
        }
        if MicrophonePermission.status != .granted {
            guard await MicrophonePermission.request() else {
                state = .failed(.microphoneDenied)
                return false
            }
            // Another start may have run while the user answered the dialog.
            guard !state.isBusy else { return false }
        }
        do {
            let otherAudio: AudioRecorder.OtherAudio =
                settings.pausesPlayback ? (mixable ? .quiet : .interrupt) : .mix
            try recorder.start(otherAudio: otherAudio)
            state = .recording
            levelReading = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: InputLevel.tick)
                    guard let self, self.state == .recording else { return }
                    self.level = InputLevel.following(self.level, self.recorder.takeLevel())
                    let recent = self.recorder.recentAudio()
                    let shape = VoiceShape.points(
                        of: recent.samples, sampleRate: recent.sampleRate, after: self.voice)
                    self.voice = VoiceShape.moving(
                        self.voice, towards: shape.map { $0 * self.level })
                }
            }
            preparedCleaner = settings.cleanupEnabled ? cleaner() : nil
            return true
        } catch {
            state = .failed(.recordingFailed(error.localizedDescription))
            return false
        }
    }

    /// Ends the recording and processes it, after the dictations whose recordings ended before.
    @discardableResult
    public func stopRecording() async -> DictationOutcome? {
        guard state == .recording else { return nil }
        let samples = endRecording()
        let prepared = takePreparedCleaner()
        state = .transcribing
        return await queue.run {
            await self.transcribe(
                samples, prepared: prepared, showsProgress: true, publishes: true)
        }
    }

    /// Ends the recording and processes it out of sight: `state` returns to idle at once, so
    /// that the next recording can start, and the result comes when the dictations before it
    /// are done. Returns `nil` when nothing was recognised or the processing failed.
    @discardableResult
    public func stopRecordingInBackground() async -> DictationOutcome? {
        guard state == .recording else { return nil }
        let samples = endRecording()
        let prepared = takePreparedCleaner()
        state = .idle
        return await queue.run {
            await self.transcribe(
                samples, prepared: prepared, showsProgress: false, publishes: false)
        }
    }

    /// Ends the recording and drops it.
    public func cancelRecording() {
        guard state == .recording else { return }
        _ = endRecording()
        preparedCleaner = nil
        state = .idle
    }

    private func endRecording() -> [Float] {
        let samples = recorder.stop()
        levelReading?.cancel()
        level = 0
        voice = []
        onRecordingEnded?()
        return samples
    }

    private func takePreparedCleaner() -> (any Cleaning)? {
        defer { preparedCleaner = nil }
        return preparedCleaner
    }

    /// Transcribes and cleans up samples recorded elsewhere — by a shortcut, say — and keeps the
    /// result in the history. Returns `nil` without touching the state while a dictation is
    /// running: it would take over the recording, whose microphone then stays open.
    @discardableResult
    public func process(samples: [Float]) async -> DictationOutcome? {
        guard !state.isBusy else { return nil }
        state = .transcribing
        return await queue.run {
            await self.transcribe(samples, prepared: nil, showsProgress: false, publishes: true)
        }
    }

    /// - Parameters:
    ///   - prepared: The cleaner made when the recording started.
    ///   - showsProgress: Publishes `progress` and learns the durations of the transcription and
    ///     the cleanup: after a recording, whose cleaner was prewarmed.
    ///   - publishes: Moves `state` through the phases; a dictation processed in the background
    ///     leaves it to the one the user sees.
    private func transcribe(
        _ samples: [Float], prepared: (any Cleaning)?, showsProgress: Bool, publishes: Bool
    ) async -> DictationOutcome? {
        guard hasRequiredModels else {
            if publishes { state = .failed(.modelsMissing) }
            return nil
        }
        let model = settings.transcriptionModel
        let seconds = Double(samples.count) / AudioRecorder.sampleRate
        let transcript: String
        do {
            transcript = try await run(
                .transcribing,
                estimate: showsProgress
                    ? .transcription(modelID: model.id, defaults: estimates) : nil,
                publishes: publishes,
                units: { seconds },
                work: {
                    let transcriber = try await engines.transcriber(for: model)
                    return try await DictationPipeline(transcriber: transcriber, cleaner: nil)
                        .run(samples: samples).transcript
                })
        } catch DictationError.nothingRecognised {
            if publishes { state = .failed(.nothingRecognised) }
            return nil
        } catch {
            if publishes { state = .failed(.transcriptionFailed(error.localizedDescription)) }
            return nil
        }
        return await finish(
            transcript: transcript, audio: samples, showsProgress: showsProgress,
            prepared: prepared, publishes: publishes)
    }

    /// Cleans up text that system dictation supplied, and keeps the result in the history. Returns
    /// `nil` while a dictation is running, like `process(samples:)`.
    @discardableResult
    public func process(text: String) async -> DictationOutcome? {
        guard !state.isBusy else { return nil }
        let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            state = .failed(.nothingRecognised)
            return nil
        }
        state = .cleaning
        return await queue.run {
            await self.finish(transcript: transcript, audio: nil, showsProgress: false)
        }
    }

    /// Cleans up text out of sight, as `stopRecordingInBackground()` does with a recording.
    /// Internal for the tests, which have no recording to stop.
    func processInBackground(text: String) async -> DictationOutcome? {
        await queue.run {
            await self.finish(
                transcript: text, audio: nil, showsProgress: false, publishes: false)
        }
    }

    /// Runs `work` as `phase`. With an `estimate`, moves `progress` by the time passed over the
    /// duration it expects for the `units` of work, which may be counted alongside — the
    /// cleanup's tokens take about 60 ms —, and learns the duration when `learns` says the
    /// result tells how long a run usually takes. Without `publishes`, only runs `work`.
    /// Internal for the tests.
    func run<Result>(
        _ phase: DictationState, estimate: DurationEstimate?, publishes: Bool = true,
        units: @escaping @MainActor () async -> Double?,
        learns: (Result) -> Bool = { _ in true },
        work: () async throws -> Result
    ) async rethrows -> Result {
        guard publishes else { return try await work() }
        state = phase
        guard let estimate else { return try await work() }
        let start = now()
        progress = 0
        let expected = Expectation(estimate.expectedDuration(units: nil))
        secondsLeft = PhaseProgress.secondsLeft(elapsed: .zero, expected: expected.duration)
        let ticking = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.state == phase else { return }
                let elapsed = Duration.seconds(self.now().timeIntervalSince(start))
                let value = PhaseProgress.value(elapsed: elapsed, expected: expected.duration)
                // A longer expectation, once the units are counted, must not move the bar back.
                self.progress = max(self.progress ?? 0, value)
                self.secondsLeft = PhaseProgress.countdown(
                    after: self.secondsLeft,
                    secondsLeft: PhaseProgress.secondsLeft(
                        elapsed: elapsed, expected: expected.duration))
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let counting = Task {
            let units = await units()
            if let units { expected.duration = estimate.expectedDuration(units: units) }
            return units
        }
        defer {
            ticking.cancel()
            progress = nil
            secondsLeft = nil
        }
        let result = try await work()
        let duration = Duration.seconds(now().timeIntervalSince(start))
        if learns(result), let units = await counting.value {
            estimate.record(duration, units: units)
        }
        return result
    }

    /// The duration the bar runs towards; it changes once the units are counted.
    @MainActor private final class Expectation {
        var duration: Duration
        init(_ duration: Duration) { self.duration = duration }
    }

    /// Returns to the idle state after a result or a failure was shown.
    public func reset() {
        guard !state.isBusy else { return }
        state = .idle
    }

    /// Internal for the tests, which have no recording to stop.
    func finish(
        transcript: String, audio: [Float]?, showsProgress: Bool, prepared: (any Cleaning)? = nil,
        publishes: Bool = true
    ) async -> DictationOutcome {
        var outcome = DictationOutcome(transcript: transcript)
        if settings.cleanupEnabled, let cleaner = prepared ?? cleaner() {
            let uncleaned = outcome
            outcome = await run(
                .cleaning, estimate: showsProgress ? .cleanup(defaults: estimates) : nil,
                publishes: publishes,
                units: { await cleaner.tokenCount(for: transcript).map(Double.init) },
                // Only a cleanup that produced text: a timeout or a refusal says nothing about
                // how long one usually takes.
                learns: { $0.cleaned != nil },
                work: {
                    (try? await DictationPipeline(
                        transcriber: Passthrough(text: transcript), cleaner: cleaner
                    ).run(text: transcript)) ?? uncleaned
                })
        }
        do {
            let entry = try await history.add(
                transcript: outcome.transcript, cleaned: outcome.cleaned, audio: audio, at: now(),
                period: settings.retentionPeriod)
            if entry != nil { onHistoryChange?() }
        } catch {
            // A result that could not be kept is still handed over.
        }
        if publishes { state = .finished(outcome) }
        return outcome
    }
}

/// Runs work one job after another, in the order it was handed in.
@MainActor
private final class SerialQueue {
    private var last: Task<Void, Never>?

    func run<Result: Sendable>(_ work: @escaping @MainActor () async -> Result) async -> Result {
        let previous = last
        let job = Task { @MainActor in
            await previous?.value
            return await work()
        }
        last = Task { @MainActor in _ = await job.value }
        return await job.value
    }
}

private struct Passthrough: Transcribing {
    let text: String
    func transcribe(_ samples: [Float]) async throws -> String { text }
}
