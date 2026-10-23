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
        let first = library(WaitingFetcher(), defaults: defaults)
        first.download(model, overCellular: true)
        // The app ends here; a new launch reads what was pending.
        let fetcher = WaitingFetcher()
        let second = library(fetcher, defaults: defaults)
        await second.resumeDownloads()
        #expect(second.state(of: model).isDownloading)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!fetcher.overCellular.isEmpty)
        #expect(fetcher.overCellular.allSatisfy { $0 })
        first.cancelDownload(model)
        second.cancelDownload(model)
    }

    @Test func forgetsADownloadTheUserStopped() async throws {
        let defaults = try #require(UserDefaults(suiteName: "\(UUID())"))
        let model = ModelCatalog.parakeetV3
        let first = library(WaitingFetcher(), defaults: defaults)
        first.download(model)
        first.cancelDownload(model)
        try await Task.sleep(for: .milliseconds(100))
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
