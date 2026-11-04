import Foundation
import OutloudKit
import os

/// The Mac's lip reading: the camera with each recording, the model and the training samples
/// (`plans/LIP_READING.md`, ADR 0034).
@MainActor
public final class CameraLipReading: LipReading {
    private let files: LipReadingFiles
    private let settings: OutloudSettings
    private let camera = Camera()
    private var readers: [String: LipReader] = [:]
    /// Called after a sample was kept, so that the coach counts it.
    public var onSampleKept: (() -> Void)?
    private static let log = Logger(subsystem: "dev.nowack.outloud", category: "lipreading")

    public init(files: LipReadingFiles, settings: OutloudSettings) {
        self.files = files
        self.settings = settings
    }

    public enum ReadError: Error { case noModel(String) }

    /// Whether the camera may be used; asks the user the first time.
    public static func requestCameraAccess() async -> Bool { await Camera.requestAccess() }
    public static var cameraAllowed: Bool { Camera.isAllowed }

    public func startWatching() -> Bool {
        guard Camera.isAllowed else {
            Task { _ = await Camera.requestAccess() }
            return false
        }
        do {
            try camera.start()
            return true
        } catch {
            Self.log.error("camera did not start: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    public func stopWatching() async -> MouthFrames? {
        await camera.stop()
    }

    public func read(_ frames: MouthFrames) async throws -> String {
        let reader = try reader(language: settings.lipReadingLanguage)
        let start = ContinuousClock.now
        let text = try await Task.detached(priority: .userInitiated) { try reader.read(frames) }
            .value
        Self.log.info(
            "read \(frames.frames) frames in \(ContinuousClock.now - start, privacy: .public)")
        return LipText.readable(text, language: reader.language)
    }

    public func keep(_ frames: MouthFrames, transcript: String, language: String) async {
        let files = files
        let date = Date()
        do {
            _ = try await Task.detached(priority: .utility) {
                try files.keep(
                    frames, text: transcript, language: language, silent: false, date: date)
            }.value
            onSampleKept?()
        } catch {
            Self.log.error("sample not kept: \(String(describing: error), privacy: .public)")
        }
    }

    /// Starts the camera for a silent practice sentence (`plans/LIP_READING.md` §"Phase 5").
    public func startPractice() -> Bool { startWatching() }

    /// Ends a practice sentence and keeps it as a silent sample; `false` when no face was seen.
    public func finishPractice(sentence: String) async -> Bool {
        guard let frames = await stopWatching() else { return false }
        let (files, language, date) = (files, settings.lipReadingLanguage, Date())
        let kept = await Task.detached(priority: .utility) {
            (try? files.keep(frames, text: sentence, language: language, silent: true, date: date))
                != nil
        }.value
        if kept { onSampleKept?() }
        return kept
    }

    /// Ends a practice sentence without keeping it.
    public func cancelPractice() async { _ = await stopWatching() }

    /// The loaded reader of a language, with the user's adapter where one was learned.
    func reader(language: String) throws -> LipReader {
        if let reader = readers[language] { return reader }
        guard files.hasModel(language: language) else { throw ReadError.noModel(language) }
        let reader = try LipReader.forReading(files: files, language: language)
        readers[language] = reader
        return reader
    }

    /// Drops the loaded readers, after an adapter was learned or deleted.
    public func reload() { readers = [:] }
}

/// The lip reader writes upper case without punctuation, as its training labels; the cleanup
/// sets the punctuation, this the case it can be sure of.
public enum LipText {
    static func readable(_ text: String, language: String) -> String {
        var words = text.lowercased().split(separator: " ").map(String.init)
        if language == "en" {
            words = words.map { $0 == "i" || $0.hasPrefix("i'") ? "I" + $0.dropFirst() : $0 }
        }
        guard let first = words.first else { return "" }
        words[0] = first.prefix(1).uppercased() + first.dropFirst()
        return words.joined(separator: " ")
    }
}
