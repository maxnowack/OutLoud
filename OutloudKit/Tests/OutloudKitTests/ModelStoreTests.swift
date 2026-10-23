import CryptoKit
import Foundation
import Testing

@testable import OutloudKit

/// Serves file contents from memory instead of the network.
private struct FakeFetcher: FileFetching {
    var contents: [String: Data]
    var delay: Duration = .zero

    func fetch(
        _ url: URL, to destination: URL, progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        if delay > .zero { try await Task.sleep(for: delay) }
        guard let data = contents[url.lastPathComponent] else {
            throw FileFetchingError.httpStatus(404)
        }
        try data.write(to: destination)
        progress(Int64(data.count))
    }
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func gitBlob(_ data: Data) -> String {
    var hasher = Insecure.SHA1()
    hasher.update(data: Data("blob \(data.count)\u{0}".utf8))
    hasher.update(data: data)
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

struct ModelStoreTests {
    let root: URL
    let weights = Data(repeating: 7, count: 4096)
    let config = Data(#"{"name":"test"}"#.utf8)
    let model: ModelDescriptor

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ModelStoreTests-\(UUID())")
        model = ModelDescriptor(
            id: "test", purpose: .transcription, displayName: "Test", repository: "org/model",
            revision: "0123456789abcdef0123456789abcdef01234567",
            files: [
                .lfs("Encoder.mlmodelc/weights/weight.bin", size: 4096, sha256: sha256(weights)),
                .git("config.json", size: Int64(config.count), blob: gitBlob(config)),
            ],
            runtime: .parakeet, languages: ["de", "en"], attribution: "")
    }

    private func store(
        fetcher: FakeFetcher? = nil, capacity: Int64 = .max
    ) -> ModelStore {
        ModelStore(
            cache: HubCache(root: root.appending(path: "hub")),
            recordURL: root.appending(path: "record.json"),
            fetcher: fetcher
                ?? FakeFetcher(contents: ["weight.bin": weights, "config.json": config]),
            availableCapacity: { _ in capacity })
    }

    private var repository: URL { root.appending(path: "hub/models--org--model") }

    @Test func downloadsIntoTheHubLayout() async throws {
        let store = store()
        #expect(await store.isInstalled(model) == false)
        try await store.download(model)

        #expect(await store.isInstalled(model))
        let link = repository.appending(
            path: "snapshots/\(model.revision)/Encoder.mlmodelc/weights/weight.bin")
        let target = try FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        #expect(target == "../../../../blobs/\(sha256(weights))")
        #expect(try Data(contentsOf: link) == weights)
        let configLink = repository.appending(path: "snapshots/\(model.revision)/config.json")
        #expect(
            try FileManager.default.destinationOfSymbolicLink(atPath: configLink.path)
                == "../../blobs/\(gitBlob(config))")
        #expect(
            FileManager.default.fileExists(
                atPath: root.appending(
                    path: "hub/.locks/models--org--model/\(sha256(weights)).lock"
                )
                .path))
        #expect(
            try await store.verifiedFolder(of: model).resolvingSymlinksInPath().lastPathComponent
                == model.revision)
    }

    @Test func reportsProgressUpToTheTotalSize() async throws {
        let reports = Reports()
        try await store().download(model) { completed, total in reports.append(completed, total) }
        let last = try #require(reports.values.last)
        #expect(last.0 == model.totalSize && last.1 == model.totalSize)
        #expect(reports.values.map(\.0) == reports.values.map(\.0).sorted())
    }

    @Test func refusesAFileWhoseHashDoesNotMatch() async throws {
        let tampered = FakeFetcher(contents: [
            "weight.bin": Data(repeating: 8, count: 4096), "config.json": config,
        ])
        await #expect(
            throws: ModelStoreError.hashMismatch(path: "Encoder.mlmodelc/weights/weight.bin")
        ) {
            try await store(fetcher: tampered).download(model)
        }
        let blobs =
            (try? FileManager.default.contentsOfDirectory(
                atPath: repository.appending(path: "blobs").path)) ?? []
        #expect(blobs.isEmpty)
    }

    @Test func refusesAFileChangedInTheCacheAfterTheDownload() async throws {
        let store = store()
        try await store.download(model)
        let blob = repository.appending(path: "blobs/\(sha256(weights))")
        try Data(repeating: 9, count: 4096).write(to: blob)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: blob.path)
        await #expect(
            throws: ModelStoreError.hashMismatch(path: "Encoder.mlmodelc/weights/weight.bin")
        ) {
            try await store.verifiedFolder(of: model)
        }
    }

    @Test func refusesToStartWithoutEnoughSpace() async throws {
        await #expect(
            throws: ModelStoreError.insufficientSpace(needed: model.totalSize, available: 100)
        ) {
            try await store(capacity: 100).download(model)
        }
    }

    @Test func reusesABlobAnotherToolDownloaded() async throws {
        let blobs = repository.appending(path: "blobs")
        try FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
        try weights.write(to: blobs.appending(path: sha256(weights)))
        let offline = FakeFetcher(contents: ["config.json": config])
        try await store(fetcher: offline).download(model)
        #expect(await store(fetcher: offline).isInstalled(model))
    }

    @Test func cancellingRemovesThePartialFile() async throws {
        let store = store(
            fetcher: FakeFetcher(
                contents: ["weight.bin": weights, "config.json": config], delay: .seconds(10)))
        let task = Task { try await store.download(model) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        let blobs =
            (try? FileManager.default.contentsOfDirectory(
                atPath: repository.appending(path: "blobs").path)) ?? []
        #expect(blobs.isEmpty)
        #expect(await store.isInstalled(model) == false)
    }

    @Test func deletingRemovesTheModelAndItsRepositoryFolder() async throws {
        let store = store()
        try await store.download(model)
        try await store.delete(model)
        #expect(await store.isInstalled(model) == false)
        #expect(FileManager.default.fileExists(atPath: repository.path) == false)
    }

    @Test func deletingKeepsWhatAnotherToolStillReferences() async throws {
        let store = store()
        try await store.download(model)
        // Another tool's file in the same snapshot, and another revision sharing the weights.
        let snapshot = repository.appending(path: "snapshots/\(model.revision)")
        let other = Data("other".utf8)
        try other.write(to: repository.appending(path: "blobs/\(sha256(other))"))
        try FileManager.default.createSymbolicLink(
            atPath: snapshot.appending(path: "README.md").path,
            withDestinationPath: "../../blobs/\(sha256(other))")
        let revision = repository.appending(path: "snapshots/fedcba/weights")
        try FileManager.default.createDirectory(at: revision, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            atPath: revision.appending(path: "weight.bin").path,
            withDestinationPath: "../../../blobs/\(sha256(weights))")

        try await store.delete(model)

        #expect(FileManager.default.fileExists(atPath: snapshot.appending(path: "README.md").path))
        #expect(
            FileManager.default.fileExists(
                atPath: repository.appending(path: "blobs/\(sha256(weights))").path))
        #expect(
            FileManager.default.fileExists(
                atPath: repository.appending(path: "blobs/\(gitBlob(config))").path) == false)
        #expect(
            FileManager.default.fileExists(
                atPath: snapshot.appending(path: "Encoder.mlmodelc").path) == false)
    }

    #if os(macOS)
        @Test func resolvesTheSharedCacheAsTheHubDoes() {
            let home = URL(filePath: "/Users/someone")
            #expect(
                HubCache.shared(environment: [:], home: home).root.path
                    == "/Users/someone/.cache/huggingface/hub")
            #expect(
                HubCache.shared(environment: ["HF_HOME": "/data/hf"], home: home).root.path
                    == "/data/hf/hub")
            #expect(
                HubCache.shared(environment: ["HF_HOME": "~/hf"], home: home).root.path
                    == "/Users/someone/hf/hub")
            #expect(
                HubCache.shared(
                    environment: ["HF_HOME": "/data/hf", "HF_HUB_CACHE": "/cache"], home: home
                ).root.path
                    == "/cache")
        }
    #endif

    @Test func pinsEveryCatalogueFileToAHash() {
        for model in ModelCatalog.all {
            #expect(!model.files.isEmpty)
            for file in model.files {
                switch file.hash {
                case .sha256(let value): #expect(value.count == 64)
                case .gitBlob(let value): #expect(value.count == 40)
                }
            }
            #expect(model.revision.count == 40)
        }
    }
}

private final class Reports: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [(Int64, Int64)] = []
    var values: [(Int64, Int64)] { lock.withLock { storage } }
    func append(_ completed: Int64, _ total: Int64) {
        lock.withLock { storage.append((completed, total)) }
    }
}
