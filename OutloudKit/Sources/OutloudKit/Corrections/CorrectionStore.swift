import Foundation
import Observation

/// Why a correction was not added. The cases name the reason only: an entry is personal data.
public enum CorrectionError: Error, Equatable, Sendable {
    /// A side is empty, too long, across lines or holds `<` or `>` (`Correction.checked`).
    case invalid
    /// An entry already corrects this text.
    case duplicate
    /// The list holds `CorrectionStore.maximumCount` entries.
    case full
    /// The file exists but could not be read; nothing is written over it.
    case unreadable
}

/// The user's corrections on this device (`docs/SPEC.md` §"Corrections", ADR 0039): the one
/// owner of their file, `Corrections.json` in the app's Application Support directory. No other
/// code reads or writes it.
///
/// The file is `{"version": 1, "corrections": [...]}`. One that cannot be read — damaged, with an
/// entry that fails the checks, or of a newer version — leaves the list empty and is never
/// written over, so that a newer app's list or a damaged one is not replaced by nothing.
@MainActor
@Observable
public final class CorrectionStore {
    /// Newest first.
    public private(set) var corrections: [Correction] = []
    /// Whether the file exists but could not be read.
    public private(set) var isUnreadable = false

    /// Bounds the work per result and the size of the file.
    public static let maximumCount = 500
    static let version = 1

    @ObservationIgnored private let file: URL

    public init(file: URL) {
        self.file = file
        do {
            let stored = try Self.decoder.decode(Stored.self, from: Data(contentsOf: file))
            guard stored.version <= Self.version else { throw CorrectionError.unreadable }
            corrections = stored.corrections.sorted { $0.createdAt > $1.createdAt }
        } catch CocoaError.fileReadNoSuchFile {
        } catch {
            isUnreadable = true
        }
    }

    /// The default file in the app's Application Support directory.
    public static func defaultFile(fileManager: FileManager = .default) throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true
        )
        .appending(path: "Outloud/Corrections.json")
    }

    /// Adds what the user entered: a term when `heard` is empty or the same as `meant`.
    @discardableResult
    public func add(heard: String?, meant: String, at date: Date) throws -> Correction {
        guard
            let correction = Correction(heard: heard, meant: meant, origin: .added, createdAt: date)
        else { throw CorrectionError.invalid }
        try insert(correction)
        return correction
    }

    /// Adds a pair learned from the user's edit (ADR 0040), unless an entry already corrects
    /// `heard`, or the pair would undo one: then the edit was the user taking a correction back,
    /// not teaching one.
    public func learn(heard: String, meant: String, at date: Date) -> Correction? {
        guard
            let correction = Correction(
                heard: heard, meant: meant, origin: .learned, createdAt: date),
            correction.heard != nil,
            !corrections.contains(where: {
                Correction.words($0.meant) == Correction.words(heard)
                    && Correction.words($0.pattern) == Correction.words(meant)
            })
        else { return nil }
        do {
            try insert(correction)
            return correction
        } catch {
            return nil
        }
    }

    public func delete(_ id: Correction.ID) throws {
        guard corrections.contains(where: { $0.id == id }) else { return }
        try save(corrections.filter { $0.id != id })
    }

    /// Counts a use of each correction that changed a result.
    public func recordUses(_ ids: Set<Correction.ID>) {
        guard !ids.isEmpty else { return }
        var updated = corrections
        for index in updated.indices where ids.contains(updated[index].id) {
            updated[index].uses += 1
        }
        // A count that could not be saved is lost; the result is not.
        try? save(updated)
    }

    /// `text` with the corrections applied (`Correction.apply`).
    public func apply(to text: String) -> (text: String, used: Set<Correction.ID>) {
        Correction.apply(corrections, to: text)
    }

    private func insert(_ correction: Correction) throws {
        guard !isUnreadable else { throw CorrectionError.unreadable }
        guard corrections.count < Self.maximumCount else { throw CorrectionError.full }
        guard
            !corrections.contains(where: {
                Correction.words($0.pattern) == Correction.words(correction.pattern)
            })
        else { throw CorrectionError.duplicate }
        try save([correction] + corrections)
    }

    private func save(_ updated: [Correction]) throws {
        guard !isUnreadable else { throw CorrectionError.unreadable }
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(Stored(version: Self.version, corrections: updated)).write(
            to: file, options: [.atomic, HistoryStore.fileProtection])
        corrections = updated
    }

    private struct Stored: Codable {
        let version: Int
        let corrections: [Correction]
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
