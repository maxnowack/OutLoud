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
            let answer = try await cleaner.clean(prepared)
            let cleaned = CleanupPrompt.sanitize(answer)
            guard Self.isUsable(cleaned, for: prepared) else {
                // Lengths and timings only: the texts are personal data.
                Self.log.notice(
                    "cleanup unusable after \(ContinuousClock.now - start, privacy: .public): \(cleaned.count) characters for \(prepared.count)"
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

    /// Cleanup only removes fillers and corrected passages and punctuates. A result that is
    /// empty or much longer than the text the model read means it answered instead of cleaning
    /// up; one with well under half its words means it dropped what was said, as it does with a
    /// request that follows a statement. Neither is used. The slack of a few words lets a short
    /// text lose a corrected passage. Nor is one that repeats a passage the transcript holds
    /// once: the model lost its place and wrote it again, and what it skipped is lost. Nor is
    /// one that lacks a passage of the transcript that was neither fillers nor corrected, as
    /// when the model runs an unfinished sentence into the next one.
    static func isUsable(_ cleaned: String, for transcript: String) -> Bool {
        !cleaned.isEmpty && cleaned.count <= transcript.count * 3 / 2 + 40
            && wordCount(of: cleaned) * 2 + 6 >= wordCount(of: transcript)
            && !repeatsPassage(cleaned, beyond: transcript)
            && !dropsPassage(of: transcript, from: cleaned)
    }

    private static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// The words of a text, compared without case and punctuation.
    private static func comparableWords(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }
    }

    /// The words of the fillers the prompt deletes, and "also" at the start of a sentence.
    private static let fillerWords = Set(
        (CleanupPrompt.englishFillers + CleanupPrompt.germanFillers + ["also"])
            .flatMap(comparableWords))
    private static let corrections =
        (CleanupPrompt.englishCorrections
        + CleanupPrompt.germanCorrections).map(comparableWords)

    /// Whether `cleaned` lacks four words in a row of `transcript`, not counting fillers, that
    /// no correction phrase in or right after them explains. The words are paired in order as
    /// the texts' longest common subsequence, so a word kept elsewhere does not count as kept.
    private static func dropsPassage(of transcript: String, from cleaned: String) -> Bool {
        let said = comparableWords(in: transcript)
        let longestCorrection = corrections.map(\.count).max() ?? 0
        return gaps(in: said, against: comparableWords(in: cleaned)).contains { gap in
            let around = said[gap.lowerBound..<min(gap.upperBound + longestCorrection, said.count)]
            let corrected = corrections.contains { phrase in
                around.indices.contains { around[$0...].starts(with: phrase) }
            }
            return !corrected && said[gap].filter { !fillerWords.contains($0) }.count >= 4
        }
    }

    /// The stretches of `said` without a counterpart in `kept` when both are paired in order as
    /// their longest common subsequence.
    private static func gaps(in said: [String], against kept: [String]) -> [Range<Int>] {
        // common[i][j]: the length of the longest common subsequence of said[i...] and kept[j...]
        var common = Array(
            repeating: Array(repeating: 0, count: kept.count + 1), count: said.count + 1)
        for i in said.indices.reversed() {
            for j in kept.indices.reversed() {
                common[i][j] =
                    said[i] == kept[j]
                    ? common[i + 1][j + 1] + 1 : max(common[i + 1][j], common[i][j + 1])
            }
        }
        var gaps: [Range<Int>] = []
        var gapStart: Int?
        var i = 0
        var j = 0
        while i < said.count {
            if j < kept.count, said[i] == kept[j] {
                if let start = gapStart { gaps.append(start..<i) }
                gapStart = nil
                i += 1
                j += 1
            } else if j < kept.count, common[i][j + 1] > common[i + 1][j] {
                j += 1
            } else {
                if gapStart == nil { gapStart = i }
                i += 1
            }
        }
        if let start = gapStart { gaps.append(start..<said.count) }
        return gaps
    }

    /// Whether a run of five words occurs more than once in `cleaned` and more often than in
    /// `transcript`. Removing fillers joins words into runs the transcript lacks, so only a
    /// repeated run counts.
    private static func repeatsPassage(_ cleaned: String, beyond transcript: String) -> Bool {
        let inTranscript = runsOfFiveWords(in: transcript)
        return runsOfFiveWords(in: cleaned).contains { run, count in
            count > 1 && count > inTranscript[run, default: 0]
        }
    }

    /// How often each run of five words occurs, compared without case and punctuation.
    private static func runsOfFiveWords(in text: String) -> [String: Int] {
        let words = comparableWords(in: text)
        guard words.count >= 5 else { return [:] }
        var counts: [String: Int] = [:]
        for start in 0...(words.count - 5) {
            counts[words[start..<start + 5].joined(separator: " "), default: 0] += 1
        }
        return counts
    }
}
