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
@MainActor
@Observable
public final class DictationController {
    public private(set) var state: DictationState = .idle
    /// The input level while recording, 0 to 1.
    public private(set) var level: Float = 0
    /// Roughly how far the cleanup is, 0 to 1, while it runs after a recording; `nil` otherwise.
    public private(set) var cleanupProgress: Double?

    @ObservationIgnored private let settings: OutloudSettings
    @ObservationIgnored private let library: ModelLibrary
    @ObservationIgnored private let engines: Engines
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let cleaner: @MainActor () -> (any Cleaning)?
    /// Called after a result was added to the history.
    @ObservationIgnored public var onHistoryChange: (() -> Void)?

    public init(
        settings: OutloudSettings, library: ModelLibrary, engines: Engines, history: HistoryStore,
        now: @escaping () -> Date = Date.init,
        cleaner: @escaping @MainActor () -> (any Cleaning)? = DictationController.appleCleaner
    ) {
        self.settings = settings
        self.library = library
        self.engines = engines
        self.history = history
        self.now = now
        self.cleaner = cleaner
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
    /// - Parameter mixable: Opens a session that mixes with other audio (`AudioRecorder`).
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
        }
        do {
            try recorder.start(mixable: mixable) { [weak self] level in
                Task { @MainActor [weak self] in self?.level = level }
            }
            state = .recording
            return true
        } catch {
            state = .failed(.recordingFailed(error.localizedDescription))
            return false
        }
    }

    /// Ends the recording and processes it.
    @discardableResult
    public func stopRecording() async -> DictationOutcome? {
        guard state == .recording else { return nil }
        let samples = recorder.stop()
        level = 0
        return await transcribe(samples, showsProgress: true)
    }

    /// Ends the recording and drops it.
    public func cancelRecording() {
        guard state == .recording else { return }
        _ = recorder.stop()
        level = 0
        state = .idle
    }

    /// Transcribes and cleans up samples recorded elsewhere — by a shortcut, say — and keeps the
    /// result in the history. Returns `nil` without touching the state while a dictation is
    /// running: it would take over the recording, whose microphone then stays open.
    @discardableResult
    public func process(samples: [Float]) async -> DictationOutcome? {
        guard !state.isBusy else { return nil }
        return await transcribe(samples, showsProgress: false)
    }

    /// - Parameter showsProgress: Publishes `cleanupProgress`. Only where someone sees it: the
    ///   cleanup streams for it, which uses up Apple's budget in the background sooner.
    private func transcribe(_ samples: [Float], showsProgress: Bool) async -> DictationOutcome? {
        guard hasRequiredModels else {
            state = .failed(.modelsMissing)
            return nil
        }
        state = .transcribing
        let transcript: String
        do {
            let transcriber = try await engines.transcriber(for: settings.transcriptionModel)
            transcript = try await DictationPipeline(transcriber: transcriber, cleaner: nil)
                .run(samples: samples).transcript
        } catch DictationError.nothingRecognised {
            state = .failed(.nothingRecognised)
            return nil
        } catch {
            state = .failed(.transcriptionFailed(error.localizedDescription))
            return nil
        }
        return await finish(transcript: transcript, audio: samples, showsProgress: showsProgress)
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
        return await finish(transcript: transcript, audio: nil, showsProgress: false)
    }

    private func advanceCleanupProgress(to value: Double) {
        // Reports arrive out of order across tasks; the bar only moves forward.
        guard state == .cleaning, let current = cleanupProgress, value > current else { return }
        cleanupProgress = value
    }

    /// Returns to the idle state after a result or a failure was shown.
    public func reset() {
        guard !state.isBusy else { return }
        state = .idle
    }

    private func finish(transcript: String, audio: [Float]?, showsProgress: Bool) async
        -> DictationOutcome
    {
        var outcome = DictationOutcome(transcript: transcript)
        if settings.cleanupEnabled, let cleaner = cleaner() {
            state = .cleaning
            cleanupProgress = showsProgress ? 0 : nil
            var progress: (@Sendable (Double) -> Void)?
            if showsProgress {
                progress = { [weak self] value in
                    Task { @MainActor in self?.advanceCleanupProgress(to: value) }
                }
            }
            outcome =
                (try? await DictationPipeline(
                    transcriber: Passthrough(text: transcript), cleaner: cleaner
                ).run(text: transcript, progress: progress)) ?? outcome
            cleanupProgress = nil
        }
        do {
            let entry = try await history.add(
                transcript: outcome.transcript, cleaned: outcome.cleaned, audio: audio, at: now(),
                period: settings.retentionPeriod)
            if entry != nil { onHistoryChange?() }
        } catch {
            // A result that could not be kept is still handed over.
        }
        state = .finished(outcome)
        return outcome
    }
}

private struct Passthrough: Transcribing {
    let text: String
    func transcribe(_ samples: [Float]) async throws -> String { text }
}
