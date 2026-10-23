import Foundation

public enum ModelStoreError: Error, Equatable, Sendable {
    /// The volume has less free space than the download needs.
    case insufficientSpace(needed: Int64, available: Int64)
    /// A file's content does not match the hash the catalogue pins.
    case hashMismatch(path: String)
    /// The model is not complete in the cache.
    case notInstalled
}

/// The one owner of the model files (`OutloudKit/AGENTS.md` §"Persistence").
///
/// Files are written in the hub's layout (ADR 0010): each to `blobs/<etag>.incomplete`, checked
/// against the catalogue's hash, renamed to `blobs/<etag>` and linked from the snapshot folder.
/// What another tool already downloaded under the same hash is reused, after a check of its hash.
public actor ModelStore {
    public nonisolated let cache: HubCache
    private let fetcher: any FileFetching
    private let availableCapacity: @Sendable (URL) throws -> Int64
    private let recordURL: URL
    private var record: VerificationRecord

    /// - Parameters:
    ///   - recordURL: Where the store remembers which files it has checked, in the app's own
    ///     storage — never in the shared cache.
    public init(
        cache: HubCache,
        recordURL: URL,
        fetcher: any FileFetching = URLSessionFileFetcher(),
        availableCapacity: @escaping @Sendable (URL) throws -> Int64 = ModelStore.volumeCapacity
    ) {
        self.cache = cache
        self.recordURL = recordURL
        self.fetcher = fetcher
        self.availableCapacity = availableCapacity
        self.record = VerificationRecord.load(from: recordURL)
    }

    /// Whether every file of the model is in the cache with its pinned size. Cheap; no hashing.
    public func isInstalled(_ model: ModelDescriptor) -> Bool {
        model.files.allSatisfy { file in
            size(of: cache.snapshotFile(file, of: model)) == file.size
        }
    }

    /// The bytes still to download for the model.
    public func missingBytes(of model: ModelDescriptor) -> Int64 {
        model.files.reduce(0) { total, file in
            size(of: cache.snapshotFile(file, of: model)) == file.size ? total : total + file.size
        }
    }

    /// The snapshot folder of an installed model, after checking that its files are the pinned
    /// ones. A file is hashed when the store has not checked it yet or it changed since.
    public func verifiedFolder(of model: ModelDescriptor) throws -> URL {
        guard isInstalled(model) else { throw ModelStoreError.notInstalled }
        for file in model.files {
            let url = cache.snapshotFile(file, of: model).resolvingSymlinksInPath()
            let stamp = try FileStamp(of: url)
            if record.files[file.hash.etag] == stamp { continue }
            guard try FileHashing.matches(url, file.hash) else {
                throw ModelStoreError.hashMismatch(path: file.path)
            }
            record.files[file.hash.etag] = stamp
        }
        record.save(to: recordURL)
        return cache.snapshotFolder(of: model)
    }

    /// Downloads every missing file of the model, all at once: a background session goes on with
    /// every file it was given while the app runs in front, but treats files it is given later,
    /// from the background, as postponable. Cancelling the calling task stops the download and
    /// removes the partial files.
    ///
    /// - Parameters:
    ///   - overCellular: Whether the user allowed cellular data (`FileFetching`).
    ///   - progress: Receives the bytes of the model present so far and its total size.
    public func download(
        _ model: ModelDescriptor, overCellular: Bool = false,
        progress: @escaping @Sendable (_ completed: Int64, _ total: Int64) -> Void = { _, _ in }
    ) async throws {
        let total = model.totalSize
        let missing = missingBytes(of: model)
        try FileManager.default.createDirectory(at: cache.root, withIntermediateDirectories: true)
        let available = try availableCapacity(cache.root)
        guard available >= missing else {
            throw ModelStoreError.insufficientSpace(needed: missing, available: available)
        }
        let counter = ProgressCounter(base: total - missing) { progress($0, total) }
        counter.report()
        let files = model.files.filter { size(of: cache.snapshotFile($0, of: model)) != $0.size }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in files {
                group.addTask {
                    try await self.install(file, of: model, overCellular: overCellular) {
                        counter.update(file.path, to: $0)
                    }
                    counter.update(file.path, to: file.size)
                }
            }
            try await group.waitForAll()
        }
    }

    /// The models with a file still downloading from an earlier run of the app.
    public func modelsBeingFetched() async -> [ModelDescriptor] {
        let urls = Set(await fetcher.activeDownloads())
        guard !urls.isEmpty else { return [] }
        return ModelCatalog.all.filter { model in
            model.files.contains { urls.contains(cache.downloadURL($0, of: model)) }
        }
    }

    /// Removes the model's files from its snapshot, and every blob of the repository that no
    /// snapshot refers to any more. Nothing outside the repository folder is touched.
    public func delete(_ model: ModelDescriptor) throws {
        let fileManager = FileManager.default
        let repository = cache.repositoryFolder(of: model.repository)
        for file in model.files {
            let link = cache.snapshotFile(file, of: model)
            if (try? link.checkResourceIsReachable()) == true || isSymlink(link) {
                try fileManager.removeItem(at: link)
            }
            record.files[file.hash.etag] = nil
        }
        removeEmptyFolders(under: cache.snapshotFolder(of: model), keeping: repository)
        let snapshots = repository.appending(path: "snapshots")
        let referenced = referencedBlobs(under: snapshots)
        let blobs = repository.appending(path: "blobs")
        for blob in (try? fileManager.contentsOfDirectory(atPath: blobs.path)) ?? []
        where !blob.hasSuffix(".incomplete") && !referenced.contains(blob) {
            try fileManager.removeItem(at: blobs.appending(path: blob))
        }
        if ((try? fileManager.contentsOfDirectory(atPath: snapshots.path)) ?? []).isEmpty {
            try? fileManager.removeItem(at: repository)
        }
        record.save(to: recordURL)
    }

    // MARK: - Installing one file

    private func install(
        _ file: ModelFile, of model: ModelDescriptor, overCellular: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        let fileManager = FileManager.default
        let blob = cache.blob(file, of: model)
        try fileManager.createDirectory(
            at: blob.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lock = try await FileLock.acquire(at: cache.lock(file, of: model))
        defer { lock.release() }

        if size(of: blob) == file.size, try FileHashing.matches(blob, file.hash) {
            // Another tool has it already.
        } else {
            let partial = blob.appendingPathExtension("incomplete")
            do {
                // A background download may have finished while the app was not running.
                if size(of: partial) != file.size {
                    try await fetcher.fetch(
                        cache.downloadURL(file, of: model), to: partial, overCellular: overCellular,
                        progress: progress)
                }
                try Task.checkCancellation()
                guard try FileHashing.matches(partial, file.hash) else {
                    throw ModelStoreError.hashMismatch(path: file.path)
                }
                if fileManager.fileExists(atPath: blob.path) {
                    try fileManager.removeItem(at: blob)
                }
                try fileManager.moveItem(at: partial, to: blob)
            } catch {
                try? fileManager.removeItem(at: partial)
                throw error
            }
        }
        record.files[file.hash.etag] = try FileStamp(of: blob)
        record.save(to: recordURL)
        try link(file, of: model, to: blob)
    }

    private func link(_ file: ModelFile, of model: ModelDescriptor, to blob: URL) throws {
        let fileManager = FileManager.default
        let link = cache.snapshotFile(file, of: model)
        try fileManager.createDirectory(
            at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        if isSymlink(link) || fileManager.fileExists(atPath: link.path) {
            try fileManager.removeItem(at: link)
        }
        let depth = file.path.split(separator: "/").count + 1
        let target = String(repeating: "../", count: depth) + "blobs/\(file.hash.etag)"
        try fileManager.createSymbolicLink(atPath: link.path, withDestinationPath: target)
    }

    // MARK: - Helpers

    private func size(of url: URL) -> Int64? {
        let resolved = url.resolvingSymlinksInPath()
        let attributes = try? FileManager.default.attributesOfItem(atPath: resolved.path)
        return (attributes?[.size] as? NSNumber)?.int64Value
    }

    private func isSymlink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    private func referencedBlobs(under snapshots: URL) -> Set<String> {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: snapshots.path) else { return [] }
        var names = Set<String>()
        while let relative = enumerator.nextObject() as? String {
            let path = snapshots.appending(path: relative).path
            if let destination = try? fileManager.destinationOfSymbolicLink(atPath: path) {
                names.insert((destination as NSString).lastPathComponent)
            }
        }
        return names
    }

    private func removeEmptyFolders(under folder: URL, keeping stop: URL) {
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(atPath: folder.path) {
            let folders = enumerator.compactMap { $0 as? String }
                .map { folder.appending(path: $0) }
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .sorted { $0.path.count > $1.path.count }
            for candidate in folders
            where ((try? fileManager.contentsOfDirectory(atPath: candidate.path)) ?? ["x"]).isEmpty
            {
                try? fileManager.removeItem(at: candidate)
            }
        }
        if ((try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? ["x"]).isEmpty,
            folder.path.hasPrefix(stop.path)
        {
            try? fileManager.removeItem(at: folder)
        }
    }

    public static let volumeCapacity: @Sendable (URL) throws -> Int64 = { url in
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }
}

/// Sums the bytes of the files downloading at once; reports under its lock, so that the reports
/// only grow.
private final class ProgressCounter: @unchecked Sendable {
    private let base: Int64
    private let send: (Int64) -> Void
    private let lock = NSLock()
    // Guarded by `lock`.
    private var written: [String: Int64] = [:]

    init(base: Int64, report: @escaping (Int64) -> Void) {
        self.base = base
        self.send = report
    }

    func report() {
        lock.withLock { send(base) }
    }

    func update(_ path: String, to bytes: Int64) {
        lock.withLock {
            written[path] = max(written[path] ?? 0, bytes)
            send(base + written.values.reduce(0, +))
        }
    }
}

/// The size and modification date a file had when the store last checked its hash.
struct FileStamp: Codable, Equatable {
    let size: Int64
    let modified: Date

    init(of url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        modified = attributes[.modificationDate] as? Date ?? .distantPast
    }
}

struct VerificationRecord: Codable {
    var files: [String: FileStamp] = [:]

    static func load(from url: URL) -> VerificationRecord {
        guard let data = try? Data(contentsOf: url),
            let record = try? JSONDecoder().decode(VerificationRecord.self, from: data)
        else { return VerificationRecord() }
        return record
    }

    func save(to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
