import Foundation

/// One kept result (`docs/SPEC.md` §"History").
public struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    /// The transcript as it came from transcription, not cleaned up.
    public let transcript: String
    /// The cleaned version, when cleanup was on.
    public let cleaned: String?
    /// Whether the entry has the audio of its recording; system dictation has none.
    public let hasAudio: Bool

    public init(
        id: UUID = UUID(), createdAt: Date, transcript: String, cleaned: String?, hasAudio: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.transcript = transcript
        self.cleaned = cleaned
        self.hasAudio = hasAudio
    }

    /// The text Outloud handed over.
    public var result: String { cleaned ?? transcript }
}

extension DictationOutcome {
    /// A kept result, as a result view shows it. The history keeps no failed cleanup; the caller
    /// says whether the entry's cleanup failed.
    public init(entry: HistoryEntry, cleanupFailed: Bool = false) {
        self.init(
            transcript: entry.transcript,
            cleanup: entry.cleaned.map { .cleaned($0) } ?? (cleanupFailed ? .failed : .off))
    }
}

/// The one owner of the history's files (`OutloudKit/AGENTS.md` §"Persistence").
///
/// The folder holds `index.json` and one 16 kHz mono WAV file per entry with audio. Voice
/// recordings and dictated texts are personal data; they stay on the device and are removed when
/// their retention period ends.
public actor HistoryStore {
    public nonisolated let folder: URL
    private var entries: [HistoryEntry]
    /// Set when an index exists but could not be read; the store then refuses to write, so that
    /// it never replaces kept results with an empty list.
    private var unreadableIndex: Error?

    /// Readable once the device was unlocked after starting, also while it is locked again: a
    /// dictation from the Action Button can run on a locked iPhone. Complete protection would
    /// make the index unreadable then.
    static let fileProtection: Data.WritingOptions =
        .completeFileProtectionUntilFirstUserAuthentication

    public init(folder: URL) {
        self.folder = folder
        let index = folder.appending(path: "index.json")
        do {
            let data = try Data(contentsOf: index)
            entries = try Self.decoder.decode([HistoryEntry].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            entries = []
        } catch {
            entries = []
            unreadableIndex = error
        }
    }

    /// The default folder in the app's Application Support directory.
    public static func defaultFolder(fileManager: FileManager = .default) throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true
        )
        .appending(path: "Outloud/History", directoryHint: .isDirectory)
    }

    /// The entries, newest first.
    public func all() -> [HistoryEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    /// Keeps a result, unless the period keeps nothing.
    @discardableResult
    public func add(
        transcript: String, cleaned: String?, audio: [Float]?, at date: Date,
        period: RetentionPeriod
    ) throws -> HistoryEntry? {
        guard period != .nothing else { return nil }
        if let unreadableIndex { throw unreadableIndex }
        let entry = HistoryEntry(
            createdAt: date, transcript: transcript, cleaned: cleaned, hasAudio: audio != nil)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let audio {
            try WAVFile.write(samples: audio, sampleRate: 16_000, to: audioURL(of: entry))
        }
        entries.append(entry)
        try save()
        return entry
    }

    /// The audio of an entry, if it has one.
    public func audioURL(of entry: HistoryEntry) -> URL {
        folder.appending(path: "\(entry.id.uuidString).wav")
    }

    public func delete(_ id: HistoryEntry.ID) throws {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        try removeAudio(of: entry)
        entries.removeAll { $0.id == id }
        try save()
    }

    public func deleteAll() throws {
        for entry in entries { try removeAudio(of: entry) }
        entries.removeAll()
        try save()
    }

    /// Removes every entry whose period has ended by `now`. A shorter period applies to the
    /// entries already kept.
    public func removeExpired(now: Date, period: RetentionPeriod, calendar: Calendar) throws {
        let expired = entries.filter { entry in
            guard let expiry = period.expiry(ofResultCreatedAt: entry.createdAt, in: calendar)
            else { return false }
            return expiry <= now
        }
        guard !expired.isEmpty else { return }
        for entry in expired { try removeAudio(of: entry) }
        let ids = Set(expired.map(\.id))
        entries.removeAll { ids.contains($0.id) }
        try save()
    }

    private func removeAudio(of entry: HistoryEntry) throws {
        let url = audioURL(of: entry)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func save() throws {
        if let unreadableIndex { throw unreadableIndex }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Self.encoder.encode(entries).write(
            to: folder.appending(path: "index.json"), options: [.atomic, Self.fileProtection])
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
