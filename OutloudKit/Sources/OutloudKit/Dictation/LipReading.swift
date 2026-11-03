import Foundation
import NaturalLanguage

/// When the lips are read instead of the voice (`plans/LIP_READING.md`).
public enum LipReadingMode: String, CaseIterable, Sendable {
    /// The camera stays off.
    case off
    /// The camera runs with every recording; the lips are read when the recording holds no
    /// speech.
    case whenSilent
    /// The lips are always read; the sound is not transcribed.
    case silent
}

/// A recording's mouth: greyscale crops of `size` × `size` around the mouth, row-major, at 25
/// frames a second (`OutloudLipreading.MouthCrop`).
public struct MouthFrames: Sendable, Equatable {
    public static let size = 96
    public static let framesPerSecond = 25

    public let pixels: [UInt8]
    public let frames: Int

    public init(pixels: [UInt8], frames: Int) {
        precondition(pixels.count == frames * Self.size * Self.size)
        self.pixels = pixels
        self.frames = frames
    }

    public var seconds: Double { Double(frames) / Double(Self.framesPerSecond) }
}

/// The lip reading the macOS app adds; OutloudKit only decides when to ask it, so that the
/// package's core does not carry the lip-reading model's runtime (ADR 0034).
@MainActor
public protocol LipReading: AnyObject {
    /// Turns the camera on as a recording starts; `false` when it cannot (no camera, no
    /// permission), and the recording goes on with sound alone.
    func startWatching() -> Bool
    /// Turns the camera off as the recording ends: the mouth frames, or `nil` when no face was
    /// seen.
    func stopWatching() async -> MouthFrames?
    /// The text the lips say, in the language of the settings.
    func read(_ frames: MouthFrames) async throws -> String
    /// Keeps the frames of a dictation with sound and its transcript, in the transcript's
    /// language, to learn from.
    func keep(_ frames: MouthFrames, transcript: String, language: String) async
}

/// The languages the lip reader knows, and which of them a dictated text is in.
public enum LipReadingLanguage {
    public static let all = ["de", "en"]
    /// How sure the recogniser must be: a single "Okay." scores 0.93 for English, said in a
    /// German dictation, and a sample in the wrong language teaches the reader wrong words.
    static let certainty = 0.95

    /// "de" or "en" when `text` is surely in it; nil for anything else or too short to tell.
    public static func of(_ text: String) -> String? {
        let recogniser = NLLanguageRecognizer()
        recogniser.languageConstraints = [.german, .english]
        recogniser.processString(text)
        let (language, probability) =
            recogniser.languageHypotheses(withMaximum: 1).first ?? (.undetermined, 0)
        guard probability >= certainty else { return nil }
        switch language {
        case .german: return "de"
        case .english: return "en"
        default: return nil
        }
    }
}
