import Foundation

/// How dictations started and ended on this device, kept to be read out later (ADR 0031): the
/// shortcut's starts fail now and then, in ways only the device shows. The entries hold
/// durations, outcomes and error kinds, never dictated text (`docs/ARCHITECTURE.md` §"Data").
///
/// One line of JSON per entry, the newest last; only the last `limit` entries are kept. A write
/// that fails is dropped: the log must never get in the way of a dictation.
public actor DiagnosticsLog {
    public struct Entry: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable {
            /// The first use of a new process: iOS had ended Outloud, or never started it.
            case launch
            /// A recording started, or did not.
            case start
            /// A recording was processed.
            case end
        }

        /// What started the dictation.
        public enum Trigger: String, Codable, Sendable {
            /// The shortcut, while the user stays in their app (ADR 0022).
            case shortcut
            /// Outloud's record button or the Action Button, with Outloud in front.
            case app
        }

        public var at: Date
        public var kind: Kind
        public var trigger: Trigger?
        /// From the trigger to the recording, for a start; from the stop to the text, for an end.
        public var milliseconds: Int?
        /// `recording`, or why not, for a start; what became of the cleanup, or why there is no
        /// text, for an end.
        public var outcome: String?

        public static func launch(at date: Date) -> Entry {
            Entry(at: date, kind: .launch)
        }

        /// - Parameter state: The dictation's state after the start.
        public static func start(
            at date: Date, trigger: Trigger, after duration: Duration, state: DictationState
        ) -> Entry {
            let outcome =
                switch state {
                case .recording: "recording"
                case .transcribing, .cleaning: "busy"
                case .failed(let failure): name(of: failure)
                case .idle, .finished: "notStarted"
                }
            return Entry(
                at: date, kind: .start, trigger: trigger,
                milliseconds: milliseconds(of: duration), outcome: outcome)
        }

        /// - Parameter state: The dictation's state when it produced no outcome.
        public static func end(
            at date: Date, trigger: Trigger, after duration: Duration, outcome: DictationOutcome?,
            state: DictationState
        ) -> Entry {
            let name =
                switch (outcome?.cleanup, state) {
                case (.cleaned?, _): "cleaned"
                case (.failed?, _): "cleanupFailed"
                case (.off?, _): "cleanupOff"
                case (nil, .failed(let failure)): Self.name(of: failure)
                case (nil, _): "noResult"
                }
            return Entry(
                at: date, kind: .end, trigger: trigger,
                milliseconds: milliseconds(of: duration), outcome: name)
        }

        private static func name(of failure: DictationFailure) -> String {
            switch failure {
            case .microphoneDenied: "microphoneDenied"
            case .modelsMissing: "modelsMissing"
            case .nothingRecognised: "nothingRecognised"
            // The errors' descriptions, which name their domain and code.
            case .recordingFailed(let error): "recordingFailed: \(error)"
            case .transcriptionFailed(let error): "transcriptionFailed: \(error)"
            }
        }

        private static func milliseconds(of duration: Duration) -> Int {
            Int((duration / .milliseconds(1)).rounded())
        }
    }

    public nonisolated let file: URL
    private let limit: Int

    /// Readable once the device was unlocked after starting, also while it is locked again, like
    /// the history: a dictation from the Action Button can run on a locked iPhone.
    static let fileProtection: Data.WritingOptions =
        .completeFileProtectionUntilFirstUserAuthentication

    public init(file: URL, limit: Int = 500) {
        self.file = file
        self.limit = limit
    }

    /// The default file in the app's Application Support directory.
    public static func defaultFile(fileManager: FileManager = .default) throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true
        )
        .appending(path: "Outloud/diagnostics.jsonl")
    }

    public func record(_ entry: Entry) {
        guard let data = try? Self.encoder.encode(entry),
            let line = String(data: data, encoding: .utf8)
        else { return }
        let kept = (lines() + [line]).suffix(limit)
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data((kept.joined(separator: "\n") + "\n").utf8).write(
            to: file, options: [.atomic, Self.fileProtection])
    }

    /// The kept entries, oldest first.
    func entries() -> [Entry] {
        lines().compactMap { try? Self.decoder.decode(Entry.self, from: Data($0.utf8)) }
    }

    private func lines() -> [String] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
