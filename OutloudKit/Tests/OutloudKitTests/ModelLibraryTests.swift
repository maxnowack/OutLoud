import Foundation
import Testing

@testable import OutloudKit

/// Records how it was asked to fetch, and never finishes on its own.
private final class WaitingFetcher: FileFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var cellular: [Bool] = []

    var overCellular: [Bool] { lock.withLock { cellular } }

    func fetch(
        _ url: URL, to destination: URL, overCellular: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        lock.withLock { cellular.append(overCellular) }
        try await Task.sleep(for: .seconds(60))
    }
}

@MainActor
struct ModelLibraryTests {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "ModelLibraryTests-\(UUID())")

    private func library(_ fetcher: WaitingFetcher, defaults: UserDefaults) -> ModelLibrary {
        ModelLibrary(
            store: ModelStore(
                cache: HubCache(root: root.appending(path: "hub")),
                recordURL: root.appending(path: "record.json"), fetcher: fetcher,
                availableCapacity: { _ in .max }),
            defaults: defaults)
    }

    @Test func goesOnWithADownloadTheAppDidNotFinish() async throws {
        let defaults = try #require(UserDefaults(suiteName: "\(UUID())"))
        let model = ModelCatalog.parakeetV3
        // What an ended app leaves behind: the pending download, and no file locks.
        defaults.set([model.id: true], forKey: "pendingDownloads")
        let fetcher = WaitingFetcher()
        let library = library(fetcher, defaults: defaults)
        await library.resumeDownloads()
        #expect(library.state(of: model).isDownloading)
        let deadline = ContinuousClock.now + .seconds(5)
        while fetcher.overCellular.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!fetcher.overCellular.isEmpty)
        #expect(fetcher.overCellular.allSatisfy { $0 })
        library.cancelDownload(model)
    }

    @Test func forgetsADownloadTheUserStopped() async throws {
        let defaults = try #require(UserDefaults(suiteName: "\(UUID())"))
        let model = ModelCatalog.parakeetV3
        let first = library(WaitingFetcher(), defaults: defaults)
        first.download(model)
        first.cancelDownload(model)
        let deadline = ContinuousClock.now + .seconds(5)
        while first.state(of: model).isDownloading, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let second = library(WaitingFetcher(), defaults: defaults)
        await second.resumeDownloads()
        #expect(!second.state(of: model).isDownloading)
    }

    @Test func keepsDownloadDestinationsRelativeToTheHomeFolder() {
        let destination = URL(filePath: NSHomeDirectory()).appending(path: "Library/x.incomplete")
        let description = URLSessionFileFetcher.describe(destination)
        #expect(description == "~/Library/x.incomplete")
        #expect(URLSessionFileFetcher.resolve(description)?.path == destination.path)
        #expect(URLSessionFileFetcher.resolve("/tmp/y")?.path == "/tmp/y")
        #expect(URLSessionFileFetcher.resolve("relative") == nil)
    }
}
