import Foundation
import Observation
import os

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

    @ObservationIgnored private let settings: OutloudSettings
    @ObservationIgnored private let library: ModelLibrary
    @ObservationIgnored private let engines: Engines
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let now: () -> Date
    /// Called after a result was added to the history.
    @ObservationIgnored public var onHistoryChange: (() -> Void)?

    public init(
        settings: OutloudSettings, library: ModelLibrary, engines: Engines, history: HistoryStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.settings = settings
        self.library = library
        self.engines = engines
        self.history = history
        self.now = now
    }

    /// Whether the models the current settings need are installed.
    public var hasRequiredModels: Bool {
        library.state(of: settings.transcriptionModel).isInstalled
            && (!settings.cleanupEnabled || library.state(of: settings.cleanupModel).isInstalled)
    }

    /// Loads the models ahead of the first dictation.
    public func preloadModels() async {
        guard hasRequiredModels else { return }
        await engines.preload(settings.transcriptionModel)
        if settings.cleanupEnabled { await engines.preload(settings.cleanupModel) }
    }

    /// Starts a recording. Returns `false` and sets a failed state when it cannot start.
    @discardableResult
    public func startRecording() async -> Bool {
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
            try recorder.start { [weak self] level in
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
        return await process(samples: samples)
    }

    /// Ends the recording and drops it.
    public func cancelRecording() {
        guard state == .recording else { return }
        _ = recorder.stop()
        level = 0
        state = .idle
    }

    /// Transcribes and cleans up recorded samples, and keeps the result in the history.
    @discardableResult
    public func process(samples: [Float]) async -> DictationOutcome? {
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
        return await finish(transcript: transcript, audio: samples)
    }

    /// Cleans up text that system dictation supplied, and keeps the result in the history.
    @discardableResult
    public func process(text: String) async -> DictationOutcome? {
        let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            state = .failed(.nothingRecognised)
            return nil
        }
        return await finish(transcript: transcript, audio: nil)
    }

    /// Returns to the idle state after a result or a failure was shown.
    public func reset() {
        guard !state.isBusy else { return }
        state = .idle
    }

    private func finish(transcript: String, audio: [Float]?) async -> DictationOutcome {
        var outcome = DictationOutcome(transcript: transcript, cleaned: nil)
        if settings.cleanupEnabled, library.state(of: settings.cleanupModel).isInstalled {
            state = .cleaning
            let cleaner: (any Cleaning)?
            do {
                cleaner = try await engines.cleaner(for: settings.cleanupModel)
            } catch {
                Self.log.error(
                    "cleanup model failed to load: \(String(describing: error), privacy: .public)")
                cleaner = nil
            }
            if let cleaner {
                outcome =
                    (try? await DictationPipeline(
                        transcriber: Passthrough(text: transcript), cleaner: cleaner
                    ).run(text: transcript)) ?? outcome
            } else {
                outcome = DictationOutcome(
                    transcript: transcript, cleaned: nil, cleanupFailed: true)
            }
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

extension DictationController {
    fileprivate static let log = Logger(
        subsystem: "io.github.maxnowack.outloud", category: "dictation")
}

private struct Passthrough: Transcribing {
    let text: String
    func transcribe(_ samples: [Float]) async throws -> String { text }
}
