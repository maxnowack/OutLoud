import Foundation
import FoundationModels

/// Why the cleanup produced no text. The cases name the reason only: the texts are personal
/// data and are never part of an error.
public enum CleanerError: Error, Equatable, Sendable {
    case timedOut
    /// The transcript is longer than the cleanup handles in one pass.
    case tooLong
    /// Apple's model refused, e.g. `rateLimited` while the app is in the background or
    /// `unsupportedLanguageOrLocale`.
    case refused(String)
}

/// Whether Apple's on-device model can clean up on this device, and why not
/// (`docs/SPEC.md` §"Cleanup").
public enum CleanupAvailability: Equatable, Sendable {
    case available
    /// The device does not support Apple Intelligence.
    case deviceNotEligible
    /// Apple Intelligence is switched off in the system settings.
    case appleIntelligenceOff
    /// The system is still downloading or preparing the model.
    case modelNotReady

    /// What the system says now; it changes when the user switches Apple Intelligence on or off.
    public static var current: CleanupAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): .appleIntelligenceOff
        case .unavailable: .modelNotReady
        }
    }
}

/// Cleans up with Apple's on-device model through Foundation Models (ADR 0019): a fresh session
/// per text, the instructions and worked examples as earlier turns of it, greedy sampling. The
/// model runs in a system process, so an iOS app may use it in the background, within a budget.
///
/// A cleaner prewarms its first session when it is made, so that the model reads the
/// instructions and examples before the text arrives — while the user still speaks, when it is
/// made at the start of a recording. That halves the cleanup on a Mac
/// (`plans/done/MAC_LOGIN_OVERLAY_PROGRESS.md` §"Problem").
public struct AppleCleaner: Cleaning {
    /// Transcripts longer than this are not cleaned up, so that prompt and answer fit the model's
    /// context (`docs/SPEC.md` §"Scope of the first version": short texts).
    public static let maximumCharacters = 4000

    private let timeout: Duration
    private let prepared = PreparedSession()

    public init(timeout: Duration = .seconds(20)) {
        self.timeout = timeout
    }

    public func clean(_ transcript: String) async throws -> String {
        guard transcript.count <= Self.maximumCharacters else { throw CleanerError.tooLong }
        let session = prepared.take() ?? LanguageModelSession(transcript: Self.examples)
        let prompt = CleanupPrompt.userMessage(for: transcript)
        let options = GenerationOptions(samplingMode: .greedy)
        return try await Self.withDeadline(timeout) {
            do {
                return try await session.respond(to: prompt, options: options).content
            } catch let error as LanguageModelError {
                throw CleanerError.refused(Self.name(of: error))
            }
        }
    }

    /// The prewarmed session, handed out once: a session keeps its turns, so a second text gets
    /// a fresh one.
    private final class PreparedSession: @unchecked Sendable {
        private let lock = NSLock()
        private var session: LanguageModelSession?

        init() {
            let session = LanguageModelSession(transcript: AppleCleaner.examples)
            session.prewarm()
            self.session = session
        }

        func take() -> LanguageModelSession? {
            lock.withLock {
                defer { session = nil }
                return session
            }
        }
    }

    /// Runs `operation`, but throws `CleanerError.timedOut` once `timeout` has passed, whether or
    /// not the operation reacts to its cancellation: a structured task group would wait for it.
    static func withDeadline<Value: Sendable>(
        _ timeout: Duration, _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let race = Race<Value>()
        let work = Task {
            do { race.finish(.success(try await operation())) } catch {
                race.finish(.failure(error))
            }
        }
        let timer = Task {
            guard (try? await Task.sleep(for: timeout)) != nil else { return }
            race.finish(.failure(CleanerError.timedOut))
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.wait(continuation, cancelling: [work, timer])
            }
        } onCancel: {
            race.finish(.failure(CancellationError()))
        }
    }

    /// The instructions and the worked examples as a conversation the session continues: the
    /// model follows demonstrated turns more reliably than examples listed in the instructions
    /// (`plans/APPLE_CLEANUP.md` §"Status").
    private static let examples: Transcript = {
        var entries: [Transcript.Entry] = [
            .instructions(
                .init(segments: [.text(.init(content: CleanupPrompt.system))], toolDefinitions: []))
        ]
        for example in CleanupPrompt.examples {
            entries.append(
                .prompt(
                    .init(segments: [
                        .text(.init(content: CleanupPrompt.userMessage(for: example.transcript)))
                    ])))
            entries.append(
                .response(.init(assetIDs: [], segments: [.text(.init(content: example.cleaned))])))
        }
        return Transcript(entries: entries)
    }()

    private static func name(of error: LanguageModelError) -> String {
        switch error {
        case .contextSizeExceeded: "contextSizeExceeded"
        case .rateLimited: "rateLimited"
        case .guardrailViolation: "guardrailViolation"
        case .refusal: "refusal"
        case .unsupportedCapability: "unsupportedCapability"
        case .unsupportedTranscriptContent: "unsupportedTranscriptContent"
        case .unsupportedGenerationGuide: "unsupportedGenerationGuide"
        case .unsupportedLanguageOrLocale: "unsupportedLanguageOrLocale"
        case .timeout: "timeout"
        @unknown default: "other"
        }
    }
}

/// The first of the operation, the timer and a cancellation to finish wins; the others are
/// cancelled and their results dropped.
private final class Race<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    // Guarded by `lock`.
    private var result: Result<Value, Error>?
    private var continuation: CheckedContinuation<Value, Error>?
    private var tasks: [Task<Void, Never>] = []

    func wait(
        _ continuation: CheckedContinuation<Value, Error>, cancelling tasks: [Task<Void, Never>]
    ) {
        let finished: Result<Value, Error>? = lock.withLock {
            if self.result == nil {
                self.continuation = continuation
                self.tasks = tasks
            }
            return self.result
        }
        if let finished {
            for task in tasks { task.cancel() }
            continuation.resume(with: finished)
        }
    }

    func finish(_ result: Result<Value, Error>) {
        let (continuation, tasks): (CheckedContinuation<Value, Error>?, [Task<Void, Never>]) =
            lock.withLock {
                guard self.result == nil else { return (nil, []) }
                self.result = result
                defer {
                    self.continuation = nil
                    self.tasks = []
                }
                return (self.continuation, self.tasks)
            }
        for task in tasks { task.cancel() }
        continuation?.resume(with: result)
    }
}
