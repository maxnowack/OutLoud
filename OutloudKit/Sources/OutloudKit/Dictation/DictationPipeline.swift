import Foundation
import os

/// Turns 16 kHz mono samples into a transcript.
public protocol Transcribing: Sendable {
    func transcribe(_ samples: [Float]) async throws -> String
}

/// Cleans up a transcript (`docs/SPEC.md` §"Cleanup").
public protocol Cleaning: Sendable {
    func clean(_ transcript: String) async throws -> String
}

/// What one dictation produced.
public struct DictationOutcome: Equatable, Sendable {
    /// What the cleanup did with the transcript.
    public enum Cleanup: Equatable, Sendable {
        /// Cleanup was off or unavailable; the transcript is the result.
        case off
        case cleaned(String)
        /// Cleanup ran but produced no usable text; the transcript is the result.
        case failed
    }

    /// The transcript as it came from transcription or system dictation.
    public let transcript: String
    public let cleanup: Cleanup

    public init(transcript: String, cleanup: Cleanup = .off) {
        self.transcript = transcript
        self.cleanup = cleanup
    }

    /// The cleaned version, when the cleanup succeeded.
    public var cleaned: String? {
        if case .cleaned(let text) = cleanup { text } else { nil }
    }

    /// The text Outloud hands over.
    public var result: String { cleaned ?? transcript }
}

public enum DictationError: Error, Equatable, Sendable {
    /// The recording was too short or silent; nothing was said.
    case nothingRecognised
}

/// Transcription, then cleanup when it is on.
public struct DictationPipeline: Sendable {
    /// Recordings shorter than this are not transcribed.
    public static let minimumSamples = Int(AudioRecorder.sampleRate * 0.3)

    private let transcriber: any Transcribing
    private let cleaner: (any Cleaning)?

    /// - Parameter cleaner: `nil` when cleanup is off.
    public init(transcriber: any Transcribing, cleaner: (any Cleaning)?) {
        self.transcriber = transcriber
        self.cleaner = cleaner
    }

    public func run(samples: [Float]) async throws -> DictationOutcome {
        guard samples.count >= Self.minimumSamples else { throw DictationError.nothingRecognised }
        let transcript = try await transcriber.transcribe(samples)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw DictationError.nothingRecognised }
        return await cleanUp(transcript)
    }

    /// The path of text that system dictation supplied: cleanup only.
    public func run(text: String) async throws -> DictationOutcome {
        let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw DictationError.nothingRecognised }
        return await cleanUp(transcript)
    }

    private func cleanUp(_ transcript: String) async -> DictationOutcome {
        guard let cleaner else { return DictationOutcome(transcript: transcript) }
        let start = ContinuousClock.now
        do {
            let prepared = HesitationFilter.apply(to: transcript)
            let cleaned = CleanupPrompt.sanitize(try await cleaner.clean(prepared))
            guard Self.isUsable(cleaned, for: transcript) else {
                // Lengths and timings only: the texts are personal data.
                Self.log.notice(
                    "cleanup unusable after \(ContinuousClock.now - start, privacy: .public): \(cleaned.count) characters for \(transcript.count)"
                )
                return DictationOutcome(transcript: transcript, cleanup: .failed)
            }
            Self.log.info("cleanup done in \(ContinuousClock.now - start, privacy: .public)")
            return DictationOutcome(transcript: transcript, cleanup: .cleaned(cleaned))
        } catch {
            Self.log.error(
                "cleanup failed after \(ContinuousClock.now - start, privacy: .public): \(String(describing: error), privacy: .public)"
            )
            return DictationOutcome(transcript: transcript, cleanup: .failed)
        }
    }

    private static let log = Logger(subsystem: "dev.nowack.outloud", category: "cleanup")

    /// Cleanup only removes and punctuates. A result that is empty or much longer than the
    /// transcript means the model answered instead of cleaning up, and is not used.
    static func isUsable(_ cleaned: String, for transcript: String) -> Bool {
        !cleaned.isEmpty && cleaned.count <= transcript.count * 3 / 2 + 40
    }
}
